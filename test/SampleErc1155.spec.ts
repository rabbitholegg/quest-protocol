import {expect} from 'chai'
import {ethers} from 'hardhat'

describe('Sample ERC-1155 contract', async () => {
    let deployedErc1155: any, owner: any

    beforeEach(async () => {
        const sampleErc1155 = await ethers.getContractFactory('SampleErc1155')
        const [localOwner] = await ethers.getSigners()
        owner = localOwner

        deployedErc1155 = await sampleErc1155.deploy()
        await deployedErc1155.deployed()
    })

    describe('Deployment', () => {
        it('deploys a mock erc1155 and mints 10 rewards', async () => {
            const tokenBalance = await deployedErc1155.balanceOf(owner.address, 1)
            expect(tokenBalance.toString()).to.equal("100")
        })
    })
})
