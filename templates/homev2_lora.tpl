{ "model" : "homeV2Lora", "board": "senseBox:samd:sb" }
/*
  senseBox:home - Citizen Sensingplatform
  Version: lorav2_1.6.0
  Date: 2022-03-04
  Homepage: https://www.sensebox.de https://www.opensensemap.org
  Author: Reedu GmbH & Co. KG
  Note: Sketch for senseBox:home LoRa MCU Edition
  Model: homeV2lora
  Email: support@sensebox.de
  Code is in the public domain.
  https://github.com/sensebox/node-sketch-templater
*/
#include <LoraMessage.h>
#include <lmic.h>
#include <hal/hal.h>
#include <SPI.h>
#include <senseBoxIO.h>

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_HDC1000.h>
#include <Adafruit_BMP280.h>
#include <Adafruit_BME680.h>
#include <VEML6070.h>
#include <SdsDustSensor.h>
#include <SparkFun_SCD30_Arduino_Library.h>
#include <LTR329.h>
#include <Adafruit_DPS310.h> // http://librarymanager/All#Adafruit_DPS310


// Uncomment the next line to get debugging messages printed on the Serial port
// Do not leave this enabled for long time use
// #define ENABLE_DEBUG

#ifdef ENABLE_DEBUG
#define DEBUG(str) Serial.println(str)
#else
#define DEBUG(str)
#endif

/* ------------------------------------------------------------------------- */
/* ---------------------------------Metadata-------------------------------- */
/* ------------------------------------------------------------------------- */
/* SENSEBOX ID  : @@SENSEBOX_ID@@                                            */
/* SENSEBOX NAME: @@SENSEBOX_NAME@@                                          */
/* ------------------------------------------------------------------------- */
/* ------------------------------End of Metadata---------------------------- */
/* ------------------------------------------------------------------------- */

// Connected sensors
@@SENSORS|toDefineWithSuffixPrefixAndKey~,_CONNECTED,sensorType@@

// Display enabled
// Uncomment the next line to get values of measurements printed on display
@@DISPLAY_ENABLED|toDefineDisplay@@

// Number of serial port the SDS011 is connected to. Either Serial1 or Serial2
#ifdef SDS011_CONNECTED
#define SDS_UART_PORT (@@SERIAL_PORT@@)
#endif

//Load sensors / instances
#ifdef HDC1080_CONNECTED
  Adafruit_HDC1000 HDC = Adafruit_HDC1000();
  float temperature = 0;
  float humidity = 0;
#endif
#ifdef BMP280_CONNECTED
  Adafruit_BMP280 BMP;
  double pressure;
#endif
#ifdef TSL45315_CONNECTED
  uint32_t lux;
  // no declaration
  bool lightsensortype = 0; //0 for tsl - 1 for ltr
  //settings for LTR sensor
  LTR329 LTR;
  unsigned char gain = 1;
  unsigned char integrationTime = 0;
  unsigned char measurementRate = 3;
#endif
#ifdef VEML6070_CONNECTED
  VEML6070 VEML;
  uint16_t uv;
#endif
#ifdef SDS011_CONNECTED
  SdsDustSensor sds(SDS_UART_PORT);
#endif
#ifdef SMT50_CONNECTED
  #define SOILTEMPPIN @@SOIL_DIGITAL_PORT|digitalPortToPortNumber@@
  #define SOILMOISPIN @@SOIL_DIGITAL_PORT|digitalPortToPortNumber~1@@
#endif
#ifdef SOUNDLEVELMETER_CONNECTED
  #define SOUNDMETERPIN @@SOUND_METER_PORT|digitalPortToPortNumber@@
#endif
#ifdef BME680_CONNECTED
  Adafruit_BME680 BME;
#endif
#ifdef WINDSPEED_CONNECTED
  #define WINDSPEEDPIN @@WIND_DIGITAL_PORT|digitalPortToPortNumber@@
#endif
#ifdef SCD30_CONNECTED
  SCD30 SCD;
