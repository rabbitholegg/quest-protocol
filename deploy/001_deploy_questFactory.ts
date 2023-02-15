import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
const { ethers } = require('hardhat')

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer, owner, claimSignerAddress, protocolFeeReceipient} = await getNamedAccounts();

  const Erc20Quest = await ethers.getContractFactory('Erc20Quest')
  const Erc1155Quest = await ethers.getContractFactory('Erc1155Quest')

  const erc20Quest = await Erc20Quest.deploy()
  await erc20Quest.deployed()
  const erc1155Quest = await Erc1155Quest.deploy()
  await erc1155Quest.deployed()
  const erc20addy = erc20Quest.address
  const erc1155addy = erc1155Quest.address

  const rabbitholeReceiptAddress = '0x83149DE08844331591DD45E9D3A89D1CF64f59Bc'
  const rabbitholeTicketsAddress = '0x68dE4434a00374C2b63A0D90E5FD8C7d2878eEe2'

  const initArgs = [claimSignerAddress, rabbitholeReceiptAddress, rabbitholeTicketsAddress, protocolFeeReceipient, erc20addy, erc1155addy, owner]
  console.log('initialize args:', initArgs)

  await deploy('QuestFactory', {
    contract: 'QuestFactory',
    from: deployer,
    deterministicDeployment: '0x0000000000000000000000000000000000000000000000000000000000000020',
    proxy: {
      owner: owner,
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: initArgs,
        },
      }
    },
    log: true,
  });

  return true; // only run once
};

export default func;
func.tags = ['QuestFactory'];
func.id = 'deploy_QuestFactory';