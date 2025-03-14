"use strict";

const fs = require("fs");
const child_process = require("child_process");

const SketchTemplater = require("../src");

const sketchTemplater = new SketchTemplater("test.ingress.domain");

const boxStub = function (model) {
  return {
    _id: "59479ed5a4ad5900112d8dec",
    name: "Teststation",
    model: model,
    sensors: [
      {
        title: "Temperatur",
        _id: "59479ed5a4ad5900112d8ded",
        sensorType: "HDC1080",
      },
      {
        title: "rel. Luftfeuchte",
        _id: "59479ed5a4ad5900112d8dee",
        sensorType: "HDC1080",
      },
      {
        title: "Luftdruck",
        _id: "59479ed5a4ad5900112d8def",
        sensorType: "BMP280",
      },
      {
        title: "Beleuchtungsstärke",
        _id: "59479ed5a4ad5900112d8df0",
        sensorType: "TSL45315",
      },
      {
        title: "UV-Intensität",
        _id: "59479ed5a4ad5900112d8df1",
        sensorType: "VEML6070",
      },
      { title: "PM10", _id: "59479ed5a4ad5900112d8df2", sensorType: "SDS 011" },
      {
        title: "PM2.5",
        _id: "59479ed5a4ad5900112d8df3",
        sensorType: "SDS 011",
      },
      {
        title: "Bodenfeuchte",
        _id: "59479ed5a4ad5900112d8df4",
        sensorType: "SMT50",
      },
      {
        title: "Bodentemperatur",
        _id: "59479ed5a4ad5900112d8df5",
        sensorType: "SMT50",
      },
      {
        title: "Lufttemperatur",
        _id: "59479ed5a4ad5900112d8df6",
        sensorType: "BME680",
      },
      {
        title: "Luftfeuchtigkeit",
        _id: "59479ed5a4ad5900112d8df7",
        sensorType: "BME680",
      },
      {
        title: "atm. Luftdruck",
        _id: "59479ed5a4ad5900112d8df8",
        sensorType: "BME680",
      },
      { title: "VOC", _id: "59479ed5a4ad5900112d8df9", sensorType: "BME680" },
      {
        title: "Lautstärke",
        _id: "59479ed5a4ad5900112d8dfa",
        sensorType: "SoundLevelMeter",
      },
      {
        title: "Gesamtniederschlag",
        _id: "59479ed5a4ad5900112d8dfb",
        sensorType: "RG15",
      },
      {
        title: "Niederschlagsintensität",
        _id: "59479ed5a4ad5900112d8dfb",
        sensorType: "RG15",
      },
      {
        title: "Solarspannung",
        _id: "59479ed5a4ad5900112d8dfc",
        sensorType: "SB041",
      },
      {
        title: "Batteriespannung",
        _id: "59479ed5a4ad5900112d8dfc",
        sensorType: "SB041",
      },
      {
        title: "Ladelevel", //TODO eigentlich "Batterielevel", aber geht nicht, da erste 6 Buchstaben identisch zu "Batteriespannung"
        _id: "59479ed5a4ad5900112d8dfc",
        sensorType: "SB041",
      },
    ],
    sdsSerialPort: "Serial1",
    rg15SerialPort: "Serial2",
    ssid: "MY-HOME-NETWORK",
    password: "MY-SUPER-PASSWORD",
    display_enabled: "true",
  };
};

const buildMatrix = {
  "arduino:avr:uno": [],
  "sensebox:samd:sb": [],
};

for (const model of Object.keys(sketchTemplater._templates)) {
  if (model.includes("V2")) {
    buildMatrix["sensebox:samd:sb"].push(model);
  } else {
    buildMatrix["arduino:avr:uno"].push(model);
  }
}

const mkdirp = function mkdirp(path) {
  /* eslint-disable no-empty */
  try {
    fs.mkdirSync(path);
  } catch (e) {}
  /* eslint-enable no-empty */
};

const build = function build(board, model) {
  mkdirp(`${sketchesPath}/${model}`);
  fs.writeFileSync(
    `${sketchesPath}/${model}/${model}.ino`,
    sketchTemplater.generateSketch(boxStub(model))
  );
  console.log(
    `Building model ${model} with "arduino-cli compile --fqbn ${board} ${sketchesPath}/${model}/${model}.ino"`
  );
  try {
    child_process.execSync(
      `arduino-cli compile --fqbn ${board} -e ${sketchesPath}/${model}/${model}.ino`,
      // `arduino --verbose-build --verify --board ${board} ${sketchesPath}/${model}/${model}.ino`,
      { stdio: "inherit" }
    );
    console.log("Compilation success!");
    console.log("###########################################################");
  } catch (error) {
    console.log("Compilation failed!");
    if (error.stdout) {
      console.error("Standard Output (stdout):", error.stdout.toString());
    }
    if (error.stderr) {
      console.error("Standard Error (stderr):", error.stderr.toString());
    }
    console.log("###########################################################");
  }
};

const sketchesPath = `${__dirname}/sketches`;
mkdirp(sketchesPath);

for (const board of Object.keys(buildMatrix)) {
  for (const model of buildMatrix[board]) {
    build(board, model);
  }
}
console.log("done");
