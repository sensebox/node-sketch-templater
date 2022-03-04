FROM node:16

# install arduicno-cli
RUN curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=/usr/local/bin sh

RUN arduino-cli config init

# aloow unsafe sources (zip, git)
RUN arduino-cli config set library.enable_unsafe_install true

# update arduino-cli
RUN arduino-cli core update-index

# install arduino avr and libraries for senseBox V1
RUN arduino-cli core install arduino:avr
RUN arduino-cli lib install Ethernet
RUN arduino-cli lib install Ethernet2
RUN arduino-cli lib install Wifi101

RUN wget https://raw.githubusercontent.com/sensebox/home/master/libraries/BMP280.zip
RUN wget https://raw.githubusercontent.com/sensebox/home/master/libraries/HDC100X.zip
RUN wget https://raw.githubusercontent.com/sensebox/home/master/libraries/Makerblog_TSL45315.zip
RUN wget https://raw.githubusercontent.com/sensebox/home/master/libraries/VEML6070.zip
RUN wget https://raw.githubusercontent.com/sensebox/home/master/libraries/LTR329.zip

RUN arduino-cli lib install --zip-path BMP280.zip
RUN arduino-cli lib install --zip-path HDC100X.zip
RUN arduino-cli lib install --zip-path Makerblog_TSL45315.zip
RUN arduino-cli lib install --zip-path VEML6070.zip
RUN arduino-cli lib install --zip-path LTR329.zip
RUN arduino-cli lib install --git-url https://github.com/sensebox/SDS011-select-serial 

# install arduino stuff for senseBox V2
RUN arduino-cli core install arduino:samd
RUN curl -o /root/.arduino15/package_sensebox_index.json https://raw.githubusercontent.com/sensebox/senseBoxMCU-core/master/package_sensebox_index.json
RUN arduino-cli --additional-urls https://raw.githubusercontent.com/sensebox/senseBoxMCU-core/master/package_sensebox_index.json core install sensebox:samd

RUN arduino-cli lib install --git-url https://github.com/adafruit/Adafruit_DPS310

# SPI Hotfix
RUN rm -r /root/.arduino15/packages/sensebox/hardware/samd/1.5.0-beta/libraries/Adafruit_BMP280
RUN arduino-cli lib install "Adafruit BMP280 Library"

WORKDIR /app

COPY package.json /app
COPY yarn.lock /app

RUN yarn install --pure-lockfile --production

COPY . /app/

CMD ["node","arduino-test/build-sketches.js"]
