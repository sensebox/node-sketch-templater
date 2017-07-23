'use strict';

const fs = require('fs'),
  processors = require('./processors');

const SketchTemplater = function SketchTemplater(postDomain) {
  // pre load templates from templates folder
  const templates = {};

  // import and prepare templates
  for (const filename of fs.readdirSync(`${__dirname}/../templates`)) {
    if (filename.endsWith('.tpl')) {
      // read filename to array of lines
      const [configJsonStr, ...templateLines] = fs
        .readFileSync(`${__dirname}/../templates/${filename}`, 'utf-8')
        .split('\n');

      // first line has processor information. Extract it and store along with lines
      let processor, boxModel;
      try {
        const { processorName, model } = JSON.parse(configJsonStr);

        processor = processors[processorName];
        boxModel = model;

        if (!model && model !== '') {
          throw new Error(
            `Missing or invalid model declaration in config of file ${filename}`
          );
        }

        if (!processor) {
          throw new Error(
            `Missing or invalid processorName declaration in config of file ${filename}`
          );
        }
      } catch (err) {
        if (err instanceof SyntaxError) {
          throw new Error(
            `Missing or invalid config declaration in file ${filename}`
          );
        }

        throw err;
      }

      templates[boxModel] = function(box) {
        return processor({
          template: templateLines.join('\r\n'),
          box,
          postDomain
        });
      };
    }
  }

  this._templates = templates;
};

SketchTemplater.prototype.generateSketch = function generateSketch(box) {
  if (this._templates[box.model]) {
    return this._templates[box.model](box);
  }

  return `no sketch template availiable for model ${box.model}`;
};

module.exports = SketchTemplater;