#endif
#ifdef DISPLAY128x64_CONNECTED
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET 4
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
#endif
#ifdef DPS310_CONNECTED
  Adafruit_DPS310 dps;
#endif

// This EUI must be in little-endian format, so least-significant-byte (lsb)
// first. When copying an EUI from ttnctl output, this means to reverse
// the bytes.
static const u1_t PROGMEM DEVEUI[8]= @@DEV_EUI|transformTTNID~true@@;
void os_getDevEui (u1_t* buf) { memcpy_P(buf, DEVEUI, 8);}

// This EUI must be in little-endian format, so least-significant-byte (lsb)
// first. When copying an EUI from ttnctl output, this means to reverse
// the bytes. For TTN issued EUIs the last bytes should be 0xD5, 0xB3,
// 0x70.
static const u1_t PROGMEM APPEUI[8]= @@APP_EUI|transformTTNID~true@@;
void os_getArtEui (u1_t* buf) { memcpy_P(buf, APPEUI, 8);}

// This key should be in big endian format (msb) (or, since it is not really a
// number but a block of memory, endianness does not really apply). In
// practice, a key taken from ttnctl can be copied as-is.
// The key shown here is the semtech default key.
static const u1_t PROGMEM APPKEY[16] = @@APP_KEY|transformTTNID@@;
void os_getDevKey (u1_t* buf) {  memcpy_P(buf, APPKEY, 16);}

static osjob_t sendjob;
#ifdef DISPLAY128x64_CONNECTED
  static osjob_t displayjob;
#endif


// Schedule TX every this many seconds (might become longer due to duty
// cycle limitations).
const unsigned TX_INTERVAL = 60;
#ifdef DISPLAY128x64_CONNECTED
  const unsigned DISPLAY_INTERVAL = 5; // update display each 5 seconds
  int unsigned displayPage = 0;
#endif

// Pin mapping
const lmic_pinmap lmic_pins = {
  .nss = PIN_XB1_CS,
  .rxtx = LMIC_UNUSED_PIN,
  .rst = LMIC_UNUSED_PIN,
  .dio = {PIN_XB1_INT, PIN_XB1_INT, LMIC_UNUSED_PIN},
};

void onEvent (ev_t ev) {
  senseBoxIO.statusGreen();
  DEBUG(os_getTime());
  switch(ev) {
    case EV_SCAN_TIMEOUT:
      DEBUG(F("EV_SCAN_TIMEOUT"));
      break;
    case EV_BEACON_FOUND:
      DEBUG(F("EV_BEACON_FOUND"));
      break;
    case EV_BEACON_MISSED:
      DEBUG(F("EV_BEACON_MISSED"));
      break;
    case EV_BEACON_TRACKED:
      DEBUG(F("EV_BEACON_TRACKED"));
      break;
    case EV_JOINING:
      DEBUG(F("EV_JOINING"));
      break;
    case EV_JOINED:
      DEBUG(F("EV_JOINED"));

      // Disable link check validation (automatically enabled
      // during join, but not supported by TTN at this time).
      LMIC_setLinkCheckMode(0);
      break;
    case EV_RFU1:
      DEBUG(F("EV_RFU1"));
      break;
    case EV_JOIN_FAILED:
      DEBUG(F("EV_JOIN_FAILED"));
      break;
    case EV_REJOIN_FAILED:
      DEBUG(F("EV_REJOIN_FAILED"));
      break;
    case EV_TXCOMPLETE:
      DEBUG(F("EV_TXCOMPLETE (includes waiting for RX windows)"));
      if (LMIC.txrxFlags & TXRX_ACK)
        DEBUG(F("Received ack"));
      if (LMIC.dataLen) {
        DEBUG(F("Received "));
        DEBUG(LMIC.dataLen);
        DEBUG(F(" bytes of payload"));
      }
      // Schedule next transmission
      os_setTimedCallback(&sendjob, os_getTime()+sec2osticks(TX_INTERVAL), do_send);
      break;
    case EV_LOST_TSYNC:
      DEBUG(F("EV_LOST_TSYNC"));
      break;
    case EV_RESET:
      DEBUG(F("EV_RESET"));
      break;
    case EV_RXCOMPLETE:
      // data received in ping slot
      DEBUG(F("EV_RXCOMPLETE"));
      break;
    case EV_LINK_DEAD:
      DEBUG(F("EV_LINK_DEAD"));
      break;
    case EV_LINK_ALIVE:
      DEBUG(F("EV_LINK_ALIVE"));
      break;
    default:
      DEBUG(F("Unknown event"));
      break;
  }
}

