'use strict';

module.exports = {
  hex(str) {
    return str
      .split('')
      .map((c, i) => {
        return i % 2 ? `${c}, ` : `0x${c}`;
      })
      .join('')
      .slice(0, -2);
  }
};
