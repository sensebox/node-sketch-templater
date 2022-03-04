'use strict';

const randomHex = function randomHex() {
  return Buffer.from(Math.random().toString(36)).toString('hex');
};

module.exports = function testBox() {
  return {
    _id: randomHex(),
    name: 'Teststation',
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
    ssid: 'MY-HOME-NETWORK',
    password: 'MY-SUPER-PASSWORD'
  };
};
