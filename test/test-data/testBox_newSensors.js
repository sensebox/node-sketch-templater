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
      }
    ],
    serialPort: 'Serial1',
    soilDigitalPort: 'B',
    soundMeterPort: 'C',
    ssid: 'MY-HOME-NETWORK',
    password: 'MY-SUPER-PASSWORD',
    devEui: '00DD31D067B999DF',
    appEui: '70B3D57ED002E0C8',
    appKey: 'ADF11B14C2747C1DB5F790D6921EE7E5'
  };
};
