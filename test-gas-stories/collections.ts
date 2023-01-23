import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { ContractTransaction, utils } from 'ethers'
import { ethers, upgrades } from 'hardhat'
import { story } from './gas-stories'

import {
  QuestFactory,
  QuestFactory__factory,
  Erc20Quest,
  Erc20Quest__factory,
  Erc1155Quest,
  Erc1155Quest__factory,
  SampleERC20,
  SampleERC20__factory,
  SampleErc1155,
  SampleErc1155__factory,
  RabbitHoleReceipt,
  RabbitHoleReceipt__factory,
  ReceiptRenderer,
  ReceiptRenderer__factory,
} from '../typechain-types'
import { TestContracts, deployAll } from '../test/helpers/deploy'

describe('Collections', () => {
  let owner: SignerWithAddress
  let claimAddressSigner: SignerWithAddress
  let contracts: TestContracts
  let questFactory: QuestFactory
  let tx: ContractTransaction

  beforeEach(async () => {
    ;[owner, claimAddressSigner] = await ethers.getSigners()
    contracts = await deployAll(owner, claimAddressSigner)
    await contracts.questFactory.setRewardAllowlistAddress(contracts.sampleErc20.address, true)
    questFactory = contracts.questFactory
  })

  it('Mint Receipt', async () => {
    const questId = 'quest-id'
    const hash = utils.solidityKeccak256(['address', 'string'], [owner.address.toLowerCase(), questId])
    const signature = await claimAddressSigner.signMessage(utils.arrayify(hash))
    tx = await questFactory.mintReceipt(questId, hash, signature)
    await story('QuestFactory', 'Mint Receipt', 'mintReceipt', '1st mint', tx)
  })
})
