import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
const { ethers } = require('hardhat')

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer, claimSignerAddress, protocolFeeReceipient} = await getNamedAccounts();

  const Erc20Quest = await ethers.getContractFactory('Erc20Quest')
  const Erc1155Quest = await ethers.getContractFactory('Erc1155Quest')

  const erc20Quest = await Erc20Quest.deploy()
  await erc20Quest.deployed()
  const erc1155Quest = await Erc1155Quest.deploy()
  await erc1155Quest.deployed()

  const rabbitholeReceiptAddress = '0x0000000000000000000000000000000000000000'
  const rabbitholeTicketsAddress = '0x0000000000000000000000000000000000000000'

  await deploy('QuestFactory', {
    contract: 'QuestFactory',
    from: deployer,
    deterministicDeployment: true,
    proxy: {
      owner: deployer,
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [claimSignerAddress, rabbitholeReceiptAddress, rabbitholeTicketsAddress, protocolFeeReceipient, erc20Quest.address, erc1155Quest.address],
        },
      }
    },
    log: true,
  });
};
export default func;
func.tags = ['QuestFactory'];