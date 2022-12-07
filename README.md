# Quest Protocol
[![Tests](https://github.com/rabbitholegg/quest-protocol/workflows/Tests/badge.svg)](https://github.com/rabbitholegg/quest-protocol/actions?query=workflow%3ATests)
[![Lint](https://github.com/rabbitholegg/quest-protocol/workflows/Lint/badge.svg)](https://github.com/rabbitholegg/quest-protocol/actions?query=workflow%3ALint)


Once a protocol decides to run a quest, it creates a new `Quest` and distributes a finite number of `Receipts` that can be claimed for a `Reward`. `Receipts` are ERC-721 NFTs that are transferrable but only claimable once per `Quest`. Individuals that complete the `Quest` action are given the abliity to transfer a `Receipt` to their wallet. They then can use the `Receipt` to claim the `Reward` in the future and any other potential usages.

---

## Key Concepts

- **Receipts**: A set of ERC-721 tokens custodied by the `Quest` contract, these are acquired in the Quest creation phase from the factory. These are originally minted to the `Quest` contract and transferred out during claim of `Receipts`.
- **Rewards**: A set of ERC-20 or ERC-1155 tokens custodied by the `Quest` contract, these are acquired in the Quest creation phase from the factory. These are originally minted to the `Quest` contract and transferred out during claim of `Rewards`.
- **Receipt NFT**: An NFT (ERC721) representing a receipt from completing an action defined in the `Quest`.
- **Quest**: The quest contract itself, which custodies the Receipts & Rewards and ultimately manages the claim lifecyle for receipts and rewards. This can either be an 1155Quest or an erc20Quest proxy.
- **Distributions**: An (ungoverned) mechanism by which parties can claim `reward` tokens held by the Quest to themselves, these have a 24hr/block timestamp to acceptance.
- **Quest Deployer**: Predefined accounts that have autonomous power to creates `Quests`. Conventionally defined as Rabbithole, but will open up over time.
- **Proxies**: All `Quest` instances are deployed as simple [`Quest`](../contracts/utils/Proxy.sol) contracts that forward calls to a `Quest` implementation contract.
- **ProposalExecutionEngine**: An upgradable contract the `Quest` contract delegatecalls into that implements the logic for executing specific proposal types.

---

## Contracts

The main contracts involved in this phase are:

- `Quest Factory` ([code](../contracts/quests/QuestFactory.sol))
  - Creates new proxified `Quest` instances of an 1155 reward Quest or erc20 reward Quest.
- `ERC20 Quest` 
  - The governance contract that also custodies the Receipt NFTs and Rewards. This is also the ERC-721 contract for the Governance NFTs.
- `ProposalExecutionEngine` 
  - An upgradable logic (and some state) contract for executing each proposal type from the context of the `Party`.
- `TokenDistributor` 
  - Escrow contract for distributing deposited ETH and ERC20 tokens to members of parties.

// Put In diagram here

---

## Quest Creation

Quests are created through the `QuestFactory` contract. This is performed
by a whitelisted account, historically the Internal Rabbithole team.

The sequence of events is:
1. Call `QuestFactory.createQuest(rewardType: [erc20|erc1155])` defined as:
   ```solidity
   function createQuest(
      string rewardType,
      address rewardAddress,
   )
   ```
   - `rewardType` will be either an ERC-1155 or an ERC-20 token.
   - `rewardAddress` is the address of the corresponding reward for completing the quest. This can be an ERC-1155 or ERC-20 contract address.
2. Transfer rewards to the newly created Quest. You can transfer direct or execute the `depositFullAwardAmount` function.
3. The Quest Factory will call the mintAndSend function for the total number of allowed recipients of Receipts.
4. Execute the markQuestAsReady function. This will validate that the Quest is ready for public and upon reaching the effective StartDate, will be ready for use.

## UML diagrams

You can render UML diagrams using [Mermaid](https://mermaidjs.github.io/). For example, this will produce a sequence diagram:

```mermaid
graph LR
A[Quest Deployer] --> B{Choose Reward}
B -- ERC-20 Reward--> C(ERC-20 Reward Quest)
B -- ERC-1155 Reward--> D(ERC-1155 Reward Quest)
```
