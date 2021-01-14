{ "model" : "homeV2Wifi", "board": "senseBox:samd:sb" }
/*
  senseBox:home - Citizen Sensingplatform
  Version: wifiv2_0.3
  Date: 2019-12-06
  Homepage: https://www.sensebox.de https://www.opensensemap.org
  Author: Reedu GmbH & Co. KG
  Note: Sketch for senseBox:home WiFi MCU Edition
  Model: homeV2Wifi
  Email: support@sensebox.de
  Code is in the public domain.
  https://github.com/sensebox/node-sketch-templater
*/

#include <WiFi101.h>
#include <Wire.h>
#include <SPI.h>
#include <senseBoxIO.h>

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_HDC1000.h>
#include <Adafruit_BMP280.h>
#include <Adafruit_BME680.h>
#include <Makerblog_TSL45315.h>
#include <VEML6070.h>
#include <SparkFun_SCD30_Arduino_Library.h>


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
/* ------------------------------Configuration------------------------------ */
/* ------------------------------------------------------------------------- */

// Wifi Credentials
const char *ssid = "@@SSID@@"; // your network SSID (name)
const char *pass = "@@PASSWORD@@"; // your network password

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

// Display enabled 
// Uncomment the next line to get values of measurements printed on display
@@DISPLAY_ENABLED|toDefineDisplay@@

// Sensor SENSOR_IDs
@@SENSOR_IDS|toProgmem@@

WiFiSSLClient client;

//Load sensors / instances
#ifdef HDC1080_CONNECTED
  Adafruit_HDC1000 HDC = Adafruit_HDC1000();
#endif
#ifdef BMP280_CONNECTED
  Adafruit_BMP280 BMP;
#endif
#ifdef TSL45315_CONNECTED
  Makerblog_TSL45315 TSL = Makerblog_TSL45315(TSL45315_TIME_M4);
#endif
#ifdef VEML6070_CONNECTED
  VEML6070 VEML;
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
#define OLED_RESET 4
Adafruit_SSD1306 display(OLED_RESET);
#endif

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
}

void writeMeasurementsToClient() {
  // iterate throug the measurements array
  for (uint8_t i = 0; i < num_measurements; i++) {
    sprintf_P(buffer, PSTR("%s,%9.2f\n"), measurements[i].sensorId,
              measurements[i].value);

    // transmit buffer to client
    client.print(buffer);
    DEBUG2(buffer);
  }

  // reset num_measurements
  num_measurements = 0;
}

void submitValues() {
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.disconnect();
    delay(1000); // wait 1s
    WiFi.begin(ssid, pass);
    delay(5000); // wait 5s
  }
  // close any connection before send a new request.
  // This will free the socket on the WiFi shield
  if (client.connected()) {
    client.stop();
    delay(1000);
  }
  bool connected = false;
  char _server[strlen_P(server)];
  strcpy_P(_server, server);
  for (uint8_t timeout = 2; timeout != 0; timeout--) {
    Serial.println(F("connecting..."));
    connected = client.connect(_server, 443);
    if (connected == true) {
      DEBUG(F("Connection successful, transferring..."));
      // construct the HTTP POST request:
      sprintf_P(buffer,
                PSTR("POST /boxes/%s/data HTTP/1.1\nAuthorization: @@ACCESS_TOKEN@@\nHost: %s\nContent-Type: "
                     "text/csv\nConnection: close\nContent-Length: %i\n\n"),
                SENSEBOX_ID, server, num_measurements * 35);
      DEBUG(buffer);

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

      while (client.available()) {
        char c = client.read();
        DEBUG_WRITE(c);
        // if the server's disconnected, stop the client:
        if (!client.connected()) {
          DEBUG();
          DEBUG(F("disconnecting from server."));
          client.stop();
          break;
        }
      }

      DEBUG(F("done!"));

      // reset number of measurements
      num_measurements = 0;
      break;
    }
    delay(1000);
  }

  if (connected == false) {
    // Reset durchführen
    DEBUG(F("connection failed. Restarting System."));
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
  DEBUG(F("\nScanning..."));
  for (int i = 0; i < sizeof(sensorAddr); i++) {
    Wire.beginTransmission(sensorAddr[i]);
    error = Wire.endTransmission();
    if (error == 0) {
      nDevices++;
      switch (sensorAddr[i])
      {
        case 0x29:
          DEBUG(F("TSL45315 found."));
          break;
        case 0x38: // &0x39
          DEBUG(F("VEML6070 found."));
          break;
        case 0x40:
          DEBUG(F("HDC1080 found."));
          break;
        case 0x76:
        #ifdef BMP280_CONNECTED
          DEBUG("BMP280 found.");
        #else
          DEBUG("BME680 found.");
        #endif
          break;
        case 0x61:
          DEBUG("SCD30 found.");
          break;
      }
    }
    else if (error == 4)
    {
      DEBUG2(F("Unknown error at address 0x"));
      if (sensorAddr[i] < 16)
        DEBUG2(F("0"));
      DEBUG_ARGS(sensorAddr[i], HEX);
    }
  }
  if (nDevices == 0) {
    DEBUG(F("No I2C devices found.\nCheck cable connections and press Reset."));
    while(true);
  } else {
    DEBUG2(nDevices);
    DEBUG(F(" sensors found.\n"));
  }
}

