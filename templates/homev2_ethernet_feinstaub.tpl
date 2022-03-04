{ "model":"homeV2EthernetFeinstaub", "board": "senseBox:samd:sb"}
/*
  senseBox:home - Citizen Sensingplatform
  Version: ethernetv2_0.3
  Date: 2019-12-06
  Homepage: https://www.sensebox.de https://www.opensensemap.org
  Author: Reedu GmbH & Co. KG
  Note: Sketch for senseBox:home Ethernet MCU Edition with dust particle upgrade
  Model: homeEthernetV2Feinstaub
  Email: support@sensebox.de
  Code is in the public domain.
  https://github.com/sensebox/node-sketch-templater
*/

#include <Ethernet.h>
#include <Wire.h>
#include <senseBoxIO.h>
#include <SPI.h>

#include <Adafruit_Sensor.h>
#include <Adafruit_BMP280.h>
#include <Adafruit_BME680.h>
#include <Adafruit_HDC1000.h>
#include <VEML6070.h>
#include <SDS011-select-serial.h>
#include <SparkFun_SCD30_Arduino_Library.h>
#include <LTR329.h>
#include <ArduinoBearSSL.h>
#include <EthernetUdp.h>
#include <NTPClient.h>
#include <Adafruit_DPS310.h> // http://librarymanager/All#Adafruit_DPS310


// Uncomment the next line to get debugging messages printed on the Serial port
// Do not leave this enabled for long time use
// #define ENABLE_DEBUG

#ifdef ENABLE_DEBUG
#define DEBUG(str) Serial.println(str)
#define DEBUG_ARGS(str,str1) Serial.println(str,str1)
#define DEBUG2(str) Serial.print(str)
#define DEBUG_WRITE(c) Serial.write(c)
#else
#define DEBUG(str)
#define DEBUG_ARGS(str,str1)
#define DEBUG2(str)
#define DEBUG_WRITE(c)
#endif

/* ------------------------------------------------------------------------- */
/* ---------------------------------Metadata-------------------------------- */
/* ------------------------------------------------------------------------- */
/* SENSEBOX ID  : @@SENSEBOX_ID@@                                            */
/* SENSEBOX NAME: @@SENSEBOX_NAME@@                                          */
/* ------------------------------------------------------------------------- */
/* ------------------------------End of Metadata---------------------------- */
/* ------------------------------------------------------------------------- */

/* ------------------------------------------------------------------------- */
/* ------------------------------Configuration------------------------------ */
/* ------------------------------------------------------------------------- */

// Number of serial port the SDS011 is connected to. Either Serial1 or Serial2
#define SDS_UART_PORT (@@SERIAL_PORT@@)

// Interval of measuring and submitting values in seconds
const unsigned int postingInterval = 60e3;

// address of the server to send to
const char server[] PROGMEM = "@@INGRESS_DOMAIN@@";

// senseBox ID
const char SENSEBOX_ID[] PROGMEM = "@@SENSEBOX_ID@@";

// Number of sensors
// Change this number if you add or remove sensors
// do not forget to remove or add the sensors on opensensemap.org
static const uint8_t NUM_SENSORS = @@NUM_SENSORS@@;

// Connected sensors
@@SENSORS|toDefineWithSuffixPrefixAndKey~,_CONNECTED,sensorType@@

// sensor IDs
@@SENSOR_IDS|toProgmem@@

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
EthernetClient eclient;
BearSSLClient client(eclient);
EthernetUDP Udp;
NTPClient timeClient(Udp);

unsigned long getTime() {
  timeClient.update();
  return timeClient.getEpochTime();
}

//Configure static IP setup (only needed if DHCP is disabled)
IPAddress myIp(192, 168, 0, 42);
IPAddress myDns(8, 8, 8, 8);
IPAddress myGateway(192, 168, 0, 177);
IPAddress mySubnet(255, 255, 255, 0);

//Load sensors / instances
#ifdef HDC1080_CONNECTED
  Adafruit_HDC1000 HDC = Adafruit_HDC1000();
