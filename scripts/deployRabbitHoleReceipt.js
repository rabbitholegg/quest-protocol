require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const royaltyRecipient = '0x5FbDB2315678afecb367f032d93F642f64180aa3' // TODO: change this to the royalty recipient
  const minterAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3' // TODO: change this to the minter address
  const royaltyPercentage = 10;

  const RabbitHoleReceipt = await ethers.getContractFactory('RabbitHoleReceipt')

  const deployment = await hre.upgrades.deployProxy(
    RabbitHoleReceipt,
    [royaltyRecipient, minterAddress, royaltyPercentage],
    { initializer: 'initialize' }
  )

  await deployment.deployed()
  console.log('deployed to:', deployment.address)

  const proxyImplAddress = await upgrades.erc1967.getImplementationAddress(
    deployment.address
  );
  console.log("verifying implementation: ", proxyImplAddress);
  await hre.run("verify:verify", { address: proxyImplAddress });
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