void setup() {
  // Initialize serial and wait for port to open:
  #ifdef ENABLE_DEBUG
    Serial.begin(9600);
  #endif
  delay(5000);

  DEBUG2(F("xbee1 spi enable..."));
  senseBoxIO.SPIselectXB1(); // select XBEE1 spi
  DEBUG(F("done"));
  senseBoxIO.powerXB1(false);
  delay(200);
  DEBUG2(F("xbee1 power on..."));
  senseBoxIO.powerXB1(true); // power ON XBEE1
  DEBUG(F("done"));
  senseBoxIO.powerI2C(false);
  delay(200);
  senseBoxIO.powerI2C(true);

#ifdef DISPLAY128x64_CONNECTED
  DEBUG2(F("enable display..."));
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
  display.println("Version Wifi ");
  display.setTextSize(2);
  display.display();
  delay(2000);
  display.clearDisplay();
  display.setCursor(0, 0);
  display.setTextSize(1);
  display.println("Connecting to:");
  display.println();
  display.println(ssid);
  display.setTextSize(1);
  display.display();
#endif

  // Check WiFi Bee status
  if (WiFi.status() == WL_NO_SHIELD) {
    DEBUG(F("WiFi shield not present"));
    // don't continue:
    while (true);
  }
  uint8_t status = WL_IDLE_STATUS;
  // attempt to connect to Wifi network:
  while (status != WL_CONNECTED) {
#ifdef DISPLAY128x64_CONNECTED
    display.print(".");
    display.display();
#endif
    DEBUG2(F("Attempting to connect to SSID: "));
    DEBUG(ssid);
    // Connect to WPA/WPA2 network. Change this line if using open or WEP
    // network
    status = WiFi.begin(ssid, pass);
    // wait 10 seconds for connection:
    DEBUG2(F("Waiting 10 seconds for connection..."));
    delay(10000);
    DEBUG(F("done."));
  }


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
    TSL.begin();
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
  display.clearDisplay();
  display.setCursor(30, 28);
  display.setTextSize(2);
  display.print("Ready!");
  display.display();
#endif
  DEBUG(F("Initializing sensors done!"));
  DEBUG(F("Starting loop in 3 seconds."));
  delay(3000);
}


