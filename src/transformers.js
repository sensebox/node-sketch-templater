'use strict';

const dedent = require('dedent');

/* Used in toHexArray
 * sensors should follow this order strictlyI
 * when using the standard senseBox:home wifi setup
 * 0 Temperature
 * 1 Humidity
 * 2 Pressure
 * 3 Lux
 * 4 UV
 * 5 PM10
 * 6 PM2.5
 * the rest
 */
const homeSensorTitles = [
  'Temperatur',
  'rel. Luftfeuchte',
  'Luftdruck',
  'Beleuchtungsstärke',
  'UV-Intensität',
  'PM10',
  'PM2.5'
];

module.exports = {
  'as-is'(str) {
    return str;
  },
  toHex(idStr) {
    return idStr.toString().replace(/(..)/g, ', 0x$1').substr(2);
  },
  toDefine(sensors) {
    const output = [];
    for (const [i, { _id, title }] of sensors.entries()) {
      output.push(dedent`// ${title}
                         #define SENSOR${i + 1}_ID "${_id}"`);
    }

    return output.join('\r\n');
  },
  toHexArray(sensors) {
    const homeSensors = [];
    const otherSensors = [];
    for (const { _id, title } of sensors) {
      const index = homeSensorTitles.findIndex(t => t === title);
      if (index !== -1) {
        homeSensors[index] = dedent`// ${title}
                                    { ${this.toHex(_id)} }`;
        continue;
      }
      otherSensors.push(dedent`// ${title}
                               { ${this.toHex(_id)} }`);
    }

    return homeSensors.filter(s => s).concat(otherSensors).join(',\r\n');
  }
};
