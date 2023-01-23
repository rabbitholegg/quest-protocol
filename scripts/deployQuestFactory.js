require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const claimSignerAddress = '0x22890b38D6ab6090e5123DB7497f4bCE7062929F'
  const rabbitholeReceiptAddress = '0x97a1F6Eb42DDD89ddf7E2745472D8b393970e011' // goerli
  const protocolFeeReceipient = '0xC4a68e2c152bCA2fE5E8D26FFb8AA44bCE1B56b0' // goerli

  const QuestFactory = await ethers.getContractFactory('QuestFactory')

  const deployment = await hre.upgrades.deployProxy(
    QuestFactory,
    [claimSignerAddress, rabbitholeReceiptAddress, protocolFeeReceipient],
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