void do_send(osjob_t* j){
  // Check if there is not a current TX/RX job running
  if (LMIC.opmode & OP_TXRXPEND) {
    DEBUG(F("OP_TXRXPEND, not sending"));
  } else {
    LoraMessage message;

    //-----Temperature-----//
    //-----Humidity-----//
    #ifdef HDC1080_CONNECTED
      DEBUG(F("Temperature: "));
      temperature = HDC.readTemperature();
      DEBUG(temperature);
      message.addUint16((temperature + 18) * 771);
      delay(2000);

      DEBUG(F("Humidity: "));
      humidity = HDC.readHumidity();
      DEBUG(humidity);
      message.addHumidity(humidity);
      delay(2000);
    #endif

    //-----Pressure-----//
    #ifdef BMP280_CONNECTED
      float altitude;
      pressure = BMP.readPressure()/100;
      altitude = BMP.readAltitude(1013.25); //1013.25 = sea level pressure
      DEBUG(F("Pressure: "));
      DEBUG(pressure);
      message.addUint16((pressure - 300) * 81.9187);
      delay(2000);
    #endif

    //-----Lux-----//
    #ifdef TSL45315_CONNECTED
      DEBUG(F("Illuminance: "));
      lux = Lightsensor_getIlluminance();
      DEBUG(lux);
      message.addUint8(lux % 255);
      message.addUint16(lux / 255);
      delay(2000);
    #endif

    //-----UV intensity-----//
    #ifdef VEML6070_CONNECTED
      DEBUG(F("UV: "));
      uv = VEML.getUV();
      DEBUG(uv);
      message.addUint8(uv % 255);
      message.addUint16(uv / 255);
      delay(2000);
    #endif

    //-----PM-----//
    #ifdef SDS011_CONNECTED
      mResult pm = sds.queryPm();
      float pm10, pm25;
      pm10 = pm.pm10;
      pm25 = pm.pm25;
      addMeasurement(SDS011_PM10SENSOR_ID, pm10);
      addMeasurement(SDS011_PM25SENSOR_ID, pm25);
    #endif

    //-----Soil Temperature & Moisture-----//
    #ifdef SMT50_CONNECTED
      float voltage = analogRead(SOILTEMPPIN) * (3.3 / 1024.0);
      float soilTemperature = (voltage - 0.5) * 100;
      message.addUint16((soilTemperature + 18) * 771);
      voltage = analogRead(SOILMOISPIN) * (3.3 / 1024.0);
      float soilMoisture = (voltage * 50) / 3;
      message.addHumidity(soilMoisture);
    #endif

    //-----dB(A) Sound Level-----//
    #ifdef SOUNDLEVELMETER_CONNECTED
      float v = analogRead(SOUNDMETERPIN) * (3.3 / 1024.0);
      float decibel = v * 50;
      message.addUint16(decibel * 10);
    #endif

    //-----BME680-----//
    #ifdef BME680_CONNECTED
      BME.setGasHeater(0, 0);
      if( BME.performReading()) {
        message.addUint16((BME.temperature-1 + 18) * 771);
        message.addHumidity(BME.humidity);
        message.addUint16((BME.pressure/100 - 300) * 81.9187);
      }
      delay(100);
      BME.setGasHeater(320, 150); // 320*C for 150 ms
      if( BME.performReading()) {
        uint16_t gasResistance = BME.gas_resistance / 1000.0;
        message.addUint8(gasResistance % 255);
        message.addUint16(gasResistance / 255);
      }
    #endif

    //-----Wind speed-----//
    #ifdef WINDSPEED_CONNECTED
      float voltageWind = analogRead(WINDSPEEDPIN) * (3.3 / 1024.0);
      float windspeed = 0.0;
      if (voltageWind >= 0.018){
        float poly1 = pow(voltageWind, 3);
        poly1 = 17.0359801998299 * poly1;
        float poly2 = pow(voltageWind, 2);
        poly2 = 47.9908168343362 * poly2;
        float poly3 = 122.899677524413 * voltageWind;
        float poly4 = 0.657504127272728;
        windspeed = poly1 - poly2 + poly3 - poly4;
        windspeed = windspeed * 0.2777777777777778; //conversion in m/s
      }
      message.addUint16(windspeed * 10);
    #endif

    //-----CO2-----//
    #ifdef SCD30_CONNECTED
      message.addUint16(SCD.getCO2());
    #endif

    //-----DPS310 Pressure-----//
    #ifdef DPS310_CONNECTED
      sensors_event_t temp_event, pressure_event;
      dps.getEvents(&temp_event, &pressure_event);
      message.addUint16((pressure_event.pressure - 300) * 81.9187);
    #endif

    // Prepare upstream data transmission at the next possible time.
    LMIC_setTxData2(1, message.getBytes(), message.getLength(), 0);
    DEBUG(F("Packet queued"));
  }
  // Next TX is scheduled after TX_COMPLETE event.
}

