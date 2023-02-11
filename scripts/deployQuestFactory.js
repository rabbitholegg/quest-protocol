require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const claimSignerAddress = '0x22890b38D6ab6090e5123DB7497f4bCE7062929F'
  const rabbitholeReceiptAddress = '0x61A8CC96a3576C2a50716a0cDE70BF373C018aa6' // goerli
  const rabbitholeTicketsAddress = '0x5C3eBe0C4a1F1505a4A106859CaBdca0913fa42F' // goerli
  const protocolFeeReceipient = '0xC4a68e2c152bCA2fE5E8D26FFb8AA44bCE1B56b0' // goerli

  const QuestFactory = await ethers.getContractFactory('QuestFactory')
  const Erc20Quest = await ethers.getContractFactory('Erc20Quest')
  const Erc1155Quest = await ethers.getContractFactory('Erc1155Quest')

  const erc20Quest = await Erc20Quest.deploy()
  await erc20Quest.deployed()
  const erc1155Quest = await Erc1155Quest.deploy()
  await erc1155Quest.deployed()

  const deployment = await hre.upgrades.deployProxy(
    QuestFactory,
    [claimSignerAddress, rabbitholeReceiptAddress, rabbitholeTicketsAddress, protocolFeeReceipient, erc20Quest.address, erc1155Quest.address],
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
