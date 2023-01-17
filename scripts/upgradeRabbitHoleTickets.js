require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  hre.run("compile");
  const address = "0xC5340D9c3bDE433492D1Af95AD353B74C7DbD98C"; // goerli
  const contract = await ethers.getContractFactory('RabbitHoleTickets')

  const implAddress = await upgrades.erc1967.getImplementationAddress(address);
  console.log("Old implementation address:", implAddress);

  const proposal = await hre.defender.proposeUpgrade(address, contract);
  console.log("Upgrade proposal created at:", proposal.url);

  const newImplAddress = proposal.metadata.newImplementationAddress;
  console.log("verifying new implementation: ", newImplAddress);
  await hre.run("verify:verify", {address: newImplAddress});
};

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
