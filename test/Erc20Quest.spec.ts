import { Result } from '@ethersproject/abi'
import { expect } from 'chai'
import { ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { Wallet, utils } from 'ethers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import {
  Erc20Quest__factory,
  RabbitHoleReceipt__factory,
  SampleERC20__factory,
  Erc20Quest,
  SampleERC20,
  RabbitHoleReceipt,
  QuestFactory,
  QuestFactory__factory,
} from '../typechain-types'

describe('Erc20Quest', async () => {
  let deployedQuestContract: Erc20Quest
  let deployedSampleErc20Contract: SampleERC20
  let deployedRabbitholeReceiptContract: RabbitHoleReceipt
  let expiryDate: number, startDate: number
  const mockAddress = '0x0000000000000000000000000000000000000000'
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
  let questContract: Erc20Quest__factory
  let sampleERC20Contract: SampleERC20__factory
  let rabbitholeReceiptContract: RabbitHoleReceipt__factory
  let deployedFactoryContract: QuestFactory
  let questFactoryContract: QuestFactory__factory
  let wallet: Wallet
  let messageHash: string
  let signature: string

  beforeEach(async () => {
    const [local_owner, local_firstAddress, local_secondAddress, local_thirdAddress, local_fourthAddress] =
      await ethers.getSigners()
    questContract = await ethers.getContractFactory('Erc20Quest')
    sampleERC20Contract = await ethers.getContractFactory('SampleERC20')
    rabbitholeReceiptContract = await ethers.getContractFactory('RabbitHoleReceipt')
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
    await deployRabbitholeReceiptContract()
    await deploySampleErc20Contract()
    await deployFactoryContract()

    messageHash = utils.solidityKeccak256(['address', 'string'], [firstAddress.address.toLowerCase(), questId])
    signature = await wallet.signMessage(utils.arrayify(messageHash))
    await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc20Contract.address, true)
    const createQuestTx = await deployedFactoryContract.createQuest(
      deployedSampleErc20Contract.address,
      expiryDate,
      startDate,
      totalParticipants,
      rewardAmount,
      'erc20',
      questId
    )

    const waitedTx = await createQuestTx.wait()

    const event = waitedTx?.events?.find((event) => event.event === 'QuestCreated')
    const [_from, contractAddress, type] = event?.args as Result

    deployedQuestContract = await questContract.attach(contractAddress)
    await transferRewardsToDistributor()
  })

  const deployFactoryContract = async () => {
    const erc20QuestContract = await ethers.getContractFactory('Erc20Quest')
    const erc1155QuestContract = await ethers.getContractFactory('Erc1155Quest')
    const rabbitHoleTicketsContract = await ethers.getContractFactory('RabbitHoleTickets')
    const deployedErc20Quest = await erc20QuestContract.deploy()
    const deployedErc1155Quest = await erc1155QuestContract.deploy()
    const deployedRabbitHoleTickets = await rabbitHoleTicketsContract.deploy()

    deployedFactoryContract = (await upgrades.deployProxy(questFactoryContract, [
      wallet.address,
      deployedRabbitholeReceiptContract.address,
      deployedRabbitHoleTickets.address,
      protocolFeeRecipient.address,
      deployedErc20Quest.address,
      deployedErc1155Quest.address,
    ])) as QuestFactory
  }

  const deployRabbitholeReceiptContract = async () => {
    const ReceiptRenderer = await ethers.getContractFactory('ReceiptRenderer')
    const deployedReceiptRenderer = await ReceiptRenderer.deploy()
    await deployedReceiptRenderer.deployed()

    deployedRabbitholeReceiptContract = (await upgrades.deployProxy(rabbitholeReceiptContract, [
      deployedReceiptRenderer.address,
      owner.address,
      minterAddress.address, // as a placeholder, would the factory contract
      10,
    ])) as RabbitHoleReceipt
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

  const transferRewardsToDistributor = async () => {
    await deployedSampleErc20Contract.functions.transfer(deployedQuestContract.address, totalRewardsPlusFee)
  }

  describe('Deployment', () => {
    describe('when start time is in past', () => {
      it('Should revert', async () => {
        expect(
          upgrades.deployProxy(questContract, [mockAddress, expiryDate, startDate - 1000, totalParticipants])
        ).to.be.revertedWithCustomError(questContract, 'StartTimeInPast')
      })
    })

    describe('when end time is in past', () => {
      it('Should revert', async () => {
        expect(
          upgrades.deployProxy(questContract, [mockAddress, startDate - 1000, startDate, totalParticipants])
        ).to.be.revertedWithCustomError(questContract, 'EndTimeInPast')
      })
    })

    describe('when end time is before start time', () => {
      it('Should revert', async () => {
        expect(
          upgrades.deployProxy(questContract, [mockAddress, startDate - 1000, startDate + 1000, totalParticipants])
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
        const hasStarted = await deployedQuestContract.hasStarted()
        expect(hasStarted).to.equal(false)
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

  describe('start()', () => {
    it('should only allow the owner to start', async () => {
      await expect(deployedQuestContract.connect(firstAddress).start()).to.be.revertedWith(
        'Ownable: caller is not the owner'
      )
    })

    it('should set start correctly', async () => {
      expect(await deployedQuestContract.hasStarted()).to.equal(false)
      await deployedQuestContract.connect(owner).start()
      expect(await deployedQuestContract.hasStarted()).to.equal(true)
    })
  })

  describe('pause()', () => {
    it('should only allow the owner to pause', async () => {
      await expect(deployedQuestContract.connect(firstAddress).pause()).to.be.revertedWith(
        'Ownable: caller is not the owner'
      )
    })

    it('should set pause correctly', async () => {
      expect(await deployedQuestContract.hasStarted()).to.equal(false)
      await deployedQuestContract.connect(owner).start()
      expect(await deployedQuestContract.isPaused()).to.equal(false)
      await deployedQuestContract.connect(owner).pause()
      expect(await deployedQuestContract.isPaused()).to.equal(true)
    })
  })

  describe('unPause()', () => {
    it('should only allow the owner to pause', async () => {
      await expect(deployedQuestContract.connect(firstAddress).unPause()).to.be.revertedWith(
        'Ownable: caller is not the owner'
      )
    })

    it('should set unPause correctly', async () => {
      expect(await deployedQuestContract.hasStarted()).to.equal(false)
      expect(await deployedQuestContract.isPaused()).to.equal(false)
      await deployedQuestContract.connect(owner).start()
      expect(await deployedQuestContract.isPaused()).to.equal(false)
      await deployedQuestContract.connect(owner).pause()
      expect(await deployedQuestContract.isPaused()).to.equal(true)
      await deployedQuestContract.connect(owner).unPause()
      expect(await deployedQuestContract.isPaused()).to.equal(false)
    })
  })

  describe('claim()', async () => {
    it('should fail if quest has not started yet', async () => {
      expect(await deployedQuestContract.hasStarted()).to.equal(false)
      await expect(deployedQuestContract.claim()).to.be.revertedWithCustomError(questContract, 'NotStarted')
    })

    it('should fail if quest is paused', async () => {
      await deployedQuestContract.start()
      await time.setNextBlockTimestamp(startDate + 1)
      await deployedQuestContract.pause()

      await expect(deployedQuestContract.claim()).to.be.revertedWithCustomError(questContract, 'QuestPaused')
    })

    it('should fail if before start time stamp', async () => {
      await deployedQuestContract.start()
      await expect(deployedQuestContract.claim()).to.be.revertedWithCustomError(questContract, 'ClaimWindowNotStarted')
    })

    it('should fail if the contract is out of rewards', async () => {
      await deployedQuestContract.start()
      await time.setNextBlockTimestamp(expiryDate + 1)
      await deployedQuestContract.withdrawRemainingTokens()
      await expect(deployedQuestContract.claim()).to.be.revertedWithCustomError(questContract, 'NoTokensToClaim')
    })

    it('should only transfer the correct amount of rewards', async () => {
      await deployedRabbitholeReceiptContract.connect(minterAddress).mint(owner.address, questId)
      await deployedQuestContract.start()

      await time.increaseTo(startDate)

      expect(await deployedSampleErc20Contract.balanceOf(owner.address)).to.equal(0)

      const totalTokens = await deployedRabbitholeReceiptContract.getOwnedTokenIdsOfQuest(questId, owner.address)
      expect(totalTokens.length).to.equal(1)

      expect(await deployedQuestContract.isClaimed(1)).to.equal(false)

      await deployedQuestContract.claim()
      expect(await deployedSampleErc20Contract.balanceOf(owner.address)).to.equal(rewardAmount)
    })

    it('should let you claim mulitiple rewards if you have multiple tokens', async () => {
      await deployedRabbitholeReceiptContract.connect(minterAddress).mint(owner.address, questId)
      await deployedRabbitholeReceiptContract.connect(minterAddress).mint(owner.address, questId)
      await deployedQuestContract.start()

      await time.increaseTo(startDate)

      const startingBalance = await deployedSampleErc20Contract.balanceOf(owner.address)
      expect(startingBalance).to.equal(0)

      const totalTokens = await deployedRabbitholeReceiptContract.getOwnedTokenIdsOfQuest(questId, owner.address)
      expect(totalTokens.length).to.equal(2)

      expect(await deployedQuestContract.isClaimed(1)).to.equal(false)

      await deployedQuestContract.claim()
      const endingBalance = await deployedSampleErc20Contract.balanceOf(owner.address)
      expect(endingBalance).to.equal(2000)
    })

    it('should not let you claim if you have already claimed', async () => {
      await deployedRabbitholeReceiptContract.connect(minterAddress).mint(owner.address, questId)
      await deployedQuestContract.start()

      await time.increaseTo(expiryDate + 1)
      await deployedQuestContract.claim()
      await expect(deployedQuestContract.claim()).to.be.revertedWithCustomError(questContract, 'AlreadyClaimed')
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
      await deployedRabbitholeReceiptContract.setMinterAddress(deployedFactoryContract.address)
      await deployedQuestContract.start()

      await time.setNextBlockTimestamp(startDate + 1)
      await deployedFactoryContract.connect(firstAddress).mintReceipt(questId, messageHash, signature)
      await deployedQuestContract.connect(firstAddress).claim()
      expect(await deployedSampleErc20Contract.balanceOf(protocolFeeRecipient.address)).to.equal(0)

      await time.setNextBlockTimestamp(expiryDate + 1000)
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
      await deployedRabbitholeReceiptContract.setMinterAddress(deployedFactoryContract.address)
      await deployedQuestContract.start()

      await time.setNextBlockTimestamp(startDate + 1)
      await deployedFactoryContract.connect(firstAddress).mintReceipt(questId, messageHash, signature)
      const secondMessageHash = utils.solidityKeccak256(
        ['address', 'string'],
        [secondAddress.address.toLowerCase(), questId]
      )
      const secondSignature = await wallet.signMessage(utils.arrayify(secondMessageHash))
      await deployedFactoryContract.connect(secondAddress).mintReceipt(questId, secondMessageHash, secondSignature)
      await time.setNextBlockTimestamp(expiryDate + 1)
      await deployedQuestContract.connect(firstAddress).claim()
      expect(await deployedSampleErc20Contract.balanceOf(protocolFeeRecipient.address)).to.equal(0)

      await time.setNextBlockTimestamp(expiryDate + 2)
      await deployedQuestContract.connect(protocolFeeRecipient).withdrawRemainingTokens()

      const receiptRedeemers = (await deployedQuestContract.receiptRedeemers()).toNumber()
      expect(receiptRedeemers).to.equal(2)

      const protocolFee = (await deployedQuestContract.protocolFee()).toNumber()
      expect(protocolFee).to.equal(400) // 2 * 1000 * (2000 / 10000) = 400

      expect(await deployedSampleErc20Contract.balanceOf(deployedQuestContract.address)).to.equal(rewardAmount)
      expect(await deployedSampleErc20Contract.balanceOf(owner.address)).to.equal(
        totalRewardsPlusFee - receiptRedeemers * rewardAmount - protocolFee
      )

      expect(await deployedSampleErc20Contract.balanceOf(protocolFeeRecipient.address)).to.equal(protocolFee)

      await expect(deployedQuestContract.connect(protocolFeeRecipient).withdrawRemainingTokens()).to.be.revertedWith(
        'Already withdrawn'
      )
      expect(await deployedSampleErc20Contract.balanceOf(deployedQuestContract.address)).to.equal(rewardAmount)
    })
  })
})
