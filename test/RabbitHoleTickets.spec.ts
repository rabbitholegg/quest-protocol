import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

describe('RabbitholeTickets Contract', async () => {
  let RHTickets: Contract,
    contractOwner: SignerWithAddress,
    royaltyRecipient: SignerWithAddress,
    minterAddress: SignerWithAddress,
    firstAddress: SignerWithAddress

  beforeEach(async () => {
    ;[contractOwner, royaltyRecipient, minterAddress, firstAddress] = await ethers.getSigners()
    const RabbitHoleTickets = await ethers.getContractFactory('RabbitHoleTickets')

    RHTickets = await upgrades.deployProxy(RabbitHoleTickets, [
      royaltyRecipient.address,
      minterAddress.address,
      10,
      contractOwner.address,
      'cid',
      'animationUrlCid',
    ])
  })

  describe('Deployment', () => {
    it('deploys and initializes the the 1155 correctly', async () => {
      expect(await RHTickets.minterAddress()).to.equal(minterAddress.address)
      expect(await RHTickets.royaltyRecipient()).to.equal(royaltyRecipient.address)
    })
  })

  describe('mint', () => {
    it('mints 5 tokens', async () => {
      await RHTickets.connect(minterAddress).mint(firstAddress.address, 1, 5, '0x')

      expect(await RHTickets.balanceOf(firstAddress.address, 1)).to.eq(5)
    })

    it('reverts if not called by minter', async () => {
      await expect(
        RHTickets.connect(firstAddress).mint(firstAddress.address, 1, 5, '0x')
      ).to.be.revertedWithCustomError(RHTickets, 'OnlyMinter')
    })
  })

  describe('mintBatch', () => {
    it('mints 5 tokens with correct questId', async () => {
      await RHTickets.connect(minterAddress).mintBatch(firstAddress.address, [1, 2, 3], [6, 7, 8], '0x')

      expect(await RHTickets.balanceOf(firstAddress.address, 1)).to.eq(6)
      expect(await RHTickets.balanceOf(firstAddress.address, 2)).to.eq(7)
      expect(await RHTickets.balanceOf(firstAddress.address, 3)).to.eq(8)
    })
  })

  describe('uri', () => {
    it('has the correct metadata', async () => {
      await RHTickets.connect(minterAddress).mint(firstAddress.address, 1, 5, '0x')
      let base64encoded = await RHTickets.uri(1)

      let buff = Buffer.from(base64encoded.replace('data:application/json;base64,', ''), 'base64')
      let metadata = buff.toString('ascii')

      console.log(metadata)

      let expectedMetada = {
        name: 'RabbitHole Ticket',
        description: 'RabbitHole Tickets',
        image: 'ipfs://cid',
        animation_url: 'ipfs://animationUrlCid',
      }

      expect(JSON.parse(metadata)).to.eql(expectedMetada)
    })
  })
})
