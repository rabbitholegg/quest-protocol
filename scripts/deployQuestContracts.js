require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const Erc20Quest = await ethers.getContractFactory('Quest')
  const erc20Quest = await Erc20Quest.deploy()
  await erc20Quest.deployed()
  console.log('deployed Erc20Quest to:', erc20Quest.address)
  console.log('verifying erc20Quest: ', erc20Quest.address)
  await hre.run('verify:verify', { address: erc20Quest.address })

  // to manually upgrade the quest factory
  // const QuestFactory = await ethers.getContractFactory('QuestFactory')
  // const questFactory = await QuestFactory.deploy()
  // await questFactory.deployed()
  // console.log('deployed QuestFactory to:', questFactory.address)
  // console.log('verifying questFactory: ', questFactory.address)
  // await hre.run('verify:verify', { address: questFactory.address })
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
