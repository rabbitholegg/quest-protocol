import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers, upgrades } from 'hardhat'
import { time } from '@nomicfoundation/hardhat-network-helpers'

describe('QuestNFT Contract', async () => {
  let questNFT: Contract,
    contractOwner: { address: String },
    royaltyRecipient: { address: String },
    minterAddress: { address: String },
    firstAddress: { address: String },
    expiryDate: number,
    startDate: number,
    questFee: number

  beforeEach(async () => {
    ;[contractOwner, royaltyRecipient, minterAddress, firstAddress] = await ethers.getSigners()
    const QuestNFT = await ethers.getContractFactory('QuestNFT')

    const latestTime = await time.latest()
    expiryDate = latestTime + 10000
    startDate = latestTime + 10

    questFee = 100

    questNFT = await upgrades.deployProxy(QuestNFT, [
      royaltyRecipient.address, // protocolFeeRecipient
      minterAddress.address,
      'CollectionName',
    ])
  })

  describe('Deployment', () => {
    it('deploys and initializes the the 1155 correctly', async () => {
      expect(await questNFT.owner()).to.equal(contractOwner.address)
      expect(await questNFT.collectionName()).to.equal('CollectionName')
      expect(await questNFT.minterAddress()).to.equal(minterAddress.address)
      expect(await questNFT.protocolFeeRecipient()).to.equal(royaltyRecipient.address)
    })
  })

  describe('addQuest', () => {
    it('adds a quest', async () => {
      await questNFT
        .connect(minterAddress)
        .addQuest(questFee, startDate, expiryDate, 10, 'questID', 'Quest Description', 'imageipfscid')

      expect(await questNFT.quests('questID')).to.eql([
        ethers.BigNumber.from(startDate),
        ethers.BigNumber.from(expiryDate),
        ethers.BigNumber.from(10),
        ethers.BigNumber.from(questFee),
        ethers.BigNumber.from(1),
        'Quest Description',
        'imageipfscid',
      ])
    })

    it('does not add a quest when not calling from minterAddress', async () => {
      await expect(
        questNFT.addQuest(questFee, startDate, expiryDate, 10, 'questID', 'Quest Description', 'ipfs://imageipfs')
      ).to.be.revertedWith('Only minter address')
    })

    it('does not add a quest when start time and end time are out of sync', async () => {
      await expect(
        questNFT
          .connect(minterAddress)
          .addQuest(questFee, expiryDate, startDate, 10, 'questID', 'Quest Description', 'ipfs://imageipfs')
      ).to.be.revertedWith('startTime_ before endTime_')
    })

    it('does not add a quest start time is in the past', async () => {
      await expect(
        questNFT
          .connect(minterAddress)
          .addQuest(questFee, 1, expiryDate, 10, 'questID', 'Quest Description', 'ipfs://imageipfs')
      ).to.be.revertedWith('startTime_ in the past')
    })

    it('does not add a quest end time is in the past', async () => {
      await expect(
        questNFT
          .connect(minterAddress)
          .addQuest(questFee, startDate, 1, 10, 'questID', 'Quest Description', 'ipfs://imageipfs')
      ).to.be.revertedWith('endTime_ in the past')
    })
  })

  describe('mint', () => {
    beforeEach(async () => {
      await questNFT
        .connect(minterAddress)
        .addQuest(questFee, startDate, expiryDate, 10, 'questID', 'Quest Description', 'imageipfscid')
    })

    it('mints a token with correct questId', async () => {
      const royaltyRecipientStartingBalance = await ethers.provider.getBalance(royaltyRecipient.address)
      await time.setNextBlockTimestamp(startDate + 1)
      const transferAmount = await questNFT.totalTransferAmount('questID')
      const tokenId = await questNFT.tokenIdFromQuestId('questID')

      await contractOwner.sendTransaction({
        to: questNFT.address,
        value: transferAmount.toNumber(),
      })

      await questNFT.connect(minterAddress).mint(firstAddress.address, 'questID')

      expect(await questNFT.balanceOf(firstAddress.address, tokenId)).to.eq(1)
      expect(await ethers.provider.getBalance(royaltyRecipient.address)).to.eq(
        royaltyRecipientStartingBalance.add(questFee * 1)
      ) // only 1 token minted

      const base64encoded = await questNFT.uri(tokenId)
      const metadata = Buffer.from(base64encoded.replace('data:application/json;base64,', ''), 'base64').toString(
        'ascii'
      )

      const expectedMetadata = {
        description: 'Quest Description',
        image: 'ipfs://imageipfscid',
        name: 'CollectionName',
      }

      expect(JSON.parse(metadata)).to.eql(expectedMetadata)
    })

    it('reverts if not called by minter address', async () => {
      await expect(questNFT.connect(firstAddress).mint(firstAddress.address, 'questID')).to.be.revertedWith(
        'Only minter address'
      )
    })

    it('reverts if called before start date', async () => {
      await time.setNextBlockTimestamp(startDate - 1)
      await expect(questNFT.connect(minterAddress).mint(firstAddress.address, 'questID')).to.be.revertedWith(
        'Quest not started'
      )
    })

    it('reverts if called after end date', async () => {
      await time.setNextBlockTimestamp(expiryDate + 1)
      await expect(questNFT.connect(minterAddress).mint(firstAddress.address, 'questID')).to.be.revertedWith(
        'Quest ended'
      )
    })
  })

  describe('withdrawRemainingCoins', () => {
    beforeEach(async () => {
      await questNFT
        .connect(minterAddress)
        .addQuest(questFee, startDate, expiryDate, 10, 'questID', 'Quest Description', 'imageipfscid')

      await time.setNextBlockTimestamp(startDate + 1)
    })

    it('withdraws remaining tokens', async () => {
      const contractOwnerStartingBalance = await ethers.provider.getBalance(contractOwner.address)
      await firstAddress.sendTransaction({
        to: questNFT.address,
        value: 1500,
      })
      await questNFT.connect(minterAddress).mint(firstAddress.address, 'questID')
      await time.setNextBlockTimestamp(expiryDate + 1)

      await questNFT.connect(minterAddress).withdrawRemainingCoins()
      expect(await ethers.provider.getBalance(contractOwner.address)).to.eq(
        contractOwnerStartingBalance.add(1500 - questFee * 1)
      )
    })

    it('reverts if called before end date', async () => {
      await expect(questNFT.withdrawRemainingCoins()).to.be.revertedWith('Not all Quests have ended')
    })
  })

  describe('refund', () => {
    it('refunds to the owner the remaining balance', async () => {
      const sampleERC20Contract = await ethers.getContractFactory('SampleERC20')
      const deployedSampleErc20Contract = await sampleERC20Contract.deploy(
        'RewardToken',
        'RTC',
        100,
        minterAddress.address
      )
      await deployedSampleErc20Contract.deployed()
      await deployedSampleErc20Contract.connect(minterAddress).transfer(questNFT.address, 100)
      await questNFT.refund(deployedSampleErc20Contract.address)

      expect(await deployedSampleErc20Contract.balanceOf(contractOwner.address)).to.eq(100)
    })
  })

  describe('royaltyInfo', () => {
    beforeEach(async () => {
      await questNFT
        .connect(minterAddress)
        .addQuest(questFee, startDate, expiryDate, 10, 'questID', 'Quest Description', 'imageipfscid')

      await time.setNextBlockTimestamp(startDate + 1)
      const transferAmount = await questNFT.totalTransferAmount('questID')

      await contractOwner.sendTransaction({
        to: questNFT.address,
        value: transferAmount.toNumber(),
      })
      await questNFT.connect(minterAddress).mint(firstAddress.address, 'questID')
    })

    it('returns the royalty recipient and fee', async () => {
      const royaltyInfo = await questNFT.royaltyInfo(1, 1000)
      expect(royaltyInfo[0]).to.eq(contractOwner.address)
      expect(royaltyInfo[1]).to.eq(1000 * 0.02)
    })
  })
})
