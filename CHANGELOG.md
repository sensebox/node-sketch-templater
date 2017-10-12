# node-sketch-templater Changelog

## Unreleased

## v1.0.8

## v1.0.7
- Fix Arduino compilation warnings in homeWifi, homeEthernet, homeWifiFeinstaub and homeEthernetFeinstaub templates

## v1.0.6
- Do not push eslint, travis gitignore files to npm

## v1.0.3
- Bump sketch versions
- Unify sketch headers
- Implement sprintf_P PROGMEM based building of HTTP strings and payload
- Should send less TCP packets
- Use same structure in all templates except `custom`

## v1.0.2
Add `encoding` field to `generateSketch` which allows to specify base64 encoding

## v1.0.1
Fix npm package name in README.md

## v1.0.0
Initial release to npm after extracting from sensebox/openSenseMap-API
