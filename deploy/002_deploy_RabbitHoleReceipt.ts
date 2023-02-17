import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
const { ethers } = require('hardhat')

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer, owner, royaltyRecipient} = await getNamedAccounts();

  // const ReceiptRenderer = await ethers.getContractFactory('ReceiptRenderer')
  // const receiptRenderer = await ReceiptRenderer.deploy()
  // await receiptRenderer.deployed()

  // const minterAddress = '0xE4A85599217c4F5dE677e542738ba4031098A72D' // The factory address
  // const royaltyBps = 100
  // const initArgs = [receiptRenderer.address, royaltyRecipient, minterAddress, royaltyBps, owner]
  // console.log('initialize args:', initArgs)

  await deploy('RabbitHoleReceipt', {
    contract: 'RabbitHoleReceipt',
    from: deployer,
    deterministicDeployment: '0x0000000000000000000000000000000000000000000000000000000000000020',
    proxy: {
      owner: owner,
      proxyContract: 'OpenZeppelinTransparentProxy'
    },
    log: true,
  });

  return true; // only run once
};

export default func;
func.tags = ['RabbitHoleReceipt'];
func.id = 'deploy_RabbitHoleReceipt';