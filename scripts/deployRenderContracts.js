require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const ReceiptRenderer = await ethers.getContractFactory('ReceiptRenderer')
  const receiptRenderer = await ReceiptRenderer.deploy()
  await receiptRenderer.deployed()

  console.log('deployed ReceiptRenderer to:', receiptRenderer.address)
  console.log('verifying ReceiptRenderer: ', receiptRenderer.address)
  await hre.run('verify:verify', { address: receiptRenderer.address })
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })