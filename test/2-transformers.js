'use strict';

/* global describe it */
const expect = require('chai').expect,
  testBox = require('./test-data/testBox'),
  transformers = require('../src/transformers');

describe('Transformers', function() {
  it('as-is should just return whats given', function() {
    const teststring = 'I am a teststring';
    expect(transformers['as-is'](teststring)).to.equal(teststring);
  });

  it('toDefine should transform a sensor array to multiple lines with #defines', function() {
    const { sensors } = testBox();

    const result = transformers.toDefine(sensors);

    expect(result).to.include('#define');
    expect(result).to.include('SENSOR');

    for (const { title, _id } of sensors) {
      expect(result).to.include(title);
      expect(result).to.include(_id);
    }
  });

  it('toDefineWithPrefixAndSuffix should transform a sensor array to multiple lines with #defines', function() {
    const { sensors } = testBox();
    const prefix = '';
    const suffix = '_CONNECTED';

    const result = transformers.toDefineWithSuffixPrefixAndKey(
      sensors,
      prefix,
      suffix,
      'sensorType'
    );

    expect(result).to.include('#define');

    for (const { title, sensorType } of sensors) {
      expect(result).to.include(title);
      expect(result).to.include(`${sensorType.toUpperCase()}${suffix}`);
      expect(result).to.include(
        `${prefix}${sensorType.toUpperCase()}${suffix}`
      );
    }
  });

  it('toProgmem should transform a sensor array to multiple lines with PROGMEM chars', function() {
    const { sensors } = testBox();

    const result = transformers.toProgmem(sensors);

    expect(result).to.include('PROGMEM');
    expect(result).to.include('SENSOR');

    for (const { title, _id } of sensors) {
      expect(result).to.include(title);
      expect(result).to.include(_id);
    }
  });
});
