import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers, upgrades } from 'hardhat'

describe('QuestTerminalDiscount Contract', async () => {
  let questTerminalDiscount: Contract,
    contractOwner: { address: String },
    royaltyRecipient: { address: String },
    minterAddress: { address: String },
    firstAddress: { address: String }

  beforeEach(async () => {
    ;[contractOwner, royaltyRecipient, minterAddress, firstAddress] = await ethers.getSigners()
    const QuestTerminalDiscount = await ethers.getContractFactory('QuestTerminalDiscount')

    questTerminalDiscount = await upgrades.deployProxy(QuestTerminalDiscount, [
      royaltyRecipient.address,
      minterAddress.address,
      10,
      contractOwner.address,
    ])
  })

  describe('Deployment', () => {
    it('deploys and initializes the the 721 correctly', async () => {
      expect(await questTerminalDiscount.symbol()).to.equal('QTD')
      expect(await questTerminalDiscount.name()).to.equal('QuestTerminalDiscount')
      expect(await questTerminalDiscount.minterAddress()).to.equal(minterAddress.address)
      expect(await questTerminalDiscount.royaltyRecipient()).to.equal(royaltyRecipient.address)
    })
  })

  describe('mint', () => {
    it('mints a token with correct questId', async () => {
      await questTerminalDiscount.connect(minterAddress).mint(firstAddress.address, 100, 3)
      const discount = await questTerminalDiscount.discounts(1)

      expect(await questTerminalDiscount.balanceOf(firstAddress.address)).to.eq(1)
      expect(discount.percentage).to.eq(100)
      expect(discount.maxUses).to.eq(3)
      expect(await questTerminalDiscount.tokenURI(1)).to.eq('https://api.rabbithole.gg/nft/discount/1')
    })

    it('reverts if not called by minter', async () => {
      await expect(questTerminalDiscount.connect(firstAddress).mint(firstAddress.address, 100, 3)).to.be.revertedWith(
        'Only minter'
      )
    })
  })

  describe('getOwnedTokenIds', () => {
    it('returns the correct token ids', async () => {
      await questTerminalDiscount.connect(minterAddress).mint(firstAddress.address, 100, 3)
      await questTerminalDiscount.connect(minterAddress).mint(firstAddress.address, 100, 3)
      await questTerminalDiscount.connect(minterAddress).mint(firstAddress.address, 100, 3)

      const ownedTokenIds = await questTerminalDiscount.getOwnedTokenIds(firstAddress.address)
      const ownedTokenIdsAsNumbers = ownedTokenIds.map((tokenId: any) => tokenId.toNumber())

      expect(ownedTokenIdsAsNumbers).to.eql([1, 2, 3])
    })
  })
})
