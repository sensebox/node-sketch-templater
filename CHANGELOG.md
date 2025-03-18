# node-sketch-templater Changelog

## Unreleased

## v1.13.3

## v1.13.2

## v1.13.1
- 🐛 Fix EOL in template files

## v1.13.1-beta.0

## v.1.13.0
- ⚙️ Add SPS30 Sensor

## v1.12.1

- 🔧 Remove whitespaces in `sensorTypes` included in variable names
- 🧪 Update tests to reflect sensorTypes fcoming from API

## v1.12.0

- 🔧 Fix variable naming

## v1.11.2
- 🔧 Fix BME680_CONNECTED issue
- 🖥 Fix OLED initialisation ([#78](https://github.com/sensebox/node-sketch-templater/issues/78))

## v1.11.1
- ⬇️ Set `node` engine to v14

## v1.11.0
- 🧹 Housekeeping (`dependebot`, `dependencies`)
- 🐻 BearSSL library
- ℹ️ Add senseBox metadata and version number to sketches
- ⚙️ DPS310 library

## v1.10.5
- Fix LTR

## v1.10.4
- Add LTR329 library

## v1.10.2
- Power UART in setup

## v1.10.1

## v1.10.0

## v1.9.0

## v1.8.3
- Add CO2 Sensor

## v1.8.3-beta.4

## v1.8.3-beta.3

## v1.8.3-beta.2

## v1.8.3-beta.1

## v1.8.2
- Fix duplicate variable voltage

## v1.8.1

## v1.8.0
- Add windspeed sensor to templates

## v1.7.0
- Release new version

## v1.7.0-beta2

## v1.7.1-beta
- Rename Parameters

## v1.7.0-beta
- Add TTN Transformer to insert and transform keys

## v1.5.5
- Added delay to BME gas reading in lora sketch

## v1.5.4

## v1.5.3
- Add SMT50, Sound Level Meter and BME680 to LoRa sketch

## v1.5.2
- Fix integration of Sound Level Meter
- Add missing semicolon

## v1.5.1
- Implemented transformer `digitalPortToPortNumber`

## v1.5.0
- Added 3 new sensors for senseBox V2 (`BME680`, `SMT50`, `SoundLevelMeter`)

## v1.4.0
- Fix #13 in all V2 sketches
- use new `<Ethernet.h>` library in V2 ethernet sketches
- replaced all `Serial.print() and Serial.println()` with DEBUG statements

## v1.4.0-beta.4
- Fix #13 in all V2 sketches
- use new `<Ethernet.h>` library in V2 ethernet sketches
- replaced all `Serial.print() and Serial.println()` with DEBUG statements

## v1.4.0-beta.3

## v1.4.0-beta
- Add `SSID` and `Password` replacement possibility for `homeV2Wifi` models

## v1.3.0
- Add LoRa template for senseBox MCU

## v1.2.0
- Add WiFi template for new senseBox MCU
- Add Ethernet template for new senseBox MCU
- Allow to specify serial port for SDS 011 on new senseBox MCU

## v1.1.2
- Change content-type header in all sketches to `text/csv` instead of just `csv` [@mpfeil](https://github.com/mpfeil)

## v1.1.1
- Fix calling constructor SketchTemplater with undefined parameter caused an error

## v1.1.0
- Include lorenwest/node-config for configuration
- Allow to specify ingress domain both as js object and plain string in SketchTemplater constructor
- Allow to specify ingress domain through external configuration

## v1.0.10
- Update v2 sketch for senseBox MCU Rev 1.1 and arduino-senseBoxCore 1.0.2

## v1.0.9
- Added sketch template for new senseBox board
- Updated the building process to test the new sketch
- Update travis configuration: Install senseBox core and use Arduino IDE 1.8.5

## v1.0.8
- Use Ethernet2.h library in ethernet templates homeEthernet and homeEthernetFeinstaub

## v1.0.7
- Fix Arduino compilation warnings in homeWifi, homeEthernet, homeWifiFeinstaub and homeEthernetFeinstaub templates

## v1.0.6
- Do not push eslint, travis gitignore files to npm

## v1.0.3
- Bump sketch versions
- Unify sketch headers
- Implement sprintf_P PROGMEM based building of HTTP strings and payload
- Should send less TCP packets
- Use same structure in all templates except `custom`

## v1.0.2
Add `encoding` field to `generateSketch` which allows to specify base64 encoding

## v1.0.1
Fix npm package name in README.md

## v1.0.0
Initial release to npm after extracting from sensebox/openSenseMap-API
