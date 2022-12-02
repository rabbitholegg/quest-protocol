import {MerkleDistributorContractType, SampleErc20Type} from "./types";
import {expect} from 'chai'
import {ethers, upgrades} from 'hardhat'
import {loadFixture} from '@nomicfoundation/hardhat-network-helpers'
import {parseBalanceMap} from '../src/parse-balance-map'

describe('Merkle Distributor contract', async () => {
    let deployedMerkleDistributorContract: MerkleDistributorContractType

    let deployedSampleErc20Contract: SampleErc20Type

    const expiryDate = Math.floor(Date.now() / 1000) + 10000
    const startDate = Math.floor(Date.now() / 1000) + 1000
    const mockAddress = '0x0000000000000000000000000000000000000000'
    const totalRewards = 1000
    const [owner, firstAddress, secondAddress] = await ethers.getSigners()
    const merkleDistributorContract = await ethers.getContractFactory('MerkleDistributor')
    const sampleERC20Contract = await ethers.getContractFactory('SampleERC20')

    beforeEach(async () => {
        await deployDistributorContract()
        await deploySampleErc20Contract()
        await transferRewardsToDistributor()
    })

    const deployDistributorContract = async () => {
        deployedMerkleDistributorContract = await upgrades.deployProxy(merkleDistributorContract, [
            mockAddress,
            expiryDate,
            startDate,
            totalRewards,
        ])
    }

    const deploySampleErc20Contract = async () => {
        deployedSampleErc20Contract = await sampleERC20Contract.deploy('RewardToken', 'RTC', 1000, owner.address)
        await deployedSampleErc20Contract.deployed()
    }

    const transferRewardsToDistributor = async () => {
        const distributorContractAddress = deployedMerkleDistributorContract.address
        await deployedSampleErc20Contract.functions.transfer(distributorContractAddress, 1000)
    }

    describe('Deployment', () => {
        describe('when start time is in past', () => {
            it('Should revert', async () => {
                expect(upgrades.deployProxy(merkleDistributorContract, [
                        mockAddress,
                        expiryDate,
                        startDate - 1000,
                        totalRewards,
                    ])
                ).to.be.revertedWithCustomError(merkleDistributorContract, 'StartTimeInPast')
            })
        })

        describe('when end time is in past', () => {
            it('Should revert', async () => {
                expect(upgrades.deployProxy(merkleDistributorContract, [
                        mockAddress,
                        startDate - 1000,
                        startDate,
                        totalRewards,
                    ])
                ).to.be.revertedWithCustomError(merkleDistributorContract, 'EndTimeInPast')
            })
        })

        describe('setting public variables', () => {
            it('Should set the token address with correct value', async () => {
                const rewardContractAddress = await deployedMerkleDistributorContract.token()
                expect(rewardContractAddress).to.equal(mockAddress)
            })

            it('Should set the total reward amount with correct value', async () => {
                const totalAmount = await deployedMerkleDistributorContract.totalAmount()
                expect(totalAmount).to.equal(totalRewards)
            })

            it('Should set has started with correct value', async () => {
                const hasStarted = await deployedMerkleDistributorContract.hasStarted()
                expect(hasStarted).to.equal(false)
            })

            it('Should set the end time with correct value', async () => {
                const endTime = await deployedMerkleDistributorContract.endTime()
                expect(endTime).to.equal(expiryDate)
            })

            it('Should set the start time with correct value', async () => {
                const startTime = await deployedMerkleDistributorContract.startTime()
                expect(startTime).to.equal(startDate)
            })
        })

        it('Deployment should set the correct owner address', async () => {
            expect(await deployedMerkleDistributorContract.owner()).to.equal(owner.address)
        })
    })

    describe('start()', () => {
        it('should only allow the owner to start', async () => {
            await expect(
                deployedMerkleDistributorContract.connect(firstAddress).start()
            ).to.be.revertedWith('Ownable: caller is not the owner')
        })

        it('should set start correctly', async () => {
            expect(await deployedMerkleDistributorContract.hasStarted()).to.equal(false)
            await deployedMerkleDistributorContract.connect(owner).start()
            expect(await deployedMerkleDistributorContract.hasStarted()).to.equal(true)
        })
    })

    describe('pause()', () => {
        it('should only allow the owner to pause', async () => {
            await expect(
                deployedMerkleDistributorContract.connect(firstAddress).pause()
            ).to.be.revertedWith('Ownable: caller is not the owner')
        })

        it('should set pause correctly', async () => {
            expect(await deployedMerkleDistributorContract.hasStarted()).to.equal(false)
            await deployedMerkleDistributorContract.connect(owner).start()
            expect(await deployedMerkleDistributorContract.hasStarted()).to.equal(true)
            await deployedMerkleDistributorContract.connect(owner).pause()
            expect(await deployedMerkleDistributorContract.hasStarted()).to.equal(false)
        })
    })

    describe('unPause()', () => {
        it('should only allow the owner to pause', async () => {
            await expect(
                deployedMerkleDistributorContract.connect(firstAddress).unPause()
            ).to.be.revertedWith('Ownable: caller is not the owner')
        })

        it('should set unPause correctly', async () => {
            expect(await deployedMerkleDistributorContract.hasStarted()).to.equal(false)
            await deployedMerkleDistributorContract.connect(owner).start()
            expect(await deployedMerkleDistributorContract.hasStarted()).to.equal(true)
            await deployedMerkleDistributorContract.connect(owner).pause()
            expect(await deployedMerkleDistributorContract.hasStarted()).to.equal(false)
            await deployedMerkleDistributorContract.connect(owner).unPause()
            expect(await deployedMerkleDistributorContract.hasStarted()).to.equal(true)
        })
    })

    describe('setMerkleTree()', () => {
        it('should set start correctly', async () => {
            expect(await deployedMerkleDistributorContract.merkleRoot()).to.equal('0x0000000000000000000000000000000000000000000000000000000000000000')
            await deployedMerkleDistributorContract.connect(owner).setMerkleRoot('0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d')
            expect(await deployedMerkleDistributorContract.merkleRoot()).to.equal('0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d')
        })

        it('should only allow the owner to start', async () => {
            await expect(
                deployedMerkleDistributorContract.connect(firstAddress).setMerkleRoot('0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d')
            ).to.be.revertedWith('Ownable: caller is not the owner')
        })
    })

    describe('claim()', async () => {

    })

    describe('withDraw()', async () => {
        it('should only allow the owner to withdraw', async () => {
            await expect(
                deployedMerkleDistributorContract.connect(firstAddress).withdraw()
            ).to.be.revertedWith('Ownable: caller is not the owner')
        })

        it('should revert if trying to withdraw before end date', async () => {
            await expect(
                deployedMerkleDistributorContract.connect(owner).withdraw()
            ).to.be.revertedWithCustomError(merkleDistributorContract, 'NoWithdrawDuringClaim')
        })

        it('should transfer all rewards back to owner', async () => {
            const beginningContractBalance = await deployedSampleErc20Contract.functions.balanceOf(deployedMerkleDistributorContract.address)
            const beginningOwnerBalance = await deployedSampleErc20Contract.functions.balanceOf(owner.address)
            expect(beginningContractBalance.toString()).to.equal(totalRewards.toString())
            expect(beginningOwnerBalance.toString()).to.equal('0')
            await ethers.provider.send('evm_increaseTime', [10000])
            await deployedMerkleDistributorContract.withdraw()
            // const endContactBalance = await deployedSampleErc20Contract.functions.balanceOf(deployedMerkleDistributorContract.address)
            // expect(endContactBalance.toString()).to.equal('0')
        })
    })

    //
    // describe('Claim rewards', function () {
    //   it('Valid redeemer should be able to claim reward', async function () {
    //     const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
    //       deployAndTransferRewardToDisperser
    //     )
    //     const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners()
    //     const arr = [owner.address, addr1.address, addr2.address, addr3.address, addr4.address]
    //     let dataObject: any = {}
    //     arr.forEach(function (item) {
    //       dataObject[item] = 250
    //     })
    //     const balanceMap = parseBalanceMap(dataObject)
    //     const merkleRoot = balanceMap.merkleRoot
    //     await hardhatDisperseToken.setMerkleRoot(merkleRoot)
    //     const getMerkleRoot = await hardhatDisperseToken.merkleRoot()
    //     expect(merkleRoot).to.equal(getMerkleRoot)
    //     const checksumAddr = ethers.utils.getAddress(addr1.address)
    //     const testClaim = balanceMap.claims[checksumAddr]
    //     await ethers.provider.send('evm_increaseTime', [100])
    //     await hardhatDisperseToken.start()
    //     const claimTxn = await hardhatDisperseToken.connect(addr1).claim(checksumAddr, 250, testClaim.proof)
    //     const testAddrBalance = await hardhatRewardToken.functions.balanceOf(checksumAddr)
    //   })
    //   it('Revert with error when not started', async function () {
    //     const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
    //       deployAndTransferRewardToDisperser
    //     )
    //     const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners()
    //     const arr = [owner.address, addr1.address, addr2.address, addr3.address, addr4.address]
    //     let dataObject: any = {}
    //     arr.forEach(function (item) {
    //       dataObject[item] = 10000
    //     })
    //     const balanceMap = parseBalanceMap(dataObject)
    //     const merkleRoot = balanceMap.merkleRoot
    //     await hardhatDisperseToken.setMerkleRoot(merkleRoot)
    //     const getMerkleRoot = await hardhatDisperseToken.merkleRoot()
    //     expect(merkleRoot).to.equal(getMerkleRoot)
    //     const checksumAddr = ethers.utils.getAddress(addr1.address)
    //     const testClaim = balanceMap.claims[checksumAddr]
    //     await ethers.provider.send('evm_increaseTime', [100])
    //     await expect(
    //       hardhatDisperseToken.connect(addr1).claim(checksumAddr, 10000, testClaim.proof)
    //     ).to.be.revertedWithCustomError(hardhatDisperseToken, 'NotStarted')
    //   })
    //   it('Valid redeemer should not be able to claim more than contract has', async function () {
    //     const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
    //       deployAndTransferRewardToDisperser
    //     )
    //     const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners()
    //     const arr = [owner.address, addr1.address, addr2.address, addr3.address, addr4.address]
    //     let dataObject: any = {}
    //     arr.forEach(function (item) {
    //       dataObject[item] = 10000
    //     })
    //     const balanceMap = parseBalanceMap(dataObject)
    //     const merkleRoot = balanceMap.merkleRoot
    //     await hardhatDisperseToken.setMerkleRoot(merkleRoot)
    //     const getMerkleRoot = await hardhatDisperseToken.merkleRoot()
    //     expect(merkleRoot).to.equal(getMerkleRoot)
    //     const checksumAddr = ethers.utils.getAddress(addr1.address)
    //     const testClaim = balanceMap.claims[checksumAddr]
    //     await ethers.provider.send('evm_increaseTime', [100])
    //     await hardhatDisperseToken.start()
    //     await expect(
    //       hardhatDisperseToken.connect(addr1).claim(checksumAddr, 10000, testClaim.proof)
    //     ).to.be.revertedWithCustomError(hardhatDisperseToken, 'AmountExceedsBalance')
    //   })
    //   it('Valid redeemer should not be be able to claim reward twice ', async function () {
    //     const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
    //       deployAndTransferRewardToDisperser
    //     )
    //     const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners()
    //     const arr = [owner.address, addr1.address, addr2.address, addr3.address, addr4.address]
    //     let dataObject: any = {}
    //     arr.forEach(function (item) {
    //       dataObject[item] = 250
    //     })
    //     const balanceMap = parseBalanceMap(dataObject)
    //     const merkleRoot = balanceMap.merkleRoot
    //     await hardhatDisperseToken.setMerkleRoot(merkleRoot)
    //     const getMerkleRoot = await hardhatDisperseToken.merkleRoot()
    //     expect(merkleRoot).to.equal(getMerkleRoot)
    //     const checksumAddr = ethers.utils.getAddress(addr1.address)
    //     const testClaim = balanceMap.claims[checksumAddr]
    //     await ethers.provider.send('evm_increaseTime', [100])
    //     await hardhatDisperseToken.start()
    //     const claimTxn = await hardhatDisperseToken.connect(addr1).claim(checksumAddr, 250, testClaim.proof)
    //     await expect(hardhatDisperseToken.connect(addr1).claim(checksumAddr, 250, testClaim.proof)).to.be.reverted
    //   })
    //   it('Invalid redeemer should not be be able to claim reward', async function () {
    //     const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
    //       deployAndTransferRewardToDisperser
    //     )
    //     const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners()
    //     const arr = [owner.address, addr1.address, addr2.address, addr3.address, addr4.address]
    //     let dataObject: any = {}
    //     arr.forEach(function (item) {
    //       dataObject[item] = 250
    //     })
    //     const balanceMap = parseBalanceMap(dataObject)
    //     const merkleRoot = balanceMap.merkleRoot
    //     await hardhatDisperseToken.setMerkleRoot(merkleRoot)
    //     const getMerkleRoot = await hardhatDisperseToken.merkleRoot()
    //     expect(merkleRoot).to.equal(getMerkleRoot)
    //     const checksumAddr = ethers.utils.getAddress(addr1.address)
    //     const testClaim = balanceMap.claims[checksumAddr]
    //     const sampleAddress = '0xdafea492d9c6733ae3d56b7ed1adb60692c98bc5'
    //     await expect(hardhatDisperseToken.connect(addr2).claim(sampleAddress, 250, testClaim.proof)).to.be.reverted
    //   })
    // })
    //
    // describe('Admin withdraw tokens', function () {
    //   it('Admin should be able to withdraw remaining tokens after redemption expiry', async function () {
    //     const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
    //       deployAndTransferRewardToDisperserWithExpiry
    //     )
    //     const [owner] = await ethers.getSigners()
    //     const contractBalanceBefore = await hardhatRewardToken.functions.balanceOf(disperseTokenAddresss)
    //     await ethers.provider.send('evm_increaseTime', [90])
    //     const tx = await hardhatDisperseToken.withdraw()
    //     await expect(tx.wait()).not.to.be.reverted
    //     const adminBalanceAfter = await hardhatRewardToken.functions.balanceOf(owner.address)
    //     const cbString = contractBalanceBefore.toString()
    //     const abAfter = adminBalanceAfter.toString()
    //     expect(cbString).to.equal(abAfter)
    //   })
    // })
})
