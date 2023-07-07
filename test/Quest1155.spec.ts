import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers, upgrades } from 'hardhat'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

describe('Quest1155 Contract', async () => {
  let quest1155: Contract,
    sampleERC1155: Contract,
    contractOwner: SignerWithAddress,
    protocolFeeRecipient: SignerWithAddress,
    firstAddress: SignerWithAddress,
    expiryDate: number,
    startDate: number,
    questFee: number,
    totalParticipants: number,
    tokenId: number

  beforeEach(async () => {
    ;[contractOwner, protocolFeeRecipient, firstAddress] = await ethers.getSigners()
    const Quest1155 = await ethers.getContractFactory('Quest1155')
    const SampleERC1155 = await ethers.getContractFactory('SampleERC1155')

    const latestTime = await time.latest()
    expiryDate = latestTime + 10000
    startDate = latestTime + 10
    questFee = 100
    totalParticipants = 10
    tokenId = 1

    sampleERC1155 = await SampleERC1155.deploy()

    quest1155 = await upgrades.deployProxy(Quest1155, [
      sampleERC1155.address,
      expiryDate,
      startDate,
      totalParticipants,
      tokenId,
      questFee,
      protocolFeeRecipient.address,
    ])
  })

  describe('Deployment', () => {
    it('deploys and Quest1155 correctly', async () => {
      expect(await quest1155.owner()).to.equal(contractOwner.address)
      expect(await quest1155.tokenId()).to.equal(1)
      expect(await quest1155.totalParticipants()).to.equal(10)
      expect(await quest1155.rewardToken()).to.equal(sampleERC1155.address)
      expect(await quest1155.questFee()).to.equal(100)
    })
  })

  describe('queue', () => {
    it('should revert if no tokens are in the contract', async () => {
      await expect(quest1155.queue()).to.be.revertedWithCustomError(quest1155, 'InsufficientTokenBalance')
    })

    it('should revert if not enough ETH is in the contract', async () => {
      sampleERC1155.batchMint(firstAddress.address, [1], [10])
      await sampleERC1155.connect(firstAddress).safeTransferFrom(firstAddress.address, quest1155.address, 1, 10, [])

      await expect(quest1155.queue()).to.be.revertedWithCustomError(quest1155, 'InsufficientETHBalance')
    })

    it('should queue if enough tokens and ETH are in the contract', async () => {
      sampleERC1155.batchMint(firstAddress.address, [1], [10])
      await sampleERC1155.connect(firstAddress).safeTransferFrom(firstAddress.address, quest1155.address, 1, 10, [])
      await contractOwner.sendTransaction({ to: quest1155.address, value: 1000 })
      await quest1155.queue()

      expect(await quest1155.queued()).to.eq(true)
    })
  })

  describe('singleClaim', () => {
    // whenNotEnded
    it('should revert if the contract has ended', async () => {
      await time.increaseTo(expiryDate + 1)
      await expect(quest1155.singleClaim(firstAddress.address)).to.be.revertedWithCustomError(quest1155, 'QuestEnded')
    })

    //onlyStarted
    it('should revert if the contract has not started', async () => {
      await time.setNextBlockTimestamp(startDate - 1)
      await expect(quest1155.singleClaim(firstAddress.address)).to.be.revertedWithCustomError(quest1155, 'NotStarted')
    })

    //onlyQueued
    it('should revert if the contract has not been queued', async () => {
      await time.increaseTo(startDate)
      await expect(quest1155.singleClaim(firstAddress.address)).to.be.revertedWithCustomError(quest1155, 'NotQueued')
    })

    //onlyQuestFactory
    it('should revert if the caller is not the QuestFactory', async () => {
      await time.increaseTo(startDate)
      sampleERC1155.batchMint(firstAddress.address, [1], [10])
      await sampleERC1155.connect(firstAddress).safeTransferFrom(firstAddress.address, quest1155.address, 1, 10, [])
      await contractOwner.sendTransaction({ to: quest1155.address, value: 1000 })
      await quest1155.queue()
      await expect(quest1155.connect(firstAddress).singleClaim(firstAddress.address)).to.be.revertedWithCustomError(
        quest1155,
        'NotQuestFactory'
      )
    })

    it('should transfer rewards to the account and protocol fee to protocol fee receipient', async () => {
      await time.increaseTo(startDate)
      sampleERC1155.batchMint(firstAddress.address, [1], [10])
      await sampleERC1155.connect(firstAddress).safeTransferFrom(firstAddress.address, quest1155.address, 1, 10, [])
      await contractOwner.sendTransaction({ to: quest1155.address, value: 1000 })
      await quest1155.queue()
      const protocolFeeRecipientOGBalance = await protocolFeeRecipient.getBalance()
      await quest1155.singleClaim(firstAddress.address)

      expect(await protocolFeeRecipient.getBalance()).to.eq(
        ethers.BigNumber.from(questFee).add(protocolFeeRecipientOGBalance)
      )
      expect(await sampleERC1155.balanceOf(firstAddress.address, 1)).to.eq(1)
    })
  })

  describe('maxProtocolReward', () => {
    it('should return the correct amount', async () => {
      expect(await quest1155.maxProtocolReward()).to.eq(1000) // totalParticipants * questFee
    })
  })

  describe('withdrawRemainingTokens', () => {
    it('should revert if the contract is still queued', async () => {
      await expect(quest1155.withdrawRemainingTokens()).to.be.revertedWithCustomError(quest1155, 'NotQueued')
    })

    it('should revert if the contract has not ended', async () => {
      sampleERC1155.batchMint(firstAddress.address, [1], [10])
      await sampleERC1155.connect(firstAddress).safeTransferFrom(firstAddress.address, quest1155.address, 1, 10, [])
      await contractOwner.sendTransaction({ to: quest1155.address, value: 1000 })
      await quest1155.queue()

      await expect(quest1155.withdrawRemainingTokens()).to.be.revertedWithCustomError(quest1155, 'NotEnded')
    })

    it('should send all ETH and 1155 tokens in the contract to the contrnact owner', async () => {
      sampleERC1155.batchMint(firstAddress.address, [1], [10])
      await sampleERC1155.connect(firstAddress).safeTransferFrom(firstAddress.address, quest1155.address, 1, 10, [])
      await firstAddress.sendTransaction({ to: quest1155.address, value: 1000 })
      await quest1155.queue()
      const contractOwnerOGBalance = await contractOwner.getBalance()
      await time.increaseTo(expiryDate + 1)
      await quest1155.connect(firstAddress).withdrawRemainingTokens()

      expect(await contractOwner.getBalance()).to.eq(ethers.BigNumber.from(1000).add(contractOwnerOGBalance))
      expect(await sampleERC1155.balanceOf(contractOwner.address, 1)).to.eq(10)
    })
  })
})
