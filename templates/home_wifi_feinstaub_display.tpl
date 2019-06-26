/*
  senseBox - Citizen Sensing Platform
  Version: mcu_1.0.0
  Date: 2019-04-26
  Homepage: https://www.sensebox.de https://www.opensensemap.org
  Author: Reedu GmbH & Co. KG
  Note: Sketch for senseBox:home (MCU Edition)
  Model: homeV2_WiFi
  Email: support@sensebox.de
  Code is in the public domain.
  https://github.com/sensebox/node-sketch-templater
*/

// LED blink codes //
// Blink green if trying to connect. If connected, solid green light.
// Blink red fast(10Hz): no sensor data
// Blink red slow( 1Hz): no WiFi Module found

/* -------------------------------------------------------------------- */
/* ------------------------- User Settings ---------------------------- */
/* -------------------------------------------------------------------- */
 // if DEBUG_MODE set to '1' you get more detailed output on serial monitor.
 // CAUTION: program will not start until serial monitor has been opened. 
 // Set back to '0' before field deployment!
#define DEBUG_MODE 0

/********* WiFi Credentials *********/
const char *ssid = "GIATSCHOOL-NET"; // your network SSID (name)
const char *pass = "werockschools"; // your network password
/********** Hardware Setup **********/
#define HDC_CONNECTED
#define BMP_CONNECTED
#define LIGHT_CONNECTED
#define DISPLAY_CONNECTED
#define SDS_CONNECTED (Serial1)

/********** OSeM Settings **********/
// ID's are taken from https://api.opensensemap.org/boxes/5ca1e336cbf9ae001a6f1d81
// address of the openSenseMap server
const char server[] PROGMEM = "ingress.opensensemap.org";
// senseBox ID
const char SENSEBOX_ID[] PROGMEM = "5ca1e336cbf9ae001a6f1d81";
// sensor IDs
// Temperatur
const char TEMPERSENSOR_ID[] PROGMEM = "5ca1e336cbf9ae001a6f1d88";
// rel. Luftfeuchte
const char RELLUFSENSOR_ID[] PROGMEM = "5ca1e336cbf9ae001a6f1d87";
// Luftdruck
const char LUFTDRSENSOR_ID[] PROGMEM = "5ca1e336cbf9ae001a6f1d86";
// Beleuchtungsstärke
const char BELEUCSENSOR_ID[] PROGMEM = "5ca1e336cbf9ae001a6f1d85";
// UV-Intensität
const char UVINTESENSOR_ID[] PROGMEM = "5ca1e336cbf9ae001a6f1d84";
// PM10
const char PM10SENSOR_ID[] PROGMEM = "5ca1e336cbf9ae001a6f1d83";
// PM2.5
const char PM25SENSOR_ID[] PROGMEM = "5ca1e336cbf9ae001a6f1d82";
// Authentication Token
//const char AUTH_TOKEN[] PROGMEM = "XXXXXXXXXX";

/* -------------------------------------------------------------------- */
/* -------------------- End of User Settings -------------------------- */
/* -------------------------------------------------------------------- */
int measuredPhenomena = 0;
// Display interval 
const long display_interval = 2000;
long time_start = 0;
long time_actual = 0;
unsigned long lastConnectionTime = 0 ;
int displayCounter = 0; 

/******* Libraries to include *******/
#include <SPI.h>
#include <Wire.h>
#include <WiFi101.h>
#include <senseBoxIO.h>
/*********** Display Setup***********/
#ifdef DISPLAY_CONNECTED
  #include <Adafruit_SSD1306.h>
  #include <Adafruit_GFX.h>
  #define OLED_RESET 4  
  Adafruit_SSD1306 display(OLED_RESET); 
#endif
/*********** Sensor Setup ***********/
#if defined HDC_CONNECTED
  #include <Adafruit_HDC1000.h>
  Adafruit_HDC1000 hdc;
  float temperature, humidity;
  bool hdc_test_passed = false;
#endif
#if defined BMP_CONNECTED
  #include <Adafruit_BMP280.h>
  Adafruit_BMP280 bmp;
  float pressure,temp;
  bool bmp_test_passed = false;
#endif
#if defined LIGHT_CONNECTED
  #include <VEML6070.h>
  #include <Makerblog_TSL45315.h>
  VEML6070 veml;
  float uvIntensity;
  bool veml_test_passed = false;
  Makerblog_TSL45315 tsl = Makerblog_TSL45315(TSL45315_TIME_M4);
  long illuminance;
  bool tsl_test_passed = false;
