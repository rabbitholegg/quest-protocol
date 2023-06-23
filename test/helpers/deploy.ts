import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { upgrades } from 'hardhat'
import {
  Quest,
  Quest__factory,
  QuestFactory,
  QuestFactory__factory,
  QuestNFT,
  QuestNFT__factory,
  QuestTerminalKey,
  QuestTerminalKey__factory,
  RabbitHoleReceipt,
  RabbitHoleReceipt__factory,
  ReceiptRenderer,
  ReceiptRenderer__factory,
  SampleERC20,
  SampleERC20__factory,
} from '../../typechain-types'

export type TestContracts = {
  quest: Quest
  questFactory: QuestFactory
  questNFT: QuestNFT
  questTerminalKey: QuestTerminalKey
  rabbitHoleReceipt: RabbitHoleReceipt
  receiptRenderer: ReceiptRenderer

  // sample contracts for testing
  sampleErc20: SampleERC20
}

export async function deployAll(
  deployer: SignerWithAddress,
  claimAddressSigner: SignerWithAddress
): Promise<TestContracts> {
  // upgrades.silenceWarnings()
  const receiptRenderer = await deployReceiptRenderer({ deployer })
  const sampleErc20 = await deploySampleErc20({ deployer })
  const quest = await deployQuest({ deployer })
  const questNFT = await deployQuestNFT({ deployer })
  const questTerminalKey = await deployQuestTerminalKey({ deployer })
  const rabbitHoleReceipt = await deployRabbitHoleReceipt({ deployer, receiptRendererAddress: receiptRenderer.address })
  const questFactory = await deployQuestFactory({
    deployer,
    claimAddressSigner,
    receiptAddress: rabbitHoleReceipt.address,
    questAddress: quest.address,
    questTerminalKeyAddress: questTerminalKey.address,
    questNFTAddress: questNFT.address,
  })
  await rabbitHoleReceipt.setQuestFactory(questFactory.address)
  await rabbitHoleReceipt.setMinterAddress(questFactory.address)
  await questTerminalKey.setQuestFactoryAddress(questFactory.address)
  await questTerminalKey.setMinterAddress(questFactory.address)

  return {
    quest,
    questFactory,
    questNFT,
    questTerminalKey,
    rabbitHoleReceipt,
    receiptRenderer,
    sampleErc20,
  }
}

export async function deployReceiptRenderer({ deployer }: { deployer: SignerWithAddress }) {
  const ReceiptRenderer = new ReceiptRenderer__factory(deployer)
  const receiptRenderer = await ReceiptRenderer.deploy()
  return receiptRenderer
}

export async function deployQuestTerminalKey({ deployer }: { deployer: SignerWithAddress }) {
  const QuestTerminalKey = new QuestTerminalKey__factory(deployer)
  const questTerminalKey = (await upgrades.deployProxy(QuestTerminalKey, [
    deployer.address,
    deployer.address,
    deployer.address,
    100,
    deployer.address,
    'imageIPFSHash',
    'animationUrlIPFSHash',
  ])) as QuestTerminalKey
  return questTerminalKey
}

export async function deployRabbitHoleReceipt({
  deployer,
  receiptRendererAddress,
}: {
  deployer: SignerWithAddress
  receiptRendererAddress: string
}) {
  const RabbitHoleReceipt = new RabbitHoleReceipt__factory(deployer)
  const rabbitHoleReceipt = (await upgrades.deployProxy(RabbitHoleReceipt, [
    receiptRendererAddress,
    deployer.address,
    deployer.address,
    10,
    deployer.address,
  ])) as RabbitHoleReceipt
  return rabbitHoleReceipt
}

export async function deployQuestFactory({
  deployer,
  claimAddressSigner,
  receiptAddress,
  questAddress,
  questTerminalKeyAddress,
  questNFTAddress,
}: {
  deployer: SignerWithAddress
  claimAddressSigner: SignerWithAddress
  receiptAddress: string
  questAddress: string
  questTerminalKeyAddress: string
  questNFTAddress: string
}) {
  const QuestFactory = new QuestFactory__factory(deployer)
  const questFactory = (await upgrades.deployProxy(QuestFactory, [
    claimAddressSigner.address,
    receiptAddress,
    deployer.address,
    questAddress,
    deployer.address,
    questTerminalKeyAddress,
    questNFTAddress,
    100,
  ])) as QuestFactory
  return questFactory
}

export async function deployQuest({ deployer }: { deployer: SignerWithAddress }) {
  const Quest = new Quest__factory(deployer)
  const quest = await Quest.deploy()
  return quest
}

export async function deployQuestNFT({ deployer }: { deployer: SignerWithAddress }) {
  const QuestNFT = new QuestNFT__factory(deployer)
  const questNFT = await QuestNFT.deploy()
  return questNFT
}

export async function deploySampleErc20({ deployer }: { deployer: SignerWithAddress }) {
  const SampleERC20 = new SampleERC20__factory(deployer)
  const sampleERC20 = await SampleERC20.deploy('RewardToken', 'RTC', 1000000, deployer.address)
  return sampleERC20
}
