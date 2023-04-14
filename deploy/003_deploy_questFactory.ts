import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
const { ethers } = require('hardhat')

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer, owner, claimSignerAddress, protocolFeeReceipient} = await getNamedAccounts();

  await deploy('QuestFactory', {
    contract: 'QuestFactory',
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

func.tags = ['QuestFactory'];
func.id = 'deploy_QuestFactory';

export default func;