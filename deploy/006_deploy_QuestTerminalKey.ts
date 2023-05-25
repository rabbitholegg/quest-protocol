import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
const { ethers } = require('hardhat')

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments
  const { deployer, owner } = await getNamedAccounts()

  await deploy('QuestTerminalKey', {
    contract: 'QuestTerminalKey',
    from: deployer,
    deterministicDeployment: '0x0000000000000000000000000000000000000000000000000000000000000020', // 20 for for production, 21 for staging
    proxy: {
      owner: owner,
      proxyContract: 'OpenZeppelinTransparentProxy',
    },
    log: true,
  })

  return true // only run once
}

func.tags = ['QuestTerminalKey']
func.id = 'deploy_QuestTerminalKey'

export default func
