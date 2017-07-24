'use strict';

/* global describe it */
const expect = require('chai').expect,
  { hex } = require('./helpers'),
  testBox = require('./test-data/testBox'),
  transformers = require('../src/transformers');

describe('Transformers', function() {
  it('as-is should just return whats given', function() {
    const teststring = 'I am a teststring';
    expect(transformers['as-is'](teststring)).to.equal(teststring);
  });

  it('toHex should hexify a string', function() {
    const teststring = 'DEADBEEF';
    const testresult = hex(teststring);
    expect(transformers['toHex'](teststring)).to.equal(testresult);
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

  it('toHexArray should transform a sensor array to its hex representations', function() {
    const { sensors } = testBox();

    const result = transformers.toHexArray(sensors);

    for (const { title, _id } of sensors) {
      expect(result).to.include(title);
      expect(result).to.include(hex(_id));
    }
  });
});
