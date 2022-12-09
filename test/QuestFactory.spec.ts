import {QuestContractType, SampleErc20Type} from './types'
import {expect} from 'chai'
import {ethers, upgrades} from 'hardhat'
import {parseBalanceMap} from '../src/parse-balance-map'
import {deploy} from "@openzeppelin/hardhat-upgrades/dist/utils";

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
        deployedFactoryContract = await upgrades.deployProxy(questFactoryContract, [])
    }

    const deploySampleErc20Contract = async () => {
        deployedSampleErc20Contract = await sampleERC20Contract.deploy('RewardToken', 'RTC', 1000, owner.address)
        await deployedSampleErc20Contract.deployed()
    }

    describe('createQuest', () => {
        describe('asdf', () => {
            it('Should create a new quest', async () => {
                const deployedNewQuest = await deployedFactoryContract.connect(owner.address).createQuest(
                    deployedSampleErc20Contract.address,
                    expiryDate,
                    startDate,
                    totalRewards,
                    allowList,
                    rewardAmount
                )

                expect(deployedNewQuest).to.equal("foo")
                expect(true).to.equal(false)
            })
        })
    })
})