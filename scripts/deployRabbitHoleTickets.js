require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const royaltyRecipient = '0xC4a68e2c152bCA2fE5E8D26FFb8AA44bCE1B56b0' // goerli
  const minterAddress = '0x37A4a767269B5D1651E544Cd2f56BDfeADC37B05' // goerli factory address
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
