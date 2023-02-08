require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const Erc20Quest = await ethers.getContractFactory('Erc20Quest')
  const Erc1155Quest = await ethers.getContractFactory('Erc1155Quest')

  const erc20Quest = await Erc20Quest.deploy()
  await erc20Quest.deployed()
  const erc1155Quest = await Erc1155Quest.deploy()
  await erc1155Quest.deployed()

  console.log('deployed Erc20Quest to:', erc20Quest.address)
  console.log('deployed Erc1155Quest to:', erc1155Quest.address)

  console.log('verifying erc20Quest: ', erc20Quest.address)
  await hre.run('verify:verify', { address: erc20Quest.address })
  console.log('verifying erc1155Quest: ', erc1155Quest.address)
  await hre.run('verify:verify', { address: erc1155Quest.address })
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