#endif
#if defined SDS_CONNECTED
  #include <SDS011-select-serial.h>
  float pm10,pm25;
  SDS011 SDS(SDS_CONNECTED);
  bool sds_test_passed = false;
#endif

/******* Network Client Setup *******/
#if defined AUTH_TOKEN
  WiFiSSLClient senseBox_client;
#else
  WiFiClient senseBox_client;
#endif
String sensorDataCsv = "";
const unsigned long postingInterval = 60000;

/* ------------------------------------- */
/* -------- System Functions ----------- */
/* ------------------------------------- */
void connectToWlan() {
  senseBoxIO.statusNone();
  uint8_t status = WL_IDLE_STATUS;
  do{
     if(DEBUG_MODE){
     Serial.print("Attempting to connect to SSID: ");
     Serial.println(ssid);}
     senseBoxIO.statusGreen();
     delay(250);
     senseBoxIO.statusNone();
     delay(250);
     status = WiFi.begin(ssid, pass);
     senseBoxIO.statusGreen();
     delay(250);
     senseBoxIO.statusNone();
     delay(250);
  }while (status != WL_CONNECTED);
  if(DEBUG_MODE)Serial.println("Connection Successful");
  senseBoxIO.statusNone();
  senseBoxIO.statusGreen();
}

// Check sensor communication //
void testSensors(){
// Check if SDS connected //
#if defined SDS_CONNECTED
  if(DEBUG_MODE)Serial.println("\nChecking UART port...");
  //Scan serial ports for connection//
  senseBoxIO.powerUART(false);
  delay(250);
  senseBoxIO.powerUART(true);
  delay(5000);
  SDS_CONNECTED.begin(9600);
  if (checkSerialPort(SDS_CONNECTED) == 1)
  {
    if(DEBUG_MODE){
      Serial.println("-SDS011 connected.");
      measuredPhenomena+=2;
      delay(1000);}
  }
  else{
    if(DEBUG_MODE){
      Serial.println("-Warning: SDS011 not found on specified port.");
      delay(2000);}
    SDS_CONNECTED.end();
    //senseBoxIO.powerUART(false);
    
  }
#endif
  if(DEBUG_MODE)Serial.println("\nChecking I2C ports...");
// Init and scan I2C ports for connected sensors //
  senseBoxIO.powerI2C(false);
  delay(250);
  senseBoxIO.powerI2C(true);
  delay(250);
  Wire.begin();
  byte devices = 0;
  for(byte address = 1; address < 127; address++ )
  {
    Wire.beginTransmission(address);
    byte error = Wire.endTransmission();
    if(error == 0)
    {
      devices++;
      if(DEBUG_MODE){
        Serial.print("-Device found at 0x");
        Serial.println(address, HEX);}
      checkWirePort(address);
    }
    else if (error ==4)
    {
      if(DEBUG_MODE){
        Serial.print("\n-Unknown Error at 0x");
        Serial.println(address, HEX);}
    }
  }
}

#if defined SDS_CONNECTED
  /* check if sds is connected */
  int checkSerialPort(HardwareSerial &uart){
    int sds_data;
    for (int i = 1; i < 3; i++){
      sds_data = 0;
      while (uart.available() > 0){
        byte buffer = uart.read();
        sds_data += int(buffer);
      }
      delay(1000);
    }
    delay(250);
    if (sds_data > 1){
      sds_test_passed = true;
      return 1;
    }
    else return 0;
  }
#endif

/* Check all I2C addresses for cennected devices */
void checkWirePort(byte &address){
  if((address == 0) || (address > 127)) return;
  switch(address){
    case 0x29: 
    #if defined LIGHT_CONNECTED
      tsl.begin();
      tsl_test_passed = true;
      if(DEBUG_MODE)Serial.println("-TSL45315 connected.");
      measuredPhenomena+=1;
    #else
      if(DEBUG_MODE)Serial.println("-Attention: TSL45315 found but not defined in hardware setup.");
    #endif
      break;
    case 0x38:
    //case 0x39:
    #if defined LIGHT_CONNECTED
      if(DEBUG_MODE)Serial.println("-VEML6070 connected.");
      veml.begin();
      veml_test_passed = true;
      measuredPhenomena+=1;
    #else
      if(DEBUG_MODE)Serial.println("-Attention: VEML6070 found but not defined in hardware setup.");
    #endif
      break;
    case 0x40:  //HDC1080
    case 0x41:
    //case 0x42:
    case 0x43:
    #if defined HDC_CONNECTED
      hdc.begin(address);
      hdc_test_passed = true;
      if(DEBUG_MODE)Serial.println("-HDC1080 connected.");
      measuredPhenomena+=2;
    #else
      if(DEBUG_MODE)Serial.println("-Attention: HDC1080 found but not defined in hardware setup.");
    #endif
      break;
    case 0x76:
    case 0x77:
    #if defined BMP_CONNECTED
      bmp.begin(address);
      bmp_test_passed = true;
      if(DEBUG_MODE)Serial.println("-BMP280 connected.");
      measuredPhenomena+=1;

    #else
      if(DEBUG_MODE)Serial.println("-Attention: BMP280 found but not defined in hardware setup.");
    #endif
      break;
  }
  delay(250);
}

