# Overview

Once a protocol decides to run a quest, it creates a new `Quest` that will declare a finite number of `Receipts` that
can ultimately be claimed for a `Reward`. `Receipts` are ERC-721 NFTs that are transferable but only claimable once
per `Quest`.
Individuals that complete the `Quest` action are given the ability to mint a `Receipt` to their wallet. They then
can use the `Receipt` to claim the `Reward` in the future and any other potential usages.

---

## Key Concepts

- **Receipts**: An NFT (ERC-721) representing a receipt from completing an action defined in the `Quest`. These are
  originally minted to a participants EOA address and the amount of available Receipts are defined by the `Quest`
  contract. Receipts track ability to see if there is a reward to claim.
- **Rewards**: A set of ERC-20 or ERC-1155 tokens custodied by the `Quest` contract, these are acquired in the Quest
  creation phase from the factory. These are originally transferred to the `Quest` contract on Quest Creation and
  transferred out during the claim Reward process.
- **Quest**: The quest contract itself, which custodies the Rewards, defines the available Receipts, and ultimately
  manages the claim lifecyle
  for receipts and rewards. This can either be an ERC-1155 or ERC-20 reward.
- **Claim Reward**: An (ungoverned) mechanism by which parties can claim `reward` tokens held by the Quest to
  themselves, these are claimable with an unclaimed `Receipt`.
- **Quest Deployer**: Predefined accounts that have autonomous power to creates `Quests`. Conventionally defined as
  Rabbithole, but will open up over time.
- **Proxies**: All `Quest` instances are deployed as simple [`Quest`](../contracts/utils/Proxy.sol) contracts that
  forward calls to a `Quest` implementation contract.
- **ProposalExecutionEngine**: An upgradable contract the `Quest` contract delegatecalls into that implements the logic
  for executing specific proposal types.
