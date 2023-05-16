require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  hre.run('compile')
  // const address = '0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E' // production everywhere
  const address = '0x74016208260cE10ef421ed0CFC4C7Baae0BaEF86' // sepolia staging
  const contract = await ethers.getContractFactory('QuestFactory')

  const implAddress = await upgrades.erc1967.getImplementationAddress(address)
  console.log('Old implementation address:', implAddress)

  // force import only needed first time after deploy
  hre.upgrades.forceImport(address, contract)

  const proposal = await hre.defender.proposeUpgrade(address, contract)
  console.log('Upgrade proposal created at:', proposal.url)

  const newImplAddress = proposal.metadata.newImplementationAddress;
  console.log("verifying new implementation: ", newImplAddress);
  await hre.run("verify:verify", {
    address: newImplAddress,
  });
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
