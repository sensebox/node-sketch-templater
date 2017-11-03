'use strict';

const fs = require('fs');

const getProperty = function getProperty(obj, ...properties) {
  let seenPropertyKey, value;
  for (const key of properties) {
    if (obj[key]) {
      if (typeof seenPropertyKey !== 'undefined') {
        throw new Error(
          `Definition of keys "${seenPropertyKey}" and "${key}" at the same time not allowed`
        );
      }
      seenPropertyKey = key;
      value = obj[key];
    }
  }

  if (!value) {
    throw new Error(
      `Key "${properties.slice(0, -1).join('", "')}" or "${properties.slice(
        -1
      )}" not found`
    );
  }

  if (!Array.isArray(value)) {
    value = [value];
  }

  return value;
};

const parseTemplateConfig = function parseTemplateConfig(configJsonStr) {
  // first line has processor information. Extract it and store along with lines
  try {
    const configObj = JSON.parse(configJsonStr);

    const models = getProperty(configObj, 'model', 'models');

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
