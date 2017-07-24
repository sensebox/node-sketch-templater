'use strict';

/* eslint-disable global-require */
[
  '0-included-templates',
  '1-template-config-parsing',
  '2-transformers'
].forEach(t => require(`./${t}`));
/* eslint-enable global-require */
