/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require('dotenv').config()
require('hardhat-deploy')
import { HardhatUserConfig } from 'hardhat/types'
import '@nomicfoundation/hardhat-chai-matchers'
import '@nomiclabs/hardhat-ethers'
import '@nomicfoundation/hardhat-toolbox'
import '@openzeppelin/hardhat-upgrades'
import '@openzeppelin/hardhat-defender'

const config: HardhatUserConfig = {
  namedAccounts: {
    deployer: 0,
    owner: {
      default: 1,
      1: '0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c',
      5: '0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c',
      10: '0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c',
      137: '0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c',
    },
    claimSignerAddress: {
      // public address on API
      1: '0x458d84d42878930C929C660F24F1505368107276',
      5: '0x22890b38D6ab6090e5123DB7497f4bCE7062929F',
      10: '0x458d84d42878930C929C660F24F1505368107276',
      137: '0x458d84d42878930C929C660F24F1505368107276',
    },
    protocolFeeReceipient: {
      // multisig
      1: '0x482c973675b3E3f84A23Dc03430aCfF293952e74',
      5: '0xC4a68e2c152bCA2fE5E8D26FFb8AA44bCE1B56b0',
      10: '0xbD72a3Cd66B3e40E5151B153164905FD65b55145',
      137: '0x482c973675b3E3f84A23Dc03430aCfF293952e74',
    },
    royaltyRecipient: {
      // multisig
      1: '0x482c973675b3E3f84A23Dc03430aCfF293952e74',
      5: '0xC4a68e2c152bCA2fE5E8D26FFb8AA44bCE1B56b0',
      10: '0xbD72a3Cd66B3e40E5151B153164905FD65b55145',
      137: '0x482c973675b3E3f84A23Dc03430aCfF293952e74',
    },
  },
  gasReporter: {
    gasPrice: 100,
  },
  defender: {
    apiKey: process.env.DEFENDER_TEAM_API_KEY,
    apiSecret: process.env.DEFENDER_TEAM_API_SECRET_KEY,
  },
  solidity: {
    compilers: [
      {
        version: '0.8.16',
        settings: {
          optimizer: {
            enabled: true,
            runs: 5000,
          },
        },
      },
    ],
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.MAIN_ETHERSCAN_API_KEY,
      goerli: process.env.MAIN_ETHERSCAN_API_KEY,
      optimisticEthereum: process.env.OPT_ETHERSCAN_API_KEY,
      optimisticGoerli: process.env.OPT_ETHERSCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY,
    },
  },
  networks: {
    hardhat: {
      chainId: 1337,
      forking: {
        url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_MAINNET_API_KEY}`,
        blockNumber: 14787640,
      },
      settings: {
        debug: {
          revertStrings: 'debug',
        },
      },
    },
    mainnet: {
      url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_MAINNET_API_KEY}`,
      accounts: process.env.MAINNET_PRIVATE_KEY ? [`0x${process.env.MAINNET_PRIVATE_KEY}`] : [],
      verify: {
        etherscan: {
          apiKey: process.env.MAIN_ETHERSCAN_API_KEY,
        },
      },
    },
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_SEPOLIA_API_KEY}`,
      accounts: process.env.MAINNET_PRIVATE_KEY ? [`0x${process.env.MAINNET_PRIVATE_KEY}`] : [],
      verify: {
        etherscan: {
          apiKey: process.env.MAIN_ETHERSCAN_API_KEY,
        },
      },
    },
    goerli: {
      url: `https://eth-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_GOERLI_API_KEY}`,
      accounts: process.env.MAINNET_PRIVATE_KEY ? [`0x${process.env.MAINNET_PRIVATE_KEY}`] : [],
      verify: {
        etherscan: {
          apiKey: process.env.MAIN_ETHERSCAN_API_KEY,
        },
      },
    },
    polygon: {
      gasPrice: 500_000_000_000,
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_POLYGON_API_KEY}`,
      accounts: process.env.MAINNET_PRIVATE_KEY ? [`0x${process.env.MAINNET_PRIVATE_KEY}`] : [],
      verify: {
        etherscan: {
          apiKey: process.env.POLYGONSCAN_API_KEY,
        },
      },
    },
    optimism: {
      url: `https://opt-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_MAINNET_API_KEY}`,
      accounts: process.env.MAINNET_PRIVATE_KEY ? [`0x${process.env.MAINNET_PRIVATE_KEY}`] : [],
      verify: {
        etherscan: {
          apiKey: process.env.OPT_ETHERSCAN_API_KEY,
        },
      },
    },
    optimismGoerli: {
      url: `https://opt-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_MAINNET_API_KEY}`,
      accounts: process.env.MAINNET_PRIVATE_KEY ? [`0x${process.env.MAINNET_PRIVATE_KEY}`] : [],
      verify: {
        etherscan: {
          apiKey: process.env.OPT_ETHERSCAN_API_KEY,
        },
      },
    },
  },
}

export default config
