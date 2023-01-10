import {expect} from 'chai'
import { Contract } from 'ethers';
import {ethers, upgrades} from 'hardhat'

describe('RabbitholeTickets Contract', async () => {
  let RHTickets: Contract,
    contractOwner: { address: String; },
    royaltyRecipient: { address: String; },
    minterAddress: { address: String; },
    firstAddress: { address: String; };

  beforeEach(async () => {
    [contractOwner, royaltyRecipient, minterAddress, firstAddress] = await ethers.getSigners();
    const RabbitHoleTickets = await ethers.getContractFactory('RabbitHoleTickets')

    RHTickets = await upgrades.deployProxy(RabbitHoleTickets, [
      royaltyRecipient.address,
      minterAddress.address,
      10
    ])
  })

  describe('Deployment', () => {
    it('deploys and initializes the the 1155 correctly', async () => {
      expect(await RHTickets.minterAddress()).to.equal(minterAddress.address)
      expect(await RHTickets.royaltyRecipient()).to.equal(royaltyRecipient.address)
    })
  })

  describe('mint', () => {
    it('mints 5 tokens with correct questId', async () => {
      await RHTickets.connect(minterAddress).mint("quest123", firstAddress.address, 1, 5, "0x");

      expect(await RHTickets.balanceOf(firstAddress.address, 1)).to.eq(5);
      expect(await RHTickets.questIdForTokenId(1)).to.eq("quest123");
    })

    it('mints tokens twice correct questId', async () => {
      await RHTickets.connect(minterAddress).mint("quest123", firstAddress.address, 1, 5, "0x");
      expect(await RHTickets.questIdForTokenId(1)).to.eq("quest123");

      await RHTickets.connect(minterAddress).mint("notthis", firstAddress.address, 1, 5, "0x");
      expect(await RHTickets.questIdForTokenId(1)).to.eq("quest123");
    })
  })

  describe('mintBatch', () => {
    it('mints 5 tokens with correct questId', async () => {
      await RHTickets.connect(minterAddress).mintBatch(["quest1", "quest2", "quest3"], firstAddress.address, [1,2,3], [6,7,8], "0x");

      expect(await RHTickets.balanceOf(firstAddress.address, 1)).to.eq(6);
      expect(await RHTickets.balanceOf(firstAddress.address, 2)).to.eq(7);
      expect(await RHTickets.balanceOf(firstAddress.address, 3)).to.eq(8);
      expect(await RHTickets.questIdForTokenId(1)).to.eq("quest1");
      expect(await RHTickets.questIdForTokenId(2)).to.eq("quest2");
      expect(await RHTickets.questIdForTokenId(3)).to.eq("quest3");
    })

    it('mints tokens twice correct questId', async () => {
      await RHTickets.connect(minterAddress).mintBatch(["quest1", "quest2", "quest3"], firstAddress.address, [1,2,3], [6,7,8], "0x");
      expect(await RHTickets.questIdForTokenId(1)).to.eq("quest1");

      await RHTickets.connect(minterAddress).mintBatch(["quest100", "quest200", "quest300"], firstAddress.address, [1,2,3], [6,7,8], "0x");
      expect(await RHTickets.questIdForTokenId(1)).to.eq("quest1");
      expect(await RHTickets.questIdForTokenId(2)).to.eq("quest2");
      expect(await RHTickets.questIdForTokenId(3)).to.eq("quest3");
    })
  })

  describe('uri', () => {
    it('has the correct metadata', async () => {
      await RHTickets.connect(minterAddress).mint("quest123", firstAddress.address, 1, 5, "0x");
      let base64encoded = await RHTickets.uri(1);

      let buff = Buffer.from(base64encoded.replace("data:application/json;base64,", ""), 'base64');
      let metadata = buff.toString('ascii');

      let expectedMetada = {
        "name": "RabbitHole Tickets #quest123 Redeemer #1",
        "description": "A reward for completing quests within RabbitHole, with unk(no)wn utility",
        "image": "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHByZXNlcnZlQXNwZWN0UmF0aW89InhNaW5ZTWluIG1lZXQiIHZpZXdCb3g9IjAgMCAzNTAgMzUwIj48c3R5bGU+LmJhc2UgeyBmaWxsOiB3aGl0ZTsgZm9udC1mYW1pbHk6IHNlcmlmOyBmb250LXNpemU6IDE0cHg7IH08L3N0eWxlPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9ImJsYWNrIiAvPjx0ZXh0IHg9IjUwJSIgeT0iNDAlIiBjbGFzcz0iYmFzZSIgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+UmFiYml0SG9sZSBUaWNrZXRzICNxdWVzdDEyMzwvdGV4dD48dGV4dCB4PSI3MCUiIHk9IjQwJSIgY2xhc3M9ImJhc2UiIGRvbWluYW50LWJhc2VsaW5lPSJtaWRkbGUiIHRleHQtYW5jaG9yPSJtaWRkbGUiPlJhYmJpdEhvbGUgVGlja2V0cyBSZWNlaXB0ICMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATwvdGV4dD48L3N2Zz4="
      }

      expect(JSON.parse(metadata)).to.eql(expectedMetada);
    })
  })
})