#endif
#ifdef BMP280_CONNECTED
  Adafruit_BMP280 BMP;
#endif
#ifdef TSL45315_CONNECTED
  bool lightsensortype = 0; //0 for tsl - 1 for ltr
  //settings for LTR sensor
  LTR329 LTR;
  unsigned char gain = 1;
  unsigned char integrationTime = 0;
  unsigned char measurementRate = 3;
#endif
#ifdef VEML6070_CONNECTED
  VEML6070 VEML;
#endif
#ifdef SDS011_CONNECTED
  SDS011 SDS(SDS_UART_PORT);
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
#ifdef DPS310_CONNECTED
  Adafruit_DPS310 dps;
#endif

int dataLength;

typedef struct measurement {
  const char *sensorId;
  float value;
} measurement;

measurement measurements[NUM_SENSORS];
uint8_t num_measurements = 0;

// buffer for sprintf
char buffer[750];

/* ------------------------------------------------------------------------- */
/* --------------------------End of Configuration--------------------------- */
/* ------------------------------------------------------------------------- */

void addMeasurement(const char *sensorId, float value) {
  measurements[num_measurements].sensorId = sensorId;
  measurements[num_measurements].value = value;
  num_measurements++;
  dataLength += String(sensorId).length() + 1; //length of ID + ','
  dataLength += String((int)value * 100).length() + 1; //length of measurement value + decimal digit
}

void writeMeasurementsToClient() {
  // iterate throug the measurements array
  for (uint8_t i = 0; i < num_measurements; i++)
  {
    //convert float to char[]
    float temp = measurements[i].value;
    int intPart = (int)measurements[i].value;
    temp -= intPart;
    temp *= 100; //2 decimal places
    int fracPart = (int)temp;
    sprintf_P(buffer, PSTR("%s,%i.%02i\n"), measurements[i].sensorId, intPart, fracPart);
    // transmit buffer to client
    client.print(buffer);
    DEBUG2(buffer);
  }

  // reset num_measurements
  num_measurements = 0;
}

void submitValues() {
  // close any connection before send a new request.
  if (client.connected()) {
    client.stop();
    delay(1000);
  }
  bool connected = false;
  char _server[strlen_P(server)];
  strcpy_P(_server, server);
  for (uint8_t timeout = 2; timeout != 0; timeout--) {
    DEBUG(F("connecting..."));
    connected = client.connect(_server, 443);
    if (connected == true) {
      DEBUG(F("Connection successful, transferring..."));
      // construct the HTTP POST request:
      sprintf_P(buffer,
                PSTR("POST /boxes/%s/data HTTP/1.1\nAuthorization: @@ACCESS_TOKEN@@\nHost: %s\nContent-Type: "
                     "text/csv\nConnection: close\nContent-Length: %i\n\n"),
                SENSEBOX_ID, server, dataLength);
      DEBUG2(buffer);

      // send the HTTP POST request:
      client.print(buffer);

      // send measurements
      writeMeasurementsToClient();

      // send empty line to end the request
      client.println();

      uint16_t timeout = 0;
      // allow the response to be computed

      while (timeout <= 5000) {
        delay(10);
        timeout = timeout + 10;
        if (client.available()) {
          break;
        }
      }
      delay(1000);
      while (client.available()) {
        char c = client.read();
        DEBUG_WRITE(c);
        // if the server's disconnected, stop the client:
        if (!client.connected()) {
          DEBUG();
          DEBUG("disconnecting from server.");
          client.stop();
          break;
        }
      }

      DEBUG("done!");

      // reset number of measurements
      num_measurements = 0;
      break;
    }
    delay(1000);
  }

  if (connected == false) {
    // Reset durchführen
    DEBUG(F("connection failed. Restarting..."));
    delay(5000);
    noInterrupts();
    NVIC_SystemReset();
    while (1)
      ;
  }
}