/* Uploading the sensor data as CSV over HTTP to openSenseMap */
void sendData(){
  senseBox_client.stop();
  String httpRequestUrl = "POST /boxes/" + String(SENSEBOX_ID) + "/data HTTP/1.1";
  int contentLength = sensorDataCsv.length();
  Serial.println("\nCalling openSenseMap...");
#if defined AUTH_TOKEN
  if (senseBox_client.connect(server, 443)) //port 443 for SSL and 80 for standart
#else
  if (senseBox_client.connect(server, 80))
#endif
  {
    lastConnectionTime = millis();
    Serial.println("-Connection established.\n");
    Serial.print("Sending HTTP request: ");
    Serial.println(httpRequestUrl);
  // Construct HTTP header//
    senseBox_client.println(httpRequestUrl);
    senseBox_client.print  ("Host: ");senseBox_client.println(server);
  #if defined AUTH_TOKEN
    senseBox_client.print("Authorization: Basic ");senseBox_client.println(AUTH_TOKEN);
  #endif
    senseBox_client.println("Content-Type: text/csv");
    senseBox_client.println("Connection: close");
    senseBox_client.print  ("Content-Length: ");senseBox_client.println(contentLength);
    senseBox_client.println();
  // Send the data (CSV) //
    senseBox_client.println(sensorDataCsv);
    senseBox_client.println();
    Serial.println("-Done. Waiting for server response...\n");
  }
  else{
  // If connection failed report //
    Serial.println("-Connection failed.");
    senseBoxIO.statusRed();
  }
}

/*************************************************/
/* Add a new row to the CSV file for each sensor */
/*************************************************/
void addMeasurementToCsv(const char *sensorId, float measurement){
  String newRow = String(sensorId) + ',' + String(measurement) + '\n';
  sensorDataCsv += newRow;
  if(DEBUG_MODE)Serial.print(newRow);
}

void addMeasurementToCsv(const char *sensorId, int measurement){
  String newRow = String(sensorId) + ',' + String(measurement) + '\n';
  sensorDataCsv += newRow;
  if(DEBUG_MODE)Serial.print(newRow);
}

void addMeasurementToCsv(const char *sensorId, long measurement){
  String newRow = String(sensorId) + ',' + String(measurement) + '\n';
  sensorDataCsv += newRow;
  if(DEBUG_MODE)Serial.print(newRow);
}
void print2Display(String message,int x, int y,int textSize)
{
    display.setCursor(x,y);
    display.setTextSize(textSize);
    display.setTextColor(WHITE,BLACK);
    display.println(message);
    display.display();
}

