import { expect } from 'chai'
import { ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { SampleERC20, SampleErc1155, QuestFactory, RabbitHoleReceipt } from '../typechain-types/contracts'
import {
  QuestFactory__factory,
  RabbitHoleReceipt__factory,
  SampleERC20__factory,
  SampleErc1155__factory,
} from '../typechain-types'

describe('QuestFactory', () => {
  let deployedSampleErc20Contract: SampleERC20
  let deployedSampleErc1155Contract: SampleErc1155
  let deployedRabbitHoleReceiptContract: RabbitHoleReceipt
  let deployedFactoryContract: QuestFactory

  let expiryDate: number, startDate: number
  const allowList = 'ipfs://someCidToAnArrayOfAddresses'
  const totalRewards = 100 // 1000 is to much gas for tests
  const rewardAmount = 10
  let owner: SignerWithAddress
  let royaltyRecipient: SignerWithAddress

  let questFactoryContract: QuestFactory__factory
  let rabbitholeReceiptContract: RabbitHoleReceipt__factory
  let sampleERC20Contract: SampleERC20__factory
  let sampleERC1155Contract: SampleErc1155__factory

  beforeEach(async () => {
    [owner, royaltyRecipient] = await ethers.getSigners()
    expiryDate = Math.floor(Date.now() / 1000) + 10000
    startDate = Math.floor(Date.now() / 1000) + 1000

    questFactoryContract = await ethers.getContractFactory('QuestFactory')
    rabbitholeReceiptContract = await ethers.getContractFactory('RabbitHoleReceipt')
    sampleERC20Contract = await ethers.getContractFactory('SampleERC20')
    sampleERC1155Contract = await ethers.getContractFactory('SampleErc1155')

    await deploySampleErc20Contract()
    await deploySampleErc1155Conract()
    await deployFactoryContract()
    await deployRabbitHoleReceiptContract()
  })

  const deployFactoryContract = async () => {
    deployedFactoryContract = (await upgrades.deployProxy(questFactoryContract, [owner.address])) as QuestFactory
  }

  const deploySampleErc20Contract = async () => {
    deployedSampleErc20Contract = await sampleERC20Contract.deploy('RewardToken', 'RTC', 1000, owner.address)
    await deployedSampleErc20Contract.deployed()
  }

  const deploySampleErc1155Conract = async () => {
    deployedSampleErc1155Contract = await sampleERC1155Contract.deploy()
    await deployedSampleErc1155Contract.deployed()
  }

  const deployRabbitHoleReceiptContract = async () => {
    deployedRabbitHoleReceiptContract = (await upgrades.deployProxy(rabbitholeReceiptContract, [
      royaltyRecipient.address,
      deployedFactoryContract.address,
      69,
    ])) as RabbitHoleReceipt
  }

  describe('createQuest()', () => {
    const erc20QuestId = 'asdf'
    const erc1155QuestId = 'fdsa'

    it('should init with right owner', async () => {
      expect(await deployedFactoryContract.owner()).to.equal(owner.address)
    })

    it('Should create a new ERC20 quest', async () => {
      const tx = await deployedFactoryContract.createQuest(
        deployedSampleErc20Contract.address,
        expiryDate,
        startDate,
        totalRewards,
        allowList,
        rewardAmount,
        'erc20',
        erc20QuestId,
        deployedRabbitHoleReceiptContract.address
      )
      await tx.wait()
      const questAddress = await deployedFactoryContract.questAddressForQuestId(erc20QuestId)
      const deployedErc20Quest = await ethers.getContractAt('Erc20Quest', questAddress)
      expect(await deployedErc20Quest.startTime()).to.equal(startDate)
      expect(await deployedErc20Quest.owner()).to.equal(owner.address)
      expect(await deployedRabbitHoleReceiptContract.balanceOf(questAddress)).to.equal(totalRewards)
    })

    it('Should create a new ERC1155 quest', async () => {
      const tx = await deployedFactoryContract.createQuest(
        deployedSampleErc20Contract.address,
        expiryDate,
        startDate,
        totalRewards,
        allowList,
        rewardAmount,
        'erc1155',
        erc1155QuestId,
        deployedRabbitHoleReceiptContract.address
      )
      await tx.wait()
      const questAddress = await deployedFactoryContract.questAddressForQuestId(erc1155QuestId)
      const deployedErc1155Quest = await ethers.getContractAt('Erc1155Quest', questAddress)
      expect(await deployedErc1155Quest.startTime()).to.equal(startDate)
      expect(await deployedErc1155Quest.owner()).to.equal(owner.address)
      expect(await deployedRabbitHoleReceiptContract.balanceOf(questAddress)).to.equal(totalRewards)
    })

    it('Should revert if trying to use existing quest id', async () => {
      expect(
        await deployedFactoryContract.createQuest(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          allowList,
          rewardAmount,
          'erc20',
          erc20QuestId,
          deployedRabbitHoleReceiptContract.address
        )
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestIdUsed')
      expect(
        await deployedFactoryContract.createQuest(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          allowList,
          rewardAmount,
          'erc1155',
          erc1155QuestId,
          deployedRabbitHoleReceiptContract.address
        )
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestIdUsed')
    })
  })

  describe('setClaimSignerAddress()', () => {
    it('Should update claimSignerAddress', async () => {
      const newAddress = royaltyRecipient.address
      await deployedFactoryContract.setClaimSignerAddress(newAddress)
      expect(await deployedFactoryContract.claimSignerAddress()).to.equal(newAddress)
    })
  })
})
