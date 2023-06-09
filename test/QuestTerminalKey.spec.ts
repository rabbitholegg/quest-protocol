import { expect } from 'chai'
import { Contract, Wallet, utils } from 'ethers'
import { ethers, upgrades } from 'hardhat'
const mnemonic = 'announce room limb pattern dry unit scale effort smooth jazz weasel alcohol'
const mnemonic2 = 'indoor dish desk flag debris potato excuse depart ticket judge file exit'

describe('QuestTerminalKey Contract', async () => {
  let questTerminalKey: Contract,
    wallet: Wallet,
    wallet2: Wallet,
    contractOwner: { address: String },
    royaltyRecipient: { address: String },
    minterAddress: { address: String },
    firstAddress: { address: String }

  beforeEach(async () => {
    ;[contractOwner, royaltyRecipient, minterAddress, firstAddress] = await ethers.getSigners()
    const QuestTerminalKey = await ethers.getContractFactory('QuestTerminalKey')
    wallet = Wallet.fromMnemonic(mnemonic)
    wallet2 = Wallet.fromMnemonic(mnemonic2)

    questTerminalKey = await upgrades.deployProxy(QuestTerminalKey, [
      royaltyRecipient.address,
      minterAddress.address,
      ethers.constants.AddressZero, // this is questFactory address, but not needed here
      10,
      contractOwner.address,
      'QmTy8w65yBXgyfG2ZBg5TrfB2hPjrDQH3RCQFJGkARStJb',
      'QmcniBv7UQ4gGPQQW2BwbD4ZZHzN3o3tPuNLZCbBchd1zh',
      wallet.address,
    ])
  })

  describe('Deployment', () => {
    it('deploys and initializes the the 721 correctly', async () => {
      expect(await questTerminalKey.symbol()).to.equal('QTK')
      expect(await questTerminalKey.name()).to.equal('QuestTerminalKey')
      expect(await questTerminalKey.minterAddress()).to.equal(minterAddress.address)
      expect(await questTerminalKey.royaltyRecipient()).to.equal(royaltyRecipient.address)
    })
  })

  describe('mint', () => {
    it('mints a token with correct questId', async () => {
      await questTerminalKey.connect(minterAddress).mint(firstAddress.address, 1000)
      const discount = await questTerminalKey.discounts(1)

      expect(await questTerminalKey.balanceOf(firstAddress.address)).to.eq(1)
      expect(await questTerminalKey.ownerOf(1)).to.eq(firstAddress.address)
      expect(discount.percentage).to.eq(1000)
      expect(discount.usedCount).to.eq(0)

      const base64encoded = await questTerminalKey.tokenURI(1)
      const metadata = Buffer.from(base64encoded.replace('data:application/json;base64,', ''), 'base64').toString(
        'ascii'
      )

      const expectedMetadata = {
        name: 'Quest Terminal Key',
        description: 'A key that can be used to create quests in the Quest Terminal',
        image: 'ipfs://QmTy8w65yBXgyfG2ZBg5TrfB2hPjrDQH3RCQFJGkARStJb',
        animation_url: 'ipfs://QmcniBv7UQ4gGPQQW2BwbD4ZZHzN3o3tPuNLZCbBchd1zh',
        attributes: [
          { trait_type: 'Discount Percentage BPS', value: '1000' },
          { trait_type: 'Discount Used Count', value: '0' },
        ],
      }

      expect(JSON.parse(metadata)).to.eql(expectedMetadata)
    })

    it('reverts if not called by minter', async () => {
      await expect(questTerminalKey.connect(firstAddress).mint(firstAddress.address, 1000)).to.be.revertedWith(
        'Only minter'
      )
    })
  })

  describe('bulkMintNoDiscount', () => {
    it('mints a token with correct questId', async () => {
      await questTerminalKey
        .connect(minterAddress)
        .bulkMintNoDiscount([firstAddress.address, firstAddress.address, firstAddress.address])

      expect(await questTerminalKey.balanceOf(firstAddress.address)).to.eq(3)
    })

    it('reverts if not called by minter', async () => {
      await expect(
        questTerminalKey.connect(firstAddress).bulkMintNoDiscount([firstAddress.address])
      ).to.be.revertedWith('Only minter')
    })
  })

  describe('lazyMint', () => {
    it('mints a token with correct questId', async () => {
      let messageHash = utils.solidityKeccak256(['address', 'uint16'], [firstAddress.address.toLowerCase(), 1000])
      let signature = await wallet.signMessage(utils.arrayify(messageHash))

      await questTerminalKey.lazyMint(firstAddress.address, 1000, messageHash, signature)
      const discount = await questTerminalKey.discounts(1)

      expect(await questTerminalKey.balanceOf(firstAddress.address)).to.eq(1)
      expect(await questTerminalKey.ownerOf(1)).to.eq(firstAddress.address)
      expect(discount.percentage).to.eq(1000)
      expect(discount.usedCount).to.eq(0)

      const base64encoded = await questTerminalKey.tokenURI(1)
      const metadata = Buffer.from(base64encoded.replace('data:application/json;base64,', ''), 'base64').toString(
        'ascii'
      )

      const expectedMetadata = {
        name: 'Quest Terminal Key',
        description: 'A key that can be used to create quests in the Quest Terminal',
        image: 'ipfs://QmTy8w65yBXgyfG2ZBg5TrfB2hPjrDQH3RCQFJGkARStJb',
        animation_url: 'ipfs://QmcniBv7UQ4gGPQQW2BwbD4ZZHzN3o3tPuNLZCbBchd1zh',
        attributes: [
          { trait_type: 'Discount Percentage BPS', value: '1000' },
          { trait_type: 'Discount Used Count', value: '0' },
        ],
      }

      expect(JSON.parse(metadata)).to.eql(expectedMetadata)
    })

    it('reverts if not signed by correct claimSignerAddress', async () => {
      let messageHash = utils.solidityKeccak256(['address', 'uint16'], [firstAddress.address.toLowerCase(), 1000])
      let signature = await wallet2.signMessage(utils.arrayify(messageHash))

      await expect(questTerminalKey.lazyMint(firstAddress.address, 1000, messageHash, signature)).to.be.revertedWith(
        'Address not signed'
      )
    })
  })

  describe('getOwnedTokenIds', () => {
    it('returns the correct token ids', async () => {
      await questTerminalKey.connect(minterAddress).mint(firstAddress.address, 1000)
      await questTerminalKey.connect(minterAddress).mint(firstAddress.address, 1000)
      await questTerminalKey.connect(minterAddress).mint(firstAddress.address, 1000)

      const ownedTokenIds = await questTerminalKey.getOwnedTokenIds(firstAddress.address)
      const ownedTokenIdsAsNumbers = ownedTokenIds.map((tokenId: any) => tokenId.toNumber())

      expect(ownedTokenIdsAsNumbers).to.eql([1, 2, 3])
    })
  })
})
