import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

export type QuestContractType = {
    rewardToken: () => Promise<string>
    totalAmount: () => Promise<number>
    owner: () => Promise<string>
    startTime: () => Promise<number>
    endTime: () => Promise<number>
    hasStarted: () => Promise<boolean>
    merkleRoot: () => Promise<void>
    address: string
    connect: (address: SignerWithAddress) => { setAllowList: (newAllowList: string) => Promise<void>; setMerkleRoot: (merkleRoot: string) => Promise<void>; start: () => Promise<void>; pause: () => Promise<void>; unPause: () => Promise<void>; withdraw: () => Promise<void>; setRewardToken: (address: string) => Promise<void> }
    withdraw: () => Promise<void>
    claim: (owner: string, amount: number, merkleProof: string[]) => Promise<void>
    setMerkleRoot: (merkleRoot: string) => Promise<void>
    unPause: () => Promise<void>
    transfer: () => Promise<void>
    allowList: () => Promise<string>
    isPaused: () => Promise<boolean>
    start: () => Promise<void>
    pause: () => Promise<void>
}

export type SampleErc20Type = {
    address: string
    deployed: () => Promise<any>
    functions: {
        transfer: (transferee: string, amount: number) => Promise<any>
        balanceOf: (tokenAddress: string) => Promise<number>
    }
}
