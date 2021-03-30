{ "model" : "homeV2GSM", "board": "senseBox:samd:sb" }
/*
  senseBox:home - Citizen Sensingplatform
  Version: tingg_0.1
  Date: 2019-12-06
  Homepage: https://www.sensebox.de https://www.opensensemap.org
  Author: Reedu GmbH & Co. KG
  Note: Sketch for senseBox:home WiFi MCU Edition with dust particle upgrade
  Model: homeV2WifiFeinstaub
  Email: support@sensebox.de
  Code is in the public domain.
  https://github.com/sensebox/node-sketch-templater
*/


/* we need to add the following libraries to https://github.com/sensebox/senseBoxMCU-core/tree/master/arduino/samd/libraries
 geenymodem
 PubSubClient
 ArduinoJSON
 tinygsm
*/


#include <senseBoxIO.h>
#include <SPI.h>
#include <Wire.h>

#include <Adafruit_Sensor.h>
#include <GEENYmodem.h>




// Connected sensors
@@SENSORS|toDefineWithSuffixPrefixAndKey~,_CONNECTED,sensorType@@

#ifdef HDC1080_CONNECTED
#include <Adafruit_HDC1000.h>
#endif
#ifdef BMP280_CONNECTED
#include <Adafruit_BMP280.h>
#endif
#ifdef BME680_CONNECTED
#include <Adafruit_BME680.h>
#endif
#ifdef TSL45315_CONNECTED
#include <Makerblog_TSL45315.h>
#endif
#ifdef VEML6070_CONNECTED
#include <VEML6070.h>
#endif
#ifdef SDS011_CONNECTED
#include <SDS011-select-serial.h>
#endif
#ifdef SCD30_CONNECTED
#include <SparkFun_SCD30_Arduino_Library.h>
#endif

// Uncomment the next line to get debugging messages printed on the Serial port
// Do not leave this enabled for long time use
// #define ENABLE_DEBUG

#ifdef ENABLE_DEBUG
#define DEBUG(str) Serial.println(str)
#define DEBUG_ARGS(str,str1) Serial.println(str,str1)
#define DEBUG2(str) Serial.print(str)
#define DEBUG_WRITE(c) Serial.write(c)

#include <StreamDebugger.h>
StreamDebugger debugger(Serial3, Serial);

#else
#define DEBUG(str)
#define DEBUG_ARGS(str,str1)
#define DEBUG2(str)
#define DEBUG_WRITE(c)
#endif

/* ------------------------------------------------------------------------- */
/* ------------------------------Configuration------------------------------ */
/* ------------------------------------------------------------------------- */

GEENYmodem geeny = GEENYmodem();

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

// sensor IDs
@@SENSOR_IDS|toProgmem@@

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
  
  if(!geeny.isMQTTConnected())
  {
    if(!geeny.connectMQTT())
    {
      DEBUG(F("Can't publish to MQTT broker."));
      // reset num_measurements
      num_measurements = 0;
      return;
    }
  }
  
  // iterate throug the measurements array
  for (uint8_t i = 0; i < num_measurements; i++) {
    String _topic = String("/osm/")+String(SENSEBOX_ID)+String("/")+String(measurements[i].sensorId);
    DEBUG2(F("_topic: "));
    DEBUG(_topic.c_str());
    sprintf_P(buffer, PSTR("{\"value\":%9.2f}"), measurements[i].value);
    DEBUG2("value: ");
    DEBUG(buffer);
    if(geeny.mqttPublish(_topic.c_str(),buffer)){
      DEBUG(F("MQTT publish was successful"));
    }
    else{
      DEBUG(F("MQTT publish failed"));
    }
  }

  // reset num_measurements
  num_measurements = 0;
}

bool connectToNetwork(){
  if(geeny.isNetworkConnected()){
    return true;
  }

  if(!geeny.connectGPRS()){
    DEBUG(F("GPRS connection failed"));
    return false;
  }
    
    
  DEBUG2(F("IP: "));
  DEBUG(geeny.getLocalIP());
  return true;
}

bool connectMqtt(){
  if(geeny.isMQTTConnected()){
    return true;
  }

  return geeny.connectMQTT();
}


void submitValues(){
  // send measurements
  writeMeasurementsToClient();
  geeny.disconnectMQTT();
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
  senseBoxIO.powerAll();
  delay(1000);

  // Initialize serial and wait for port to open:
  #ifdef ENABLE_DEBUG
    Serial.begin(9600);
  #endif
  Serial3.begin(115200);//XBEE1 UART for tinggmodem
  delay(5000);

  #ifdef ENABLE_DEBUG
    geeny.begin(debugger, Serial); 
  #else
    geeny.begin(Serial3); 
  #endif
  
  
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
  #ifdef SDS011_CONNECTED
    SDS_UART_PORT.begin(9600);
  #endif
  #ifdef SCD30_CONNECTED
    Wire.begin();
    SCD.begin();
  #endif
  DEBUG(F("Initializing sensors done!"));
  DEBUG(F("Starting loop in 3 seconds."));
  delay(3000);
}

void loop() {
  DEBUG(F("Starting new measurement..."));
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
    pressure = BMP.readPressure()/100;
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
    DEBUG("BME.setGasHeater(320, 150)");
    delay(500);
    if( BME.performReading()) {
      DEBUG("BME.performReading()");
       addMeasurement(VOCSENSOR_ID, BME.gas_resistance / 1000.0);
    }
    else
    {
      DEBUG("BME.performReading() failed");
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

  DEBUG(F("Submit values"));
  submitValues();

  // schedule next round of measurements
  for (;;) {
    unsigned long now = millis();
    unsigned long elapsed = now - start;
    if (elapsed >= postingInterval)
      return;
  }
}
