require('dotenv').config()

import { Deployer } from '@matterlabs/hardhat-zksync-deploy'
import { Wallet } from 'zksync-web3'
import * as hre from 'hardhat'

const wallet = new Wallet(process.env.MAINNET_PRIVATE_KEY)
const deployer = new Deployer(hre, wallet)

async function deployProxy(contractName: string, initializerArgs: any[]) {
  console.log('Deploying ' + contractName + '...')

  const artificat = await deployer.loadArtifact(contractName)
  const contract = await hre.zkUpgrades.deployProxy(deployer.zkWallet, artificat, initializerArgs, {
    initializer: 'initialize',
  })

  await contract.deployed()
  console.log(contractName + ' deployed to:', contract.address)
}

async function deploy(contractName: string, initializerArgs: any[]) {
  console.log('Deploying ' + contractName + '...')

  const artifact = await deployer.loadArtifact(contractName)
  const contract = await deployer.deploy(artifact, initializerArgs)

  await contract.deployed()
  console.log(contractName + ' deployed to:', contract.address)
}

async function upgrade(contractName: string, proxyAddress: string) {
  console.log('Upgrading ' + contractName + '...')

  const artifact = await deployer.loadArtifact(contractName)
  await hre.zkUpgrades.upgradeProxy(deployer.zkWallet, proxyAddress, artifact)

  console.log('Upgraded ' + contractName)
}

async function main() {
  await deployProxy('QuestFactory', [
    '0x94c3e5e801830dd65cd786f2fe37e79c65df4148', // claimSignerAddress_
    '0x0000000000000000000000000000000000000000', // rabbitHoleReceiptContract_
    '0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c', // protocolFeeRecipient_
    '0x043020B85eb76f5f829a96e2d90fCA3A7bc080db', // erc20QuestAddress_
    '0x9F610426A31d7F50991754FA77FFbAdC87D3098F', // erc1155QuestAddress_
    '0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c', // ownerAddress_
    '0x0000000000000000000000000000000000000000', // questTerminalKeyAddress_
    '500000000000000', // nftQuestFee_
    '5000', // referralFee_
  ])

  // no need to deploy RabbitHoleReceipt
  // no need to deploy QuestTerminalKey

  await deployProxy('RabbitHoleTickets', [
    '0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c', // royaltyRecipient_,
    '0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c', // minterAddress_,
    '100', // royaltyFee_,
    '0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c', // owner_,
    'bafkreicoysyc5chqjntdpxiyfojoljabycedep3mssphpwv7opfqfrlwbq', // imageIPFSCID_
    'bafybeib43gbmeloa6o6hs7xxwioyvduohmuf6yyu2avusjuke7delbou3m', // animationUrlIPFSCID_
  ])

  // await deploy('Quest', [])
  // await deploy('Quest1155', [])

  // await upgrade('QuestFactory', '0x49f05f2646772b6D0E695550CA49D1e3fF8A17E7') // testnet
  // await upgrade('RabbitHoleTickets', '0x651c7fBBaC1fA3a8937377C4879Ca99C11F1261c') // testnet
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
