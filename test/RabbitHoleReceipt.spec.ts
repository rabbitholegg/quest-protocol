import {expect} from 'chai'
import { Contract } from 'ethers';
import {ethers, upgrades} from 'hardhat'

describe('RabbitholeReceipt Contract', async () => {
  let RHReceipt: Contract,
    contractOwner: { address: String; },
    royaltyRecipient: { address: String; },
    minterAddress: { address: String; };

  beforeEach(async () => {
    [contractOwner, royaltyRecipient, minterAddress] = await ethers.getSigners();
    const RabbitHoleReceipt = await ethers.getContractFactory('RabbitHoleReceipt')

    RHReceipt = await upgrades.deployProxy(RabbitHoleReceipt, [
      royaltyRecipient.address,
      minterAddress.address,
      10
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
    it('mints 5 tokens with correct questId', async () => {
      await RHReceipt.connect(minterAddress).mint(5, "def456");

      expect(await RHReceipt.balanceOf(minterAddress.address)).to.eq(5);
      expect(await RHReceipt.questIdForTokenId(1)).to.eq("def456");
    })
  })

  describe('tokenURI', () => {
    it('has the correct metadata', async () => {
      await RHReceipt.connect(minterAddress).mint(1, "abc123");
      let base64encoded = await RHReceipt.tokenURI(1);

      let buff = Buffer.from(base64encoded.replace("data:application/json;base64,", ""), 'base64');
      let metadata = buff.toString('ascii');

      let expectedMetada = {
        "name": "RabbitHole Quest #abc123 Redeemer #1",
        "description": "This is a receipt for a RabbitHole Quest. You can use this receipt to claim a reward on RabbitHole.",
        "image": "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAwIiBoZWlnaHQ9IjEwMDAiPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9IiMwMDAwMDAiIC8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGRvbWluYW50LWJhc2VsaW5lPSJtaWRkbGUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTAwIiBmaWxsPSIjZmZmZmZmIj5SYWJiaXRIb2xlPC90ZXh0Pjwvc3ZnPg=="
      }

      expect(JSON.parse(metadata)).to.eql(expectedMetada);
    })
  })

  describe('getOwnedTokenIdsOfQuest', () => {
    it('returns the correct tokenIds', async () => {
      await RHReceipt.mint(3, "abc123");
      await RHReceipt.mint(2, "def456");
      await RHReceipt.mint(4, "eeeeee");

      let tokenIds = await RHReceipt.getOwnedTokenIdsOfQuest("abc123", contractOwner.address);

      expect(tokenIds.length).to.eq(3);
      expect(tokenIds.map((tokenId) => tokenId.toNumber())).to.eql([1, 2, 3]);
    })
  })
})
