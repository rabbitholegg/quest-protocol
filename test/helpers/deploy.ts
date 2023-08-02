import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { upgrades } from 'hardhat'
import {
  Quest,
  Quest__factory,
  QuestFactory,
  QuestFactory__factory,
  Quest1155,
  Quest1155__factory,
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
  quest1155: Quest1155
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
  const quest1155 = await deployQuest1155({ deployer })
  const questTerminalKey = await deployQuestTerminalKey({ deployer })
  const rabbitHoleReceipt = await deployRabbitHoleReceipt({ deployer, receiptRendererAddress: receiptRenderer.address })
  const questFactory = await deployQuestFactory({
    deployer,
    claimAddressSigner,
    receiptAddress: rabbitHoleReceipt.address,
    questAddress: quest.address,
    questTerminalKeyAddress: questTerminalKey.address,
    quest1155Address: quest1155.address,
  })
  await rabbitHoleReceipt.setQuestFactory(questFactory.address)
  await rabbitHoleReceipt.setMinterAddress(questFactory.address)
  await questTerminalKey.setQuestFactoryAddress(questFactory.address)
  await questTerminalKey.setMinterAddress(questFactory.address)

  return {
    quest,
    questFactory,
    quest1155,
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
  quest1155Address,
}: {
  deployer: SignerWithAddress
  claimAddressSigner: SignerWithAddress
  receiptAddress: string
  questAddress: string
  questTerminalKeyAddress: string
  quest1155Address: string
}) {
  const QuestFactory = new QuestFactory__factory(deployer)
  const questFactory = (await upgrades.deployProxy(QuestFactory, [
    claimAddressSigner.address,
    receiptAddress,
    deployer.address, // protocol fee recipient
    questAddress,
    quest1155Address,
    deployer.address,
    questTerminalKeyAddress,
    100, // nft quest fee
    10, // referral fee in bips
  ])) as QuestFactory
  return questFactory
}

export async function deployQuest({ deployer }: { deployer: SignerWithAddress }) {
  const Quest = new Quest__factory(deployer)
  const quest = await Quest.deploy()
  return quest
}

export async function deployQuest1155({ deployer }: { deployer: SignerWithAddress }) {
  const Quest1155 = new Quest1155__factory(deployer)
  const quest1155 = await Quest1155.deploy()
  return quest1155
}

export async function deploySampleErc20({ deployer }: { deployer: SignerWithAddress }) {
  const SampleERC20 = new SampleERC20__factory(deployer)
  const sampleERC20 = await SampleERC20.deploy('RewardToken', 'RTC', 1000000, deployer.address)
  return sampleERC20
}
