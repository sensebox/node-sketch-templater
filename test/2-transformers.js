'use strict';

/* global describe it */
const expect = require('chai').expect,
  testBox = require('./test-data/testBox_newSensors'),
  transformers = require('../src/transformers');

describe('Transformers', function () {
  it('as-is should just return whats given', function () {
    const teststring = 'I am a teststring';
    expect(transformers['as-is'](teststring)).to.equal(teststring);
  });

  it('toDefine should transform a sensor array to multiple lines with #defines', function () {
    const { sensors } = testBox();

    const result = transformers.toDefine(sensors);

    expect(result).to.include('#define');
    expect(result).to.include('SENSOR');

    for (const { title, _id } of sensors) {
      expect(result).to.include(title);
      expect(result).to.include(_id);
    }
  });

  it('toDefineWithPrefixAndSuffix should transform a sensor array to multiple lines with #defines', function () {
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

  it('toProgmem should transform a sensor array to multiple lines with PROGMEM chars', function () {
    const { sensors } = testBox();

    const result = transformers.toProgmem(sensors);

    expect(result).to.include('PROGMEM');
    expect(result).to.include('SENSOR');

    for (const { title, _id } of sensors) {
      expect(result).to.include(title);
      expect(result).to.include(_id);
    }
  });

  it('transformTTNID should transform a strign to a C compatible hex array', function () {
    const { devEUI, appEUI, appKey } = testBox();

    const devEUITransformed = transformers.transformTTNID(devEUI, true);
    const appEUITransformed = transformers.transformTTNID(appEUI, true);
    const appKeyTransformed = transformers.transformTTNID(appKey);

    expect(devEUITransformed).to.include(
      '{ 0xDF, 0x99, 0xB9, 0x67, 0xD0, 0x31, 0xDD, 0x00 }'
    );
    expect(appEUITransformed).to.include(
      '{ 0xC8, 0xE0, 0x02, 0xD0, 0x7E, 0xD5, 0xB3, 0x70 }'
    );
    expect(appKeyTransformed).to.include(
      '{ 0xAD, 0xF1, 0x1B, 0x14, 0xC2, 0x74, 0x7C, 0x1D, 0xB5, 0xF7, 0x90, 0xD6, 0x92, 0x1E, 0xE7, 0xE5 }'
    );
    expect(transformers.transformTTNID('iammalformed')).to.include('{ }');
  });

  it('toDefineEnableDebug("true") should add a #define ENABLE_DEBUG', function () {
    const result = transformers.toDefineEnableDebug('true');
    expect(result).to.equal('#define ENABLE_DEBUG');
  } );

  if('toDefineEnableDebug("false") should not add a #define ENABLE_DEBUG instead comment the line out', function () {
    const result = transformers.toDefineEnableDebug('false');
    expect(result).to.equal('//#define ENABLE_DEBUG');
  } );

});


