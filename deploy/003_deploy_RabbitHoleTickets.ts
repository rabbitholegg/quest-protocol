import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
const { ethers } = require('hardhat')

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer, owner, royaltyRecipient} = await getNamedAccounts();

  const TicketRenderer = await ethers.getContractFactory('TicketRenderer')
  const ticketRenderer = await TicketRenderer.deploy()
  await ticketRenderer.deployed()


  const minterAddress = owner
  const royaltyBps = 100
  const initArgs = [ticketRenderer.address, royaltyRecipient, minterAddress, royaltyBps, owner]
  console.log('initialize args:', initArgs)

  await deploy('RabbitHoleTickets', {
    contract: 'RabbitHoleTickets',
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
func.tags = ['RabbitHoleTickets'];
func.id = 'deploy_RabbitHoleTickets';