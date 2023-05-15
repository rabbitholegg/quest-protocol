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
      expiryDate,
      startDate,
      5, // totalParticipants
      'quest1', // questId_
      questFee, // questFee
      royaltyRecipient.address, // protocolFeeRecipient
      minterAddress.address, // minterAddress
      '', // jsonSpecCID - blank on purpose
      'NFT Name', // name
      'NFTN', // symbol
      'NFT Description', // description
      'imageipfs', // imageIPFSHash
    ])
  })

  describe('Deployment', () => {
    it('deploys and initializes the the 721 correctly', async () => {
      expect(await questNFT.symbol()).to.equal('NFTN')
      expect(await questNFT.name()).to.equal('NFT Name')
      expect(await questNFT.protocolFeeRecipient()).to.equal(royaltyRecipient.address)
    })
  })

  describe('mint', () => {
    it('mints a token with correct questId', async () => {
      const royaltyRecipientStartingBalance = await ethers.provider.getBalance(royaltyRecipient.address)
      await time.setNextBlockTimestamp(startDate + 1)
      const transferAmount = await questNFT.totalTransferAmount()

      await contractOwner.sendTransaction({
        to: questNFT.address,
        value: transferAmount.toNumber(),
      })

      await questNFT.connect(minterAddress).safeMint(firstAddress.address)

      expect(await questNFT.balanceOf(firstAddress.address)).to.eq(1)
      expect(await questNFT.ownerOf(1)).to.eq(firstAddress.address)
      expect(await ethers.provider.getBalance(royaltyRecipient.address)).to.eq(
        royaltyRecipientStartingBalance.add(questFee * 1)
      ) // only 1 token minted

      const base64encoded = await questNFT.tokenURI(1)
      const metadata = Buffer.from(base64encoded.replace('data:application/json;base64,', ''), 'base64').toString(
        'ascii'
      )

      const expectedMetadata = {
        name: 'NFT Name',
        description: 'NFT Description',
        image: 'ipfs://imageipfs',
      }

      expect(JSON.parse(metadata)).to.eql(expectedMetadata)
    })

    it('reverts if not called by minter address', async () => {
      await expect(questNFT.connect(firstAddress).safeMint(firstAddress.address)).to.be.revertedWith(
        'Only minter address'
      )
    })

    it('reverts if called before start date', async () => {
      await time.setNextBlockTimestamp(startDate - 1)
      await expect(questNFT.connect(minterAddress).safeMint(firstAddress.address)).to.be.revertedWith(
        'Quest not started'
      )
    })

    it('reverts if called after end date', async () => {
      await time.setNextBlockTimestamp(expiryDate + 1)
      await expect(questNFT.connect(minterAddress).safeMint(firstAddress.address)).to.be.revertedWith('Quest ended')
    })
  })

  describe('withdrawRemainingTokens', () => {
    it('withdraws remaining tokens', async () => {
      const contractOwnerStartingBalance = await ethers.provider.getBalance(contractOwner.address)
      await time.setNextBlockTimestamp(startDate + 1)
      await firstAddress.sendTransaction({
        to: questNFT.address,
        value: 1500,
      })
      await questNFT.connect(minterAddress).safeMint(firstAddress.address)
      await time.setNextBlockTimestamp(expiryDate + 1)

      await questNFT.connect(minterAddress).withdrawRemainingTokens()
      expect(await ethers.provider.getBalance(contractOwner.address)).to.eq(
        contractOwnerStartingBalance.add(1500 - questFee * 1)
      )
    })

    it('reverts if called before end date', async () => {
      await time.setNextBlockTimestamp(startDate + 1)
      await firstAddress.sendTransaction({
        to: questNFT.address,
        value: 1500,
      })
      await questNFT.connect(minterAddress).safeMint(firstAddress.address)
      await expect(questNFT.connect(minterAddress).withdrawRemainingTokens()).to.be.revertedWith('Quest has not ended')
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
})
