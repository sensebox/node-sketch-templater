'use strict';

const dedent = require('dedent');

const constructSensorsDefinitions = function constructSensorsDefinitions(
  sensors
) {
  const output = [];
  for (const [i, { _id, title }] of sensors.entries()) {
    output.push(`#define SENSOR${i + 1}_ID "${_id}" // ${title}`);
  }

  return output.join('\n');
};

module.exports = function processSketchGeneric({ template, box, postDomain }) {
  return template
    .replace(
      '//senseBox ID',
      dedent`//senseBox ID
            #define SENSEBOX_ID "${box._id}"`
    )
    .replace(
      '//Sensor IDs',
      dedent`//Sensor IDs
              ${constructSensorsDefinitions(box.sensors)}`
    )
    .replace('@@OSEM_POST_DOMAIN@@', postDomain);
};
