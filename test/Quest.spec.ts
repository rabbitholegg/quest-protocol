import { Result } from '@ethersproject/abi'
import { expect } from 'chai'
import { ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { Wallet, utils } from 'ethers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import {
  Quest__factory,
  SampleERC20__factory,
  Quest,
  SampleERC20,
  QuestFactory,
  QuestFactory__factory,
} from '../typechain-types'

describe('Quest', async () => {
  let deployedQuestContract: Quest
  let deployedSampleErc20Contract: SampleERC20
  let expiryDate: number, startDate: number
  const sablierV2LockupLinearAddress = '0xB10daee1FCF62243aE27776D7a92D39dC8740f95'
  const mnemonic = 'announce room limb pattern dry unit scale effort smooth jazz weasel alcohol'
  const questId = 'asdf'
  const totalParticipants = 300
  const rewardAmount = 1000
  const questFee = 2000 // 20%
  const totalRewardsPlusFee = totalParticipants * rewardAmount + (totalParticipants * rewardAmount * questFee) / 10_000
  let owner: SignerWithAddress
  let firstAddress: SignerWithAddress
  let secondAddress: SignerWithAddress
  let minterAddress: SignerWithAddress
  let protocolFeeRecipient: SignerWithAddress
  let questContract: Quest__factory
  let sampleERC20Contract: SampleERC20__factory
  let deployedFactoryContract: QuestFactory
  let questFactoryContract: QuestFactory__factory
  let wallet: Wallet
  let messageHash: string
  let signature: string

  beforeEach(async () => {
    // local_owner is our default signature, unless another signer is manually connected expect this one to be the one used
    // Right now we're only using the owner, firstAddress(this account is our main claimer/completer) and the protocolFeeRecipient
    const [local_owner, local_firstAddress, local_secondAddress, local_thirdAddress, local_fourthAddress] =
      await ethers.getSigners()
    questContract = await ethers.getContractFactory('Quest')
    sampleERC20Contract = await ethers.getContractFactory('SampleERC20')
    questFactoryContract = await ethers.getContractFactory('QuestFactory')
    wallet = Wallet.fromMnemonic(mnemonic)

    owner = local_owner
    firstAddress = local_firstAddress
    secondAddress = local_secondAddress
    minterAddress = local_thirdAddress
    protocolFeeRecipient = local_fourthAddress

    const latestTime = await time.latest()
    expiryDate = latestTime + 1000
    startDate = latestTime + 100

    await deploySampleErc20Contract()
    await deployFactoryContract()

    // Setup quest completion signature
    messageHash = utils.solidityKeccak256(['address', 'string'], [firstAddress.address.toLowerCase(), questId])
    signature = await wallet.signMessage(utils.arrayify(messageHash))
    // Setup ERC20 instance of quest contract through factory
    await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
    await deployedSampleErc20Contract.approve(deployedFactoryContract.address, totalRewardsPlusFee)
    await deployedFactoryContract.createQuestAndQueue(
      deployedSampleErc20Contract.address,
      expiryDate,
      startDate,
      totalParticipants,
      rewardAmount,
      questId,
      '', // actionSpec
      0   // discountTokenId
    )
    let questAddress = await deployedFactoryContract.quests(questId).then((res) => res.questAddress)
    deployedQuestContract = await ethers.getContractAt('Quest', questAddress)

  })

  const deployFactoryContract = async () => {
    const erc20QuestContract = await ethers.getContractFactory('Quest')
    const deployedErc20Quest = await erc20QuestContract.deploy()

    deployedFactoryContract = (await upgrades.deployProxy(questFactoryContract, [
      wallet.address,
      protocolFeeRecipient.address,
      deployedErc20Quest.address,
      ethers.constants.AddressZero, // as a placeholder, would be the Quest1155 NFT contract
      owner.address,
      ethers.constants.AddressZero, // as a placeholder, would be the QuestTerminalKey NFT contract
      sablierV2LockupLinearAddress, // sablier contract address on mainnet
      100, // the nftQuestFee
      5000, // referralFee
    ])) as QuestFactory
  }

  const deploySampleErc20Contract = async () => {
    deployedSampleErc20Contract = await sampleERC20Contract.deploy(
      'RewardToken',
      'RTC',
      totalRewardsPlusFee,
      owner.address
    )
    await deployedSampleErc20Contract.deployed()
  }

  describe('Deployment', () => {
    describe('when end time is in past', () => {
      it('Should revert', async () => {
        await expect(
          upgrades.deployProxy(questContract, [
            ethers.constants.AddressZero,
            startDate - 1000,
            startDate,
            totalParticipants,
            100,
            'questid',
            10,
            ethers.constants.AddressZero,
            0, // durationTotal_
            sablierV2LockupLinearAddress, // sablier contract address on mainnet
          ])
        ).to.be.revertedWithCustomError(questContract, 'EndTimeInPast')
      })
    })

    describe('when end time is before start time', () => {
      it('Should revert', async () => {
        await expect(
          upgrades.deployProxy(questContract, [
            ethers.constants.AddressZero,
            startDate + 1,
            startDate + 10,
            totalParticipants,
            100,
            'questid',
            10,
            ethers.constants.AddressZero,
            0, // durationTotal_
            sablierV2LockupLinearAddress, // sablier contract address on mainnet
          ])
        ).to.be.revertedWithCustomError(questContract, 'EndTimeLessThanOrEqualToStartTime')
      })
    })

    describe('setting public variables', () => {
      it('Should set the token address with correct value', async () => {
        const rewardContractAddress = await deployedQuestContract.rewardToken()
        expect(rewardContractAddress).to.equal(deployedSampleErc20Contract.address)
      })

      it('Should set the total participants with correct value', async () => {
        const totalParticipants = await deployedQuestContract.totalParticipants()
        expect(totalParticipants).to.equal(totalParticipants)
      })

      it('Should set has started with correct value', async () => {
        const queued = await deployedQuestContract.queued()
        expect(queued).to.equal(true) // New default behavior is to queue quests on creation - this will be removed in follow-on
      })

      it('Should set the end time with correct value', async () => {
        const endTime = await deployedQuestContract.endTime()
        expect(endTime).to.equal(expiryDate)
      })

      it('Should set the start time with correct value', async () => {
        const startTime = await deployedQuestContract.startTime()
        expect(startTime).to.equal(startDate)
      })
    })

    it('Deployment should set the correct owner address', async () => {
      expect(await deployedQuestContract.owner()).to.equal(owner.address)
    })
  })

  describe('pause()', () => {
    it('should only allow the owner to pause', async () => {
      await expect(deployedQuestContract.connect(firstAddress).pause()).to.be.revertedWithCustomError(
        questContract,
        'Unauthorized'
      )
    })

    it('should set pause correctly', async () => {
      expect(await deployedQuestContract.paused()).to.equal(false)
      await deployedQuestContract.connect(owner).pause()
      expect(await deployedQuestContract.paused()).to.equal(true)
    })
  })

  describe('unPause()', () => {
    it('should only allow the owner to pause', async () => {
      await expect(deployedQuestContract.connect(firstAddress).unPause()).to.be.revertedWithCustomError(
        questContract,
        'Unauthorized'
      )
    })

    it('should set unPause correctly', async () => {
      expect(await deployedQuestContract.queued()).to.equal(true)
      expect(await deployedQuestContract.paused()).to.equal(false)
      await deployedQuestContract.connect(owner).pause()
      expect(await deployedQuestContract.paused()).to.equal(true)
      await deployedQuestContract.connect(owner).unPause()
      expect(await deployedQuestContract.paused()).to.equal(false)
    })
  })


  describe('withdrawRemainingTokens()', async () => {
    it('should only allow the owner to withdrawRemainingTokens', async () => {
      await expect(deployedQuestContract.connect(firstAddress).withdrawRemainingTokens()).to.be.revertedWith(
        'Not protocol fee recipient or owner'
      )
    })

    it('should revert if trying to withdrawRemainingTokens before end date', async () => {
      await expect(deployedQuestContract.connect(owner).withdrawRemainingTokens()).to.be.revertedWithCustomError(
        questContract,
        'NoWithdrawDuringClaim'
      )
    })

    it('if zero receiptRedeemers and reedemedTokens transfer all rewards back to owner', async () => {
      expect(await deployedSampleErc20Contract.balanceOf(deployedQuestContract.address)).to.equal(totalRewardsPlusFee)
      expect(await deployedSampleErc20Contract.balanceOf(owner.address)).to.equal(0)
      await time.setNextBlockTimestamp(expiryDate + 1000)
      await deployedQuestContract.connect(owner).withdrawRemainingTokens()

      expect(await deployedSampleErc20Contract.balanceOf(deployedQuestContract.address)).to.equal(0)
      expect(await deployedSampleErc20Contract.balanceOf(owner.address)).to.equal(totalRewardsPlusFee)
    })

    it('should transfer non-claimable rewards back to owner and protocol fees to protocolFeeAddress - called from owner', async () => {
      await time.setNextBlockTimestamp(startDate + 1)
      await deployedFactoryContract.connect(firstAddress).claimRewards(questId, messageHash, signature)
      expect(await deployedSampleErc20Contract.balanceOf(protocolFeeRecipient.address)).to.equal(0)

      await time.setNextBlockTimestamp(expiryDate + 1)
      await deployedQuestContract.withdrawRemainingTokens()

      const receiptRedeemers = (await deployedQuestContract.receiptRedeemers()).toNumber()
      expect(receiptRedeemers).to.equal(1)

      const protocolFee = (await deployedQuestContract.protocolFee()).toNumber()
      expect(protocolFee).to.equal(200) // 1 * 1000 * (2000 / 10000) = 200

      expect(await deployedSampleErc20Contract.balanceOf(deployedQuestContract.address)).to.equal(0)
      expect(await deployedSampleErc20Contract.balanceOf(owner.address)).to.equal(
        totalRewardsPlusFee - receiptRedeemers * rewardAmount - protocolFee
      )

      expect(await deployedSampleErc20Contract.balanceOf(protocolFeeRecipient.address)).to.equal(protocolFee)
    })

    it('should transfer non-claimable rewards back to owner and protocol fees to protocolFeeAddress - called from protocolFeeRecipient', async () => {
      await time.setNextBlockTimestamp(startDate + 1)
      await deployedFactoryContract.connect(firstAddress).claimRewards(questId, messageHash, signature)
      expect(await deployedSampleErc20Contract.balanceOf(protocolFeeRecipient.address)).to.equal(0)

      await time.setNextBlockTimestamp(expiryDate + 1)
      await deployedQuestContract.connect(protocolFeeRecipient).withdrawRemainingTokens()

      const receiptRedeemers = (await deployedQuestContract.receiptRedeemers()).toNumber()
      expect(receiptRedeemers).to.equal(1)

      const protocolFee = (await deployedQuestContract.protocolFee()).toNumber()
      expect(protocolFee).to.equal(200) // 1 * 1000 * (2000 / 10000) = 200

      expect(await deployedSampleErc20Contract.balanceOf(deployedQuestContract.address)).to.equal(0)
      expect(await deployedSampleErc20Contract.balanceOf(owner.address)).to.equal(
        totalRewardsPlusFee - receiptRedeemers * rewardAmount - protocolFee
      )

      expect(await deployedSampleErc20Contract.balanceOf(protocolFeeRecipient.address)).to.equal(protocolFee)
    })
  })

  describe('singleClaim()', async () => {
    beforeEach(async () => {
      await deployedQuestContract.queue()
      await time.increaseTo(startDate)
    })

    it('should transfer the correct amount of rewards', async () => {
      await hre.network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [deployedFactoryContract.address],
      })
      const signer = await ethers.getSigner(deployedFactoryContract.address)
      await firstAddress.sendTransaction({ to: signer.address, value: ethers.utils.parseEther('1') })

      await deployedQuestContract.connect(signer).singleClaim(owner.address)

      expect(await deployedSampleErc20Contract.balanceOf(owner.address)).to.equal(rewardAmount)

      await hre.network.provider.request({
        method: 'hardhat_stopImpersonatingAccount',
        params: [deployedFactoryContract.address],
      })
    })

    it('should only be able to be called by the quest factory', async () => {
      expect(await deployedSampleErc20Contract.balanceOf(owner.address)).to.equal(0)
      await expect(deployedQuestContract.singleClaim(owner.address)).to.be.revertedWithCustomError(
        questContract,
        'NotQuestFactory'
      )
    })
  })

  describe('erc20Stream Quest', async () => {
    const streamQuestId = questId + 'stream'
    const maxTotalRewards = totalParticipants * rewardAmount
    const maxProtocolReward = (maxTotalRewards * 2_000) / 10_000
    const transferAmount = maxTotalRewards + maxProtocolReward
    let erc20StreamQuest: Quest
    let newErc20Contract: SampleERC20

    beforeEach(async () => {
      newErc20Contract = await sampleERC20Contract.deploy(
        'RewardToken2',
        'RTC2',
        totalRewardsPlusFee * 10,
        owner.address
      )
      await deployedFactoryContract.setRewardAllowlistAddress(newErc20Contract.address, true)
      await newErc20Contract.functions.transfer(deployedQuestContract.address, totalRewardsPlusFee)
      await newErc20Contract.approve(deployedFactoryContract.address, transferAmount)
      await deployedFactoryContract.createERC20StreamQuest(
        newErc20Contract.address,
        expiryDate,
        startDate,
        totalParticipants,
        rewardAmount,
        streamQuestId,
        '', // actionSpec
        0, // discountTokenId
        5000 // durationTotal
      )

      let questAddress = await deployedFactoryContract.quests(streamQuestId).then((res) => res.questAddress)
      erc20StreamQuest = await ethers.getContractAt('Quest', questAddress)

      await time.increaseTo(startDate)
    })

    it('should create the sablier stream', async () => {
      await hre.network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [deployedFactoryContract.address],
      })
      const signer = await ethers.getSigner(deployedFactoryContract.address)
      await firstAddress.sendTransaction({ to: signer.address, value: ethers.utils.parseEther('1') })

      await erc20StreamQuest.connect(signer).singleClaim(owner.address)
      const streamId = await erc20StreamQuest.streamIdForAddress(owner.address)

      const sablierV2LockupLinear = await ethers.getContractAt(
        'ISablierV2LockupLinear',
        '0xB10daee1FCF62243aE27776D7a92D39dC8740f95'
      )
      expect(await sablierV2LockupLinear.getDepositedAmount(streamId)).to.equal(rewardAmount)
    })
  })
})