void readSensorsAndSendData(){
  if(DEBUG_MODE){
    Serial.println("\n\n------------------------------------------------------");
    Serial.println("Reading sensor data...");}
  sensorDataCsv = "";
/* ------------------------------------------------------------------------- */
/* - Use addMeasurementToCsv(*SENSOR_ID , MEASUREMENT) to extend CSV file. - */
/* -------- Put your code inside this block for manual sensor setup -------- */
/* ------------------------------------------------------------------------- */


/* --------------------------------------------------------------------- */
  #if defined HDC_CONNECTED
    if (hdc_test_passed){
      if(DEBUG_MODE)Serial.print("HDC...");
      temperature = hdc.readTemperature();
      addMeasurementToCsv(TEMPERSENSOR_ID, temperature);
      humidity = hdc.readHumidity();
      addMeasurementToCsv(RELLUFSENSOR_ID, humidity);
    }
  #endif
  #if defined BMP_CONNECTED
    if (bmp_test_passed){
      if(DEBUG_MODE)Serial.print("BMP...");
      temp = bmp.readTemperature();
      pressure = bmp.readPressure()/100; //pressure in hPa
      addMeasurementToCsv(LUFTDRSENSOR_ID, pressure);
    }
  #endif
  #if defined LIGHT_CONNECTED
    if (tsl_test_passed){
      if(DEBUG_MODE)Serial.print("TSL...");
      illuminance = long(tsl.readLux());
      addMeasurementToCsv(BELEUCSENSOR_ID, illuminance);
    }
    if (veml_test_passed){
      if(DEBUG_MODE)Serial.print("VEML...");
      uvIntensity = veml.getUV();
      addMeasurementToCsv(UVINTESENSOR_ID, uvIntensity);
    }
  #endif
  #if defined SDS_CONNECTED
    if(sds_test_passed){
      if(DEBUG_MODE)Serial.print("SDS...");
      uint8_t attempt = 0;
      while (attempt < 5) {
        bool sds_error = SDS.read(&pm25, &pm10);
        if (!sds_error) {
          addMeasurementToCsv(PM10SENSOR_ID, pm10);
          addMeasurementToCsv(PM25SENSOR_ID, pm25);
          break;
        }
        attempt++;
      }
    }
  #endif
// Check if there is data available //
  if (sensorDataCsv.length() == 0){
    if(DEBUG_MODE)Serial.println("\n-Can not continue. No sensor data available!");
    while (true){
      senseBoxIO.statusRed();
      delay(100);
      senseBoxIO.statusNone();
      delay(100);
    }
  }
  else
  {
    if(DEBUG_MODE)Serial.println("Done.");
    sendData(); //send CSV to openSenseMap
  }
}
/******** SETUP routine ********/
void setup() { // is called only once before the endless loop
  senseBoxIO.statusNone();
  Serial.begin(9600);
  if(DEBUG_MODE)while(!Serial);
  //check if WINC1500 is available
  senseBoxIO.powerXB1(false);
  delay(250);
  senseBoxIO.powerXB1(true);
  //Blink red if bee not found
  if(WiFi.status() == WL_NO_SHIELD)
  {
    WiFi.end();
    senseBoxIO.powerXB1(false);
    if(DEBUG_MODE)Serial.println("No WiFi Module found. Please power off, check connection and restart device!");
    while(true){
      senseBoxIO.statusRed();
      delay(1000);
      senseBoxIO.statusNone();
      delay(1000);
    }
  }

  testSensors();
  #ifdef DISPLAY_CONNECTED
    senseBoxIO.powerI2C(true);
    delay(2000);
    display.begin(SSD1306_SWITCHCAPVCC, 0x3D);
    display.display();
    delay(1000);
    display.clearDisplay();
  #endif
}
/* endless LOOP */
void loop() { //function repeated until power supply disconnected
  if (WiFi.status() != WL_CONNECTED){
    WiFi.end();
    senseBoxIO.powerXB1(false);
    delay(250);
    senseBoxIO.powerXB1(true);
    connectToWlan();
  }
  else {
    unsigned long currentTime = millis();
    if ((unsigned long)(currentTime - lastConnectionTime) >= postingInterval || lastConnectionTime == 0) {
      readSensorsAndSendData();
    }

    // Reading answer from server //
    while (senseBox_client.available()){
      char c = senseBox_client.read();
      Serial.write(c);
    }
    // Create Array for the display interval // 
    #ifdef DISPLAY_CONNECTED
      float measurements[measuredPhenomena];
      String phenomenons[measuredPhenomena];
      int cursor = 0;
      #ifdef HDC_CONNECTED
        measurements[cursor] = temperature;
        phenomenons[cursor] = "Temperature";
        cursor+=1;
        measurements[cursor] = humidity;
        phenomenons[cursor] = "Humidity";

        cursor+=1;
      #endif
      #ifdef BMP_CONNECTED
        measurements[cursor] = pressure;
        phenomenons[cursor] = "Air pressure";
        cursor+=1;
      #endif
      #ifdef LIGHT_CONNECTED
        measurements[cursor] = uvIntensity;
        phenomenons[cursor] = "UV-Intensity";

        cursor+=1;
        measurements[cursor] = illuminance;
        phenomenons[cursor] = "illuminance";
        cursor+=1;
      #endif
      #ifdef SDS_CONNECTED
        measurements[cursor] = pm10;
        phenomenons[cursor] = "PM10";

        cursor+=1;
        measurements[curosr] = pm25;
        phenomenons[cursor] = "PM25";

        cursor+=1;
      #endif
    time_start = millis();
    if (time_start > time_actual + display_interval) {
        time_actual = millis();
        display.clearDisplay();
        
        print2Display(phenomenons[displayCounter],0,0,2);
        print2Display(String(measurements[displayCounter]),0,35,2);

        displayCounter+=1;
        if(displayCounter == measuredPhenomena){
            displayCounter = 0 ;
        }
    }
    #endif 

  }
  
}