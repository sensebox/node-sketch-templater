# senseBox sketch-templater
Arduino sketch templates used by the openSenseMap-api

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md)

## Usage

Install via `npm install --save @sensebox/sketch-templater` or `yarn add @sensebox/sketch-templater`

```javascript

const Sketcher = require('@sensebox/sketch-templater');

const mySketcher = new Sketcher('<your api post domain>');

// generate Sketch
const mySketch = mySketcher.generateSketch(box);
const mySketchBase64 = mySketcher.generateSketch(box, { encoding: 'base64' });
```

## Adding new Templates

To add new templates, just create a new `.tpl` file in the [`templates`](templates) directory. A template consists of two parts. The first line contains a JSON object for configuration. The second line until the end is used as the template text.

### Example configuration in first line

Specify a single model:
```json
{ "model": "homeEthernet" }
```

Specify multiple models:
```json
{ "models": ["homeWifi", "homeWifiFeinstaub"] }
```

### Templating values

The templater uses special transformers to process the templates. The transformers are applied through searching for `@@SUB_TEMPLATE_KEY@@` occurrences in the template files. Each replacement starts and ends with a double `@`. To specify a transformer, append a pipe (`|`) and the transformer name. When no transformer is specified, it just returns the input variable. For adding new template transformers, see [Adding Transformers](#adding-transformers).

As of writing this, the following replacements can be made:

| Template text | Replacement |
|------------------|-------------|
| `@@SENSEBOX_ID@@` | the senseBox ID  |
| `@@SENSOR_IDS@@` | sensor IDs |
| `@@NUM_SENSORS@@` | the number of sensors |
| `@@INGRESS_DOMAIN@@` | the domain of your ingress server |

Additionally, the following transformers are implemented:

| Transformer name | Description |
|------------------|-------------|
| `as-is` | Do nothing. |
| `toHex` | Transforms a single string to hex tuples. Example: `"DEADBEEF" => "0xDE, 0xAD, 0xBE, 0xEF"` |
| `toDefine` | Transform an array of sensors to multiple `#define` statements. |
| `toHexArray` | Transform an array of sensors to a list of hex encoded arrays. Uses `toHex` internally. |

## Adding Transformers

In order to add a new transformer, just add a function in [`src/transformers.js`](src/transformers.js) to the `module.exports`. The function should return a string.


## Adding Replacements

Add your additional replacements in [`src/index.js`](src/index.js) in the method `_cloneBox` to the second parameter of the `Object.assign` call.

## License

[MIT 2017 Matthias Pfeil, Jan Wirwahn, Gerald Pape](LICENSE)