import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers, upgrades } from 'hardhat'

describe('RabbitholeReceipt Contract', async () => {
  let RHReceipt: Contract,
    rabbitHoleReceiptV2: Contract,
    deployedFactoryContract: Contract,
    deployedReceiptRenderer: Contract,
    contractOwner: { address: String },
    royaltyRecipient: { address: String },
    minterAddress: { address: String },
    firstAddress: { address: String }

  beforeEach(async () => {
    ;[contractOwner, royaltyRecipient, minterAddress, firstAddress] = await ethers.getSigners()
    const questFactory = await ethers.getContractFactory('QuestFactory')
    const RabbitHoleReceipt = await ethers.getContractFactory('RabbitHoleReceipt')
    const RabbitHoleReceiptV2 = await ethers.getContractFactory('RabbitHoleReceiptV2')
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

    rabbitHoleReceiptV2 = await upgrades.deployProxy(RabbitHoleReceiptV2, [
      deployedReceiptRenderer.address,
      minterAddress.address,
      contractOwner.address,
    ])

    const erc20QuestContract = await ethers.getContractFactory('Erc20Quest')
    const erc1155QuestContract = await ethers.getContractFactory('Erc1155Quest')
    const rabbitHoleTicketsContract = await ethers.getContractFactory('RabbitHoleTickets')
    const deployedErc20Quest = await erc20QuestContract.deploy()
    const deployedErc1155Quest = await erc1155QuestContract.deploy()
    const deployedRabbitHoleTickets = await rabbitHoleTicketsContract.deploy()

    deployedFactoryContract = await upgrades.deployProxy(questFactory, [
      royaltyRecipient.address,
      RHReceipt.address,
      deployedRabbitHoleTickets.address,
      royaltyRecipient.address,
      deployedErc20Quest.address,
      deployedErc1155Quest.address,
      contractOwner.address,
      rabbitHoleReceiptV2.address,
    ])

    await RHReceipt.setQuestFactory(deployedFactoryContract.address)
    await rabbitHoleReceiptV2.setQuestFactory(deployedFactoryContract.address)
  })

  describe('Deployment', () => {
    it('deploys and initializes the the 721 correctly', async () => {
      expect(await rabbitHoleReceiptV2.symbol()).to.equal('RHR')
      expect(await rabbitHoleReceiptV2.name()).to.equal('RabbitHoleReceiptV2')
      expect(await rabbitHoleReceiptV2.minterAddress()).to.equal(minterAddress.address)
    })
  })

  describe('mint', () => {
    it('mints a token with correct questId', async () => {
      await rabbitHoleReceiptV2.connect(minterAddress).mint(firstAddress.address, 'def456')

      expect(await rabbitHoleReceiptV2.balanceOf(firstAddress.address)).to.eq(1)
      expect(await rabbitHoleReceiptV2.questIdForTokenId(1)).to.eq('def456')
    })

    it('reverts if not called by minter', async () => {
      await expect(rabbitHoleReceiptV2.connect(firstAddress).mint(firstAddress.address, 'def456')).to.be.revertedWith(
        'Only minter'
      )
    })
  })

  describe('Soulbound features', () => {
    it("can't transfer after minting", async () => {
      await rabbitHoleReceiptV2.connect(minterAddress).mint(contractOwner.address, 'abc123')

      await expect(
        rabbitHoleReceiptV2.connect(contractOwner).transferFrom(contractOwner.address, firstAddress.address, 1)
      ).to.be.revertedWith(
        'This is a Soulbound token. It cannot be transferred. It can only be burned by the token owner.'
      )
    })
  })
})
