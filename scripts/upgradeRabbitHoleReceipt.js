require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  hre.run('compile')
  // const address = '0x61A8CC96a3576C2a50716a0cDE70BF373C018aa6' // goerli
  const address = '0x5fa55346fc7979FC521115C4Cf37AECc35B36Ec6' // goerli chugsplash
  const contract = await ethers.getContractFactory('RabbitHoleReceipt')

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
