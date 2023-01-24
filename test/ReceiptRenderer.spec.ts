import {expect} from 'chai'
import { Contract } from 'ethers';
import {ethers, upgrades} from 'hardhat'

describe('ReceiptRenderer Contract', async () => {
  let ReceiptRenderer: Contract,
  deployedReceiptRenderer: Contract

  beforeEach(async () => {
    ReceiptRenderer = await ethers.getContractFactory('ReceiptRenderer')

    deployedReceiptRenderer = await ReceiptRenderer.deploy()
    await deployedReceiptRenderer.deployed()
  })

  describe('generateTokenURI', () => {
    it('has the correct metadata', async () => {
      let base64encoded = await deployedReceiptRenderer.generateTokenURI(100, "questid123", 500, true, 1000, "0xC4a68e2c152bCA2fE5E8D26FFb8AA44bCE1B56b0");

      let buff = Buffer.from(base64encoded.replace("data:application/json;base64,", ""), 'base64');
      let metadata = buff.toString('ascii');
      console.log('here:', metadata)

      let expectedMetada = {
        "name": "RabbitHole.gg Receipt #100",
        "description": "RabbitHole.gg Receipts are used to claim rewards from completed quests.",
        "image": "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHByZXNlcnZlQXNwZWN0UmF0aW89InhNaW5ZTWluIG1lZXQiIHZpZXdCb3g9IjAgMCAzNTAgMzUwIj48c3R5bGU+LmJhc2UgeyBmaWxsOiB3aGl0ZTsgZm9udC1mYW1pbHk6IHNlcmlmOyBmb250LXNpemU6IDE0cHg7IH08L3N0eWxlPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9ImJsYWNrIiAvPjx0ZXh0IHg9IjUwJSIgeT0iNDAlIiBjbGFzcz0iYmFzZSIgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+UmFiYml0SG9sZSBRdWVzdCAjcXVlc3RpZDEyMzwvdGV4dD48dGV4dCB4PSI3MCUiIHk9IjQwJSIgY2xhc3M9ImJhc2UiIGRvbWluYW50LWJhc2VsaW5lPSJtaWRkbGUiIHRleHQtYW5jaG9yPSJtaWRkbGUiPlJhYmJpdEhvbGUgUXVlc3QgUmVjZWlwdCAjAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGQ8L3RleHQ+PC9zdmc+",
        "attributes":
        [
          {
            "trait_type": "Quest ID",
            "value": "questid123"
          },
          {
            "trait_type": "Token ID",
            "value": "100"
          },
          {
            "trait_type": "Total Participants",
            "value": "500"
          },
          {
            "trait_type": "Claimed",
            "value": "true"
          },
          {
            "trait_type": "Reward Amount",
            "value": "1000"
          },
          {
            "trait_type": "Reward Address",
            "value": "0xc4a68e2c152bca2fe5e8d26ffb8aa44bce1b56b0"
          }
        ]
      }

      expect(JSON.parse(metadata)).to.eql(expectedMetada);
    })
  })
})
