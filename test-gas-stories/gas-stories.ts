import { BigNumber, ContractTransaction, providers } from 'ethers'
import { ethers } from 'hardhat'
const provider: providers.JsonRpcProvider = ethers.provider
import gasConfig from '../hardhat.config'
import chalk from 'chalk'
import { writeFileSync } from 'fs'
import { deployAll } from '../test/helpers/deploy'
import { snapshotEach } from '../test/helpers/snapshot'
import { Erc20Quest } from '../typechain-types'

/*
 CircleCI supported chalk styles https://app.circleci.com/pipelines/github/f8n/fnd-contracts/4069/workflows/2c043508-065a-47cd-bc58-4a303f3a1be7/jobs/22047
  - blue
  - blueBright
  - cyan
  - green
  - greenBright
  - magenta
  - red
  - redBright
  - yellow
  - yellowBright
*/

if (!gasConfig.gasReporter?.gasPrice) {
  throw new Error('gasReporter.gasPrice is not set')
}

const ETH_PRICE = 1500
const GAS_PRICE = gasConfig.gasReporter.gasPrice

let records: {
  contract: string
  category: string
  func: string
  description: string
  gasUsed: BigNumber
  notes?: string
}[] = []
let resultsLog = ''

snapshotEach(async function () {
  const [deployer, claimAddressSigner, rando1, rando2] = await ethers.getSigners()
  const contracts = await deployAll(deployer, claimAddressSigner)
  this.contracts = contracts

  const expiryDate = Math.floor(Date.now() / 1000) + 10000
  const startDate = Math.floor(Date.now() / 1000) + 1000
  const totalParticipants = 1000
  const rewardAmount = 10
  await contracts.questFactory.setRewardAllowlistAddress(contracts.sampleErc20.address, true)
  await contracts.questFactory
    .connect(deployer)
    .createQuest(
      contracts.sampleErc20.address,
      expiryDate,
      startDate,
      totalParticipants,
      rewardAmount,
      'erc20',
      'quest-id',
      2000
    )

  const quest = await contracts.questFactory.connect(deployer).quests('quest-id')
  const erc20QuestAddress = await quest.questAddress
  const erc20Quest = (await ethers.getContractAt('Erc20Quest', erc20QuestAddress)) as Erc20Quest
  const val = (await erc20Quest.maxTotalRewards()).add(await erc20Quest.maxProtocolReward())
  await contracts.sampleErc20.transfer(erc20QuestAddress, val)
  await erc20Quest.start()
  console.log((await contracts.questFactory.quests('quest-id')).totalAmount)
  console.log((await contracts.questFactory.quests('quest-id')).numberMinted)

  // await contracts.collection.connect(creator).mint(testIpfsPath[0])
  // await contracts.collection.connect(creator).mint(testIpfsPath[1])
  // const sharesBefore = [
  //   { recipient: creator.address, percentInBasisPoints: 5000 },
  //   { recipient: deployer.address, percentInBasisPoints: 5000 },
  // ]
  // const callData = contracts.percentSplitFactory.interface.encodeFunctionData('createSplit', [sharesBefore])
  // await contracts.collection
  //   .connect(creator)
  //   .mintWithCreatorPaymentFactory(testIpfsPath[2], contracts.percentSplitFactory.address, callData)

  // // Warm up the market
  // const tx = await contracts.nftCollectionFactoryV2.connect(rando).createNFTCollection('name', 'symbol', 69)
  // const testCol = await getNFTCollection(tx, rando)
  // await testCol.connect(rando).mintAndApprove(testIpfsPath[0], mockMarket.address)
  // await testCol.connect(rando).mint(testIpfsPath[1])
  // await contracts.feth.connect(rando).deposit({ value: ONE_ETH.mul(100) })

  // // Avoid inconsistent results due to an unexpected change in hour
  // await increaseTimeToNextHour()
})

