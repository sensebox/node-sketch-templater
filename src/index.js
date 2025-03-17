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
  // Wenn das Modell "homev2wifiFeinstuab" ist, wird es als "homeV2" behandelt.
  if (box.model === "homev2WifiFeinstaub" || box.model === "homev2EthernetFeinstaub") {
    box.model = "homeV2";
  }

  if (this._templates[box.model]) {
    // transformiere "CO₂" zu "CO2" nur für node sketch templater
    box.sensors = box.sensors.map((s) => {
      if (s.title === "CO₂") {
        s.title = 'CO2';
      }
      return s;
    });

    if (encoding && encoding === "base64") {
      return Buffer.from(this._executeTemplate(box)).toString("base64");
    }
    return this._executeTemplate(box);
  }

  return `Error: No sketch template availiable for model ${box.model}`;
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
