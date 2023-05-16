require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const Erc20Quest = await ethers.getContractFactory('Quest')
  // const questFactoryAddress = '0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E' // production everywhere
  const questFactoryAddress = '0x74016208260cE10ef421ed0CFC4C7Baae0BaEF86' // sepolia staging
  const QuestFactory = await ethers.getContractFactory('QuestFactory')

  // deploy new quest
  // const erc20Quest = await Erc20Quest.deploy()
  // await erc20Quest.deployed()
  // console.log('deployed Erc20Quest to:', erc20Quest.address)
  // await hre.run('verify:verify', { address: erc20Quest.address })

  // the below doesnt seem to work, so we do it manually with `validateUpgrade` and `deploy`
  // const NewImplementationAddress = await hre.upgrades.prepareUpgrade(questFactoryAddress, QuestFactory)

  // Validates and deploys a new implementation contract
  await hre.upgrades.forceImport(questFactoryAddress, QuestFactory)
  await hre.upgrades.validateUpgrade(questFactoryAddress, QuestFactory)
  const questFactoryImp = await QuestFactory.deploy()
  await questFactoryImp.deployed()
  console.log('deployed QuestFactory to:', questFactoryImp.address)
  await hre.run('verify:verify', { address: questFactoryImp.address })
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
