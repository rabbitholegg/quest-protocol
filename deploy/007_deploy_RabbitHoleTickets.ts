import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
const { ethers } = require('hardhat')

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer, owner, royaltyRecipient} = await getNamedAccounts();

  await deploy('RabbitHoleTickets', {
    contract: 'RabbitHoleTickets',
    from: deployer,
    deterministicDeployment: '0x0000000000000000000000000000000000000000000000000000000000000020', // 20 for for production, 21 for staging
    proxy: {
      owner: owner,
      proxyContract: 'OpenZeppelinTransparentProxy'
    },
    log: true,
  });

  return true; // only run once
};

func.tags = ['RabbitHoleTickets'];
func.id = 'deploy_RabbitHoleTickets';

export default func;
