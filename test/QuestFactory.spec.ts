import { expect } from 'chai'
import { ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import {
  SampleERC20,
  SampleErc1155,
  QuestFactory,
  RabbitHoleReceipt,
  QuestFactory__factory,
  RabbitHoleReceipt__factory,
  SampleERC20__factory,
  SampleErc1155__factory,
} from '../typechain-types'
import { Wallet, utils, constants } from 'ethers'

describe('QuestFactory', () => {
  let deployedSampleErc20Contract: SampleERC20
  let deployedSampleErc1155Contract: SampleErc1155
  let deployedRabbitHoleReceiptContract: RabbitHoleReceipt
  let deployedFactoryContract: QuestFactory
  const protocolFeeAddress = '0xE8B17e572c1Eea45fCE267F30aE38862CF03BC84'
  let expiryDate: number, startDate: number
  const totalRewards = 1000
  const rewardAmount = 10
  const mnemonic = 'announce room limb pattern dry unit scale effort smooth jazz weasel alcohol'
  let owner: SignerWithAddress
  let royaltyRecipient: SignerWithAddress

  let questFactoryContract: QuestFactory__factory
  let rabbitholeReceiptContract: RabbitHoleReceipt__factory
  let sampleERC20Contract: SampleERC20__factory
  let sampleERC1155Contract: SampleErc1155__factory
  let wallet: Wallet

  beforeEach(async () => {
    ;[owner, royaltyRecipient] = await ethers.getSigners()
    expiryDate = Math.floor(Date.now() / 1000) + 10000
    startDate = Math.floor(Date.now() / 1000) + 1000

    wallet = Wallet.fromMnemonic(mnemonic)

    questFactoryContract = await ethers.getContractFactory('QuestFactory')
    rabbitholeReceiptContract = await ethers.getContractFactory('RabbitHoleReceipt')
    sampleERC20Contract = await ethers.getContractFactory('SampleERC20')
    sampleERC1155Contract = await ethers.getContractFactory('SampleErc1155')

    await deploySampleErc20Contract()
    await deploySampleErc1155Conract()
    await deployRabbitHoleReceiptContract()
    await deployFactoryContract()
  })

  const deployFactoryContract = async () => {
    deployedFactoryContract = (await upgrades.deployProxy(questFactoryContract, [
      wallet.address,
      deployedRabbitHoleReceiptContract.address,
      protocolFeeAddress,
    ])) as QuestFactory
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
    const ReceiptRenderer = await ethers.getContractFactory('ReceiptRenderer')
    const deployedReceiptRenderer = await ReceiptRenderer.deploy()
    await deployedReceiptRenderer.deployed()

    deployedRabbitHoleReceiptContract = (await upgrades.deployProxy(rabbitholeReceiptContract, [
      deployedReceiptRenderer.address,
      royaltyRecipient.address,
      owner.address,
      69,
    ])) as RabbitHoleReceipt
  }

  describe('Deployment', () => {
    it('Should revert if trying to deploy with protocolFeeRecipient set to zero address', async () => {
      await expect(
        upgrades.deployProxy(questFactoryContract, [
          wallet.address,
          deployedRabbitHoleReceiptContract.address,
          constants.AddressZero,
        ])
      ).to.be.revertedWithCustomError(questFactoryContract, 'AddressZeroNotAllowed')
    })
  })

  describe('createQuest()', () => {
    const erc20QuestId = 'asdf'
    const erc1155QuestId = 'fdsa'

    it('should init with right owner', async () => {
      expect(await deployedFactoryContract.owner()).to.equal(owner.address)
    })

    it('should revert if incorrect quest contract type', async () => {
      await expect(
        deployedFactoryContract.createQuest(
          deployedSampleErc20Contract.address,
          expiryDate,
          startDate,
          totalRewards,
          rewardAmount,
          'some-incorrect-contract-type',
          erc20QuestId
        )
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestTypeInvalid')
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

      expect(await deployedFactoryContract.questIdCount()).to.equal(1)

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
      const deployedErc20Quest = await ethers.getContractAt('Erc20Quest', questAddress)
      expect(await deployedErc20Quest.startTime()).to.equal(startDate)
      expect(await deployedErc20Quest.owner()).to.equal(owner.address)
      expect(await deployedFactoryContract.questIdCount()).to.equal(2)
    })

    it('Should create a new ERC1155 quest', async () => {
      expect(await deployedFactoryContract.questIdCount()).to.equal(1)
      const tx = await deployedFactoryContract.createQuest(
        deployedSampleErc20Contract.address,
        expiryDate,
        startDate,
        totalRewards,
        rewardAmount,
        'erc1155',
        erc1155QuestId
      )
      await tx.wait()
      const questAddress = await deployedFactoryContract.quests(erc1155QuestId).then((res) => res.questAddress)
      const deployedErc1155Quest = await ethers.getContractAt('Erc1155Quest', questAddress)
      expect(await deployedErc1155Quest.startTime()).to.equal(startDate)
      expect(await deployedErc1155Quest.owner()).to.equal(owner.address)
      expect(await deployedFactoryContract.questIdCount()).to.equal(2)
    })

    it('Should revert when creating an ERC1155 quest that is not from the owner', async () => {
      const createQuestRole = await deployedFactoryContract.CREATE_QUEST_ROLE()
      await deployedFactoryContract.grantRole(createQuestRole, royaltyRecipient.address)
      await expect(
        deployedFactoryContract
          .connect(royaltyRecipient)
          .createQuest(
            deployedSampleErc20Contract.address,
            expiryDate,
            startDate,
            totalRewards,
            rewardAmount,
            'erc1155',
            erc1155QuestId
          )
      ).to.be.revertedWithCustomError(questFactoryContract, 'OnlyOwnerCanCreate1155Quest')
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

  describe('mintReceipt()', () => {
    const erc20QuestId = 'asdf'
    let messageHash: string
    let signature: string

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
    })

    it('Should mint a receipt', async () => {
      await deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      expect(await deployedRabbitHoleReceiptContract.balanceOf(owner.address)).to.equal(1)
    })

    it('Should fail if user tries to use a hash + signature that is not tied to them', async () => {
      await expect(
        deployedFactoryContract.connect(royaltyRecipient).mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'InvalidHash')
    })

    it('Should fail if user is able to call mintReceipt multiple times', async () => {
      await deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      expect(await deployedRabbitHoleReceiptContract.balanceOf(owner.address)).to.equal(1)

      await expect(
        deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'AddressAlreadyMinted')
      expect(await deployedRabbitHoleReceiptContract.balanceOf(owner.address)).to.equal(1)
    })
  })
})
