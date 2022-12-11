import { expect } from 'chai'
import { ethers, upgrades } from 'hardhat'
import { SampleERC20, QuestFactory, RabbitHoleReceipt } from './../typechain-types/contracts'

describe('QuestFactory', async () => {
  let deployedSampleErc20Contract: SampleERC20
  let deployedRabbitHoleReceiptContract: RabbitHoleReceipt
  let deployedFactoryContract: QuestFactory

  let expiryDate: number, startDate: number
  const mockAddress = '0x0000000000000000000000000000000000000000'
  const allowList = 'ipfs://someCidToAnArrayOfAddresses'
  const totalRewards = 1000
  const rewardAmount = 10
  const [owner, firstAddress, secondAddress, thirdAddress, fourthAddress] = await ethers.getSigners()

  const questFactoryContract = await ethers.getContractFactory('QuestFactory')
  const rabbitholeReceiptContract = await ethers.getContractFactory('RabbitHoleReceipt')
  const sampleERC20Contract = await ethers.getContractFactory('SampleERC20')

  beforeEach(async () => {
    expiryDate = Math.floor(Date.now() / 1000) + 10000
    startDate = Math.floor(Date.now() / 1000) + 1000

    await deploySampleErc20Contract()
    await deployRabbitHoleReceiptContract()
    await deployFactoryContract()
  })

  const deployFactoryContract = async () => {
    deployedFactoryContract = (await upgrades.deployProxy(questFactoryContract)) as QuestFactory
  }

  const deploySampleErc20Contract = async () => {
    deployedSampleErc20Contract = await sampleERC20Contract.deploy('RewardToken', 'RTC', 1000, owner.address)
    await deployedSampleErc20Contract.deployed()
  }

  const deployRabbitHoleReceiptContract = async () => {
    deployedRabbitHoleReceiptContract = (await upgrades.deployProxy(rabbitholeReceiptContract, [
      firstAddress.address,
      secondAddress.address,
      69,
    ])) as RabbitHoleReceipt
  }

  describe('createQuest', () => {
    const questId = 'asdf'

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
        questId,
        deployedRabbitHoleReceiptContract.address
      )
      await tx.wait()
      const questAddress = await deployedFactoryContract.questAddressForQuestId(questId)
      const deployedErc20Quest = await ethers.getContractAt('Erc20Quest', questAddress)
      expect(await deployedErc20Quest.startTime()).to.equal(startDate)
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
          questId,
          deployedRabbitHoleReceiptContract.address
        )
      ).to.be.revertedWithCustomError(questFactoryContract, 'QuestIdUsed')
    })
  })
})
