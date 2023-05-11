import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers, upgrades } from 'hardhat'
import { time } from '@nomicfoundation/hardhat-network-helpers'

describe('QuestNFT Contract', async () => {
  let questNFT: Contract,
    questFactory: Contract,
    contractOwner: { address: String },
    royaltyRecipient: { address: String },
    minterAddress: { address: String },
    firstAddress: { address: String },
    expiryDate: number,
    startDate: number

  beforeEach(async () => {
    ;[contractOwner, royaltyRecipient, minterAddress, firstAddress] = await ethers.getSigners()
    const QuestNFT = await ethers.getContractFactory('QuestNFT')
    const QuestFactory = await ethers.getContractFactory('QuestFactory')
    const erc20QuestContract = await ethers.getContractFactory('Quest')

    const deployedErc20Quest = await erc20QuestContract.deploy()

    const latestTime = await time.latest()
    expiryDate = latestTime + 10000
    startDate = latestTime + 10

    questFactory = await upgrades.deployProxy(QuestFactory, [
      royaltyRecipient.address,
      firstAddress.address, // really RH Receipt contract but doesnt matter here
      royaltyRecipient.address,
      deployedErc20Quest.address,
      contractOwner.address,
      firstAddress.address, // really questTerminalKey address but doesnt matter here
    ])

    questNFT = await upgrades.deployProxy(QuestNFT, [
      expiryDate,
      startDate,
      5, // uint256 totalParticipants_,
      'quest1', // string memory questId_,
      100, // uint16 questFee_,
      royaltyRecipient.address, // address protocolFeeRecipient_,
      minterAddress.address, // address minterAddress_,
      '', // string memory jsonSpecCID_, // blank on purpose
      'NFT Name', // string memory name_,
      'NFTN', // string memory symbol_,
      'imageipfs', // string memory imageIPFSHash_
    ])
  })

  describe('Deployment', () => {
    it('deploys and initializes the the 721 correctly', async () => {
      expect(await questNFT.symbol()).to.equal('NFTN')
      expect(await questNFT.name()).to.equal('NFT Name')
      expect(await questNFT.protocolFeeRecipient()).to.equal(royaltyRecipient.address)
    })
  })

  describe('mint', () => {
    it('mints a token with correct questId', async () => {
      await time.setNextBlockTimestamp(startDate + 1)
      const transferAmount = await questNFT.totalTransferAmount()

      await contractOwner.sendTransaction({
        to: questNFT.address,
        value: transferAmount.toNumber(),
      })

      await questNFT.connect(minterAddress).safeMint(firstAddress.address)

      expect(await questNFT.balanceOf(firstAddress.address)).to.eq(1)
      expect(await questNFT.ownerOf(1)).to.eq(firstAddress.address)

      const base64encoded = await questNFT.tokenURI(1)
      const metadata = Buffer.from(base64encoded.replace('data:application/json;base64,', ''), 'base64').toString(
        'ascii'
      )

      const expectedMetadata = {
        name: 'NFT Name',
        description: 'The RabbitHole.gg Quest Completion NFT',
        image: 'ipfs://imageipfs',
        attributes: [], // todo is it okay to remove this key in the opensea metadata?
      }

      expect(JSON.parse(metadata)).to.eql(expectedMetadata)
    })

    it('reverts if not called by minter address', async () => {
      await expect(questNFT.connect(firstAddress).safeMint(firstAddress.address)).to.be.revertedWith(
        'Only minter address'
      )

      // todo test onlyQuestBetweenStartEnd modifier
    })

    // todo test withdrawRemainingTokens fx
    // todo test refund fx
  })
})
