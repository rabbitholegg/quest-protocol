import { expect } from 'chai'
import { ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import {
  Quest,
  SampleERC20,
  QuestFactory,
  RabbitHoleReceipt,
  Quest__factory,
  QuestFactory__factory,
  RabbitHoleReceipt__factory,
  SampleERC20__factory,
} from '../typechain-types'
import { Wallet, utils, constants } from 'ethers'

describe('QuestFactory', () => {
  let deployedSampleErc20Contract: SampleERC20
  let deployedRabbitHoleReceiptContract: RabbitHoleReceipt
  let deployedFactoryContract: QuestFactory
  let deployedErc20Quest: Quest
  let expiryDate: number, startDate: number
  const totalRewards = 1000
  const rewardAmount = 10
  const mnemonic = 'announce room limb pattern dry unit scale effort smooth jazz weasel alcohol'
  let owner: SignerWithAddress
  let royaltyRecipient: SignerWithAddress
  let protocolRecipient: SignerWithAddress
  let mintFeeRecipient: SignerWithAddress

  let questFactoryContract: QuestFactory__factory
  let erc20QuestContract: Quest__factory
  let rabbitholeReceiptContract: RabbitHoleReceipt__factory
  let sampleERC20Contract: SampleERC20__factory
  let wallet: Wallet

  beforeEach(async () => {
    ;[owner, royaltyRecipient, protocolRecipient, mintFeeRecipient] = await ethers.getSigners()
    const latestTime = await time.latest()
    expiryDate = latestTime + 1000
    startDate = latestTime + 100

    wallet = Wallet.fromMnemonic(mnemonic)

    questFactoryContract = await ethers.getContractFactory('QuestFactory')
    erc20QuestContract = await ethers.getContractFactory('Quest')
    rabbitholeReceiptContract = await ethers.getContractFactory('RabbitHoleReceipt')
    sampleERC20Contract = await ethers.getContractFactory('SampleERC20')

    await deploySampleErc20Contract()
    await deployRabbitHoleReceiptContract()
    await deployFactoryContract()
  })

  const deployFactoryContract = async () => {
    deployedErc20Quest = await erc20QuestContract.deploy()
    await deployedErc20Quest.deployed()

    deployedFactoryContract = (await upgrades.deployProxy(questFactoryContract, [
      wallet.address,
      deployedRabbitHoleReceiptContract.address,
      protocolRecipient.address,
      deployedErc20Quest.address,
      owner.address,
    ])) as QuestFactory

    await deployedRabbitHoleReceiptContract.setMinterAddress(deployedFactoryContract.address)
  }

  const deploySampleErc20Contract = async () => {
    deployedSampleErc20Contract = await sampleERC20Contract.deploy('RewardToken', 'RTC', '1000000000', owner.address)
    await deployedSampleErc20Contract.deployed()
  }

  const deployRabbitHoleReceiptContract = async () => {
    const ReceiptRenderer = await ethers.getContractFactory('ReceiptRenderer')
    const deployedReceiptRenderer = await ReceiptRenderer.deploy()
    await deployedReceiptRenderer.deployed()

    deployedRabbitHoleReceiptContract = (await upgrades.deployProxy(rabbitholeReceiptContract, [
      deployedReceiptRenderer.address,
      royaltyRecipient.address,
      owner.address,
      69,
      owner.address,
    ])) as RabbitHoleReceipt
  }

  describe('createQuest()', () => {
    const erc20QuestId = 'asdf'

    it('should init with right owner', async () => {
      expect(await deployedFactoryContract.owner()).to.equal(owner.address)
    })

    it('Should revert if reward address is not on the reward allowlist', async () => {
      const rewardAddress = deployedSampleErc20Contract.address
      expect(await deployedFactoryContract.rewardAllowlist(rewardAddress)).to.equal(false)

      await expect(
        deployedFactoryContract.createQuest(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          rewardAmount,
          'erc20',
          erc20QuestId
        )
      ).to.be.revertedWithCustomError(questFactoryContract, 'RewardNotAllowed')
    })

    it('Should create a new ERC20 quest', async () => {
      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)

      const tx = await deployedFactoryContract.createQuest(
        deployedSampleErc20Contract.address,
        expiryDate,
        startDate,
        totalRewards,
        rewardAmount,
        'erc20',
        erc20QuestId
      )
      await tx.wait()
      const questAddress = await deployedFactoryContract.quests(erc20QuestId).then((res) => res.questAddress)
      const deployedErc20Quest = await ethers.getContractAt('Quest', questAddress)
      expect(await deployedErc20Quest.startTime()).to.equal(startDate)
      expect(await deployedErc20Quest.owner()).to.equal(owner.address)
    })

    it('Should revert if reward address is removed from allowlist', async () => {
      const rewardAddress = deployedSampleErc20Contract.address

      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, false)

      expect(await deployedFactoryContract.rewardAllowlist(rewardAddress)).to.equal(false)

      await expect(
        deployedFactoryContract.createQuest(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          rewardAmount,
          'erc20',
          erc20QuestId
        )
      ).to.be.revertedWithCustomError(questFactoryContract, 'RewardNotAllowed')
    })

    it('Should revert if trying to use existing quest id', async () => {
      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)

      await deployedFactoryContract.createQuest(
        deployedSampleErc20Contract.address,
        expiryDate,
        startDate,
        totalRewards,
        rewardAmount,
        'erc20',
        erc20QuestId
      )

      await expect(
        deployedFactoryContract.createQuest(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          rewardAmount,
          'erc20',
          erc20QuestId
        )
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestIdUsed')
    })

    it('Should revert if msg.sender does not have correct role', async () => {
      await expect(
        deployedFactoryContract
          .connect(royaltyRecipient)
          .createQuest(
            deployedSampleErc20Contract.address,
            expiryDate,
            startDate,
            totalRewards,
            rewardAmount,
            'erc20',
            erc20QuestId
          )
      ).to.be.revertedWith(
        `AccessControl: account ${royaltyRecipient.address.toLowerCase()} is missing role 0xf9ca453be4e83785e69957dffc5e557020ebe7df32422c6d32ccad977982cadd`
      )
    })

    it('createQuestAndStart should create a new quest and start it', async () => {
      // this.maxTotalRewards() + this.maxProtocolReward()
      const maxTotalRewards = totalRewards * rewardAmount
      const maxProtocolReward = (maxTotalRewards * 2_000) / 10_000
      const transferAmount = maxTotalRewards + maxProtocolReward

      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
      // approve the quest factory to spend the reward token
      await deployedSampleErc20Contract.approve(deployedFactoryContract.address, transferAmount)

      const tx = await deployedFactoryContract.createQuestAndStart(
        deployedSampleErc20Contract.address,
        expiryDate,
        startDate,
        totalRewards,
        rewardAmount,
        'erc20',
        erc20QuestId
      )

      await tx.wait()
      const questAddress = await deployedFactoryContract.quests(erc20QuestId).then((res) => res.questAddress)
      const deployedErc20Quest = await ethers.getContractAt('Quest', questAddress)
      expect(await deployedErc20Quest.startTime()).to.equal(startDate)
      expect(await deployedErc20Quest.owner()).to.equal(owner.address)

      expect(await deployedErc20Quest.queued()).to.equal(true)
      expect(await deployedSampleErc20Contract.balanceOf(questAddress)).to.equal(transferAmount)
    })
  })

  describe('setClaimSignerAddress()', () => {
    it('Should update claimSignerAddress', async () => {
      const newAddress = royaltyRecipient.address
      await deployedFactoryContract.setClaimSignerAddress(newAddress)
      expect(await deployedFactoryContract.claimSignerAddress()).to.equal(newAddress)
    })
  })

  describe('setProtocolFeeRecipient()', () => {
    it('Should update protocolFeeRecipient', async () => {
      const newAddress = royaltyRecipient.address
      await deployedFactoryContract.setProtocolFeeRecipient(newAddress)
      expect(await deployedFactoryContract.protocolFeeRecipient()).to.equal(newAddress)
    })

    it('Should revert if setting protocolFeeRecipient to zero address', async () => {
      await expect(
        deployedFactoryContract.setProtocolFeeRecipient(constants.AddressZero)
      ).to.be.revertedWithCustomError(questFactoryContract, 'AddressZeroNotAllowed')
    })
  })

  describe('setQuestFee()', () => {
    it('Should update questFee', async () => {
      const newQuestFee = 2500
      await deployedFactoryContract.setQuestFee(newQuestFee)
      expect(await deployedFactoryContract.questFee()).to.equal(newQuestFee)
    })

    it('Should revert if setting questFee beyond 10k basis points', async () => {
      const newQuestFee = 10001
      await expect(deployedFactoryContract.setQuestFee(newQuestFee)).to.be.revertedWithCustomError(
        questFactoryContract,
        'QuestFeeTooHigh'
      )
    })
  })

  describe('getMintFeeRecipient', () => {
    it('Should return the protocolRecipient when no mintFeeRecipient is set', async () => {
      expect(await deployedFactoryContract.getMintFeeRecipient()).to.equal(protocolRecipient.address)
    })

    it('Should return the mintFeeRecipient when set', async () => {
      await deployedFactoryContract.setMintFeeRecipient(mintFeeRecipient.address)
      expect(await deployedFactoryContract.getMintFeeRecipient()).to.equal(mintFeeRecipient.address)
    })
  })

  describe('mintReceipt()', () => {
    const erc20QuestId = 'asdf'
    let messageHash: string
    let signature: string
    let questAddress: string
    let erc20Quest: Quest

    beforeEach(async () => {
      messageHash = utils.solidityKeccak256(['address', 'string'], [owner.address.toLowerCase(), erc20QuestId])
      signature = await wallet.signMessage(utils.arrayify(messageHash))
      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
      await deployedFactoryContract.createQuest(
        deployedSampleErc20Contract.address,
        expiryDate,
        startDate,
        totalRewards,
        rewardAmount,
        'erc20',
        erc20QuestId
      )
      questAddress = (await deployedFactoryContract.quests(erc20QuestId)).questAddress

      const transferAmount = totalRewards * rewardAmount + totalRewards * rewardAmount * 0.2
      await deployedSampleErc20Contract.transfer(questAddress, transferAmount)
      erc20Quest = await ethers.getContractAt('Quest', questAddress)
    })

    it('Should fail when trying to mint before quest has been queued', async () => {
      await expect(
        deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestNotQueued')
    })

    it('Should fail when trying to mint before quest time has started', async () => {
      await erc20Quest.queue()
      await time.setNextBlockTimestamp(startDate - 1)
      await expect(
        deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestNotStarted')
    })

    it('Should mint a receipt', async () => {
      await erc20Quest.queue()
      await time.setNextBlockTimestamp(startDate)
      await deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      expect(await deployedRabbitHoleReceiptContract.balanceOf(owner.address)).to.equal(1)
    })

    it('Should fail if user tries to use a hash + signature that is not tied to them', async () => {
      await erc20Quest.queue()
      await time.setNextBlockTimestamp(startDate)
      await expect(
        deployedFactoryContract.connect(royaltyRecipient).mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'InvalidHash')
    })

    it('Should fail if user is able to call mintReceipt multiple times', async () => {
      await erc20Quest.queue()
      await time.setNextBlockTimestamp(startDate)
      await deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      expect(await deployedRabbitHoleReceiptContract.balanceOf(owner.address)).to.equal(1)

      await expect(
        deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'AddressAlreadyMinted')
      expect(await deployedRabbitHoleReceiptContract.balanceOf(owner.address)).to.equal(1)
    })

    it('Should fail when trying to mint after quest time has passed', async () => {
      await erc20Quest.queue()
      await time.setNextBlockTimestamp(expiryDate + 1)
      await expect(
        deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestEnded')
    })

    it('should revert if the mint fee is insufficient', async function () {
      const requiredFee = 1000
      await erc20Quest.queue()
      await deployedFactoryContract.setMintFee(requiredFee)
      await time.setNextBlockTimestamp(startDate)

      await expect(
        deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature, {
          value: requiredFee - 1,
        })
      ).to.be.revertedWith('Insufficient mint fee')
    })

    it('should succeed if the mint fee is equal or greator than required amount, and only recieve the required amount', async function () {
      const requiredFee = 1000
      const extraChange = 100
      await erc20Quest.queue()
      await deployedFactoryContract.setMintFee(requiredFee)
      await time.setNextBlockTimestamp(startDate)
      const balanceBefore = await ethers.provider.getBalance(deployedFactoryContract.getMintFeeRecipient())

      await expect(
        deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature, {
          value: requiredFee + extraChange,
        })
      )
        .to.emit(deployedFactoryContract, 'ReceiptMinted')
        .to.emit(deployedFactoryContract, 'ExtraMintFeeReturned')
        .withArgs(owner.address, extraChange)
      expect(await ethers.provider.getBalance(deployedFactoryContract.getMintFeeRecipient())).to.equal(
        balanceBefore.add(requiredFee)
      )
    })
  })
})
