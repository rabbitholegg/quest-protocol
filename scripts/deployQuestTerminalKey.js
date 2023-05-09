require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const royaltyRecipient = '0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c'
  const minterAddress = '0x61A8CC96a3576C2a50716a0cDE70BF373C018aa6' // goerli
  const questFactoryAddress = '0x10851543671491656606E6A49dE32c9cCb41b4F8' // goerli
  const royaltyFee = 1000 // 10%
  const owner = '0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c'
  const ipfsCid = 'QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n'

  const QuestTerminalKey = await ethers.getContractFactory('QuestTerminalKey')

  const deployment = await hre.upgrades.deployProxy(
    QuestTerminalKey,
    [royaltyRecipient, minterAddress, questFactoryAddress, royaltyFee, owner, ipfsCid],
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
