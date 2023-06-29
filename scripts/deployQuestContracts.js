require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const questFactoryAddress = '0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E' // production everywhere
  const questTerminalKeyAddress = '0x6Fd74033a717ebb3c60c08b37A94b6CF96DE54Ab' // production everywhere
  const rabbitHoleReceiptAddress = '0xEC3a9c7d612E0E0326e70D97c9310A5f57f9Af9E' // production everywhere
  const Erc20Quest = await ethers.getContractFactory('Quest')
  const QuestNFT = await ethers.getContractFactory('QuestNFT')
  const QuestFactory = await ethers.getContractFactory('QuestFactory')
  const QuestTerminalKey = await ethers.getContractFactory('QuestTerminalKey')
  const RabbitHoleReceipt = await ethers.getContractFactory('RabbitHoleReceipt')

  // deploy new quest implementation
  const erc20Quest = await Erc20Quest.deploy()
  await erc20Quest.deployed()
  console.log('deployed Erc20Quest implementation to:', erc20Quest.address)
  await hre.run('verify:verify', { address: erc20Quest.address })

  // deploy new quest nft implementation
  const questNFT = await QuestNFT.deploy()
  await questNFT.deployed()
  console.log('deployed QuestNFT implementation to:', questNFT.address)
  await hre.run('verify:verify', { address: questNFT.address })

  // the below doesnt seem to work, so we do it manually with `validateUpgrade` and `deploy`
  // const NewImplementationAddress = await hre.upgrades.prepareUpgrade(questFactoryAddress, QuestFactory)

  // Validates and deploys a new implementation contract for QuestFactory
  await hre.upgrades.forceImport(questFactoryAddress, QuestFactory)
  await hre.upgrades.validateUpgrade(questFactoryAddress, QuestFactory)
  const questFactoryImp = await QuestFactory.deploy()
  await questFactoryImp.deployed()
  console.log('deployed QuestFactory Implementation to:', questFactoryImp.address)
  await hre.run('verify:verify', { address: questFactoryImp.address })

  // Validates and deploys a new implementation contract for RabbitHoleReceipt
  // await hre.upgrades.forceImport(rabbitHoleReceiptAddress, RabbitHoleReceipt)
  // await hre.upgrades.validateUpgrade(rabbitHoleReceiptAddress, RabbitHoleReceipt)
  // const RabbitHoleReceiptImp = await RabbitHoleReceipt.deploy()
  // await RabbitHoleReceiptImp.deployed()
  // console.log('deployed RabbitHoleReceipt Implementation to:', RabbitHoleReceiptImp.address)
  // await hre.run('verify:verify', { address: RabbitHoleReceiptImp.address })

  // validates and deploys a new implementation contract for QuestTerminalKey
  // await hre.upgrades.forceImport(questTerminalKeyAddress, QuestTerminalKey)
  // await hre.upgrades.validateUpgrade(questTerminalKeyAddress, QuestTerminalKey)
  // const QTKImp = await QuestTerminalKey.deploy()
  // await QTKImp.deployed()
  // console.log('deployed QTK to:', QTKImp.address)
  // await hre.run('verify:verify', { address: QTKImp.address })
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
