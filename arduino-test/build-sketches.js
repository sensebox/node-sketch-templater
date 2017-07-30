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
    ]
  };
};

const sketchesPath = `${__dirname}/sketches`;
fs.mkdirSync(sketchesPath);

for (const model of Object.keys(sketchTemplater._templates)) {
  fs.mkdirSync(`${sketchesPath}/${model}`);
  fs.writeFileSync(
    `${sketchesPath}/${model}/${model}.ino`,
    sketchTemplater.generateSketch(boxStub(model))
  );
  console.log(
    `Building model ${model} with "arduino --verbose-build --verify --board ${process
      .env.BOARD} ${sketchesPath}/${model}/${model}.ino"`
  );
  child_process.execSync(
    `arduino --verbose-build --verify --board ${process.env
      .BOARD} ${sketchesPath}/${model}/${model}.ino`,
    { stdio: [0, 1, 2] }
  );
  console.log('###########################################################');
}
console.log('done');
