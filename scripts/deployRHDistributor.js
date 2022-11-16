require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main(tokenAddress, root, expiry) {
  const MerkleDistributorWithDeadline = await ethers.getContractFactory('MerkleDistributorRH')
  const merkleDistributorWithDeadline = await MerkleDistributorWithDeadline.deploy(tokenAddress, root, expiry)
  await merkleDistributorWithDeadline.deployed()
  console.log(`merkleDistributorWithDeadline deployed at ${merkleDistributorWithDeadline.address}`)
}

// Replace with actual values
const tokenAddress = ''
const root = ''
const expiry = 0

main(tokenAddress, root, expiry)
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