void checkI2CSensors() {
  byte error;
  int nDevices = 0;
  byte sensorAddr[] = {41, 56, 57, 64, 97, 118};
  DEBUG("\nScanning...");
  for (int i = 0; i < sizeof(sensorAddr); i++) {
    Wire.beginTransmission(sensorAddr[i]);
    error = Wire.endTransmission();
    if (error == 0) {
      nDevices++;
      switch (sensorAddr[i])
      {
        case 0x29:
          DEBUG("TSL45315 found.");
          break;
        case 0x38: // &0x39
          DEBUG("VEML6070 found.");
          break;
        case 0x40:
          DEBUG("HDC1080 found.");
          break;
        case 0x76:
        #ifdef BMP280_CONNECTED
          DEBUG("BMP280 found.");
        #elif BME680_CONNECTED
          DEBUG("BME680 found.");
        #else
          DEBUG("DPS310 found.");
        #endif
          break;
        case 0x61:
          DEBUG("SCD30 found.");
          break;
      }
    }
    else if (error == 4)
    {
      DEBUG2("Unknown error at address 0x");
      if (sensorAddr[i] < 16)
        DEBUG2("0");
      DEBUG_ARGS(sensorAddr[i], HEX);
    }
  }
  if (nDevices == 0) {
    DEBUG("No I2C devices found.\nCheck cable connections and press Reset.");
    while(true);
  } else {
    DEBUG2(nDevices);
    DEBUG(" sensors found.\n");
  }
}

void setup() {
  // Initialize serial and wait for port to open:
  #ifdef ENABLE_DEBUG
    Serial.begin(9600);
  #endif
  delay(5000);

  DEBUG2("xbee1 spi enable...");
  senseBoxIO.SPIselectXB1(); // select XBEE1 spi
  DEBUG("done");
  senseBoxIO.powerXB1(false);
  delay(200);
  DEBUG2("xbee1 power on...");
  senseBoxIO.powerXB1(true); // power ON XBEE1
  DEBUG("done");
  senseBoxIO.powerI2C(false);
  delay(200);
  senseBoxIO.powerI2C(true);
  delay(200);
  senseBoxIO.powerUART(true);

  Ethernet.init(23);
  // start the Ethernet connection:
  if (Ethernet.begin(mac) == 0) {
    DEBUG2("Failed to configure Ethernet using DHCP");
    // no point in carrying on, so do nothing forevermore:
    // try to congifure using IP address instead of DHCP:
    Ethernet.begin(mac, myIp);
  }
  // give the Ethernet shield a second to initialize:
  delay(1000);

  #ifdef ENABLE_DEBUG
    // init I2C/wire library
    Wire.begin();
    checkI2CSensors();
  #endif

  // Sensor initialization
  DEBUG(F("Initializing sensors..."));
  #ifdef HDC1080_CONNECTED
    HDC.begin();
  #endif
  #ifdef BMP280_CONNECTED
    BMP.begin(0x76);
  #endif
  #ifdef VEML6070_CONNECTED
    VEML.begin();
    delay(500);
  #endif
  #ifdef TSL45315_CONNECTED
    Lightsensor_begin();
  #endif
  #ifdef BME680_CONNECTED
    BME.begin(0x76);
    BME.setTemperatureOversampling(BME680_OS_8X);
    BME.setHumidityOversampling(BME680_OS_2X);
    BME.setPressureOversampling(BME680_OS_4X);
    BME.setIIRFilterSize(BME680_FILTER_SIZE_3);
  #endif
  #ifdef SDS011_CONNECTED
    SDS_UART_PORT.begin(9600);
  #endif
  #ifdef SCD30_CONNECTED
    Wire.begin();
    SCD.begin();
  #endif
  #ifdef DPS310_CONNECTED
    dps.begin_I2C(0x76);
    dps.configurePressure(DPS310_64HZ, DPS310_64SAMPLES);
    dps.configureTemperature(DPS310_64HZ, DPS310_64SAMPLES);
  #endif
  DEBUG(F("Initializing sensors done!"));
  DEBUG(F("Starting loop in 3 seconds."));
  delay(3000);

  timeClient.begin();
  ArduinoBearSSL.onGetTime(getTime);  
}

