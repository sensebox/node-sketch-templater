module.exports = {
  'env': {
    'es6': true,
    'node': true
  },
  'plugins': [
    'prettier'
  ],
  'extends': [ 'eslint:recommended', 'prettier' ],
  'rules': {
    'prettier/prettier': [
      'error',
      {
        'trailingComma': "none", "singleQuote": true}
    ],
    'linebreak-style': [
      'error',
      'unix'
    ],
    'eqeqeq': [
      'error',
      'always'
    ],
    'guard-for-in': [
      'error'
    ],
    'strict': [
      'error',
      'global'
    ],
    'no-console': 'off',
    'no-template-curly-in-string': [
      'error'
    ],
    'block-scoped-var': [
      'error'
    ],
    'complexity': [
      'warn',
      10
    ],
    'no-else-return': 'error',
    'no-floating-decimal': 'error',
    'no-implicit-coercion': 'error',
    'no-implicit-globals': 'error',
    'no-implied-eval': 'error',
    'no-lone-blocks': 'error',
    'no-loop-func': 'error',
    'no-multi-str': 'error',
    'no-new-wrappers': 'error',
    'no-new': 'error',
    'no-return-assign': 'error',
    'no-throw-literal': 'error',
    'no-unmodified-loop-condition': 'error',
    'no-useless-return': 'error',
    'radix': [
      'error',
      'always'
    ],
    'yoda': 'error',
    'callback-return': 'error',
    'global-require': 'error',
    'func-name-matching': [
      'error',
      'always'
    ],
    'func-style': [
      'error',
      'expression'
    ],
    'lines-around-directive': [
      'error'
    ],
    'newline-before-return': 'error',
    'no-lonely-if': 'error',
    'operator-assignment': [
      'error',
      'never'
    ],
    'no-useless-computed-key': 'error',
    'no-var': 'error',
    'prefer-const': 'error',
    'prefer-template': 'error',
    'no-warning-comments': 'error',
    'require-jsdoc': 'warn',
    'valid-jsdoc': 'warn',
    'prefer-promise-reject-errors': 'error'
  }
};
