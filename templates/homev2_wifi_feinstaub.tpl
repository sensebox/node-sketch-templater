{ "model" : "homeV2WifiFeinstaub", "board": "senseBox:samd:sb" }
/*
  senseBox:home - Citizen Sensingplatform
  Version: wifiv2_1.6.0
  Date: 2022-03-04
  Homepage: https://www.sensebox.de https://www.opensensemap.org
  Author: Reedu GmbH & Co. KG
  Note: Sketch for senseBox:home WiFi MCU Edition with dust particle upgrade
  Model: homeV2WifiFeinstaub
  Email: support@sensebox.de
  Code is in the public domain.
  https://github.com/sensebox/node-sketch-templater
*/

#include <senseBoxIO.h>
#include <WiFi101.h>
#include <SPI.h>
#include <Wire.h>

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_HDC1000.h>
#include <Adafruit_BMP280.h>
#include <Adafruit_BME680.h>
#include <VEML6070.h>
#include <SDS011-select-serial.h>
#include <SparkFun_SCD30_Arduino_Library.h>
#include <LTR329.h>
#include <ArduinoBearSSL.h>
#include <Adafruit_DPS310.h> // http://librarymanager/All#Adafruit_DPS310

//Watchdog Library, can be found in the library manager or on https://github.com/adafruit/Adafruit_SleepyDog
#include <Adafruit_SleepyDog.h>

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

// Wifi Credentials
const char *ssid = "@@SSID@@"; // your network SSID (name)
const char *pass = "@@PASSWORD@@"; // your network password

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

// Display enabled
// Uncomment the next line to get values of measurements printed on display
@@DISPLAY_ENABLED|toDefineDisplay@@

// sensor IDs
@@SENSOR_IDS|toProgmem@@

WiFiClient wifiClient;
BearSSLClient client(wifiClient);

