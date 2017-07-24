'use strict';

const fs = require('fs');

const parseTemplateConfig = function parseTemplateConfig(configJsonStr) {
  // first line has processor information. Extract it and store along with lines
  try {
    /* eslint-disable prefer-const */
    let { model, models } = JSON.parse(configJsonStr);
    /* eslint-enable prefer-const */

    if (model && models) {
      throw new Error(
        'Definition of keys "model" and "models" at the same time not allowed'
      );
    }

    if (!model && !models) {
      throw new Error('Key "model" or "models" not found');
    }

    if (!Array.isArray(models)) {
      models = [model];
    }

    for (const model of models) {
      if (!model || typeof model !== 'string' || model === '') {
        throw new Error(
          `Model declaration "${model}" (Type ${typeof model}) is invalid`
        );
      }
    }

    return { models };
  } catch (err) {
    if (err instanceof SyntaxError) {
      throw new Error(`Missing or invalid config declaration. ${err}`);
    }

    throw err;
  }
};

module.exports = {
  readTemplates(templateFolderPath) {
    const templates = {};
    // import and prepare templates
    for (const filename of fs.readdirSync(templateFolderPath)) {
      if (filename.endsWith('.tpl')) {
        const filePath = `${templateFolderPath}/${filename}`;
        // read file to array of lines, split off first line
        const [configJsonStr, ...templateLines] = fs
          .readFileSync(filePath, 'utf-8')
          .split('\n');

        try {
          const { models } = parseTemplateConfig(configJsonStr);

          for (const model of models) {
            if (Object.keys(templates).includes(model)) {
              console.warn(
                `Sketch Templater Error: Duplicate declaration of model "${model}" in file ${filePath}.`
              );
            }

            templates[model] = templateLines.join('\r\n');
          }
        } catch (err) {
          console.warn(
            `Sketch Templater Error: ${err.message} in file ${filePath}.`
          );
        }
      }
    }

    return templates;
  }
};
