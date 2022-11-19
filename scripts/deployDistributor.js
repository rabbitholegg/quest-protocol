require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main(tokenAddress, endTime, startTime, totalAmount) {
  const MerkleDistributor = await ethers.getContractFactory('MerkleDistributor')
  const deployment = await hre.upgrades.deployProxy(
    MerkleDistributor,
    [tokenAddress, endTime, startTime, totalAmount],
    { initializer: 'initialize' }
  )

  await deployment.deployed()
  console.log('deployed to:', deployment.address)
}

// Replace with actual values
const tokenAddress = ''
const endTime = 0
const startTime = 0
const totalAmount = 0

main(tokenAddress, endTime, startTime, totalAmount)
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
