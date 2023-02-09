import { Result } from '@ethersproject/abi'
import { expect } from 'chai'
import { ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { Wallet, utils } from 'ethers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import {
  Erc1155Quest__factory,
  RabbitHoleReceipt__factory,
  SampleErc1155__factory,
  Erc1155Quest,
  SampleErc1155,
  RabbitHoleReceipt,
  QuestFactory,
  QuestFactory__factory,
} from '../typechain-types'

describe('Erc1155Quest', () => {
  let deployedQuestContract: Erc1155Quest
  let deployedSampleErc1155Contract: SampleErc1155
  let deployedRabbitholeReceiptContract: RabbitHoleReceipt
  let expiryDate: number, startDate: number
  const mockAddress = '0x0000000000000000000000000000000000000000'
  const mnemonic = 'announce room limb pattern dry unit scale effort smooth jazz weasel alcohol'
  const questId = 'asdf'
  const totalRewards = 10
  const rewardAmount = 1
  let owner: SignerWithAddress
  let firstAddress: SignerWithAddress
  let secondAddress: SignerWithAddress
  let thirdAddress: SignerWithAddress
  let fourthAddress: SignerWithAddress
  let questContract: Erc1155Quest__factory
  let sampleERC1155Contract: SampleErc1155__factory
  let rabbitholeReceiptContract: RabbitHoleReceipt__factory
  let questFactoryContract: QuestFactory__factory
  let deployedFactoryContract: QuestFactory
  let wallet: Wallet
  let messageHash: string
  let signature: string

  beforeEach(async () => {
    const latestTime = await time.latest()
    const [local_owner, local_firstAddress, local_secondAddress, local_thirdAddress, local_fourthAddress] =
      await ethers.getSigners()
    questContract = await ethers.getContractFactory('Erc1155Quest')
    sampleERC1155Contract = await ethers.getContractFactory('SampleErc1155')
    rabbitholeReceiptContract = await ethers.getContractFactory('RabbitHoleReceipt')
    questFactoryContract = await ethers.getContractFactory('QuestFactory')
    wallet = Wallet.fromMnemonic(mnemonic)

    owner = local_owner
    firstAddress = local_firstAddress
    secondAddress = local_secondAddress
    thirdAddress = local_thirdAddress
    fourthAddress = local_fourthAddress

    expiryDate = latestTime + 1000
    startDate = latestTime + 100
    await deployRabbitholeReceiptContract()
    await deploySampleErc1155Contract()
    await deployFactoryContract()

    messageHash = utils.solidityKeccak256(['address', 'string'], [firstAddress.address.toLowerCase(), questId])
    signature = await wallet.signMessage(utils.arrayify(messageHash))
    await deployedFactoryContract.setRewardAllowlistAddress(deployedSampleErc1155Contract.address, true)
    const createQuestTx = await deployedFactoryContract.createQuest(
      deployedSampleErc1155Contract.address,
      expiryDate,
      startDate,
      10,
      rewardAmount,
      'erc1155',
      questId
    )

    const waitedTx = await createQuestTx.wait()

    const event = waitedTx?.events?.find((event) => event.event === 'QuestCreated')
    const [_from, contractAddress, _type] = event?.args as Result

    deployedQuestContract = questContract.attach(contractAddress)
    await transferRewardsToDistributor()
  })

  const deployRabbitholeReceiptContract = async () => {
    const ReceiptRenderer = await ethers.getContractFactory('ReceiptRenderer')
    const deployedReceiptRenderer = await ReceiptRenderer.deploy()
    await deployedReceiptRenderer.deployed()

    deployedRabbitholeReceiptContract = (await upgrades.deployProxy(rabbitholeReceiptContract, [
      deployedReceiptRenderer.address,
      owner.address,
      owner.address,
      10,
    ])) as RabbitHoleReceipt
  }

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
      wallet.address,
      deployedErc20Quest.address,
      deployedErc1155Quest.address,
    ])) as QuestFactory
  }

  const deploySampleErc1155Contract = async () => {
    deployedSampleErc1155Contract = await sampleERC1155Contract.deploy()
    await deployedSampleErc1155Contract.deployed()
  }

  const transferRewardsToDistributor = async () => {
    await deployedSampleErc1155Contract.safeTransferFrom(
      owner.address,
      deployedQuestContract.address,
      rewardAmount,
      100,
      '0x00'
    )
  }

  describe('Deployment', () => {
    describe('when start time is in past', () => {
      it('Should revert', async () => {
        expect(
          upgrades.deployProxy(questContract, [mockAddress, expiryDate, startDate - 1000, totalRewards])
        ).to.be.revertedWithCustomError(questContract, 'StartTimeInPast')
      })
    })

    describe('when end time is in past', () => {
      it('Should revert', async () => {
        expect(
          upgrades.deployProxy(questContract, [mockAddress, startDate - 1000, startDate, totalRewards])
        ).to.be.revertedWithCustomError(questContract, 'EndTimeInPast')
      })
    })

    describe('when end time is before start time', () => {
      it('Should revert', async () => {
        expect(
          upgrades.deployProxy(questContract, [mockAddress, startDate - 1000, startDate + 1000, totalRewards])
        ).to.be.revertedWithCustomError(questContract, 'EndTimeLessThanOrEqualToStartTime')
      })
    })

    describe('setting public variables', () => {
      it('Should set the token address with correct value', async () => {
        const rewardContractAddress = await deployedQuestContract.rewardToken()
        expect(rewardContractAddress).to.equal(deployedSampleErc1155Contract.address)
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
      await ethers.provider.send('evm_increaseTime', [10000])
      await deployedQuestContract.pause()

      await expect(deployedQuestContract.claim()).to.be.revertedWithCustomError(questContract, 'QuestPaused')
      await ethers.provider.send('evm_increaseTime', [-10000])
    })

    it('should fail if before start time stamp', async () => {
      await deployedQuestContract.start()
      await expect(deployedQuestContract.claim()).to.be.revertedWithCustomError(questContract, 'ClaimWindowNotStarted')
    })

    it('should fail if the contract is out of rewards', async () => {
      await deployedQuestContract.start()
      await ethers.provider.send('evm_increaseTime', [10000])
      await deployedQuestContract.withdrawRemainingTokens()
      await expect(deployedQuestContract.claim()).to.be.revertedWithCustomError(questContract, 'NoTokensToClaim')
      await ethers.provider.send('evm_increaseTime', [-10000])
    })

    it('should fail if there are no tokens to claim', async () => {
      await deployedQuestContract.start()
      await ethers.provider.send('evm_increaseTime', [expiryDate + 100])

      await expect(deployedQuestContract.claim()).to.be.revertedWithCustomError(questContract, 'NoTokensToClaim')
    })

    it('should only transfer the correct amount of rewards', async () => {
      await deployedRabbitholeReceiptContract.mint(owner.address, questId)
      await deployedQuestContract.start()

      await ethers.provider.send('evm_increaseTime', [expiryDate + 100])

      expect(await deployedSampleErc1155Contract.balanceOf(owner.address, rewardAmount)).to.equal(0)

      const totalTokens = await deployedRabbitholeReceiptContract.getOwnedTokenIdsOfQuest(questId, owner.address)
      expect(totalTokens.length).to.equal(1)

      expect(await deployedQuestContract.isClaimed(1)).to.equal(false)

      await deployedQuestContract.claim()
      expect(await deployedSampleErc1155Contract.balanceOf(owner.address, rewardAmount)).to.equal(1)
    })

    it('should not let you claim if you have already claimed', async () => {
      await deployedRabbitholeReceiptContract.mint(owner.address, questId)
      await deployedQuestContract.start()

      await ethers.provider.send('evm_increaseTime', [expiryDate + 100])

      const beginningContractBalance = await deployedSampleErc1155Contract.balanceOf(
        deployedQuestContract.address,
        rewardAmount
      )

      expect(beginningContractBalance.toString()).to.equal('100')

      await deployedQuestContract.claim()
      await expect(deployedQuestContract.claim()).to.be.revertedWithCustomError(questContract, 'AlreadyClaimed')
    })
  })

  describe('withdrawRemainingTokens()', async () => {
    it('should only allow the owner to withdraw', async () => {
      await expect(deployedQuestContract.connect(firstAddress).withdrawRemainingTokens()).to.be.revertedWith(
        'Ownable: caller is not the owner'
      )
    })

    it('should revert if trying to withdraw before end date', async () => {
      await expect(deployedQuestContract.connect(owner).withdrawRemainingTokens()).to.be.revertedWithCustomError(
        questContract,
        'NoWithdrawDuringClaim'
      )
    })

    it('should transfer all rewards back to owner', async () => {
      const beginningContractBalance = await deployedSampleErc1155Contract.balanceOf(
        deployedQuestContract.address,
        rewardAmount
      )
      const beginningOwnerBalance = await deployedSampleErc1155Contract.balanceOf(owner.address, rewardAmount)
      expect(beginningContractBalance.toString()).to.equal('100')
      expect(beginningOwnerBalance.toString()).to.equal('0')
      await ethers.provider.send('evm_increaseTime', [expiryDate + 100])
      await deployedQuestContract.connect(owner).withdrawRemainingTokens()

      const endContactBalance = await deployedSampleErc1155Contract.balanceOf(
        deployedQuestContract.address,
        rewardAmount
      )
      expect(endContactBalance.toString()).to.equal('0')
    })
  })
})
