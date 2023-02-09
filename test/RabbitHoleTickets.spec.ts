import {expect} from 'chai'
import { Contract } from 'ethers';
import {ethers, upgrades} from 'hardhat'

describe('RabbitholeTickets Contract', async () => {
  let RHTickets: Contract,
  deployedTicketRenderer: Contract,
    contractOwner: { address: String; },
    royaltyRecipient: { address: String; },
    minterAddress: { address: String; },
    firstAddress: { address: String; };

  beforeEach(async () => {
    [contractOwner, royaltyRecipient, minterAddress, firstAddress] = await ethers.getSigners();
    const RabbitHoleTickets = await ethers.getContractFactory('RabbitHoleTickets')
    const TicketRenderer = await ethers.getContractFactory('TicketRenderer')

    deployedTicketRenderer = await TicketRenderer.deploy()
    await deployedTicketRenderer.deployed()

    RHTickets = await upgrades.deployProxy(RabbitHoleTickets, [
      deployedTicketRenderer.address,
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
    it('mints 5 tokens', async () => {
      await RHTickets.connect(minterAddress).mint(firstAddress.address, 1, 5, "0x");

      expect(await RHTickets.balanceOf(firstAddress.address, 1)).to.eq(5);
    })

    it('reverts if not called by minter', async () => {
      await expect(RHTickets.connect(firstAddress).mint(firstAddress.address, 1, 5, '0x')).to.be.revertedWith(
        'Only minter'
      )
    })
  })

  describe('mintBatch', () => {
    it('mints 5 tokens with correct questId', async () => {
      await RHTickets.connect(minterAddress).mintBatch(firstAddress.address, [1,2,3], [6,7,8], "0x");

      expect(await RHTickets.balanceOf(firstAddress.address, 1)).to.eq(6);
      expect(await RHTickets.balanceOf(firstAddress.address, 2)).to.eq(7);
      expect(await RHTickets.balanceOf(firstAddress.address, 3)).to.eq(8);
    })
  })

  describe('uri', () => {
    it('has the correct metadata', async () => {
      await RHTickets.connect(minterAddress).mint(firstAddress.address, 1, 5, "0x");
      let base64encoded = await RHTickets.uri(1);

      let buff = Buffer.from(base64encoded.replace("data:application/json;base64,", ""), 'base64');
      let metadata = buff.toString('ascii');

      let expectedMetada = {
        "name": "RabbitHole Tickets #1",
        "description": "A reward for completing quests within RabbitHole, with unk(no)wn utility",
        "image": "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHByZXNlcnZlQXNwZWN0UmF0aW89InhNaW5ZTWluIG1lZXQiIHZpZXdCb3g9IjAgMCAzNTAgMzUwIj48c3R5bGU+LmJhc2UgeyBmaWxsOiB3aGl0ZTsgZm9udC1mYW1pbHk6IHNlcmlmOyBmb250LXNpemU6IDE0cHg7IH08L3N0eWxlPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9ImJsYWNrIiAvPjx0ZXh0IHg9IjUwJSIgeT0iNDAlIiBjbGFzcz0iYmFzZSIgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+UmFiYml0SG9sZSBUaWNrZXRzICMxPC90ZXh0Pjwvc3ZnPg=="
      }

      expect(JSON.parse(metadata)).to.eql(expectedMetada);
    })
  })
})
