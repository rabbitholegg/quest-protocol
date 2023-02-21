import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  await deploy('Erc1155Quest', {
    contract: 'Erc1155Quest',
    from: deployer,
    log: true,
  });
};

func.tags = ['QuestFactory'];

export default func;