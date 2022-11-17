const { expect } = require('chai')
const { ethers } = require('hardhat')
// advantage of Hardhat Network's snapshot functionality.
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers')
import { parseBalanceMap } from '../src/parse-balance-map'

describe('Token contract', function () {
  async function deployRewardTokenFixture() {
    const RewardToken = await ethers.getContractFactory('SampleERC20')
    const [owner, addr1, addr2] = await ethers.getSigners()
    const expiryDate = Math.floor(Date.now() / 1000) + 10000
    const hardhatRewardToken = await RewardToken.deploy('RewardToken', 'RTC', 1000, owner.address)
    await hardhatRewardToken.deployed()
    return { RewardToken, hardhatRewardToken, owner, addr1, addr2 }
  }

  async function deployTokenFixture() {
    const Token = await ethers.getContractFactory('MerkleDistributor')
    const [owner, addr1, addr2] = await ethers.getSigners()
    const expiryDate = Math.floor(Date.now() / 1000) + 10000
    const startDate = Math.floor(Date.now() / 1000) + 1000
    const hardhatToken = await Token.deploy('0x0000000000000000000000000000000000000000', expiryDate, startDate, 1000)
    await hardhatToken.deployed()
    return { Token, hardhatToken, owner, addr1, addr2 }
  }

  async function deployAndTransferRewardToDisperser() {
    const { RewardToken, hardhatRewardToken } = await deployRewardTokenFixture()
    const rewardTokenAddress = hardhatRewardToken.address
    const rewardTokenSymbol = (await hardhatRewardToken.functions.symbol())[0]
    const DisperseToken = await ethers.getContractFactory('MerkleDistributor')
    const expiryDate = Math.floor(Date.now() / 1000) + 10000
    const startDate = Math.floor(Date.now() / 1000) + 10
    const hardhatDisperseToken = await DisperseToken.deploy(rewardTokenAddress, expiryDate, startDate, 1000)
    await hardhatDisperseToken.deployed()
    const disperseTokenAddresss = await hardhatDisperseToken.address
    await hardhatRewardToken.functions.transfer(disperseTokenAddresss, 1000)
    return { hardhatRewardToken, rewardTokenAddress, hardhatDisperseToken, disperseTokenAddresss }
  }

  async function deployAndTransferRewardToDisperserWithExpiry() {
    const { RewardToken, hardhatRewardToken } = await deployRewardTokenFixture()
    const rewardTokenAddress = hardhatRewardToken.address
    const rewardTokenSymbol = (await hardhatRewardToken.functions.symbol())[0]
    const DisperseToken = await ethers.getContractFactory('MerkleDistributor')
    const expiryDate = Math.floor(Date.now() / 1000) + 10
    const startDate = Math.floor(Date.now() / 1000) + 1000
    const hardhatDisperseToken = await DisperseToken.deploy(rewardTokenAddress, expiryDate, startDate, 1000)
    await hardhatDisperseToken.deployed()
    const disperseTokenAddresss = await hardhatDisperseToken.address
    await hardhatRewardToken.functions.transfer(disperseTokenAddresss, 1000)
    return { hardhatRewardToken, rewardTokenAddress, hardhatDisperseToken, disperseTokenAddresss }
  }

  async function getTimeout() {
    return new Promise((resolve) => {
      setTimeout(function () {
        resolve({})
      }, 100)
    })
  }

  describe('Deployment', function () {
    it('Deployment should assign the correct contract address', async function () {
      const { hardhatToken, owner } = await loadFixture(deployTokenFixture)
      const tokenContractAddress = await hardhatToken.token()
      expect(tokenContractAddress).to.equal('0x0000000000000000000000000000000000000000')
    })
    it('Deployment should set the correct owner address', async function () {
      const { hardhatToken, owner } = await loadFixture(deployTokenFixture)
      expect(await hardhatToken.owner()).to.equal(owner.address)
    })
  })

  describe('Allowlist', function () {
    it('Deployment should set an allowlist', async function () {
      const { hardhatToken, owner } = await loadFixture(deployTokenFixture)
      const merkleRoot = await hardhatToken.setMerkleRoot(
        '0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d'
      )
      const getMerkleRoot = await hardhatToken.merkleRoot()
      expect(getMerkleRoot).to.equal('0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d')
    })
    it('Deployment should allow only owner set an allowlist', async function () {
      const { hardhatToken, owner, addr1 } = await loadFixture(deployTokenFixture)
      await expect(
        hardhatToken.connect(addr1).setMerkleRoot('0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d')
      ).to.be.revertedWith('Ownable: caller is not the owner')
    })
    it('Deployment should allow owner to update the allowlist', async function () {
      const { hardhatToken, owner } = await loadFixture(deployTokenFixture)
      let merkleRoot = await hardhatToken.setMerkleRoot(
        '0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d'
      )
      let getMerkleRoot = await hardhatToken.merkleRoot()
      expect(getMerkleRoot).to.equal('0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d')
      merkleRoot = await hardhatToken.setMerkleRoot(
        '0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e0032d'
      )
      getMerkleRoot = await hardhatToken.merkleRoot()
      expect(getMerkleRoot).to.equal('0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e0032d')
    })
  })

  describe('Deploy and transfer rewards', function () {
    it('Deployment should deploy reward token', async function () {
      const { hardhatRewardToken, owner } = await loadFixture(deployRewardTokenFixture)
      const tokenSymbol = await hardhatRewardToken.symbol()
      expect(tokenSymbol).to.equal('RTC')
    })
    it('Deployment should deploy and mint reward token', async function () {
      const { hardhatRewardToken, owner } = await loadFixture(deployRewardTokenFixture)
      const supply = await hardhatRewardToken.totalSupply()
      expect(supply).to.equal(1000)
    })
    it('Deployment should mint and transfer reward token to disperse contract', async function () {
      const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
        deployAndTransferRewardToDisperser
      )
      const disperseTokenBalance = (await hardhatRewardToken.functions.balanceOf(disperseTokenAddresss)).toString()
      expect(disperseTokenBalance).to.equal('1000')
    })
  })

  describe('Claim rewards', function () {
    it('Valid redeemer should be able to claim reward', async function () {
      const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
        deployAndTransferRewardToDisperser
      )
      const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners()
      const arr = [owner.address, addr1.address, addr2.address, addr3.address, addr4.address]
      let dataObject: any = {}
      arr.forEach(function (item) {
        dataObject[item] = 250
      })
      const balanceMap = parseBalanceMap(dataObject)
      const merkleRoot = balanceMap.merkleRoot
      await hardhatDisperseToken.setMerkleRoot(merkleRoot)
      const getMerkleRoot = await hardhatDisperseToken.merkleRoot()
      expect(merkleRoot).to.equal(getMerkleRoot)
      const checksumAddr = ethers.utils.getAddress(addr1.address)
      const testClaim = balanceMap.claims[checksumAddr]
      await ethers.provider.send('evm_increaseTime', [100])
      await hardhatDisperseToken.start()
      const claimTxn = await hardhatDisperseToken
        .connect(addr1)
        .claim(testClaim.index, checksumAddr, 250, testClaim.proof)
      const testAddrBalance = await hardhatRewardToken.functions.balanceOf(checksumAddr)
    })
    it('Revert with error when not started', async function () {
      const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
        deployAndTransferRewardToDisperser
      )
      const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners()
      const arr = [owner.address, addr1.address, addr2.address, addr3.address, addr4.address]
      let dataObject: any = {}
      arr.forEach(function (item) {
        dataObject[item] = 10000
      })
      const balanceMap = parseBalanceMap(dataObject)
      const merkleRoot = balanceMap.merkleRoot
      await hardhatDisperseToken.setMerkleRoot(merkleRoot)
      const getMerkleRoot = await hardhatDisperseToken.merkleRoot()
      expect(merkleRoot).to.equal(getMerkleRoot)
      const checksumAddr = ethers.utils.getAddress(addr1.address)
      const testClaim = balanceMap.claims[checksumAddr]
      await ethers.provider.send('evm_increaseTime', [100]);
      await expect(hardhatDisperseToken.connect(addr1).claim(testClaim.index, checksumAddr, 10000, testClaim.proof)).to.be.revertedWithCustomError(hardhatDisperseToken, "NotStarted")
    })
    it('Valid redeemer should not be able to claim more than contract has', async function () {
      const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
        deployAndTransferRewardToDisperser
      )
      const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners()
      const arr = [owner.address, addr1.address, addr2.address, addr3.address, addr4.address]
      let dataObject: any = {}
      arr.forEach(function (item) {
        dataObject[item] = 10000
      })
      const balanceMap = parseBalanceMap(dataObject)
      const merkleRoot = balanceMap.merkleRoot
      await hardhatDisperseToken.setMerkleRoot(merkleRoot)
      const getMerkleRoot = await hardhatDisperseToken.merkleRoot()
      expect(merkleRoot).to.equal(getMerkleRoot)
      const checksumAddr = ethers.utils.getAddress(addr1.address)
      const testClaim = balanceMap.claims[checksumAddr]
      await ethers.provider.send('evm_increaseTime', [100]);
      await hardhatDisperseToken.start();
      await expect(hardhatDisperseToken.connect(addr1).claim(testClaim.index, checksumAddr, 10000, testClaim.proof)).to.be.revertedWithCustomError(hardhatDisperseToken, "AmountExceedsBalance")
    })
    it('Valid redeemer should not be be able to claim reward twice ', async function () {
      const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
        deployAndTransferRewardToDisperser
      )
      const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners()
      const arr = [owner.address, addr1.address, addr2.address, addr3.address, addr4.address]
      let dataObject: any = {}
      arr.forEach(function (item) {
        dataObject[item] = 250
      })
      const balanceMap = parseBalanceMap(dataObject)
      const merkleRoot = balanceMap.merkleRoot
      await hardhatDisperseToken.setMerkleRoot(merkleRoot)
      const getMerkleRoot = await hardhatDisperseToken.merkleRoot()
      expect(merkleRoot).to.equal(getMerkleRoot)
      const checksumAddr = ethers.utils.getAddress(addr1.address)
      const testClaim = balanceMap.claims[checksumAddr]
      await ethers.provider.send('evm_increaseTime', [100])
      await hardhatDisperseToken.start()
      const claimTxn = await hardhatDisperseToken
        .connect(addr1)
        .claim(testClaim.index, checksumAddr, 250, testClaim.proof)
      await expect(hardhatDisperseToken.connect(addr1).claim(testClaim.index, checksumAddr, 250, testClaim.proof)).to.be
        .reverted
    })
    it('Invalid redeemer should not be be able to claim reward', async function () {
      const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
        deployAndTransferRewardToDisperser
      )
      const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners()
      const arr = [owner.address, addr1.address, addr2.address, addr3.address, addr4.address]
      let dataObject: any = {}
      arr.forEach(function (item) {
        dataObject[item] = 250
      })
      const balanceMap = parseBalanceMap(dataObject)
      const merkleRoot = balanceMap.merkleRoot
      await hardhatDisperseToken.setMerkleRoot(merkleRoot)
      const getMerkleRoot = await hardhatDisperseToken.merkleRoot()
      expect(merkleRoot).to.equal(getMerkleRoot)
      const checksumAddr = ethers.utils.getAddress(addr1.address)
      const testClaim = balanceMap.claims[checksumAddr]
      const sampleAddress = '0xdafea492d9c6733ae3d56b7ed1adb60692c98bc5'
      await expect(hardhatDisperseToken.connect(addr2).claim(testClaim.index, sampleAddress, 250, testClaim.proof)).to
        .be.reverted
    })
  })
  describe('Admin withdraw tokens', function () {
    it('Admin should be able to withdraw remaining tokens after redemption expiry', async function () {
      const { hardhatDisperseToken, disperseTokenAddresss, hardhatRewardToken, rewardTokenAddress } = await loadFixture(
        deployAndTransferRewardToDisperserWithExpiry
      )
      const [owner] = await ethers.getSigners()
      await getTimeout()
      const contractBalanceBefore = await hardhatRewardToken.functions.balanceOf(disperseTokenAddresss)
      const tx = await hardhatDisperseToken.withdraw()
      await expect(tx).not.to.be.reverted
      const adminBalanceAfter = await hardhatRewardToken.functions.balanceOf(owner.address)
      const cbString = contractBalanceBefore.toString()
      const abAfter = adminBalanceAfter.toString()
      expect(cbString).to.equal(abAfter)
    })
  })
})
