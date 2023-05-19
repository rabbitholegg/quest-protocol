require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
const { ethers } = require('hardhat')

async function main() {
  const proxyAddress = '0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E';
  const adminSlot = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';
  const implementationSlot = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc'

  // Send the low-level call to the proxy contract
  const result = await ethers.provider.getStorageAt(proxyAddress, adminSlot);
  const resultImpl = await ethers.provider.getStorageAt(proxyAddress, implementationSlot);

  console.log('ProxyAdmin address:', result);
  console.log('Implementn address:', resultImpl);
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
