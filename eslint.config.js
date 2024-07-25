// DO NOT EDIT -- auto-updated from .gitconfig

const antfu = require('@antfu/eslint-config').default;

module.exports = antfu({
  stylistic: {
    indent: 2,
    jsx: true,
    quotes: 'single',
    semi: true,
  },
  formatters: {
    prettierOptions: {
      semi: true,
      singleQuote: true,
      printWidth: 100,
      tabWidth: 2,
      useTabs: false,
    },
  },
  typescript: {
    tsconfigPath: './tsconfig.json',
  },
  react: true,
  rules: {
    'curly': ['error', 'all'],
    'antfu/top-level-function': 'off',
    'antfu/consistent-list-newline': 'off',
    'style/brace-style': ['error', '1tbs', { allowSingleLine: true }],
    'style/arrow-parens': ['error', 'always'],
    'ts/consistent-type-definitions': 'off',
    'ts/no-var-requires': 'off',
    'ts/no-require-imports': 'off',
    'node/prefer-global/process': 'off',
    'react-hooks/exhaustive-deps': 'off',
    'no-console': ['warn', { allow: ['warn', 'error', 'info'] }],
    'max-len': ['error', { code: 100, ignoreUrls: true, ignoreStrings: true, ignoreTemplateLiterals: true, comments: 120, ignorePattern: '^(\\s*\\{t\\(.+\\)\\})|(\\s*[?:]\\s*`.+`(\\)\\})?)$' }],
    'style/multiline-ternary': 'off',
    'ts/no-use-before-define': 'off', // Disabled for React-Native styles
    'padding-line-between-statements': ['error', { blankLine: 'any', prev: ['const', 'let', 'var'], next: ['*'] }],
    'react/prefer-destructuring-assignment': 'off',
    'ts/strict-boolean-expressions': 'off',
  },
});

// DO NOT EDIT -- auto-updated from .gitconfig
