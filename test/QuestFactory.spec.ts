import { expect } from 'chai'
import { ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import {
  Quest,
  SampleERC20,
  SampleERC1155,
  QuestFactory,
  Quest__factory,
  QuestFactory__factory,
  SampleERC20__factory,
  SampleERC1155__factory,
} from '../typechain-types'
import { Wallet, utils, constants } from 'ethers'

describe('QuestFactory', () => {
  let deployedSampleErc20Contract: SampleERC20
  let deployedSampleErc1155Contract: SampleERC1155
  let deployedFactoryContract: QuestFactory
  let deployedErc20Quest: Quest
  let deployedErc1155Quest: Quest
  let expiryDate: number, startDate: number
  const sablierV2LockupLinearAddress = '0xB10daee1FCF62243aE27776D7a92D39dC8740f95'
  const totalRewards = 1000
  const rewardAmount = 10
  const mnemonic = 'announce room limb pattern dry unit scale effort smooth jazz weasel alcohol'
  const nftQuestFee = 100
  const referralFee = 5000 // 50%
  const maxTotalRewards = totalRewards * rewardAmount
  const maxProtocolReward = (maxTotalRewards * 2_000) / 10_000
  const transferAmount = maxTotalRewards + maxProtocolReward
  let owner: SignerWithAddress
  let royaltyRecipient: SignerWithAddress
  let protocolRecipient: SignerWithAddress
  let mintFeeRecipient: SignerWithAddress
  let questUser: SignerWithAddress
  let affiliate: SignerWithAddress

  let questFactoryContract: QuestFactory__factory
  let erc20QuestContract: Quest__factory
  let erc1155QuestContract: Quest__factory
  let sampleERC20Contract: SampleERC20__factory
  let sampleERC1155Contract: SampleERC1155__factory
  let wallet: Wallet

  beforeEach(async () => {
    ;[owner, royaltyRecipient, protocolRecipient, mintFeeRecipient, questUser, affiliate] = await ethers.getSigners()
    const latestTime = await time.latest()
    expiryDate = latestTime + 1000
    startDate = latestTime + 100

    wallet = Wallet.fromMnemonic(mnemonic)

    questFactoryContract = await ethers.getContractFactory('QuestFactory')
    erc20QuestContract = await ethers.getContractFactory('Quest')
    erc1155QuestContract = await ethers.getContractFactory('Quest1155')
    sampleERC20Contract = await ethers.getContractFactory('SampleERC20')
    sampleERC1155Contract = await ethers.getContractFactory('SampleERC1155')

    await deploySampleErc20Contract()
    await deploySampleErc1155Contract()
    await deployFactoryContract()
  })


  const deployFactoryContract = async () => {
    deployedErc20Quest = await erc20QuestContract.deploy()
    await deployedErc20Quest.deployed()
    deployedErc1155Quest = await erc1155QuestContract.deploy()
    await deployedErc1155Quest.deployed()

    deployedFactoryContract = (await upgrades.deployProxy(questFactoryContract, [
      wallet.address,
      protocolRecipient.address,
      deployedErc20Quest.address,
      deployedErc1155Quest.address,
      owner.address,
      ethers.constants.AddressZero, // questTerminalKey is deprecated
      sablierV2LockupLinearAddress,
      nftQuestFee,
      referralFee,
    ])) as QuestFactory

  }

  const deploySampleErc20Contract = async () => {
    deployedSampleErc20Contract = await sampleERC20Contract.deploy('RewardToken', 'RTC', '1000000000', owner.address)
    await deployedSampleErc20Contract.deployed()
  }

  const deploySampleErc1155Contract = async () => {
    deployedSampleErc1155Contract = await sampleERC1155Contract.deploy()
    await deployedSampleErc1155Contract.deployed()
  }

  describe('createQuestAndQueue()', () => {
    const erc20QuestId = 'asdf'

    it('should init with right owner', async () => {
      expect(await deployedFactoryContract.owner()).to.equal(owner.address)
    })

    it('Should revert if reward address is not on the reward allowlist', async () => {
      const rewardAddress = deployedSampleErc20Contract.address
      expect(await deployedFactoryContract.rewardAllowlist(rewardAddress)).to.equal(false)
      await deployedSampleErc20Contract.approve(deployedFactoryContract.address, transferAmount)

      await expect(
        deployedFactoryContract.createQuestAndQueue(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          rewardAmount,
          erc20QuestId,
          '', // actionSpec
          0   // discountTokenId - deprecated
        )
      ).to.be.revertedWithCustomError(questFactoryContract, 'RewardNotAllowed')
    })

    it('should create a new quest and start it', async () => {
      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
      // approve the quest factory to spend the reward token
      await deployedSampleErc20Contract.approve(deployedFactoryContract.address, transferAmount)

      await expect(
        deployedFactoryContract.createQuestAndQueue(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          rewardAmount,
          erc20QuestId,
          '',
          0
        )
      ).to.emit(deployedFactoryContract, 'QuestCreated')

      const questAddress = await deployedFactoryContract.quests(erc20QuestId).then((res) => res.questAddress)
      const deployedErc20Quest = await ethers.getContractAt('Quest', questAddress)
      expect(await deployedErc20Quest.startTime()).to.equal(startDate)
      expect(await deployedErc20Quest.owner()).to.equal(owner.address)

      expect(await deployedErc20Quest.queued()).to.equal(true)
      expect(await deployedSampleErc20Contract.balanceOf(questAddress)).to.equal(transferAmount)
    })

    it('Should revert if reward address is removed from allowlist', async () => {
      const rewardAddress = deployedSampleErc20Contract.address

      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, false)

      expect(await deployedFactoryContract.rewardAllowlist(rewardAddress)).to.equal(false)
      await deployedSampleErc20Contract.approve(deployedFactoryContract.address, transferAmount)

      await expect(
        deployedFactoryContract.createQuestAndQueue(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          rewardAmount,
          erc20QuestId,
          '', // actionSpec
          0   // discountTokenId - deprecated
        )
      ).to.be.revertedWithCustomError(questFactoryContract, 'RewardNotAllowed')
    })

    it('Should revert if trying to use existing quest id', async () => {
      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
      await deployedSampleErc20Contract.approve(deployedFactoryContract.address, transferAmount)

      await deployedFactoryContract.createQuestAndQueue(
        deployedSampleErc20Contract.address,
        expiryDate,
        startDate,
        totalRewards,
        rewardAmount,
        erc20QuestId,
        '', // actionSpec
        0   // discountTokenId - deprecated
      )

      await expect(
        deployedFactoryContract.createQuestAndQueue(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          rewardAmount,
          erc20QuestId,
          '', // actionSpec
          0   // discountTokenId - deprecated
        )
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestIdUsed')
    })

    it('Should allow anyone to create a quest', async () => {
      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
      await deployedSampleErc20Contract.transfer(royaltyRecipient.address, transferAmount)
      await deployedSampleErc20Contract.connect(royaltyRecipient).approve(deployedFactoryContract.address, transferAmount)

      const tx = await deployedFactoryContract
        .connect(royaltyRecipient)
        .createQuestAndQueue(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          rewardAmount,
          erc20QuestId,
          '', // actionSpec
          0   // discountTokenId - deprecated
        )
      await tx.wait()
      const questAddress = await deployedFactoryContract.quests(erc20QuestId).then((res) => res.questAddress)
      const deployedErc20Quest = await ethers.getContractAt('Quest', questAddress)
      expect(await deployedErc20Quest.startTime()).to.equal(startDate)
      expect(await deployedErc20Quest.owner()).to.equal(royaltyRecipient.address)
    })


    it('createQuestAndQueue should create a new quest and start it with an actionSpec', async () => {
      const maxTotalRewards = totalRewards * rewardAmount
      const maxProtocolReward = (maxTotalRewards * 2_000) / 10_000
      const transferAmount = maxTotalRewards + maxProtocolReward

      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
      await deployedSampleErc20Contract.approve(deployedFactoryContract.address, transferAmount)

      await expect(
        deployedFactoryContract.createQuestAndQueue(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          rewardAmount,
          erc20QuestId,
          'actionSpecJSON',
          0
        )
      ).to.emit(deployedFactoryContract, 'QuestCreatedWithAction')

      const questAddress = await deployedFactoryContract.quests(erc20QuestId).then((res) => res.questAddress)
      const deployedErc20Quest = await ethers.getContractAt('Quest', questAddress)
      expect(await deployedErc20Quest.startTime()).to.equal(startDate)
      expect(await deployedErc20Quest.owner()).to.equal(owner.address)

      expect(await deployedErc20Quest.queued()).to.equal(true)
      expect(await deployedSampleErc20Contract.balanceOf(questAddress)).to.equal(transferAmount)
    })

  })

  describe('createERC20StreamQuest()', () => {
    const erc20QuestId = 'erc20StreamQuestId'

    beforeEach(async () => {
      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
      await deployedSampleErc20Contract.approve(deployedFactoryContract.address, transferAmount)
    })

    it('createERC20StreamQuest should create a new quest and start it', async () => {
      await deployedFactoryContract.createERC20StreamQuest(
        deployedSampleErc20Contract.address,
        expiryDate,
        startDate,
        totalRewards,
        rewardAmount,
        erc20QuestId,
        'actionSpec',
        1000
      )
      const questAddress = await deployedFactoryContract.quests(erc20QuestId).then((res) => res.questAddress)
      const erc20StreamQuest = await ethers.getContractAt('Quest', questAddress)
      expect(await erc20StreamQuest.startTime()).to.equal(startDate)
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

  describe('questData()', () => {
    const erc20QuestId = 'abc123'
    const erc1155QuestId = '803e60d8-7c16-4ce5-8063-f9e284644bcd'

    it('Should return the correct quest data for erc20 quest', async () => {
      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
      await deployedSampleErc20Contract.approve(deployedFactoryContract.address, transferAmount)

      await deployedFactoryContract.createQuestAndQueue(
        deployedSampleErc20Contract.address,
        expiryDate,
        startDate,
        totalRewards,
        rewardAmount,
        erc20QuestId,
        '', // actionSpec
        0   // discountTokenId - deprecated
      )
      const questAddress = await deployedFactoryContract.quests(erc20QuestId).then((res) => res.questAddress)
      const questData = await deployedFactoryContract.questData(erc20QuestId)
      expect(questData).to.eql([
        questAddress,
        deployedSampleErc20Contract.address,
        true, // Queued now defaults to true
        2000, // questFee
        ethers.BigNumber.from(startDate),
        ethers.BigNumber.from(expiryDate),
        ethers.BigNumber.from(totalRewards),
        ethers.BigNumber.from(0),
        ethers.BigNumber.from(0),
        ethers.BigNumber.from(rewardAmount),
        false,
      ])
    })

    it('Should return the correct quest data for erc1155 quest', async () => {
      const NFTTokenId = 99
      const maxParticipants = 10
      const messageHash = utils.solidityKeccak256(
        ['address', 'string'],
        [questUser.address.toLowerCase(), erc1155QuestId]
      )
      const signature = await wallet.signMessage(utils.arrayify(messageHash))
      deployedSampleErc1155Contract.batchMint(owner.address, [NFTTokenId], [maxParticipants])
      deployedSampleErc1155Contract.setApprovalForAll(deployedFactoryContract.address, true)

      await deployedFactoryContract.create1155QuestAndQueue(
        deployedSampleErc1155Contract.address,
        expiryDate,
        startDate,
        maxParticipants,
        NFTTokenId,
        erc1155QuestId,
        '',
        { value: nftQuestFee * maxParticipants }
      )
      await time.setNextBlockTimestamp(startDate)
      await deployedFactoryContract.connect(questUser).claim1155Rewards(erc1155QuestId, messageHash, signature)

      const questAddress = await deployedFactoryContract.quests(erc1155QuestId).then((res) => res.questAddress)
      const questData = await deployedFactoryContract.questData(erc1155QuestId)
      expect(questData).to.eql([
        questAddress,
        deployedSampleErc1155Contract.address,
        true,
        0, //always zero for erc1155
        ethers.BigNumber.from(startDate),
        ethers.BigNumber.from(expiryDate),
        ethers.BigNumber.from(maxParticipants),
        ethers.BigNumber.from(1),
        ethers.BigNumber.from(1),
        ethers.BigNumber.from(NFTTokenId),
        false,
      ])
    })
  })

  describe('claimRewards()', () => {
    const erc20QuestId = 'rewardQuestId'
    let messageHash: string
    let signature: string
    let questAddress: string
    let erc20Quest: Quest

    beforeEach(async () => {
      messageHash = utils.solidityKeccak256(['address', 'string'], [questUser.address.toLowerCase(), erc20QuestId])
      signature = await wallet.signMessage(utils.arrayify(messageHash))
      await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
      await deployedSampleErc20Contract.approve(deployedFactoryContract.address, transferAmount)

      await deployedFactoryContract.createQuestAndQueue(
        deployedSampleErc20Contract.address,
        expiryDate,
        startDate,
        totalRewards,
        rewardAmount,
        erc20QuestId,
        'jsonSpecCid',
        0
      )
      questAddress = await deployedFactoryContract.quests(erc20QuestId).then((res) => res.questAddress)
      erc20Quest = await ethers.getContractAt('Quest', questAddress)
    })

    it('Should fail when trying to claim before quest time has started', async () => {
      await time.setNextBlockTimestamp(startDate - 1)
      await expect(
        deployedFactoryContract.connect(questUser).claimRewards(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestNotStarted')
    })

    it('Should claim rewards', async () => {
      await time.setNextBlockTimestamp(startDate)
      await deployedFactoryContract.connect(questUser).claimRewards(erc20QuestId, messageHash, signature)
      expect(await deployedSampleErc20Contract.balanceOf(questUser.address)).to.equal(rewardAmount)
    })

    it('Should fail if user tries to use a hash + signature that is not tied to them', async () => {
      await time.setNextBlockTimestamp(startDate)
      await expect(
        deployedFactoryContract.connect(royaltyRecipient).claimRewards(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'InvalidHash')
    })

    it('Should fail if user is able to call claimRewards multiple times', async () => {
      await time.setNextBlockTimestamp(startDate)
      await deployedFactoryContract.connect(questUser).claimRewards(erc20QuestId, messageHash, signature)
      expect(await deployedSampleErc20Contract.balanceOf(questUser.address)).to.equal(rewardAmount)

      await expect(
        deployedFactoryContract.connect(questUser).claimRewards(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'AddressAlreadyMinted')
      expect(await deployedSampleErc20Contract.balanceOf(questUser.address)).to.equal(rewardAmount)
    })

    it('Should fail when trying to claim after quest time has passed', async () => {
      await time.setNextBlockTimestamp(expiryDate + 1)
      await expect(
        deployedFactoryContract.connect(questUser).claimRewards(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestEnded')
    })

    it('should revert if the mint fee is insufficient', async function () {
      const requiredFee = 1000
      await deployedFactoryContract.setMintFee(requiredFee)
      await time.setNextBlockTimestamp(startDate)

      await expect(
        deployedFactoryContract.connect(questUser).claimRewards(erc20QuestId, messageHash, signature, {
          value: requiredFee - 1,
        })
      ).to.be.revertedWithCustomError(questFactoryContract, 'InvalidMintFee')
    })

    it('should succeed if the mint fee is equal or greator than required amount, and only recieve the required amount', async function () {
      const requiredFee = 1000
      const extraChange = 100
      await deployedFactoryContract.setMintFee(requiredFee)
      await time.setNextBlockTimestamp(startDate)
      const balanceBefore = await ethers.provider.getBalance(deployedFactoryContract.getMintFeeRecipient())

      await expect(
        deployedFactoryContract.connect(questUser).claimRewards(erc20QuestId, messageHash, signature, {
          value: requiredFee + extraChange,
        })
      )
        .to.emit(deployedFactoryContract, 'QuestClaimed')
        .to.emit(deployedFactoryContract, 'ExtraMintFeeReturned')
        .withArgs(questUser.address, extraChange)
      expect(await ethers.provider.getBalance(deployedFactoryContract.getMintFeeRecipient())).to.equal(
        balanceBefore.add(requiredFee)
      )
    })

    it('should transfer referral fee percentage of mintFee to referral on erc20 quest', async function () {
      messageHash = utils.solidityKeccak256(
        ['address', 'string', 'address'],
        [questUser.address.toLowerCase(), erc20QuestId, affiliate.address]
      )
      signature = await wallet.signMessage(utils.arrayify(messageHash))
      const requiredFee = 1000
      const extraChange = 100
      const referralAmount = (requiredFee * referralFee) / 10_000
      await deployedFactoryContract.setMintFee(requiredFee)
      await time.setNextBlockTimestamp(startDate)
      const mintFeeRecipientBalanceBefore = await ethers.provider.getBalance(
        deployedFactoryContract.getMintFeeRecipient()
      )
      const affiliateBalanceBefore = await ethers.provider.getBalance(affiliate.address)

      await expect(
        deployedFactoryContract.connect(questUser).claim(erc20QuestId, messageHash, signature, affiliate.address, {
          value: requiredFee + extraChange,
        })
      )
        .to.emit(deployedFactoryContract, 'QuestClaimed')
        .to.emit(deployedFactoryContract, 'QuestClaimedReferred')
        .to.emit(deployedFactoryContract, 'ExtraMintFeeReturned')
        .withArgs(questUser.address, extraChange)
      expect(await ethers.provider.getBalance(deployedFactoryContract.getMintFeeRecipient())).to.equal(
        mintFeeRecipientBalanceBefore.add(requiredFee - referralAmount)
      )
      expect(await ethers.provider.getBalance(affiliate.address)).to.equal(affiliateBalanceBefore.add(referralAmount))
    })
  })

  describe('claim1155Rewards()', () => {
    it('Should claim rewards from a 1155 Quest', async () => {
      const NFTTokenId = 99
      const maxParticipants = 10
      const erc1155QuestId = 'erc1155Id'
      const messageHash = utils.solidityKeccak256(
        ['address', 'string'],
        [questUser.address.toLowerCase(), erc1155QuestId]
      )
      const signature = await wallet.signMessage(utils.arrayify(messageHash))
      deployedSampleErc1155Contract.batchMint(owner.address, [NFTTokenId], [maxParticipants])
      deployedSampleErc1155Contract.setApprovalForAll(deployedFactoryContract.address, true)

      await deployedFactoryContract.create1155QuestAndQueue(
        deployedSampleErc1155Contract.address,
        expiryDate,
        startDate,
        maxParticipants,
        NFTTokenId,
        erc1155QuestId,
        '',
        { value: nftQuestFee * maxParticipants }
      )
      await time.setNextBlockTimestamp(startDate)

      await deployedFactoryContract.connect(questUser).claim1155Rewards(erc1155QuestId, messageHash, signature)

      expect(await deployedSampleErc1155Contract.balanceOf(questUser.address, NFTTokenId)).to.equal(1)
    })

    it('should claim rewards from a 1155 Quest with a referral', async () => {
      it('Should claim rewards from a 1155 Quest', async () => {
        const NFTTokenId = 99
        const maxParticipants = 10
        const erc1155QuestId = 'erc1155Id'
        const requiredFee = 1000
        const referralAmount = (requiredFee * referralFee) / 10_000
        await deployedFactoryContract.setMintFee(requiredFee)
        const messageHash = utils.solidityKeccak256(
          ['address', 'string'],
          [questUser.address.toLowerCase(), erc1155QuestId]
        )
        const signature = await wallet.signMessage(utils.arrayify(messageHash))
        deployedSampleErc1155Contract.batchMint(owner.address, [NFTTokenId], [maxParticipants])
        deployedSampleErc1155Contract.setApprovalForAll(deployedFactoryContract.address, true)

        await deployedFactoryContract.create1155QuestAndQueue(
          deployedSampleErc1155Contract.address,
          expiryDate,
          startDate,
          maxParticipants,
          NFTTokenId,
          erc1155QuestId,
          '',
          { value: nftQuestFee * maxParticipants }
        )
        await time.setNextBlockTimestamp(startDate)
        const mintFeeRecipientBalanceBefore = await ethers.provider.getBalance(
          deployedFactoryContract.getMintFeeRecipient()
        )
        const affiliateBalanceBefore = await ethers.provider.getBalance(affiliate.address)

        await expect(
          deployedFactoryContract.connect(questUser).claim(erc1155QuestId, messageHash, signature, affiliate.address, {
            value: requiredFee,
          })
        )
          .to.emit(deployedFactoryContract, 'Quest1155Claimed')
          .to.emit(deployedFactoryContract, 'QuestClaimedReferred')

        expect(await ethers.provider.getBalance(deployedFactoryContract.getMintFeeRecipient())).to.equal(
          mintFeeRecipientBalanceBefore.add(requiredFee - referralAmount)
        )
        expect(await ethers.provider.getBalance(affiliate.address)).to.equal(affiliateBalanceBefore.add(referralAmount))

        expect(await deployedSampleErc1155Contract.balanceOf(questUser.address, NFTTokenId)).to.equal(1)
      })
    })

    it('Should claim rewards from a 1155 Quest with zero nftQuestFee', async () => {
      const NFTTokenId = 99
      const maxParticipants = 10
      const erc1155QuestId = 'erc1155Id'
      const messageHash = utils.solidityKeccak256(
        ['address', 'string'],
        [questUser.address.toLowerCase(), erc1155QuestId]
      )
      const signature = await wallet.signMessage(utils.arrayify(messageHash))
      deployedSampleErc1155Contract.batchMint(owner.address, [NFTTokenId], [maxParticipants])
      deployedSampleErc1155Contract.setApprovalForAll(deployedFactoryContract.address, true)

      await deployedFactoryContract.setNftQuestFeeList([owner.address], [0])

      await deployedFactoryContract.create1155QuestAndQueue(
        deployedSampleErc1155Contract.address,
        expiryDate,
        startDate,
        maxParticipants,
        NFTTokenId,
        erc1155QuestId,
        ''
      )
      await time.setNextBlockTimestamp(startDate)

      await deployedFactoryContract.connect(questUser).claim1155Rewards(erc1155QuestId, messageHash, signature)

      expect(await deployedSampleErc1155Contract.balanceOf(questUser.address, NFTTokenId)).to.equal(1)
    })
  })
})