void loop() {
  Serial.println(F("Loop"));
  // capture loop start timestamp
  unsigned long start = millis();
  dataLength = NUM_SENSORS - 1; // excluding linebreak after last measurement

  //-----Temperature-----//
  //-----Humidity-----//
  #ifdef HDC1080_CONNECTED
    addMeasurement(TEMPERSENSOR_ID, HDC.readTemperature());
    delay(200);
    addMeasurement(RELLUFSENSOR_ID, HDC.readHumidity());
  #endif

  //-----Pressure-----//
  #ifdef BMP280_CONNECTED
    float pressure;
    pressure = BMP.readPressure()/100;
    addMeasurement(LUFTDRSENSOR_ID, pressure);
  #endif

  //-----Lux-----//
  #ifdef TSL45315_CONNECTED
    addMeasurement(BELEUCSENSOR_ID, Lightsensor_getIlluminance());
  #endif

  //-----UV intensity-----//
  #ifdef VEML6070_CONNECTED
    addMeasurement(UVINTESENSOR_ID, VEML.getUV());
  #endif

  //-----PM-----//
  #ifdef SDS011_CONNECTED
    uint8_t attempt = 0;
    float pm10, pm25;
    while (attempt < 5) {
      bool error = SDS.read(&pm25, &pm10);
      if (!error) {
        addMeasurement(PM10SENSOR_ID, pm10);
        addMeasurement(PM25SENSOR_ID, pm25);
        break;
      }
      attempt++;
    }
  #endif

  //-----Soil Temperature & Moisture-----//
  #ifdef SMT50_CONNECTED
    float voltage = analogRead(SOILTEMPPIN) * (3.3 / 1024.0);
    float soilTemperature = (voltage - 0.5) * 100;
    addMeasurement(BODENTSENSOR_ID, soilTemperature);
    voltage = analogRead(SOILMOISPIN) * (3.3 / 1024.0);
    float soilMoisture = (voltage * 50) / 3;
    addMeasurement(BODENFSENSOR_ID, soilMoisture);
  #endif

  //-----dB(A) Sound Level-----//
  #ifdef SOUNDLEVELMETER_CONNECTED
    float v = analogRead(SOUNDMETERPIN) * (3.3 / 1024.0);
    float decibel = v * 50;
    addMeasurement(LAUTSTSENSOR_ID, decibel);
  #endif

  //-----BME680-----//
  #ifdef BME680_CONNECTED
    BME.setGasHeater(0, 0);
    if( BME.performReading()) {
       addMeasurement(LUFTTESENSOR_ID, BME.temperature-1);
       addMeasurement(LUFTFESENSOR_ID, BME.humidity);
       addMeasurement(ATMLUFSENSOR_ID, BME.pressure/100);
    }
    BME.setGasHeater(320, 150); // 320*C for 150 ms
    if( BME.performReading()) {
       addMeasurement(VOCSENSOR_ID, BME.gas_resistance / 1000.0);
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
    addMeasurement(WINDGESENSOR_ID, windspeed);
  #endif

  //-----CO2-----//
  #ifdef SCD30_CONNECTED
    addMeasurement(CO2SENSOR_ID, SCD.getCO2());
  #endif

  //-----DPS310 Pressure-----//
  #ifdef DPS310_CONNECTED
    sensors_event_t temp_event, pressure_event;
    dps.getEvents(&temp_event, &pressure_event);
    addMeasurement(DPS310_SENSOR_ID, pressure_event.pressure);
  #endif

  DEBUG(F("submit values"));
  submitValues();

  // schedule next round of measurements
  for (;;) {
    unsigned long now = millis();
    unsigned long elapsed = now - start;
    if (elapsed >= postingInterval)
      return;
  }
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
        DEBUG2(F("LTR getData error "));
        byte error = LTR.getError();
        Serial.println(error);
      }
    }
  }
  return lux;
}
#endif