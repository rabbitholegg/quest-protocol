require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const TicketRenderer = await ethers.getContractFactory('TicketRenderer')
  const ReceiptRenderer = await ethers.getContractFactory('ReceiptRenderer')

  const ticketRenderer = await TicketRenderer.deploy()
  await ticketRenderer.deployed()
  const receiptRenderer = await ReceiptRenderer.deploy()
  await receiptRenderer.deployed()

  console.log('deployed TicketRenderer to:', ticketRenderer.address)
  console.log('deployed ReceiptRenderer to:', receiptRenderer.address)

  console.log('verifying TicketRenderer: ', ticketRenderer.address)
  await hre.run('verify:verify', { address: ticketRenderer.address })
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
