import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { ContractTransaction, utils } from 'ethers'
import { ethers } from 'hardhat'
import { story } from './gas-stories'

import {
  Quest,
  QuestFactory,
  QuestNFT,
  QuestTerminalKey,
  RabbitHoleReceipt,
  ReceiptRenderer,
  SampleERC20,
} from '../typechain-types'
import { TestContracts, deployAll } from '../test/helpers/deploy'

describe('Collections', () => {
  let owner: SignerWithAddress
  let claimAddressSigner: SignerWithAddress
  let firstAddress: SignerWithAddress
  let secondAddress: SignerWithAddress
  let contracts: TestContracts
  let questFactory: QuestFactory
  let sampleErc20: SampleERC20
  let erc20Quest: Quest
  let tx: ContractTransaction
  let createQuestAndQuestTx: ContractTransaction
  const questId = 'quest-id'
  const nftQuestId = 'nft-quest-id'
  const totalParticipants = 1000
  let expiryDate
  let startDate

  beforeEach(async () => {
    ;[owner, claimAddressSigner, firstAddress, secondAddress] = await ethers.getSigners()
    contracts = await deployAll(owner, claimAddressSigner)
    questFactory = contracts.questFactory
    sampleErc20 = contracts.sampleErc20
    await contracts.questFactory.setRewardAllowlistAddress(sampleErc20.address, true)

    const latestTime = await time.latest()
    expiryDate = latestTime + 10000
    startDate = latestTime + 100
    await time.setNextBlockTimestamp(startDate + 1)

    createQuestAndQuestTx = await createQuestAndQueue()
  })

  const createQuestAndQueue = async () => {
    const rewardAmount = 10
    const totalRewards = 100
    const maxTotalRewards = totalRewards * rewardAmount
    const maxProtocolReward = (maxTotalRewards * 2_000) / 10_000
    const transferAmount = maxTotalRewards + maxProtocolReward

    await sampleErc20.approve(questFactory.address, transferAmount)
    const tx = await questFactory.createQuestAndQueue(
      sampleErc20.address,
      expiryDate,
      startDate,
      totalRewards,
      rewardAmount,
      questId,
      '',
      0
    )

    return tx
  }

  it('Claim Rewards without a receipt', async () => {
    await createQuestAndQuestTx.wait()
    let hash = utils.solidityKeccak256(['address', 'string'], [firstAddress.address.toLowerCase(), questId])
    let signature = await claimAddressSigner.signMessage(utils.arrayify(hash))
    tx = await questFactory.connect(firstAddress).claimRewards(questId, hash, signature)
    await story('QuestFactory', 'Claim Rewards', 'claimRewards', 'claim rewards', tx)
  })

  it('Create quest and queue', async () => {
    const rewardAmount = 10
    const totalRewards = 100
    const maxTotalRewards = totalRewards * rewardAmount
    const maxProtocolReward = (maxTotalRewards * 2_000) / 10_000
    const transferAmount = maxTotalRewards + maxProtocolReward
    const tenActionSpec = {
      participants: {
        include: 'ipfs://bafkreia2hlluvhgpzaf7uhlrrq5fwd55tomprz6fsez2u76xeeasovepym',
      },
      actions: {
        $and: [
          {
            chainId: '0xa',
            to: '0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad',
            input: {
              $abi: [
                {
                  inputs: [
                    { internalType: 'bytes', name: 'commands', type: 'bytes' },
                    { internalType: 'bytes[]', name: 'inputs', type: 'bytes[]' },
                    { internalType: 'uint256', name: 'deadline', type: 'uint256' },
                  ],
                  name: 'execute',
                  outputs: [],
                  stateMutability: 'payable',
                  type: 'function',
                },
              ],
              sighash: '0x3593564c',
              commands: '0x00',
              inputs: {
                $some: {
                  $abiParams: [
                    'address recipient',
                    'uint256 amountIn',
                    'uint256 amountOut',
                    'bytes path',
                    'bool payerIsUser',
                  ],
                  amountOut: { $gte: '0x4c4b400' },
                  path: {
                    $and: [
                      { $regex: '^0x9e1028f5f1d5ede59748ffcee5532509976840e0' },
                      { $regex: '.*7f5c764cbc14f9669b88837ca1490cca17c31607$' },
                    ],
                  },
                },
              },
            },
          },
          {
            chainId: '0xa',
            to: '0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad',
            input: {
              $abi: [
                {
                  inputs: [
                    { internalType: 'bytes', name: 'commands', type: 'bytes' },
                    { internalType: 'bytes[]', name: 'inputs', type: 'bytes[]' },
                    { internalType: 'uint256', name: 'deadline', type: 'uint256' },
                  ],
                  name: 'execute',
                  outputs: [],
                  stateMutability: 'payable',
                  type: 'function',
                },
              ],
              sighash: '0x3593564c',
              commands: '0x00',
              inputs: {
                $some: {
                  $abiParams: [
                    'address recipient',
                    'uint256 amountIn',
                    'uint256 amountOut',
                    'bytes path',
                    'bool payerIsUser',
                  ],
                  amountOut: { $gte: '0x4c4b400' },
                  path: {
                    $and: [
                      { $regex: '^0x9e1028f5f1d5ede59748ffcee5532509976840e0' },
                      { $regex: '.*7f5c764cbc14f9669b88837ca1490cca17c31607$' },
                    ],
                  },
                },
              },
            },
          },
          {
            chainId: '0xa',
            to: '0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad',
            input: {
              $abi: [
                {
                  inputs: [
                    { internalType: 'bytes', name: 'commands', type: 'bytes' },
                    { internalType: 'bytes[]', name: 'inputs', type: 'bytes[]' },
                    { internalType: 'uint256', name: 'deadline', type: 'uint256' },
                  ],
                  name: 'execute',
                  outputs: [],
                  stateMutability: 'payable',
                  type: 'function',
                },
              ],
              sighash: '0x3593564c',
              commands: '0x00',
              inputs: {
                $some: {
                  $abiParams: [
                    'address recipient',
                    'uint256 amountIn',
                    'uint256 amountOut',
                    'bytes path',
                    'bool payerIsUser',
                  ],
                  amountOut: { $gte: '0x4c4b400' },
                  path: {
                    $and: [
                      { $regex: '^0x9e1028f5f1d5ede59748ffcee5532509976840e0' },
                      { $regex: '.*7f5c764cbc14f9669b88837ca1490cca17c31607$' },
                    ],
                  },
                },
              },
            },
          },
          {
            chainId: '0xa',
            to: '0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad',
            input: {
              $abi: [
                {
                  inputs: [
                    { internalType: 'bytes', name: 'commands', type: 'bytes' },
                    { internalType: 'bytes[]', name: 'inputs', type: 'bytes[]' },
                    { internalType: 'uint256', name: 'deadline', type: 'uint256' },
                  ],
                  name: 'execute',
                  outputs: [],
                  stateMutability: 'payable',
                  type: 'function',
                },
              ],
              sighash: '0x3593564c',
              commands: '0x00',
              inputs: {
                $some: {
                  $abiParams: [
                    'address recipient',
                    'uint256 amountIn',
                    'uint256 amountOut',
                    'bytes path',
                    'bool payerIsUser',
                  ],
                  amountOut: { $gte: '0x4c4b400' },
                  path: {
                    $and: [
                      { $regex: '^0x9e1028f5f1d5ede59748ffcee5532509976840e0' },
                      { $regex: '.*7f5c764cbc14f9669b88837ca1490cca17c31607$' },
                    ],
                  },
                },
              },
            },
          },
          {
            chainId: '0xa',
            to: '0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad',
            input: {
              $abi: [
                {
                  inputs: [
                    { internalType: 'bytes', name: 'commands', type: 'bytes' },
                    { internalType: 'bytes[]', name: 'inputs', type: 'bytes[]' },
                    { internalType: 'uint256', name: 'deadline', type: 'uint256' },
                  ],
                  name: 'execute',
                  outputs: [],
                  stateMutability: 'payable',
                  type: 'function',
                },
              ],
              sighash: '0x3593564c',
              commands: '0x00',
              inputs: {
                $some: {
                  $abiParams: [
                    'address recipient',
                    'uint256 amountIn',
                    'uint256 amountOut',
                    'bytes path',
                    'bool payerIsUser',
                  ],
                  amountOut: { $gte: '0x4c4b400' },
                  path: {
                    $and: [
                      { $regex: '^0x9e1028f5f1d5ede59748ffcee5532509976840e0' },
                      { $regex: '.*7f5c764cbc14f9669b88837ca1490cca17c31607$' },
                    ],
                  },
                },
              },
            },
          },
          {
            chainId: '0xa',
            to: '0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad',
            input: {
              $abi: [
                {
                  inputs: [
                    { internalType: 'bytes', name: 'commands', type: 'bytes' },
                    { internalType: 'bytes[]', name: 'inputs', type: 'bytes[]' },
                    { internalType: 'uint256', name: 'deadline', type: 'uint256' },
                  ],
                  name: 'execute',
                  outputs: [],
                  stateMutability: 'payable',
                  type: 'function',
                },
              ],
              sighash: '0x3593564c',
              commands: '0x00',
              inputs: {
                $some: {
                  $abiParams: [
                    'address recipient',
                    'uint256 amountIn',
                    'uint256 amountOut',
                    'bytes path',
                    'bool payerIsUser',
                  ],
                  amountOut: { $gte: '0x4c4b400' },
                  path: {
                    $and: [
                      { $regex: '^0x9e1028f5f1d5ede59748ffcee5532509976840e0' },
                      { $regex: '.*7f5c764cbc14f9669b88837ca1490cca17c31607$' },
                    ],
                  },
                },
              },
            },
          },
          {
            chainId: '0xa',
            to: '0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad',
            input: {
              $abi: [
                {
                  inputs: [
                    { internalType: 'bytes', name: 'commands', type: 'bytes' },
                    { internalType: 'bytes[]', name: 'inputs', type: 'bytes[]' },
                    { internalType: 'uint256', name: 'deadline', type: 'uint256' },
                  ],
                  name: 'execute',
                  outputs: [],
                  stateMutability: 'payable',
                  type: 'function',
                },
              ],
              sighash: '0x3593564c',
              commands: '0x00',
              inputs: {
                $some: {
                  $abiParams: [
                    'address recipient',
                    'uint256 amountIn',
                    'uint256 amountOut',
                    'bytes path',
                    'bool payerIsUser',
                  ],
                  amountOut: { $gte: '0x4c4b400' },
                  path: {
                    $and: [
                      { $regex: '^0x9e1028f5f1d5ede59748ffcee5532509976840e0' },
                      { $regex: '.*7f5c764cbc14f9669b88837ca1490cca17c31607$' },
                    ],
                  },
                },
              },
            },
          },
          {
            chainId: '0xa',
            to: '0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad',
            input: {
              $abi: [
                {
                  inputs: [
                    { internalType: 'bytes', name: 'commands', type: 'bytes' },
                    { internalType: 'bytes[]', name: 'inputs', type: 'bytes[]' },
                    { internalType: 'uint256', name: 'deadline', type: 'uint256' },
                  ],
                  name: 'execute',
                  outputs: [],
                  stateMutability: 'payable',
                  type: 'function',
                },
              ],
              sighash: '0x3593564c',
              commands: '0x00',
              inputs: {
                $some: {
                  $abiParams: [
                    'address recipient',
                    'uint256 amountIn',
                    'uint256 amountOut',
                    'bytes path',
                    'bool payerIsUser',
                  ],
                  amountOut: { $gte: '0x4c4b400' },
                  path: {
                    $and: [
                      { $regex: '^0x9e1028f5f1d5ede59748ffcee5532509976840e0' },
                      { $regex: '.*7f5c764cbc14f9669b88837ca1490cca17c31607$' },
                    ],
                  },
                },
              },
            },
          },
          {
            chainId: '0xa',
            to: '0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad',
            input: {
              $abi: [
                {
                  inputs: [
                    { internalType: 'bytes', name: 'commands', type: 'bytes' },
                    { internalType: 'bytes[]', name: 'inputs', type: 'bytes[]' },
                    { internalType: 'uint256', name: 'deadline', type: 'uint256' },
                  ],
                  name: 'execute',
                  outputs: [],
                  stateMutability: 'payable',
                  type: 'function',
                },
              ],
              sighash: '0x3593564c',
              commands: '0x00',
              inputs: {
                $some: {
                  $abiParams: [
                    'address recipient',
                    'uint256 amountIn',
                    'uint256 amountOut',
                    'bytes path',
                    'bool payerIsUser',
                  ],
                  amountOut: { $gte: '0x4c4b400' },
                  path: {
                    $and: [
                      { $regex: '^0x9e1028f5f1d5ede59748ffcee5532509976840e0' },
                      { $regex: '.*7f5c764cbc14f9669b88837ca1490cca17c31607$' },
                    ],
                  },
                },
              },
            },
          },
          {
            chainId: '0xa',
            to: '0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad',
            input: {
              $abi: [
                {
                  inputs: [
                    { internalType: 'bytes', name: 'commands', type: 'bytes' },
                    { internalType: 'bytes[]', name: 'inputs', type: 'bytes[]' },
                    { internalType: 'uint256', name: 'deadline', type: 'uint256' },
                  ],
                  name: 'execute',
                  outputs: [],
                  stateMutability: 'payable',
                  type: 'function',
                },
              ],
              sighash: '0x3593564c',
              commands: '0x00',
              inputs: {
                $some: {
                  $abiParams: [
                    'address recipient',
                    'uint256 amountIn',
                    'uint256 amountOut',
                    'bytes path',
                    'bool payerIsUser',
                  ],
                  amountOut: { $gte: '0x4c4b400' },
                  path: {
                    $and: [
                      { $regex: '^0x9e1028f5f1d5ede59748ffcee5532509976840e0' },
                      { $regex: '.*7f5c764cbc14f9669b88837ca1490cca17c31607$' },
                    ],
                  },
                },
              },
            },
          },
        ],
      },
    }
    const oneActionSpec = {
      chainId: '0xa',
      to: '0x3fc91a3afd70395cd496c647d5a6cc9d4b2b7fad',
      input: {
        $abi: [
          {
            inputs: [
              { internalType: 'bytes', name: 'commands', type: 'bytes' },
              { internalType: 'bytes[]', name: 'inputs', type: 'bytes[]' },
              { internalType: 'uint256', name: 'deadline', type: 'uint256' },
            ],
            name: 'execute',
            outputs: [],
            stateMutability: 'payable',
            type: 'function',
          },
        ],
        sighash: '0x3593564c',
        inputs: {
          $some: {
            $abiParams: [
              'address recipient',
              'uint256 amountIn',
              'uint256 amountOut',
              'bytes path',
              'bool payerIsUser',
            ],
            amountOut: {
              $gte: '0x4c4b400',
            },
            path: {
              $and: [
                {
                  $regex: '^0x9e1028f5f1d5ede59748ffcee5532509976840e0',
                },
                {
                  $regex: '.*7f5c764cbc14f9669b88837ca1490cca17c31607$',
                },
              ],
            },
          },
        },
      },
    }

    await story('QuestFactory', 'Quest', 'createQuestAndQueue', 'with blank actionSpec', createQuestAndQuestTx)

    await sampleErc20.approve(questFactory.address, transferAmount)
    tx = await questFactory.createQuestAndQueue(
      sampleErc20.address,
      expiryDate,
      startDate,
      totalRewards,
      rewardAmount,
      'tenActionSpecQuestId',
      JSON.stringify(tenActionSpec),
      0
    )
    await story('QuestFactory', 'Quest', 'createQuestAndQueue', 'with 10 action actionSpec', tx)

    await sampleErc20.approve(questFactory.address, transferAmount)
    tx = await questFactory.createQuestAndQueue(
      sampleErc20.address,
      expiryDate,
      startDate,
      totalRewards,
      rewardAmount,
      'oneActionSpecQuestId',
      JSON.stringify(oneActionSpec),
      0
    )
    await story('QuestFactory', 'Quest', 'createQuestAndQueue', 'with 1 action actionSpec', tx)
  })

  it('Claim an NFT reward', async () => {
    await createQuestAndQuestTx.wait()
    let hash = utils.solidityKeccak256(['address', 'string'], [firstAddress.address.toLowerCase(), nftQuestId])
    let signature = await claimAddressSigner.signMessage(utils.arrayify(hash))

    const transferAmount = await questFactory.totalQuestNFTFee(totalParticipants)
    await questFactory.connect(firstAddress).createCollection('collectionName')
    const collectionAddresses = await questFactory.ownerCollectionsByOwner(firstAddress.address)
    const collectionAddress = collectionAddresses[0]

    await questFactory
      .connect(firstAddress)
      .addQuestToCollection(
        collectionAddress,
        startDate,
        expiryDate,
        totalParticipants,
        nftQuestId,
        'NFT Description',
        'ImageipfsHash',
        { value: transferAmount.toNumber() }
      )

    tx = await questFactory.connect(firstAddress).mintQuestNFT(nftQuestId, hash, signature)
    await story('QuestFactory', 'Mint Quest NFT', 'mintQuestNFT', 'mint a quest nft', tx)
  })

  it('Withdraw Remaining Rewards', async () => {
    await createQuestAndQuestTx.wait()
    const questAddress = await questFactory.quests(questId).then((res) => res.questAddress)
    const erc20Quest = await ethers.getContractAt('Quest', questAddress)
    await time.setNextBlockTimestamp(expiryDate + 1)

    tx = await erc20Quest.withdrawRemainingTokens()
    await story('Quest', 'Withdraw', 'withdrawRemainingRewards', 'Withdraw remaining rewards from ERC20 quest', tx)
  })
})
