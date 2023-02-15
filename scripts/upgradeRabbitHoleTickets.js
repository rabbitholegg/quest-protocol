require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  hre.run('compile')
  // const address = '0x5C3eBe0C4a1F1505a4A106859CaBdca0913fa42F' // goerli
  const address = '0x70dd3F5f2356fdAeaE5aE517e0fB862b1Ce2F29C' // goerli chugsplash
  const contract = await ethers.getContractFactory('RabbitHoleTickets')

  const implAddress = await upgrades.erc1967.getImplementationAddress(address)
  console.log('Old implementation address:', implAddress)

  // force import only needed first time after chugsplash deploy
  hre.upgrades.forceImport(address, contract)

  const proposal = await hre.defender.proposeUpgrade(address, contract)
  console.log('Upgrade proposal created at:', proposal.url)

  const newImplAddress = proposal.metadata.newImplementationAddress
  console.log('verifying new implementation: ', newImplAddress)
  await hre.run('verify:verify', { address: newImplAddress })
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
