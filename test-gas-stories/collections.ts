import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { ContractTransaction, utils } from 'ethers'
import { ethers } from 'hardhat'
import { story } from './gas-stories'

import { Quest, QuestFactory, QuestNFT, QuestTerminalKey, RabbitHoleReceipt, ReceiptRenderer } from '../typechain-types'
import { TestContracts, deployAll } from '../test/helpers/deploy'

describe('Collections', () => {
  let owner: SignerWithAddress
  let claimAddressSigner: SignerWithAddress
  let firstAddress: SignerWithAddress
  let secondAddress: SignerWithAddress
  let contracts: TestContracts
  let questFactory: QuestFactory
  let erc20Quest: Quest
  let tx: ContractTransaction
  const questId = 'quest-id'
  const questId2 = 'quest-id-2'
  let expiryDate
  let startDate

  beforeEach(async () => {
    ;[owner, claimAddressSigner, firstAddress, secondAddress] = await ethers.getSigners()
    contracts = await deployAll(owner, claimAddressSigner)
    tx = await contracts.questFactory.setRewardAllowlistAddress(contracts.sampleErc20.address, true)
    await story('QuestFactory', 'RewardAllowlist', 'setRewardAllowlistAddress', 'Set the reward allowlist', tx)
    questFactory = contracts.questFactory

    const latestTime = await time.latest()
    expiryDate = latestTime + 10000
    startDate = latestTime + 100

    await createErc20Quest()

    await ethers.provider.send('evm_increaseTime', [1000])

    await startErc20Quest()
  })

  afterEach(async () => {
    await ethers.provider.send('evm_increaseTime', [-1000])
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
        questId
      )
    await story('QuestFactory', 'Quest', 'createQuest', 'Create ERC20 quest', tx)
  }

  const startErc20Quest = async () => {
    const erc20QuestStruct = await contracts.questFactory.connect(owner).quests(questId)
    const erc20QuestAddress = erc20QuestStruct.questAddress
    erc20Quest = (await ethers.getContractFactory('Quest')).attach(erc20QuestAddress) as Quest
    const val = await erc20Quest.totalTransferAmount()
    await contracts.sampleErc20.transfer(erc20QuestAddress, val)
    tx = await erc20Quest.queue()
    await story('Quest', 'Start', 'startQuest', 'Start ERC20 quest', tx)
  }

  it('Mint Receipt and Claim Rewards', async () => {
    let hash = utils.solidityKeccak256(['address', 'string'], [firstAddress.address.toLowerCase(), questId])
    let signature = await claimAddressSigner.signMessage(utils.arrayify(hash))
    tx = await questFactory.connect(firstAddress).mintReceipt(questId, hash, signature)
    await story('QuestFactory', 'Mint Receipt', 'mintReceipt', '1st mint', tx)
    tx = await erc20Quest.connect(firstAddress).claim()
    await story('Quest', 'Claim', 'claim', '1st claim', tx)

    hash = utils.solidityKeccak256(['address', 'string'], [secondAddress.address.toLowerCase(), questId])
    signature = await claimAddressSigner.signMessage(utils.arrayify(hash))
    tx = await questFactory.connect(secondAddress).mintReceipt(questId, hash, signature)
    await story('QuestFactory', 'Mint Receipt', 'mintReceipt', '2nd mint', tx)
  })

  it('Withdraw Remaining Rewards', async () => {
    await ethers.provider.send('evm_increaseTime', [10000])

    tx = await erc20Quest.withdrawRemainingTokens()
    await story('Quest', 'Withdraw', 'withdrawRemainingRewards', 'Withdraw remaining rewards from ERC20 quest', tx)

    await ethers.provider.send('evm_increaseTime', [-10000])
  })
})