unsigned long getTime() {
  return WiFi.getTime();
}

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
#ifdef DISPLAY128x64_CONNECTED
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET 4
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
#endif
#ifdef DPS310_CONNECTED
  Adafruit_DPS310 dps;
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
        #elif defined(BME680_CONNECTED)
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
  //return nDevices;
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
  senseBoxIO.powerXB1(false);delay(200);
  DEBUG2("xbee1 power on...");
  senseBoxIO.powerXB1(true); // power ON XBEE1
  DEBUG("done");
  senseBoxIO.powerI2C(false);delay(200);
  senseBoxIO.powerI2C(true);
  delay(200);
  senseBoxIO.powerUART(true);

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

  // Check WiFi Shield status
  if (WiFi.status() == WL_NO_SHIELD) {
    DEBUG(F("WiFi shield not present"));
    // don't continue:
    while (true)
      ;
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

  // check the server time for the validation of the certificate
  ArduinoBearSSL.onGetTime(getTime);

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
  #ifdef DISPLAY128x64_CONNECTED
  display.clearDisplay();
  display.setCursor(30, 28);
  display.setTextSize(2);
  display.print("Ready!");
  display.display();
  #endif
  #ifdef DPS310_CONNECTED
    dps.begin_I2C(0x76);
    dps.configurePressure(DPS310_64HZ, DPS310_64SAMPLES);
    dps.configureTemperature(DPS310_64HZ, DPS310_64SAMPLES);
  #endif
  DEBUG(F("Initializing sensors done!"));
  DEBUG2(F("Initializing Watchdog at 480000ms..."));
  // Initialize watchdog
  Watchdog.enable(480000);
  DEBUG(F("done!"));
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
    addMeasurement(HDC1080_TEMPERSENSOR_ID, HDC.readTemperature());
    delay(200);
    addMeasurement(HDC1080_RELLUFSENSOR_ID, HDC.readHumidity());
  #endif

  //-----Pressure-----//
  #ifdef BMP280_CONNECTED
    float pressure;
    pressure = BMP.readPressure()/100;
    addMeasurement(BMP280_LUFTDRSENSOR_ID, pressure);
  #endif

  //-----Lux-----//
  #ifdef TSL45315_CONNECTED
    addMeasurement(TSL45315_BELEUCSENSOR_ID, Lightsensor_getIlluminance());
  #endif

  //-----UV intensity-----//
  #ifdef VEML6070_CONNECTED
    addMeasurement(VEML6070_UVINTESENSOR_ID, VEML.getUV());
  #endif

  //-----PM-----//
  #ifdef SDS011_CONNECTED
    uint8_t attempt = 0;
    float pm10, pm25;
    while (attempt < 5) {
      bool error = SDS.read(&pm25, &pm10);
      if (!error) {
        addMeasurement(SDS011_PM10SENSOR_ID, pm10);
        addMeasurement(SDS011_PM25SENSOR_ID, pm25);
        break;
      }
      attempt++;
    }
  #endif

  //-----Soil Temperature & Moisture-----//
  #ifdef SMT50_CONNECTED
    float voltage = analogRead(SOILTEMPPIN) * (3.3 / 1024.0);
    float soilTemperature = (voltage - 0.5) * 100;
    addMeasurement(SMT50_BODENTSENSOR_ID, soilTemperature);
    voltage = analogRead(SOILMOISPIN) * (3.3 / 1024.0);
    float soilMoisture = (voltage * 50) / 3;
    addMeasurement(SMT50_BODENFSENSOR_ID, soilMoisture);
  #endif

  //-----dB(A) Sound Level-----//
  #ifdef SOUNDLEVELMETER_CONNECTED
    float v = analogRead(SOUNDMETERPIN) * (3.3 / 1024.0);
    float decibel = v * 50;
    addMeasurement(SOUNDLEVELMETER_LAUTSTSENSOR_ID, decibel);
  #endif

  //-----BME680-----//
  #ifdef BME680_CONNECTED
    float gasResistance;
    BME.setGasHeater(0, 0);
    if( BME.performReading()) {
       addMeasurement(BME680_LUFTTESENSOR_ID, BME.temperature-1);
       addMeasurement(BME680_LUFTFESENSOR_ID, BME.humidity);
       addMeasurement(BME680_ATMLUFSENSOR_ID, BME.pressure/100);
    }
    BME.setGasHeater(320, 150); // 320*C for 150 ms
    if( BME.performReading()) {
       gasResistance = BME.gas_resistance / 1000.0;
       addMeasurement(BME680_VOCSENSOR_ID, gasResistance);
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
    addMeasurement(WINDSPEED_WINDGESENSOR_ID, windspeed);
  #endif

  //-----CO2-----//
  #ifdef SCD30_CONNECTED
    addMeasurement(SCD30_CO2SENSOR_ID, SCD.getCO2());
  #endif

  //-----DPS310 Pressure-----//
  #ifdef DPS310_CONNECTED
    sensors_event_t temp_event, pressure_event;
    dps.getEvents(&temp_event, &pressure_event);
    addMeasurement(DPS310_LUFTDRSENSOR_ID, pressure_event.pressure);
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
        display.println(F("LIGHTSENSOR"));
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
    case 2:
      // SDS
      display.setTextSize(2);
      display.setTextColor(BLACK, WHITE);
      display.println(F("PM10&PM25"));
      display.setTextColor(WHITE, BLACK);
      display.println();
      display.setTextSize(1);
      display.print(F("PM10:"));
      display.println(pm10);
      display.print(F("PM25:"));
      display.println(pm25);
      break;
    case 3:
        // Soil
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
    case 4:
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
    case 5:
    //SOUND LEVEL , BME
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
      if (page == 5)
      {
        page = 0;
      }
      else
      {
        page += 1;
      }
      displayTime += 5000;
      DEBUG2(F("Resetting watchdog..."));
      Watchdog.reset();
      DEBUG(F("done."));
    }
#endif
    if (elapsed >= postingInterval)
    {
      DEBUG2(F("Preparing for Upload: Resetting watchdog..."));
      Watchdog.reset();
      DEBUG(F("done."));
      return;
    }
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
	if ((u & 0xF0) == 0xA0)						 // TSL45315
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
		lightsensortype = 1;										 //
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
