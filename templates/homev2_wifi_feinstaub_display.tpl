{ "model" : "homeV2WifiFeinstaubDisplay", "board": "senseBox:samd:sb" }
/*
  senseBox:home - Citizen Sensingplatform
  Version: wifiv2_0.2
  Date: 2018-05-17
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

#include <Adafruit_Sensor.h>
#include <Adafruit_HDC1000.h>
#include <Adafruit_BMP280.h>
#include <Makerblog_TSL45315.h>
#include <VEML6070.h>
#include <SDS011-select-serial.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_GFX.h>
#define OLED_RESET 4  

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

// Number of serial port the SDS011 is connected to. Either Serial1 or Serial2
#define SDS_UART_PORT (@@SERIAL_PORT@@)

// Interval of measuring and submitting values in seconds
const unsigned int postingInterval = @@POSTING_INTERVAL@@e3;

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
#ifdef SDS011_CONNECTED
  SDS011 SDS(SDS_UART_PORT);
#endif
#ifdef DISPLAY_CONNECTED
  Adafruit_SSD1306 display(OLED_RESET); 
  // interval in which the displayed measurements switch 
  const long display_interval = 5000;
  // variables needed for switching of measurements on the display
  long time_start = 0;
  long time_actual = 0;
  unsigned long lastConnectionTime = 0 ;
  int displayCounter = 0; 
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
                PSTR("POST /boxes/%s/data HTTP/1.1\nHost: %s\nContent-Type: "
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
  byte sensorAddr[] = {41, 56, 57, 64, 118};
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
          DEBUG("BMP280 found.");
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
// helper function for the display
#ifdef DISPLAY_CONNECTED
  void print2Display(String message,int x, int y,int textSize)
  {
      display.setCursor(x,y);
      display.setTextSize(textSize);
      display.setTextColor(WHITE,BLACK);
      display.println(message);
      display.display();
  }
#endif
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
  #ifdef SDS011_CONNECTED
    SDS_UART_PORT.begin(9600);
  #endif
  // Initialize display
  #ifdef DISPLAY_CONNECTED
    display.begin(SSD1306_SWITCHCAPVCC, 0x3D);
    display.display();
    delay(1000);
    display.clearDisplay();
  #endif
  DEBUG(F("Initializing sensors done!"));
  DEBUG(F("Starting loop in 3 seconds."));
  delay(3000);
}

void loop() {
  DEBUG(F("Starting new measurement..."));
  // capture loop start timestamp
  unsigned long start = millis();
  // Arrays that hold measurements and descriptions for display
  float measurements[NUM_SENSORS];
  String phenomenons[NUM_SENSORS];
  // cursor for display
  int cursor = 0;
  //-----Temperature-----//
  //-----Humidity-----//
  #ifdef HDC1080_CONNECTED
    addMeasurement(TEMPERSENSOR_ID, HDC.readTemperature());
    delay(200);
    addMeasurement(RELLUFSENSOR_ID, HDC.readHumidity());
    // fill arrays
    #ifdef DISPLAY_CONNECTED
      measurements[cursor] = HDC.readTemperature();
      phenomenons[cursor] = "Temperatur";
      cursor+=1;
      measurements[cursor] = HDC.readHumidity();
      phenomenons[cursor] = "rel. Luftfeuchte";
      cursor+=1;
    #endif
  #endif

  //-----Pressure-----//
  #ifdef BMP280_CONNECTED
    float pressure;
    pressure = BMP.readPressure()/100;
    addMeasurement(LUFTDRSENSOR_ID, pressure);
    #ifdef DISPLAY_CONNECTED
        measurements[cursor] = BMP.readPressure()/100;
        phenomenons[cursor] = "Luftdruck";
        cursor+=1;
    #endif
  #endif

  //-----Lux-----//
  #ifdef TSL45315_CONNECTED
    addMeasurement(BELEUCSENSOR_ID, TSL.readLux());
    #ifdef DISPLAY_CONNECTED
        measurements[cursor] = TSL.readLux();
        phenomenons[cursor] = "Lux";
        cursor+=1;
    #endif
  #endif

  //-----UV intensity-----//
  #ifdef VEML6070_CONNECTED
    addMeasurement(UVINTESENSOR_ID, VEML.getUV());
    #ifdef DISPLAY_CONNECTED
        measurements[cursor] = VEML.getUV();
        phenomenons[cursor] = "UV";
        cursor+=1;
    #endif
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
    #ifdef DISPLAY_CONNECTED
        measurements[cursor] = pm10;
        phenomenons[cursor] = "PM10";
        cursor+=1;
        measurements[cursor] = pm25;
        phenomenons[cursor] = "PM25";
        cursor+=1;
    #endif
  #endif
  DEBUG(F("Submit values"));
  submitValues();

  // schedule next round of measurements
  for (;;) {
    unsigned long now = millis();
    unsigned long elapsed = now - start;
    #ifdef DISPLAY_CONNECTED
      if (now > time_actual + display_interval) {
      // Every 5 seconds (depending on display_interval)
      // Switch the display to another measurement
      time_actual = millis();
      display.clearDisplay();
      
      print2Display(phenomenons[displayCounter],0,0,2);
      print2Display(String(measurements[displayCounter]),0,35,2);

      displayCounter+=1;
      // restart count when last measurement was displayed
      if(displayCounter == NUM_SENSORS){
          displayCounter = 0 ;
      }
      }
    #endif
    if (elapsed >= postingInterval)
      return;
  }
}
