"use strict";

const transformers = require("./transformers"),
  { readTemplates } = require("./helpers");

process.env.SUPPRESS_NO_CONFIG_WARNING = "y";
const config = require("config");

const templateFolderPath = `${__dirname}/../templates`;

const defaultConfig = {
  ingress_domain: "",
};

const SketchTemplater = function SketchTemplater(cfg) {
  // check type of ingressDomainConfig parameter
  if (typeof cfg === "string") {
    cfg = { ingress_domain: cfg };
  }
  // Mixin configs that have been passed in, and make those my defaults
  config.util.extendDeep(defaultConfig, cfg);
  config.util.setModuleDefaults("sketch-templater", defaultConfig);

  const ingress_domain = config.get("sketch-templater.ingress_domain");

  if (ingress_domain === "" || typeof ingress_domain !== "string") {
    console.warn("Invalid or missing ingressDomain");
  }

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
  let boxModel = box.model;
  const normalizedModel = boxModel.toLowerCase();

  // We merged the feinstaub extension templates into one template
  // So we need to normalize the model name to the base model and treat every feinstaub model as normal homev2 model
  switch (normalizedModel) {
    case "homev2wififeinstaub":
      boxModel = "homeV2Wifi";
      box.model = "homeV2Wifi"; 
      break;
    case "homev2ethernetfeinstaub":
      boxModel = "homeV2Ethernet";
      box.model = "homeV2Ethernet"; 
      break;
    default:
      boxModel = "homeV2Wifi";
      break;
  }

  if (this._templates[boxModel]) {
    // Transformiere "CO₂" zu "CO2" nur für node sketch templater.
    box.sensors = box.sensors.map((s) => {
      if (s.title === "CO₂") {
        s.title = "CO2";
      }
      return s;
    });

    if (encoding === "base64") {
      return Buffer.from(this._executeTemplate(box)).toString("base64");
    }
    return this._executeTemplate(box);
  }

  return `Error: No sketch template available for modelsssss ${boxModel}`;
};

SketchTemplater.prototype._cloneBox = function _cloneBox({
  _id,
  name,
  sensors,
  sdsSerialPort,
  rg15SerialPort,
  soilDigitalPort,
  soundMeterPort,
  windSpeedPort,
  ssid,
  password,
  devEUI,
  appEUI,
  appKey,
  access_token,
  display_enabled,
}) {
  return Object.assign(
    {},
    {
      SENSEBOX_ID: _id,
      SENSEBOX_NAME: name,
      SENSOR_IDS: sensors,
      INGRESS_DOMAIN: config.get("sketch-templater.ingress_domain"),
      NUM_SENSORS: sensors.length,
      SDS_SERIAL_PORT: sdsSerialPort,
      RG15_SERIAL_PORT: rg15SerialPort,
      SOIL_DIGITAL_PORT: soilDigitalPort,
      SOUND_METER_PORT: soundMeterPort,
      WIND_DIGITAL_PORT: windSpeedPort,
      SSID: ssid,
      PASSWORD: password,
      SENSORS: sensors,
      DEV_EUI: devEUI,
      APP_EUI: appEUI,
      APP_KEY: appKey,
      ACCESS_TOKEN: access_token,
      DISPLAY_ENABLED: display_enabled,
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
  return this._templates[sourceBox.model].replace(
    /@@(.+)@@/g,
    function (_, subTemplateKey) {
      // check if there is a transformer defined
      // eslint-disable-next-line prefer-const
      let [key, transformer = "as-is"] = subTemplateKey.split("|");
      let params = [];

      if (transformer.indexOf("~") >= -1) {
        [transformer, params] = transformer.split("~");
      }

      if (params) {
        const parameters = params.split(",");

        return transformers[transformer](box[key], ...parameters);
      } else if (transformers[transformer]) {
        return transformers[transformer](box[key]);
      }
    }
  );
};

module.exports = SketchTemplater;
