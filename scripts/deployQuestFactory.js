require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const claimSignerAddress = '0x94c3e5e801830dD65CD786F2fe37e79c65DF4148'
  const rabbitholeReceiptAddress = '0x85b76151Bba84D5ab6a043Daa40F29F33b4Eb362' // sepolia
  const protocolFeeReceipient = '0xC4a68e2c152bCA2fE5E8D26FFb8AA44bCE1B56b0' // goerli

  const QuestFactory = await ethers.getContractFactory('QuestFactory')
  const Erc20Quest = await ethers.getContractFactory('Quest')

  const erc20Quest = await Erc20Quest.deploy()
  await erc20Quest.deployed()

  const deployment = await hre.upgrades.deployProxy(
    QuestFactory,
    [claimSignerAddress, rabbitholeReceiptAddress, protocolFeeReceipient, erc20Quest.address],
    { initializer: 'initialize' }
  )

  await deployment.deployed()
  console.log('deployed to:', deployment.address)

  const proxyImplAddress = await upgrades.erc1967.getImplementationAddress(deployment.address)
  console.log('verifying implementation: ', proxyImplAddress)
  await hre.run('verify:verify', { address: proxyImplAddress })
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
