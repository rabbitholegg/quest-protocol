require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const Erc20Quest = await ethers.getContractFactory('Quest')
  const questFactoryAddress = '0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E' // production everywhere
  // const questFactoryAddress = '0x10851543671491656606E6A49dE32c9cCb41b4F8' // goerli staging
  const QuestFactory = await ethers.getContractFactory('QuestFactory')

  // deploy new quest
  const erc20Quest = await Erc20Quest.deploy()
  await erc20Quest.deployed()
  console.log('deployed Erc20Quest to:', erc20Quest.address)
  await hre.run('verify:verify', { address: erc20Quest.address })

  // to manually upgrade the quest factory
  // validate upgrade
  await hre.upgrades.validateUpgrade(questFactoryAddress, QuestFactory)
  // deploy new implementation
  const questFactory = await QuestFactory.deploy()
  await questFactory.deployed()
  console.log('deployed QuestFactory to:', questFactory.address)
  await hre.run('verify:verify', { address: questFactory.address })
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
