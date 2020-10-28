'use strict';

const randomHex = function randomHex() {
  return Buffer.from(Math.random().toString(36)).toString('hex');
};

module.exports = function testBox() {
  return {
    _id: randomHex(),
    sensors: [
      {
        title: 'Temperatur',
        _id: randomHex(),
        sensorType: 'HDC1080'
      },
      {
        title: 'Luftdruck',
        _id: randomHex(),
        sensorType: 'BMP280'
      },
      {
        title: 'Kellertemperatur',
        _id: randomHex(),
        sensorType: 'HDC1080'
      },
      {
        title: 'Windgeschwindigkeit',
        _id: randomHex(),
        sensorType: 'WINDSPEED'
      },
      {
        title: 'CO₂',
        _id: randomHex(),
        sensorType: 'SCD30'
      }
    ],
    serialPort: 'Serial1',
    windSpeedPort: 'A',
    soilDigitalPort: 'B',
    soundMeterPort: 'C',
    ssid: 'MY-HOME-NETWORK',
    password: 'MY-SUPER-PASSWORD',
    devEUI: '00DD31D067B999DF',
    appEUI: '70B3D57ED002E0C8',
    appKey: 'ADF11B14C2747C1DB5F790D6921EE7E5'
  };
};
