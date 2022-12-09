import {QuestContractType, SampleErc20Type} from './types'
import {expect} from 'chai'
import {ethers, upgrades} from 'hardhat'
import {Contract} from "ethers";

describe('QuestFactory', async () => {
    let deployedQuestContract: QuestContractType
    let deployedSampleErc20Contract: SampleErc20Type
    let deployedFactoryContract: any

    let expiryDate: number, startDate: number
    const mockAddress = '0x0000000000000000000000000000000000000000'
    const allowList = 'ipfs://someCidToAnArrayOfAddresses'
    const totalRewards = 1000
    const rewardAmount = 10
    const [owner, firstAddress, secondAddress, thirdAddress, fourthAddress] = await ethers.getSigners()

    const questFactoryContract = await ethers.getContractFactory('QuestFactory')
    const questContract = await ethers.getContractFactory('Quest')
    const sampleERC20Contract = await ethers.getContractFactory('SampleERC20')

    beforeEach(async () => {
        expiryDate = Math.floor(Date.now() / 1000) + 10000
        startDate = Math.floor(Date.now() / 1000) + 1000

        await deploySampleErc20Contract()
        await deployDistributorContract()
        await deployFactoryContract()
    })

    const deployDistributorContract = async () => {
        deployedQuestContract = await upgrades.deployProxy(questContract, [
            deployedSampleErc20Contract.address,
            expiryDate,
            startDate,
            totalRewards,
            allowList,
            rewardAmount
        ])
    }

    const deployFactoryContract = async () => {
        deployedFactoryContract = await questFactoryContract.deploy()
        await deployedFactoryContract.deployed()
    }

    const deploySampleErc20Contract = async () => {
        deployedSampleErc20Contract = await sampleERC20Contract.deploy('RewardToken', 'RTC', 1000, owner.address)
        await deployedSampleErc20Contract.deployed()
    }

    describe('createQuest', () => {
        it('should init with right owner', async () => {
            expect(await deployedFactoryContract.owner()).to.not.equal("0x0000000000000000000000000000000000000000")
        })
        // it('Should create a new quest', async () => {
        //     const deployedNewQuest = await deployedFactoryContract.createQuest(
        //         deployedSampleErc20Contract.address,
        //         expiryDate,
        //         startDate,
        //         totalRewards,
        //         allowList,
        //         rewardAmount
        //     )
        //
        //     expect(await deployedNewQuest.startTime()).to.equal(startDate)
        // })
    })
})