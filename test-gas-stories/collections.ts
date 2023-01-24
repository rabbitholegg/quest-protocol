import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { ContractTransaction, utils } from 'ethers'
import { ethers, upgrades } from 'hardhat'
import { story } from './gas-stories'

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
} from '../typechain-types'
import { TestContracts, deployAll } from '../test/helpers/deploy'

describe('Collections', () => {
  let owner: SignerWithAddress
  let claimAddressSigner: SignerWithAddress
  let firstAddress: SignerWithAddress
  let contracts: TestContracts
  let questFactory: QuestFactory
  let erc20Quest: Erc20Quest
  let erc1155Quest: Erc1155Quest
  let tx: ContractTransaction
  const questId = 'quest-id'
  const questId2 = 'quest-id-2'
  let expiryDate
  let startDate

  beforeEach(async () => {
    ;[owner, claimAddressSigner, firstAddress] = await ethers.getSigners()
    contracts = await deployAll(owner, claimAddressSigner)
    tx = await contracts.questFactory.setRewardAllowlistAddress(contracts.sampleErc20.address, true)
    await story('QuestFactory', 'RewardAllowlist', 'setRewardAllowlistAddress', 'Set the reward allowlist', tx)
    questFactory = contracts.questFactory

    expiryDate = Math.floor(Date.now() / 1000) + 10000
    startDate = Math.floor(Date.now() / 1000) + 1000

    await createErc20Quest()
    await createErc1155Quest()

    await ethers.provider.send('evm_increaseTime', [1000])

    await startErc20Quest()
    await startErc1155Quest()
  })

  const createErc20Quest = async () => {
    const totalParticipants = 1000
    const rewardAmount = 10
    tx = await contracts.questFactory
      .connect(owner)
      .createQuest(
        contracts.sampleErc20.address,
        expiryDate,
        startDate,
        totalParticipants,
        rewardAmount,
        'erc20',
        'quest-id'
      )
    await story('QuestFactory', 'Quest', 'createQuest', 'Create ERC20 quest', tx)
  }

  const createErc1155Quest = async () => {
    const totalParticipants = 10
    const tokenId = 1
    tx = await contracts.questFactory
      .connect(owner)
      .createQuest(
        contracts.sampleErc1155.address,
        expiryDate,
        startDate,
        totalParticipants,
        tokenId,
        'erc1155',
        questId2
      )
    await story('QuestFactory', 'Quest', 'createQuest', 'Create ERC1155 quest', tx)
  }

  const startErc20Quest = async () => {
    const erc20QuestStruct = await contracts.questFactory.connect(owner).quests(questId)
    const erc20QuestAddress = erc20QuestStruct.questAddress
    erc20Quest = (await ethers.getContractFactory('Erc20Quest')).attach(erc20QuestAddress) as Erc20Quest
    const val = (await erc20Quest.maxTotalRewards()).add(await erc20Quest.maxProtocolReward())
    await contracts.sampleErc20.transfer(erc20QuestAddress, val)
    tx = await erc20Quest.start()
    await story('Erc20Quest', 'Quest', 'startQuest', 'Start ERC20 quest', tx)
  }

  const startErc1155Quest = async () => {
    const erc1155QuestStruct = await contracts.questFactory.connect(owner).quests(questId2)
    const erc1155QuestAddress = erc1155QuestStruct.questAddress
    erc1155Quest = (await ethers.getContractFactory('Erc1155Quest')).attach(erc1155QuestAddress) as Erc1155Quest
    await contracts.sampleErc1155.safeTransferFrom(owner.address, erc1155QuestAddress, 1, 10, '0x')
    tx = await erc1155Quest.start()
    await story('Erc1155Quest', 'Quest', 'startQuest', 'Start ERC1155 quest', tx)
  }

  it('Mint Receipt and Claim Rewards', async () => {
    const hash = utils.solidityKeccak256(['address', 'string'], [firstAddress.address.toLowerCase(), questId])
    const signature = await claimAddressSigner.signMessage(utils.arrayify(hash))
    tx = await questFactory.connect(firstAddress).mintReceipt(questId, hash, signature)
    await story('QuestFactory', 'Mint Receipt', 'mintReceipt', '1st mint', tx)
    tx = await erc20Quest.connect(firstAddress).claim()
    await story('Erc20Quest', 'Claim', 'claim', '1st claim', tx)

    const hash2 = utils.solidityKeccak256(['address', 'string'], [firstAddress.address.toLowerCase(), questId2])
    const signature2 = await claimAddressSigner.signMessage(utils.arrayify(hash2))
    tx = await questFactory.connect(firstAddress).mintReceipt(questId2, hash2, signature2)
    await story('QuestFactory', 'Mint Receipt', 'mintReceipt', '2st mint', tx)
  })
})
