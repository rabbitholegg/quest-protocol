require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const royaltyRecipient = '0x482c973675b3E3f84A23Dc03430aCfF293952e74'
  const minterAddress = '0x482c973675b3E3f84A23Dc03430aCfF293952e74' // TODO: change this to the server minter address
  const royaltyPercentage = 10;

  const RabbitHoleTickets = await ethers.getContractFactory('RabbitHoleTickets')
  const TicketRenderer = await ethers.getContractFactory('TicketRenderer')

  const ticketRenderer = await TicketRenderer.deploy()
  await ticketRenderer.deployed();
  console.log('ticketRenderer deployed to:', ticketRenderer.address)

  const deployment = await hre.upgrades.deployProxy(
    RabbitHoleTickets,
    [ticketRenderer.address, royaltyRecipient, minterAddress, royaltyPercentage],
    { initializer: 'initialize' }
  )

  await deployment.deployed()
  console.log('deployed to:', deployment.address)

  const proxyImplAddress = await upgrades.erc1967.getImplementationAddress(
    deployment.address
  );

  console.log("verifying implementation: ", proxyImplAddress);
  await hre.run("verify:verify", { address: proxyImplAddress });
  console.log("verifying TicketRenderer: ", ticketRenderer.address);
  await hre.run("verify:verify", { address: ticketRenderer.address });
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