void loop() {
  DEBUG(F("Starting new measurement..."));
#ifdef DISPLAY128x64_CONNECTED
  long displayTime = 5000;
  int page = 0;

  display.clearDisplay();
  display.setCursor(0, 0);
  display.setTextSize(1);
  display.setTextColor(WHITE, BLACK);
  display.println("Uploading new measurement... ");
  display.display();
#endif
  // capture loop start timestamp
  unsigned long start = millis();

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
  pressure = BMP.readPressure() / 100;
  addMeasurement(LUFTDRSENSOR_ID, pressure);
#endif

  //-----Lux-----//
#ifdef TSL45315_CONNECTED
  addMeasurement(BELEUCSENSOR_ID, TSL.readLux());
#endif

  //-----UV intensity-----//
#ifdef VEML6070_CONNECTED
  addMeasurement(UVINTESENSOR_ID, VEML.getUV());
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
  float gasResistance;
  if ( BME.performReading()) {
    addMeasurement(LUFTTESENSOR_ID, BME.temperature - 1);
    addMeasurement(LUFTFESENSOR_ID, BME.humidity);
    addMeasurement(ATMLUFSENSOR_ID, BME.pressure / 100);
  }
  BME.setGasHeater(320, 150); // 320*C for 150 ms
  if ( BME.performReading()) {
      gasResistance = BME.gas_resistance / 1000.0;
       addMeasurement(VOCSENSOR_ID, gasResistance);
  }
#endif

  //-----Wind speed-----//
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
  addMeasurement(WINDGESENSOR_ID, windspeed);
#endif

  //-----CO2-----//
#ifdef SCD30_CONNECTED
  addMeasurement(CO2SENSOR_ID, SCD.getCO2());
#endif

  DEBUG(F("Submit values"));
  submitValues();

  // schedule next round of measurements
  for (;;) {
    unsigned long now = millis();
    unsigned long elapsed = now - start;
#ifdef DISPLAY128x64_CONNECTED
    display.clearDisplay();
    display.setCursor(0, 0);
    display.setTextSize(1);
    display.setTextColor(WHITE, BLACK);
    switch (page)
    {
      case 0:
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
        break;
      case 1:
        // TSL/VEML
        display.setTextSize(2);
        display.setTextColor(BLACK, WHITE);
        display.println(F("TSL&VEML"));
        display.setTextColor(WHITE, BLACK);
        display.println();
        display.setTextSize(1);
        display.print(F("Lux:"));
#ifdef TSL45315_CONNECTED
        display.println(TSL.readLux());
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
        break;
      case 2:
        // SMT, SOUND LEVEL , BME
        display.setTextSize(2);
        display.setTextColor(BLACK, WHITE);
        display.println(F("Soil"));
        display.setTextColor(WHITE, BLACK);
        display.println();
        display.setTextSize(1);
        display.print(F("Temp:"));
#ifdef SMT50_CONNECTED
        display.println(soilTemperature);
#else
        display.println(F("not connected"));
#endif
        display.println();
        display.print(F("Moist:"));
#ifdef SMT50_CONNECTED
        display.println(soilMoisture);
#else
        display.println(F("not connected"));
#endif

        break;
      case 3:
        // WINDSPEED SCD30
        display.setTextSize(2);
        display.setTextColor(BLACK, WHITE);
        display.println(F("Wind&SCD30"));
        display.setTextColor(WHITE, BLACK);
        display.println();
        display.setTextSize(1);
        display.print(F("Speed:"));
#ifdef WINDSPEED_CONNECTED
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
        break;
      case 4:
          // SMT, SOUND LEVEL , BME
        display.setTextSize(2);
        display.setTextColor(BLACK, WHITE);
        display.println(F("Sound&BME"));
        display.setTextColor(WHITE, BLACK);
        display.println();
        display.setTextSize(1);
        display.print(F("Sound:"));
#ifdef SOUNDLEVELMETER_CONNECTED
        display.println(decibel);
#else
        display.println(F("not connected"));
#endif
        display.println();
        display.print(F("Gas:"));
#ifdef BME680_CONNECTED
        display.println(gasResistance);
#else
        display.print(F("not connected"));
#endif
        break;
    }
    display.display();
    if (elapsed >= displayTime)
    {
      if (page == 4)
      {
        page = 0;
      }
      else
      {
        page += 1;
      }
      displayTime += 5000;
    }
#endif
    if (elapsed >= postingInterval)
      return;
  }
}