#ifdef DISPLAY128x64_CONNECTED
void update_display(osjob_t* t) {

  display.clearDisplay();
  display.setCursor(0, 0);
  display.setTextSize(1);
  display.setTextColor(WHITE, BLACK);
  switch (displayPage)
  {
    case 0:
      {
        // HDC & BMP
        display.setTextSize(2);
        display.setTextColor(BLACK, WHITE);
        display.println(F("HDC&BMP"));
        display.setTextColor(WHITE, BLACK);
        display.setTextSize(1);
        display.print(F("Temp:"));
#ifdef HDC1080_CONNECTED
        display.println(HDC.readTemperature());
#else
        display.println(F("not connected"));
#endif
        display.println();
        display.print(F("Humi:"));
#ifdef HDC1080_CONNECTED
        display.println(HDC.readHumidity());
#else
        display.println(F("not connected"));
#endif
        display.println();
        display.print(F("Press.:"));
#ifdef BMP280_CONNECTED
        display.println(BMP.readPressure() / 100);
#else
        display.println(F("not connected"));
#endif
      }
      break;
    case 1:
      {
        // TSL/VEML
        display.setTextSize(2);
        display.setTextColor(BLACK, WHITE);
        display.println(F("TSL&VEML"));
        display.setTextColor(WHITE, BLACK);
        display.println();
        display.setTextSize(1);
        display.print(F("Lux:"));
#ifdef TSL45315_CONNECTED
        display.println(Lightsensor_getIlluminance());
#else
        display.println(F("not connected"));
#endif
        display.println();
        display.print("UV:");
#ifdef VEML6070_CONNECTED
        display.println(VEML.getUV());
#else
        display.println(F("not connected"));
#endif
      }
      break;
    case 2:
      {
        // SMT, SOUND LEVEL , BME
        display.setTextSize(2);
        display.setTextColor(BLACK, WHITE);
        display.println(F("Soil"));
        display.setTextColor(WHITE, BLACK);
        display.println();
        display.setTextSize(1);
        display.print(F("Temp:"));
#ifdef SMT50_CONNECTED
        float volt = analogRead(SOILTEMPPIN) * (3.3 / 1024.0);
        float soilTemperature = (volt - 0.5) * 100;
        display.println(soilTemperature);
#else
        display.println(F("not connected"));
#endif
        display.println();
        display.print(F("Moist:"));
#ifdef SMT50_CONNECTED
        volt = analogRead(SOILMOISPIN) * (3.3 / 1024.0);
        float soilMoisture = (volt * 50) / 3;
        display.println(soilMoisture);
#else
        display.println(F("not connected"));
#endif
      }
      break;
    case 3:
      {
        // WINDSPEED SCD30
        display.setTextSize(2);
        display.setTextColor(BLACK, WHITE);
        display.println(F("Wind&SCD30"));
        display.setTextColor(WHITE, BLACK);
        display.println();
        display.setTextSize(1);
        display.print(F("Speed:"));
#ifdef WINDSPEED_CONNECTED
        float voltageWind = analogRead(WINDSPEEDPIN) * (3.3 / 1024.0);
        float windspeed = 0.0;
        if (voltageWind >= 0.018) {
          float poly1 = pow(voltageWind, 3);
          poly1 = 17.0359801998299 * poly1;
          float poly2 = pow(voltageWind, 2);
          poly2 = 47.9908168343362 * poly2;
          float poly3 = 122.899677524413 * voltageWind;
          float poly4 = 0.657504127272728;
          windspeed = poly1 - poly2 + poly3 - poly4;
          windspeed = windspeed * 0.2777777777777778; //conversion in m/s
        }
        display.println(windspeed);
#else
        display.println(F("not connected"));
#endif
        display.println();
        display.print(F("SCD30:"));
#ifdef SCD30_CONNECTED
        display.println(SCD.getCO2());
#else
        display.println(F("not connected"));
#endif
      }
      break;
    case 4:
      {
        // SMT, SOUND LEVEL , BME
        display.setTextSize(2);
        display.setTextColor(BLACK, WHITE);
        display.println(F("Sound&BME"));
        display.setTextColor(WHITE, BLACK);
        display.println();
        display.setTextSize(1);
        display.print(F("Sound:"));
#ifdef SOUNDLEVELMETER_CONNECTED
        float v = analogRead(SOUNDMETERPIN) * (3.3 / 1024.0);
        float decibel = v * 50;
        display.println(decibel);
#else
        display.println(F("not connected"));
#endif
        display.println();
        display.print(F("Gas:"));
#ifdef BME680_CONNECTED
        uint16_t gasResistance = 0;
        delay(100);
        BME.setGasHeater(320, 150); // 320*C for 150 ms
        if ( BME.performReading()) {
          uint16_t gasResistance = BME.gas_resistance / 1000.0;
        }
        display.println(gasResistance);
#else
        display.print(F("not connected"));
#endif
      }
      break;
  }
  display.display();


  if (displayPage == 4) {
    displayPage = 0;
  }
  else {
    displayPage++;
  }

  os_setTimedCallback(&displayjob, os_getTime() + sec2osticks(DISPLAY_INTERVAL), update_display);
}
#endif

