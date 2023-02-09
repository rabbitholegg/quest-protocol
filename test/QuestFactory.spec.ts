import { expect } from 'chai'
import { ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import {
  Erc20Quest,
  Erc1155Quest,
  SampleERC20,
  SampleErc1155,
  QuestFactory,
  RabbitHoleReceipt,
  RabbitHoleTickets,
  Erc20Quest__factory,
  Erc1155Quest__factory,
  QuestFactory__factory,
  RabbitHoleReceipt__factory,
  RabbitHoleTickets__factory,
  SampleERC20__factory,
  SampleErc1155__factory,
} from '../typechain-types'
import { Wallet, utils, constants } from 'ethers'

describe('QuestFactory', () => {
  let deployedSampleErc20Contract: SampleERC20
  let deployedSampleErc1155Contract: SampleErc1155
  let deployedRabbitHoleReceiptContract: RabbitHoleReceipt
  let deployedRabbitHoleTicketsContract: RabbitHoleTickets
  let deployedFactoryContract: QuestFactory
  let deployedErc20Quest: Erc20Quest
  let deployedErc1155Quest: Erc1155Quest
  const protocolFeeAddress = '0xE8B17e572c1Eea45fCE267F30aE38862CF03BC84'
  let expiryDate: number, startDate: number
  const totalRewards = 1000
  const rewardAmount = 10
  const mnemonic = 'announce room limb pattern dry unit scale effort smooth jazz weasel alcohol'
  let owner: SignerWithAddress
  let royaltyRecipient: SignerWithAddress

  let questFactoryContract: QuestFactory__factory
  let rabbitHoleTicketsContract: RabbitHoleTickets__factory
  let erc20QuestContract: Erc20Quest__factory
  let erc1155QuestContract: Erc1155Quest__factory
  let rabbitholeReceiptContract: RabbitHoleReceipt__factory
  let sampleERC20Contract: SampleERC20__factory
  let sampleERC1155Contract: SampleErc1155__factory
  let wallet: Wallet

  beforeEach(async () => {
    ;[owner, royaltyRecipient] = await ethers.getSigners()
    const latestTime = await time.latest()
    expiryDate = latestTime + 1000
    startDate = latestTime + 100

    wallet = Wallet.fromMnemonic(mnemonic)

    questFactoryContract = await ethers.getContractFactory('QuestFactory')
    erc20QuestContract = await ethers.getContractFactory('Erc20Quest')
    erc1155QuestContract = await ethers.getContractFactory('Erc1155Quest')
    rabbitholeReceiptContract = await ethers.getContractFactory('RabbitHoleReceipt')
    rabbitHoleTicketsContract = await ethers.getContractFactory('RabbitHoleTickets')
    sampleERC20Contract = await ethers.getContractFactory('SampleERC20')
    sampleERC1155Contract = await ethers.getContractFactory('SampleErc1155')

    await deploySampleErc20Contract()
    await deploySampleErc1155Conract()
    await deployRabbitHoleReceiptContract()
    await deployRabbitHoleTicketsContract()
    await deployFactoryContract()
  })

  const deployFactoryContract = async () => {
    deployedErc20Quest = await erc20QuestContract.deploy()
    await deployedErc20Quest.deployed()
    deployedErc1155Quest = await erc1155QuestContract.deploy()

    deployedFactoryContract = (await upgrades.deployProxy(questFactoryContract, [
      wallet.address,
      deployedRabbitHoleReceiptContract.address,
      deployedRabbitHoleTicketsContract.address,
      protocolFeeAddress,
      deployedErc20Quest.address,
      deployedErc1155Quest.address,
    ])) as QuestFactory

    await deployedRabbitHoleReceiptContract.setMinterAddress(deployedFactoryContract.address)
    await deployedRabbitHoleTicketsContract.setMinterAddress(deployedFactoryContract.address)
  }

  const deploySampleErc20Contract = async () => {
    deployedSampleErc20Contract = await sampleERC20Contract.deploy('RewardToken', 'RTC', '1000000000', owner.address)
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

  const deployRabbitHoleTicketsContract = async () => {
    const TicketRenderer = await ethers.getContractFactory('TicketRenderer')
    const deployedTicketRenderer = await TicketRenderer.deploy()
    await deployedTicketRenderer.deployed()

    deployedRabbitHoleTicketsContract = (await upgrades.deployProxy(rabbitHoleTicketsContract, [
      deployedTicketRenderer.address,
      royaltyRecipient.address,
      owner.address,
      10,
    ])) as RabbitHoleTickets
  }

  describe('Deployment', () => {
    it('Should revert if trying to deploy with protocolFeeRecipient set to zero address', async () => {
      await expect(
        upgrades.deployProxy(questFactoryContract, [
          wallet.address,
          deployedRabbitHoleReceiptContract.address,
          deployedRabbitHoleTicketsContract.address,
          constants.AddressZero,
          deployedErc20Quest.address,
          deployedErc1155Quest.address,
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
    })

    it('Should create a new ERC1155 quest', async () => {
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
    })

    it('Should create a new ERC1155 quest with RabbitHoleTickets', async () => {
      await deployedFactoryContract.createQuest(
        deployedRabbitHoleTicketsContract.address,
        expiryDate,
        startDate,
        totalRewards,
        rewardAmount,
        'erc1155',
        erc1155QuestId
      )
      const questAddress = await deployedFactoryContract.quests(erc1155QuestId).then((res) => res.questAddress)
      const deployedErc1155Quest = await ethers.getContractAt('Erc1155Quest', questAddress)
      expect(await deployedErc1155Quest.startTime()).to.equal(startDate)
      expect(await deployedErc1155Quest.owner()).to.equal(owner.address)

      const ticketBalance = await deployedRabbitHoleTicketsContract.balanceOf(questAddress, rewardAmount)
      expect(ticketBalance).to.equal(totalRewards)
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
    let questAddress: string
    let erc20Quest: Erc20Quest

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
      erc20Quest = await ethers.getContractAt('Erc20Quest', questAddress)
    })

    it('Should fail when trying to mint before quest has started', async () => {
      await expect(
        deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestNotStarted')
    })

    it('Should fail when trying to mint before quest time has started', async () => {
      await erc20Quest.start()
      await time.setNextBlockTimestamp(startDate - 1)
      await expect(
        deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestNotStarted')
    })

    it('Should mint a receipt', async () => {
      await erc20Quest.start()
      await time.setNextBlockTimestamp(startDate)
      await deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      expect(await deployedRabbitHoleReceiptContract.balanceOf(owner.address)).to.equal(1)
    })

    it('Should fail if user tries to use a hash + signature that is not tied to them', async () => {
      await erc20Quest.start()
      await time.setNextBlockTimestamp(startDate)
      await expect(
        deployedFactoryContract.connect(royaltyRecipient).mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'InvalidHash')
    })

    it('Should fail if user is able to call mintReceipt multiple times', async () => {
      await erc20Quest.start()
      await time.setNextBlockTimestamp(startDate)
      await deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      expect(await deployedRabbitHoleReceiptContract.balanceOf(owner.address)).to.equal(1)

      await expect(
        deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'AddressAlreadyMinted')
      expect(await deployedRabbitHoleReceiptContract.balanceOf(owner.address)).to.equal(1)
    })

    it('Should fail when trying to mint after quest time has passed', async () => {
      await erc20Quest.start()
      await time.setNextBlockTimestamp(expiryDate + 1)
      await expect(
        deployedFactoryContract.mintReceipt(erc20QuestId, messageHash, signature)
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestEnded')
    })
  })
})
