import { removeConsoleLog } from 'hardhat-preprocessor'
import config from './hardhat.config'

export default {
  ...config,
  preprocess: {
    eachLine: removeConsoleLog(() => true),
  },
  paths: {
    ...config.paths,
    tests: './test-gas-stories',
  },
}