void setup() {
  #ifdef ENABLE_DEBUG
    Serial.begin(9600);
  #endif
  delay(3000);

  // RFM9X (LoRa-Bee) in XBEE1 Socket
  senseBoxIO.powerXB1(false); // power off to reset RFM9X
  delay(250);
  senseBoxIO.powerXB1(true);  // power on
  delay(200);
  senseBoxIO.powerUART(true);

  // Sensor initialization
  DEBUG(F("Initializing sensors..."));
  #ifdef VEML6070_CONNECTED
    VEML.begin();
    delay(500);
  #endif
  #ifdef HDC1080_CONNECTED
    HDC.begin();
  #endif
  #ifdef BMP280_CONNECTED
    BMP.begin(0x76);
  #endif
  #ifdef TSL45315_CONNECTED
    Lightsensor_begin();
  #endif
  #ifdef SDS011_CONNECTED
    sds.begin();
    sds.setQueryReportingMode();
  #endif
  #ifdef BME680_CONNECTED
    BME.begin(0x76);
    BME.setTemperatureOversampling(BME680_OS_8X);
    BME.setHumidityOversampling(BME680_OS_2X);
    BME.setPressureOversampling(BME680_OS_4X);
    BME.setIIRFilterSize(BME680_FILTER_SIZE_3);
  #endif
  #ifdef SCD30_CONNECTED
    Wire.begin();
    SCD.begin();
  #endif
  #ifdef DISPLAY128x64_CONNECTED
    DEBUG(F("enable display..."));
    delay(2000);
    display.begin(SSD1306_SWITCHCAPVCC, 0x3D);
    display.display();
    delay(100);
    display.clearDisplay();
    DEBUG(F("done."));
    display.setCursor(0, 0);
    display.setTextSize(2);
    display.setTextColor(WHITE, BLACK);
    display.println("senseBox:");
    display.println("home\n");
    display.setTextSize(1);
    display.println("Version LoRaWAN");
    display.setTextSize(2);
    display.display();
  #endif
  #ifdef DPS310_CONNECTED
    dps.begin_I2C(0x76);
    dps.configurePressure(DPS310_64HZ, DPS310_64SAMPLES);
    dps.configureTemperature(DPS310_64HZ, DPS310_64SAMPLES);
  #endif

  DEBUG(F("Sensor initializing done!"));
  DEBUG(F("Starting loop in 3 seconds."));
  delay(3000);

  // LMIC init
  os_init();
  // Reset the MAC state. Session and pending data transfers will be discarded.
  LMIC_reset();

  // Start job (sending automatically starts OTAA too)
  do_send(&sendjob);
  #ifdef DISPLAY128x64_CONNECTED
    update_display(&displayjob);
  #endif

}

