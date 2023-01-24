import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { ethers, upgrades } from 'hardhat'
import {
  QuestFactory,
  QuestFactory__factory,
  Erc20Quest,
  Erc20Quest__factory,
  Erc1155Quest,
  Erc1155Quest__factory,
  SampleERC20,
  SampleERC20__factory,
  SampleErc1155,
  SampleErc1155__factory,
  RabbitHoleReceipt,
  RabbitHoleReceipt__factory,
  ReceiptRenderer,
  ReceiptRenderer__factory,
} from '../../typechain-types'

export type TestContracts = {
  questFactory: QuestFactory
  rabbitHoleReceipt: RabbitHoleReceipt
  receiptRenderer: ReceiptRenderer

  // sample contracts for testing
  sampleErc20: SampleERC20
  sampleErc1155: SampleErc1155
}

export async function deployAll(
  deployer: SignerWithAddress,
  claimAddressSigner: SignerWithAddress
): Promise<TestContracts> {
  // upgrades.silenceWarnings()
  const receiptRenderer = await deployReceiptRenderer({ deployer })
  const rabbitHoleReceipt = await deployRabbitHoleReceipt({ deployer, receiptRendererAddress: receiptRenderer.address })
  const questFactory = await deployQuestFactory({
    deployer,
    claimAddressSigner,
    receiptAddress: rabbitHoleReceipt.address,
  })
  const sampleErc20 = await deploySampleErc20({ deployer })
  const sampleErc1155 = await deploySampleErc1155({ deployer })

  // await questFactory.setRewardAllowlistAddress(sampleErc20.address, true)

  return {
    questFactory,
    rabbitHoleReceipt,
    receiptRenderer,
    sampleErc20,
    sampleErc1155,
  }
}

export async function deployReceiptRenderer({ deployer }: { deployer: SignerWithAddress }) {
  const ReceiptRenderer = new ReceiptRenderer__factory(deployer)
  const receiptRenderer = await ReceiptRenderer.deploy()
  return receiptRenderer
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
  ])) as RabbitHoleReceipt
  return rabbitHoleReceipt
}

export async function deployQuestFactory({
  deployer,
  claimAddressSigner,
  receiptAddress,
}: {
  deployer: SignerWithAddress
  claimAddressSigner: SignerWithAddress
  receiptAddress: string
}) {
  const QuestFactory = new QuestFactory__factory(deployer)
  const questFactory = (await upgrades.deployProxy(QuestFactory, [
    claimAddressSigner.address,
    receiptAddress,
    deployer.address,
  ])) as QuestFactory
  return questFactory
}

export async function deploySampleErc20({ deployer }: { deployer: SignerWithAddress }) {
  const SampleERC20 = new SampleERC20__factory(deployer)
  const sampleERC20 = await SampleERC20.deploy('RewardToken', 'RTC', 1000000, deployer.address)
  return sampleERC20
}

export async function deploySampleErc1155({ deployer }: { deployer: SignerWithAddress }) {
  const SampleErc1155 = new SampleErc1155__factory(deployer)
  const sampleErc1155 = await SampleErc1155.deploy()
  return sampleErc1155
}
