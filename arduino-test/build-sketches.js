'use strict';

const fs = require('fs');
const child_process = require('child_process');

const SketchTemplater = require('../src');

const sketchTemplater = new SketchTemplater('test.ingress.domain');

const boxStub = function(model) {
  return {
    _id: '59479ed5a4ad5900112d8dec',
    model: model,
    sensors: [
      {
        title: 'Temperatur',
        _id: '59479ed5a4ad5900112d8ded'
      },
      {
        title: 'rel. Luftfeuchte',
        _id: '59479ed5a4ad5900112d8dee'
      },
      {
        title: 'Luftdruck',
        _id: '59479ed5a4ad5900112d8def'
      },
      {
        title: 'Beleuchtungsstärke',
        _id: '59479ed5a4ad5900112d8df0'
      },
      {
        title: 'UV-Intensität',
        _id: '59479ed5a4ad5900112d8df1'
      },
      {
        title: 'PM10',
        _id: '59479ed5a4ad5900112d8df2'
      },
      {
        title: 'PM2.5',
        _id: '59479ed5a4ad5900112d8df3'
      }
    ],
    serialPort: 'Serial1'
  };
};

const buildMatrix = {
  'arduino:avr:uno': [],
  'sensebox:samd:sb': []
};

for (const model of Object.keys(sketchTemplater._templates)) {
  if (model.includes('V2')) {
    buildMatrix['sensebox:samd:sb'].push(model);
  } else {
    buildMatrix['arduino:avr:uno'].push(model);
  }
}

const mkdirp = function mkdirp(path) {
  /* eslint-disable no-empty */
  try {
    fs.mkdirSync(path);
  } catch (e) {}
  /* eslint-enable no-empty */
};

const build = function build(board, model) {
  mkdirp(`${sketchesPath}/${model}`);
  fs.writeFileSync(
    `${sketchesPath}/${model}/${model}.ino`,
    sketchTemplater.generateSketch(boxStub(model))
  );
  console.log(
    `Building model ${model} with "arduino --verbose-build --verify --board ${board} ${sketchesPath}/${model}/${model}.ino"`
  );
  child_process.execSync(
    `arduino --verbose-build --verify --board ${board} ${sketchesPath}/${model}/${model}.ino`,
    { stdio: [0, 1, 2] }
  );
  console.log('###########################################################');
};

const sketchesPath = `${__dirname}/sketches`;
mkdirp(sketchesPath);

for (const board of Object.keys(buildMatrix)) {
  for (const model of buildMatrix[board]) {
    build(board, model);
  }
}
console.log('done');
