import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
const { ethers } = require('hardhat')

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer, owner, royaltyRecipient} = await getNamedAccounts();

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

func.tags = ['RabbitHoleReceipt'];
func.id = 'deploy_RabbitHoleReceipt';

export default func;