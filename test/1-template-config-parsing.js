'use strict';

/* global describe it before after */
const expect = require('chai').expect,
  helpers = require('../src/helpers');

const templateLocation = './test/test-templates';

describe('Template config parsing', function() {
  let globalconsolewarn;
  before(function() {
    globalconsolewarn = global.console.warn;
    global.console.warn = function(err) {
      throw new Error(err);
    };
  });

  after(function() {
    global.console.warn = globalconsolewarn;
  });

  it('should show a warning when the syntax is wrong', function() {
    expect(() =>
      helpers.readTemplates(`${templateLocation}/wrong-syntax`)
    ).to.throw(/Missing or invalid/);
  });

  it('should show a warning when there is no model declaration', function() {
    expect(() =>
      helpers.readTemplates(`${templateLocation}/missing-model-models-key`)
    ).to.throw(/Key "model" or "models" not found/);
  });

  it('should show a warning for duplicate model declaration', function() {
    expect(() =>
      helpers.readTemplates(`${templateLocation}/duplicate-model`)
    ).to.throw(/Duplicate declaration of model/);
  });

  it('should show a warning when keys "model" and "models" defined at the same time', function() {
    expect(() =>
      helpers.readTemplates(`${templateLocation}/model-models-same-time`)
    ).to.throw(
      /Definition of keys "model" and "models" at the same time not allowed/
    );
  });

  it('should show a warning for invalid model definition', function() {
    expect(() =>
      helpers.readTemplates(`${templateLocation}/model-invalid`)
    ).to.throw(/is invalid/);
  });
});
