'use strict';

/* global describe it before after */
const expect = require('chai').expect,
  testBox = require('./test-data/testBox'),
  testBoxNewSensors = require('./test-data/testBox_newSensors'),
  helpers = require('../src/helpers'),
  SketchTemplater = require('../src');

const testDomain = 'test.domain.com';

const templateLocation = './templates';

describe('Included templates', function() {
  let globalconsolewarn, mySketchTemplater;
  before(function() {
    globalconsolewarn = global.console.warn;
    global.console.warn = function(err) {
      throw new Error(err);
    };

    mySketchTemplater = new SketchTemplater(testDomain);
  });

  after(function() {
    global.console.warn = globalconsolewarn;
  });

  it('should not show any warnings', function() {
    expect(() => helpers.readTemplates(templateLocation)).to.not.throw();
  });

  it('should load without warnings', function() {
    const templates = helpers.readTemplates(templateLocation);
    expect(templates).to.be.a('object');
    expect(templates).to.not.be.empty;
  });

  it('should execute custom model and make all substitutions', function() {
    const box = Object.assign({ model: 'custom' }, testBox());
    const sketch = mySketchTemplater.generateSketch(box);

    expect(sketch).to.include(testDomain);
    expect(sketch).to.include(box._id);
    expect(sketch).to.include(box.name);
    for (const { title, _id } of box.sensors) {
      expect(sketch).to.include(title);
      expect(sketch).to.include(_id);
    }
  });

  it('should execute lora model and make all substitutions', function() {
    const box = Object.assign({ model: 'homeV2Lora' }, testBoxNewSensors());

    const sketch = mySketchTemplater.generateSketch(box);

    for (const { title, sensorType } of box.sensors) {
      expect(sketch).to.include(title);
      expect(sketch).to.include(`${sensorType.toUpperCase()}_CONNECTED`);
      expect(sketch).to.include(
        '{ 0xAD, 0xF1, 0x1B, 0x14, 0xC2, 0x74, 0x7C, 0x1D, 0xB5, 0xF7, 0x90, 0xD6, 0x92, 0x1E, 0xE7, 0xE5 }'
      );
    }
  });

  it('should execute all other templates to execute and make all substitutions', function() {
    for (const model of Object.keys(mySketchTemplater._templates)) {
      if (model !== 'custom' && model !== 'homeV2Lora') {
        const box = Object.assign({ model: model }, testBox());
        const sketch = mySketchTemplater.generateSketch(box);

        expect(sketch).to.include(testDomain);
        expect(sketch).to.include(box._id);
        expect(sketch).to.include(box.name);
        expect(sketch).to.include(
          `static const uint8_t NUM_SENSORS = ${box.sensors.length};`
        );
        for (const { title, _id } of box.sensors) {
          expect(sketch).to.include(title);
          expect(sketch).to.include(_id);
        }

        if (model.startsWith('homeV2Wifi')) {
          expect(sketch).to.include(box.ssid);
          expect(sketch).to.include(box.password);
        }
      }
    }
  });

  it('should return error string for unknown model', function() {
    expect(mySketchTemplater.generateSketch({ model: 'nosketch' })).to.include(
      'Error: No sketch template availiable for model'
    );
  });

  it('should return a sketch in base64 encoding when requested', function() {
    const box = Object.assign({ model: 'custom' }, testBox());
    // baseline sketch in text format
    const sketch = mySketchTemplater.generateSketch(box);

    const b64Sketch = Buffer.from(sketch).toString('base64');

    expect(
      mySketchTemplater.generateSketch(box, { encoding: 'base64' })
    ).to.equal(b64Sketch);
  });

  it('should return a sketch with correct digital ports for soil moisture sensor, sound meter and wind sensor', function() {
    const box = Object.assign({ model: 'homeV2Wifi' }, testBoxNewSensors());
    // baseline sketch in text format
    const sketch = mySketchTemplater.generateSketch(box);

    expect(sketch).to.include(`SOILTEMPPIN 3`);
    expect(sketch).to.include(`SOILMOISPIN 4`);
    expect(sketch).to.include(`SOUNDMETERPIN 5`);
    expect(sketch).to.include(`WINDSPEEDPIN 1`);
  });

  it('should return a sketch with correct authorization header', function() {
    const box = Object.assign({ model: 'homeV2Wifi' }, testBoxNewSensors());
    // baseline sketch in text format
    const sketch = mySketchTemplater.generateSketch(box);

    expect(sketch).to.include(
      `Authorization: 1821b9d5d25c46e6af9b44e68c49ab6ac254c7986007ed73b7e46f50f06b430b`
    );
  });

  it('should return a sketch with CO2 sensor', function() {
    const box = Object.assign({ model: 'homeV2Wifi' }, testBoxNewSensors());
    // baseline sketch in text format
    const sketch = mySketchTemplater.generateSketch(box);

    expect(sketch).to.include(`#define SCD30_CONNECTED`);
    expect(sketch).to.include(`const char CO2SENSOR_ID[] PROGMEM`);
  });
});
