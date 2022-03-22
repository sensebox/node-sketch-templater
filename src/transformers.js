'use strict';

const dedent = require('dedent');

module.exports = {
  'as-is'(str) {
    return str;
  },
  toDefine(sensors) {
    const output = [];
    for (const [i, { _id, title, sensorType }] of sensors.entries()) {
      output.push(dedent`// ${title} - ${sensorType}
                         #define SENSOR${i + 1}_ID "${_id}"`);
    }

    return output.join('\r\n');
  },
  toDefineWithSuffixPrefixAndKey(sensors, prefix, suffix, key) {
    const output = [];
    for (const [, sensor] of sensors.entries()) {
      const value = sensor[key].replace(/\s+/g, '');
      output.push(dedent`// ${sensor.title} - ${sensor.sensorType}
                         #define ${prefix}${value.toUpperCase()}${suffix}`);
    }

    return output.join('\r\n');
  },
  toProgmem(sensors) {
    const output = [];
    for (const { _id, title, sensorType } of sensors) {
      output.push(dedent`// ${title} - ${sensorType}
                         const char ${sensorType.toUpperCase()}_${title
        .toUpperCase()
        .replace(/[^A-Z0-9]+/g, '')
        .slice(0, 6)}SENSOR_ID[] PROGMEM = "${_id}";`);
    }

    return output.join('\r\n');
  },
  digitalPortToPortNumber(port, offset = 0) {
    let portNumber = 0;
    switch (port) {
      case 'A':
        portNumber = 1;
        break;
      case 'B':
        portNumber = 3;
        break;
      case 'C':
        portNumber = 5;
        break;
    }

    return Number(portNumber) + Number(offset);
  },
  transformTTNID(eui, lsb = false) {
    if (eui === undefined || (eui.length !== 16 && eui.length !== 32)) {
      return '{ }';
    }

    // split eui into chunks of two
    let chunks = eui.match(/.{1,2}/g);

    if (lsb) {
      chunks = chunks.reverse();
    }

    return `{${chunks.map((c) => ` 0x${c}`)} }`;
  },
  toDefineDisplay(display) {
    const output = [];
    if (display === 'true') {
      output.push(`#define DISPLAY128x64_CONNECTED`);
    } else {
      output.push(`//#define DISPLAY128x64_CONNECTED`);
    }

    return output.join('\r\n');
  }
};