export async function story(
  contract: 'QuestFactory' | 'Erc20Quest' | 'Erc1155Quest' | 'RabbitHoleReceipt' | 'ReceiptRenderer',
  category: string,
  func: string,
  description: string,
  tx: ContractTransaction | ContractTransaction[],
  notes?: string
): Promise<void> {
  let gasUsed = BigNumber.from(0)
  if (Array.isArray(tx)) {
    for (const t of tx) {
      const receipt = await provider.getTransactionReceipt(t.hash)
      gasUsed = gasUsed.add(receipt.gasUsed)
    }
  } else {
    const receipt = await provider.getTransactionReceipt(tx.hash)
    gasUsed = receipt.gasUsed
  }

  records.push({
    contract,
    category,
    func,
    description,
    gasUsed,
    notes,
  })
}

after(async () => {
  records = records.sort((a, b) => {
    let result = a.contract.localeCompare(b.contract)
    if (result !== 0) {
      return result
    }
    result = a.category.localeCompare(b.category)
    if (result !== 0) {
      return result
    }
    result = a.func.localeCompare(b.func)
    if (result !== 0) {
      return result
    }
    result = a.description.localeCompare(b.description)
    if (result !== 0) {
      return result
    }
    if ((!a.notes && b.notes) || (a.notes && b.notes && a.notes < b.notes)) {
      return -1
    }
    return 1
  })
  console.log(`User story gas usage -- ETH $${ETH_PRICE}, gasPrice: ${GAS_PRICE} gwei
=========================================================
`)
  let previousContract = ''
  let previousCategory = ''
  let previousFunc = ''
  let minFuncCost: number | undefined
  let maxFuncCost: number | undefined
  for (const record of records) {
    if (record.func != previousFunc) {
      printCostRange(minFuncCost, maxFuncCost)
      minFuncCost = undefined
      maxFuncCost = undefined
    }
    if (record.contract != previousContract) {
      const contractString = `${record.contract}
=========================================================`
      console.log(contractString)
      resultsLog += `${contractString}\n`
      previousContract = record.contract
      previousCategory = ''
    }

    if (record.category != previousCategory) {
      const categoryString = `${record.category}
···························`
      console.log(categoryString)
      resultsLog += `${categoryString}\n`
      previousCategory = record.category
      previousFunc = ''
    }
    if (record.func != previousFunc) {
      console.log(chalk.redBright(record.func))
      resultsLog += `${record.func}\n`
      previousFunc = record.func
    }
    const cost =
      ETH_PRICE *
      Number.parseFloat(
        ethers.utils.formatEther(record.gasUsed.mul(ethers.utils.parseUnits(GAS_PRICE.toString(), 'gwei')))
      )
    if (minFuncCost === undefined || cost < minFuncCost) {
      minFuncCost = cost
    }
    if (maxFuncCost === undefined || cost > maxFuncCost) {
      maxFuncCost = cost
    }
    let suffix = ''
    if (record.notes) {
      suffix = ` [${record.notes}]`
    }
    const costString = `$${cost.toLocaleString(undefined, {
      maximumFractionDigits: 2,
      minimumFractionDigits: 2,
    })}`
    const gasString = `(${record.gasUsed.toNumber().toLocaleString()})`
    console.log(
      `${chalk.greenBright(costString.padStart(11))} ${chalk.green(gasString.padStart(10))} ${
        record.description
      }${chalk.yellowBright(suffix)}`
    )
    resultsLog += `${roundHundred(record.gasUsed.toNumber()).toLocaleString().padStart(11)} ${
      record.description
    }${suffix}\n`
  }
  printCostRange(minFuncCost, maxFuncCost)
  console.log(`
=========================================================`)
  const resultsFile = `${__dirname}/../gas-stories.txt`
  writeFileSync(resultsFile, resultsLog)
})

function printCostRange(minFuncCost: number | undefined, maxFuncCost: number | undefined) {
  if (minFuncCost !== undefined && maxFuncCost !== undefined) {
    console.log(`Range: $${minFuncCost.toLocaleString(undefined, {
      maximumFractionDigits: 2,
      minimumFractionDigits: 2,
    })} - $${maxFuncCost.toLocaleString(undefined, {
      maximumFractionDigits: 2,
      minimumFractionDigits: 2,
    })}
`)
    resultsLog += '\n'
  }
}

function roundHundred(value: number): number {
  return Math.round(value / 100) * 100
}
