import { providers } from 'ethers'
import { ethers } from 'hardhat'
import { Context } from 'mocha'

export function snapshotEach(funcBeforeSnapshot: (this: Context) => Promise<void>): void {
  const provider: providers.JsonRpcProvider = ethers.provider
  let snapshotId: string

  before(async function () {
    await funcBeforeSnapshot.call(this)
    snapshotId = await provider.send('evm_snapshot', [])
  })

  beforeEach(async function () {
    await provider.send('evm_revert', [snapshotId])
    snapshotId = await provider.send('evm_snapshot', [])
  })

  after(async function () {
    // Clean up state when tests finish
    await provider.send('evm_revert', [snapshotId])
  })
}
