require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const questFactoryAddress = '0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E' // production everywhere
  const rabbitHoleTicketsAddress = '0x0D380362762B0cf375227037f2217f59A4eC4b9E' // production everywhere
  const Erc20Quest = await ethers.getContractFactory('Quest')
  const Erc1155Quest = await ethers.getContractFactory('Quest1155')
  const QuestFactory = await ethers.getContractFactory('QuestFactory')
  const RabbitHoleTickets = await ethers.getContractFactory('RabbitHoleTickets')

  // deploy new quest implementation
  // const erc20Quest = await Erc20Quest.deploy()
  // await erc20Quest.deployed()
  // console.log('deployed Erc20Quest implementation to:', erc20Quest.address)
  // await hre.run('verify:verify', { address: erc20Quest.address })

  // // deploy new 1155 quest implementation
  // const erc1155Quest = await Erc1155Quest.deploy()
  // await erc1155Quest.deployed()
  // console.log('deployed erc1155Quest implementation to:', erc1155Quest.address)
  // await hre.run('verify:verify', { address: erc1155Quest.address })

  // the below doesnt seem to work, so we do it manually with `validateUpgrade` and `deploy`
  // const NewImplementationAddress = await hre.upgrades.prepareUpgrade(questFactoryAddress, QuestFactory)

  // Validates and deploys a new implementation contract for QuestFactory
  // await hre.upgrades.forceImport(questFactoryAddress, QuestFactory)
  await hre.upgrades.validateUpgrade(questFactoryAddress, QuestFactory)
  const questFactoryImp = await QuestFactory.deploy()
  await questFactoryImp.deployed()
  console.log('deployed QuestFactory Implementation to:', questFactoryImp.address)
  await hre.run('verify:verify', { address: questFactoryImp.address })

  // validates and deploys a new implementation contract for QuestTerminalKey
  // await hre.upgrades.forceImport(questTerminalKeyAddress, QuestTerminalKey)
  // await hre.upgrades.validateUpgrade(questTerminalKeyAddress, QuestTerminalKey)
  // const QTKImp = await QuestTerminalKey.deploy()
  // await QTKImp.deployed()
  // console.log('deployed QTK to:', QTKImp.address)
  // await hre.run('verify:verify', { address: QTKImp.address })

  // validates and deploys a new implementation contract for RabbitHoleTickets
  // await hre.upgrades.forceImport(rabbitHoleTicketsAddress, RabbitHoleTickets)
  // await hre.upgrades.validateUpgrade(rabbitHoleTicketsAddress, RabbitHoleTickets)
  // const RHTImp = await RabbitHoleTickets.deploy()
  // await RHTImp.deployed()
  // console.log('deployed RabbitHoleTickets Implementation to:', RHTImp.address)
  // await hre.run('verify:verify', { address: RHTImp.address })
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
