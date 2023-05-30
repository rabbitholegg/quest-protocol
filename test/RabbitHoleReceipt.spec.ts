import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers, upgrades } from 'hardhat'

describe('RabbitholeReceipt Contract', async () => {
  let RHReceipt: Contract,
    deployedReceiptRenderer: Contract,
    contractOwner: { address: String },
    royaltyRecipient: { address: String },
    minterAddress: { address: String },
    firstAddress: { address: String }

  beforeEach(async () => {
    ;[contractOwner, royaltyRecipient, minterAddress, firstAddress] = await ethers.getSigners()
    const RabbitHoleReceipt = await ethers.getContractFactory('RabbitHoleReceipt')
    const ReceiptRenderer = await ethers.getContractFactory('ReceiptRenderer')

    deployedReceiptRenderer = await ReceiptRenderer.deploy()
    await deployedReceiptRenderer.deployed()

    RHReceipt = await upgrades.deployProxy(RabbitHoleReceipt, [
      deployedReceiptRenderer.address,
      royaltyRecipient.address,
      minterAddress.address,
      10,
      contractOwner.address,
    ])
  })

  describe('Deployment', () => {
    it('deploys and initializes the the 721 correctly', async () => {
      expect(await RHReceipt.symbol()).to.equal('RHR')
      expect(await RHReceipt.name()).to.equal('RabbitHoleReceipt')
      expect(await RHReceipt.minterAddress()).to.equal(minterAddress.address)
      expect(await RHReceipt.royaltyRecipient()).to.equal(royaltyRecipient.address)
    })
  })

  describe('mint', () => {
    it('mints a token with correct questId', async () => {
      await RHReceipt.connect(minterAddress).mint(firstAddress.address, 'def456')

      expect(await RHReceipt.balanceOf(firstAddress.address)).to.eq(1)
      expect(await RHReceipt.questIdForTokenId(1)).to.eq('def456')
    })

    it('reverts if not called by minter', async () => {
      await expect(RHReceipt.connect(firstAddress).mint(firstAddress.address, 'def456')).to.be.revertedWith(
        'Only minter'
      )
    })
  })

  describe('getOwnedTokenIdsOfQuest', () => {
    it('returns the correct tokenIds', async () => {
      await RHReceipt.connect(minterAddress).mint(contractOwner.address, 'abc123')
      await RHReceipt.connect(minterAddress).mint(contractOwner.address, 'def456')
      await RHReceipt.connect(minterAddress).mint(contractOwner.address, 'eeeeee')

      let tokenIds = await RHReceipt.getOwnedTokenIdsOfQuest('abc123', contractOwner.address)

      expect(tokenIds.length).to.eq(1)
      expect(tokenIds[0].toNumber()).to.eql(1)
    })
  })
})
