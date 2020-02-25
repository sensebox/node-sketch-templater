{ "model" : "homeV2Lora", "board": "senseBox:samd:sb" }
/*
  senseBox:home - Citizen Sensingplatform
  Version: lorav2.0.0
  Date: 2018-09-11
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

#include <Adafruit_Sensor.h>
#include <Adafruit_HDC1000.h>
#include <Adafruit_BMP280.h>
#include <Adafruit_BME680.h>
#include <Makerblog_TSL45315.h>
#include <VEML6070.h>
#include <SDS011-select-serial.h>

// Uncomment the next line to get debugging messages printed on the Serial port
// Do not leave this enabled for long time use
// #define ENABLE_DEBUG

#ifdef ENABLE_DEBUG
#define DEBUG(str) Serial.println(str)
#else
#define DEBUG(str)
#endif

// Connected sensors
@@SENSORS|toDefineWithSuffixPrefixAndKey~,_CONNECTED,sensorType@@

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
  Makerblog_TSL45315 TSL = Makerblog_TSL45315(TSL45315_TIME_M4);
#endif
#ifdef VEML6070_CONNECTED
  VEML6070 VEML;
  uint16_t uv;
#endif
#ifdef SDS011_CONNECTED
  SDS011 SDS(SDS_UART_PORT);
  float pm10 = 0;
  float pm25 = 0;
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

// This EUI must be in little-endian format, so least-significant-byte (lsb)
// first. When copying an EUI from ttnctl output, this means to reverse
// the bytes.
static const u1_t PROGMEM DEVEUI[8]={ 0xD9, 0x6D, 0x33, 0x69, 0x38, 0xE1, 0x63, 0x00 };
void os_getDevEui (u1_t* buf) { memcpy_P(buf, DEVEUI, 8);}

// This EUI must be in little-endian format, so least-significant-byte (lsb)
// first. When copying an EUI from ttnctl output, this means to reverse
// the bytes. For TTN issued EUIs the last bytes should be 0xD5, 0xB3,
// 0x70.
static const u1_t PROGMEM APPEUI[8]={ 0x21, 0x24, 0x01, 0xD0, 0x7E, 0xD5, 0xB3, 0x70 };
void os_getArtEui (u1_t* buf) { memcpy_P(buf, APPEUI, 8);}

// This key should be in big endian format (msb) (or, since it is not really a
// number but a block of memory, endianness does not really apply). In
// practice, a key taken from ttnctl can be copied as-is.
// The key shown here is the semtech default key.
static const u1_t PROGMEM APPKEY[16] = { 0xB7, 0x05, 0x01, 0xF8, 0x72, 0xF9, 0x5E, 0xD6, 0x44, 0x7C, 0xE8, 0xF7, 0x7B, 0xE5, 0x10, 0x5D };
void os_getDevKey (u1_t* buf) {  memcpy_P(buf, APPKEY, 16);}

static osjob_t sendjob;

// Schedule TX every this many seconds (might become longer due to duty
// cycle limitations).
const unsigned TX_INTERVAL = 60;

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
      lux = TSL.readLux();
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
      uint8_t attempt = 0;
      while (attempt < 5) {
        bool error = SDS.read(&pm25, &pm10);
        if (!error) {
          DEBUG(F("PM10: "));
          DEBUG(pm10);
          message.addUint16(pm10 * 10);
          DEBUG(F("PM2.5: "));
          DEBUG(pm25);
          message.addUint16(pm25 * 10);
          break;
        }
        attempt++;
      }
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

    // Prepare upstream data transmission at the next possible time.
    LMIC_setTxData2(1, message.getBytes(), message.getLength(), 0);
    DEBUG(F("Packet queued"));
  }
  // Next TX is scheduled after TX_COMPLETE event.
}

void setup() {
  #ifdef ENABLE_DEBUG
    Serial.begin(9600);
  #endif
  delay(3000);

  // RFM9X (LoRa-Bee) in XBEE1 Socket
  senseBoxIO.powerXB1(false); // power off to reset RFM9X
  delay(250);
  senseBoxIO.powerXB1(true);  // power on

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
    TSL.begin();
  #endif
  #ifdef SDS011_CONNECTED
    SDS_UART_PORT.begin(9600);
  #endif
  #ifdef BME680_CONNECTED
    BME.begin(0x76);
    BME.setTemperatureOversampling(BME680_OS_8X);
    BME.setHumidityOversampling(BME680_OS_2X);
    BME.setPressureOversampling(BME680_OS_4X);
    BME.setIIRFilterSize(BME680_FILTER_SIZE_3);
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
}

void loop() {
  os_runloop_once();
}