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
        _id: randomHex()
      },
      {
        title: 'Luftdruck',
        _id: randomHex()
      },
      {
        title: 'Kellertemperatur',
        _id: randomHex()
      }
    ]
  };
};
