'use strict';

const transformers = require('./transformers'),
  { readTemplates } = require('./helpers');

const templateFolderPath = `${__dirname}/../templates`;

const SketchTemplater = function SketchTemplater(ingressDomain) {
  this._ingressDomain = ingressDomain;
  // pre load templates from templates folder
  const templates = readTemplates(templateFolderPath);
  if (Object.keys(templates).length === 0) {
    console.warn(
      `Sketch Templater Error: No valid templates found in path ${templateFolderPath}`
    );
  }

  this._templates = templates;
};

SketchTemplater.prototype.generateSketch = function generateSketch(
  box,
  { encoding } = {}
) {
  if (this._templates[box.model]) {
    if (encoding && encoding === 'base64') {
      return Buffer.from(this._executeTemplate(box)).toString('base64');
    }

    return this._executeTemplate(box);
  }

  return `Error: No sketch template availiable for model ${box.model}`;
};

SketchTemplater.prototype._cloneBox = function _cloneBox({ _id, sensors }) {
  return Object.assign(
    {},
    {
      SENSEBOX_ID: _id,
      SENSOR_IDS: sensors,
      INGRESS_DOMAIN: this._ingressDomain,
      NUM_SENSORS: sensors.length
    }
  );
};

SketchTemplater.prototype._executeTemplate = function _executeTemplate(
  sourceBox
) {
  // clone box. We're going to change its properties.
  // Also appends ingressDomain property
  const box = this._cloneBox(sourceBox);

  // return the template matching the box model with every occurrence of
  // @@subTemplateKey@@ replaced with the properties of the box
  return this._templates[sourceBox.model].replace(/@@(.+)@@/g, function(
    _,
    subTemplateKey
  ) {
    // check if there is a transformer defined
    const [key, transformer = 'as-is'] = subTemplateKey.split('|');

    if (transformers[transformer]) {
      box[key] = transformers[transformer](box[key]);
    }

    return box[key];
  });
};

module.exports = SketchTemplater;