void loop() {
  os_runloop_once();
}

int read_reg(byte address, uint8_t reg)
{
  int i = 0;

  Wire.beginTransmission(address);
  Wire.write(reg);
  Wire.endTransmission();
  Wire.requestFrom((uint8_t)address, (uint8_t)1);
  delay(1);
  if(Wire.available())
    i = Wire.read();

  return i;
}

void write_reg(byte address, uint8_t reg, uint8_t val)
{
  Wire.beginTransmission(address);
  Wire.write(reg);
  Wire.write(val);
  Wire.endTransmission();
}

#ifdef TSL45315_CONNECTED
void Lightsensor_begin()
{
  Wire.begin();
  unsigned int u = 0;
  DEBUG(F("Checking lightsensortype"));
  u = read_reg(0x29, 0x80 | 0x0A); //id register
  if ((u & 0xF0) == 0xA0)            // TSL45315
  {
    DEBUG(F("TSL45315"));
    write_reg(0x29, 0x80 | 0x00, 0x03); //control: power on
    write_reg(0x29, 0x80 | 0x01, 0x02); //config: M=4 T=100ms
    delay(120);
    lightsensortype = 0; //TSL45315
  }
  else
  {
    DEBUG(F("LTR329"));
    LTR.begin();
    LTR.setControl(gain, false, false);
    LTR.setMeasurementRate(integrationTime, measurementRate);
    LTR.setPowerUp(); //power on with default settings
    delay(10); //Wait 10 ms (max) - wakeup time from standby
    lightsensortype = 1;                     //
  }
}

unsigned int Lightsensor_getIlluminance()
{
  unsigned int lux = 0;
  if (lightsensortype == 0) // TSL45315
  {
    unsigned int u = (read_reg(0x29, 0x80 | 0x04) << 0);  //data low
    u |= (read_reg(0x29, 0x80 | 0x05) << 8); //data high
    lux = u * 4; // calc lux with M=4 and T=100ms
  }
  else if (lightsensortype == 1) //LTR-329ALS-01
  {
    delay(100);
    unsigned int data0, data1;
    for (int i = 0; i < 5; i++) {
      if (LTR.getData(data0, data1)) {
        if(LTR.getLux(gain, integrationTime, data0, data1, lux));
        else DEBUG(F("LTR sensor saturated"));
        if(lux > 0) break;
        else delay(10);
      }
      else {
        DEBUG(F("LTR getData error "));
        byte error = LTR.getError();
        Serial.println(error);
      }
    }
  }
  return lux;
}
#endif