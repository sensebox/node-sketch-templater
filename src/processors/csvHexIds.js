'use strict';

const dedent = require('dedent');

/* sensors should follow this order strictly
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

const sensorToString = function sensorToString({ title, _id }) {
  return dedent`// ${title}
                { ${idToHex(_id)} }`;
};

const transformSensors = function transformSensors(sensors) {
  const homeSensors = [];
  const otherSensors = [];

  for (const sensor of sensors) {
    const index = homeSensorTitles.findIndex(t => t === sensor.title);

    if (index !== -1) {
      homeSensors[index] = sensorToString(sensor);
      continue;
    }

    otherSensors.push(sensorToString(sensor));
  }

  return homeSensors.filter(s => s).concat(otherSensors).join(',\n');
};

const idToHex = function idToHex(idStr) {
  return idStr.toString().replace(/(..)/g, ', 0x$1').substr(2);
};

const substitutions = {
  ctSensors(box) {
    return dedent`// Number of sensors
                  static const uint8_t NUM_SENSORS = ${box.sensors.length};`;
  },
  postDomain(postDomain) {
    return `const char *server = "${postDomain}";`;
  },
  IDs(box) {
    return dedent`// senseBox ID and sensor IDs
                  const uint8_t SENSEBOX_ID[12] = { ${idToHex(box._id)} };

                  // Do not change order of sensor IDs
                  const sensor sensors[NUM_SENSORS] = {
                  ${transformSensors(box.sensors)}
                  };`;
  }
};

module.exports = function processSketchWifi({ template, box, postDomain }) {
  return template.replace(/^@-- tmpl ([a-zA-z]+)$/gm, function(
    match,
    subTemplateKey
  ) {
    return substitutions[subTemplateKey](
      subTemplateKey === 'postDomain' ? postDomain : box
    );
  });
};
