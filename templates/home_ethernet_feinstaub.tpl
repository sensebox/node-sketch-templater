{ "model":"homeEthernetFeinstaub" }
/*
  senseBox:home - Citizen Sensingplatform
  Version: ethernet_2.6
  Date: 2017-07-29
  Homepage: https://www.sensebox.de https://www.opensensemap.org
  Author: Institute for Geoinformatics, University of Muenster
  Note: Sketch for senseBox:home Ethernet with dust particle upgrade
  Model: homeEthernetFeinstaub
  Email: support@sensebox.de
  Code is in the public domain.
  https://github.com/sensebox/node-sketch-templater
*/

#include <Ethernet2.h>

/* ------------------------------------------------------------------------- */
/* ------------------------------Configuration------------------------------ */
/* ------------------------------------------------------------------------- */

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

//Configure static IP setup (only needed if DHCP is disabled)
IPAddress myIp(192, 168, 0, 42);
IPAddress myDns(8, 8, 8, 8);
IPAddress myGateway(192, 168, 0, 177);
IPAddress mySubnet(255, 255, 255, 0);

// Uncomment the next line to get debugging messages printed on the Serial port
// Do not leave this enabled for long time use
// #define ENABLE_DEBUG

/* ------------------------------------------------------------------------- */
/* --------------------------End of Configuration--------------------------- */
/* ------------------------------------------------------------------------- */

#include "BMP280.h"
#include <HDC100X.h>
#include <Makerblog_TSL45315.h>
#include <SDS011-select-serial.h>
#include <SPI.h>
#include <VEML6070.h>
#include <Wire.h>
#include <avr/wdt.h>

#ifdef ENABLE_DEBUG
#define DEBUG(str) Serial.println(str)
#else
#define DEBUG(str)
#endif

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
EthernetClient client;

// Sensor Instances
SDS011 my_sds(Serial);
Makerblog_TSL45315 TSL = Makerblog_TSL45315(TSL45315_TIME_M4);
HDC100X HDC(0x43);
BMP280 BMP;
VEML6070 VEML;

typedef struct measurement {
  const char *sensorId;
  float value;
} measurement;

measurement measurements[NUM_SENSORS];
uint8_t num_measurements = 0;

// buffer for sprintf
char buffer[150];

void addMeasurement(const char *sensorId, float value) {
  measurements[num_measurements].sensorId = sensorId;
  measurements[num_measurements].value = value;
  num_measurements++;
}

void writeMeasurementsToClient() {
  // iterate throug the measurements array
  for (uint8_t i = 0; i < num_measurements; i++) {
    sprintf_P(buffer, PSTR("%S,"), measurements[i].sensorId);
    // arduino sprintf just returns "?" for floats, use dtostrf
    dtostrf(measurements[i].value, 9, 2, &buffer[strlen(buffer)]);

    // transmit buffer to client
    client.println(buffer);
    DEBUG(buffer);
  }

  // reset num_measurements
  num_measurements = 0;
}

void submitValues() {
  // close any connection before send a new request.
  // This will free the socket on the Ethernet shield
  if (client.connected()) {
    client.stop();
    delay(1000);
  }
  bool connected = false;
  char _server[strlen_P(server)];
  strcpy_P(_server, server);
  for (uint8_t timeout = 2; timeout != 0; timeout--) {
    DEBUG(F("connecting..."));
    connected = client.connect(_server, 80);
    if (connected == true) {
      DEBUG(F("Connection successful, transferring..."));
      // construct the HTTP POST request:
      sprintf_P(buffer,
                PSTR("POST /boxes/%S/data HTTP/1.1\nHost: %S\nContent-Type: "
                     "text/csv\nConnection: close\nContent-Length: %i\n"),
                SENSEBOX_ID, server, num_measurements * 36);
      DEBUG(buffer);

      // send the HTTP POST request:
      client.println(buffer);

      // send measurements
      writeMeasurementsToClient();

      // send empty line to end the request
      client.println();

      delay(100);
      client.flush();
      client.stop();

      DEBUG("done!");

      // reset number of measurements
      num_measurements = 0;
      break;
    }
    delay(1000);
  }

  if (connected == false) {
    // Reset durchführen
    Serial.println(F("connection failed. Restarting System."));
    delay(5000);
    cli();
    wdt_enable(WDTO_60MS);
    while (1)
      ;
  }
}

void setup() {
  // Initialize serial and wait for port to open:
  Serial.begin(9600);

  DEBUG(F("Initializing DHCP connection..."));
  if (Ethernet.begin(mac) == 0) {
    DEBUG(F("failed! Trying static IP setup."));
    Ethernet.begin(mac, myIp, myDns, myGateway, mySubnet);
    //@TODO: Add reference to support site for network settings
  } else {
    DEBUG("done!");
  }

  // Sensor initialization
  DEBUG(F("Initializing sensors..."));
  VEML.begin();
  delay(500);
  HDC.begin(HDC100X_TEMP_HUMI, HDC100X_14BIT, HDC100X_14BIT, DISABLE);
  TSL.begin();
  BMP.begin();
  BMP.setOversampling(4);
  DEBUG(F("done!"));
  DEBUG(F("Starting loop in 30 seconds."));
  HDC.getTemp();
  delay(30000);
}

void loop() {
  // capture loop start timestamp
  unsigned long start = millis();

  // read measurements from sensors
  addMeasurement(TEMPERSENSOR_ID, HDC.getTemp());
  delay(200);
  addMeasurement(RELLUFSENSOR_ID, HDC.getHumi());

  double tempBaro, pressure;
  char result;
  result = BMP.startMeasurment();
  if (result != 0) {
    delay(result);
    result = BMP.getTemperatureAndPressure(tempBaro, pressure);
    addMeasurement(LUFTDRSENSOR_ID, pressure);
  }

  addMeasurement(BELEUCSENSOR_ID, TSL.readLux());
  addMeasurement(UVINTESENSOR_ID, VEML.getUV());

  uint8_t attempt = 0;
  float pm10, pm25;
  while (attempt < 5) {
    bool error = my_sds.read(&pm25, &pm10);
    if (!error) {
      addMeasurement(PM10SENSOR_ID, pm10);
      addMeasurement(PM25SENSOR_ID, pm25);
      break;
    }
    attempt++;
  }

  submitValues();

  // schedule next round of measurements
  for (;;) {
    unsigned long now = millis();
    unsigned long elapsed = now - start;
    if (elapsed >= postingInterval)
      return;
  }
}
