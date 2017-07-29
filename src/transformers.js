'use strict';

const dedent = require('dedent');

module.exports = {
  'as-is'(str) {
    return str;
  },
  toDefine(sensors) {
    const output = [];
    for (const [i, { _id, title }] of sensors.entries()) {
      output.push(dedent`// ${title}
                         #define SENSOR${i + 1}_ID "${_id}"`);
    }

    return output.join('\r\n');
  },
  toProgmem(sensors) {
    const output = [];
    for (const { _id, title } of sensors) {
      output.push(dedent`// ${title}
                         const char ${title
                           .toUpperCase()
                           .replace(/[^A-Z0-9]+/g, '')
                           .slice(0, 6)}SENSOR_ID[] PROGMEM = "${_id}";`);
    }

    return output.join('\r\n');
  }
};
