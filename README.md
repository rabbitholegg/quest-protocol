# Quest Protocol

[![Tests](https://github.com/rabbitholegg/quest-protocol/workflows/Tests/badge.svg)](https://github.com/rabbitholegg/quest-protocol/actions?query=workflow%3ATests)
[![Lint](https://github.com/rabbitholegg/quest-protocol/workflows/Lint/badge.svg)](https://github.com/rabbitholegg/quest-protocol/actions?query=workflow%3ALint)

## Overview

Quests Protocol is a protocol to distribute token rewards for completing on-chain tasks.

![img.png](img.png)

---

## Table of Contents

- [Quest Protocol](https://github.com/rabbitholegg/quest-protocol#quest-protocol)
  - [Documentation](https://github.com/rabbitholegg/quest-protocol#documentation)
  - [Addresses](https://github.com/rabbitholegg/quest-protocol#addresses)
  - [Contracts](https://github.com/rabbitholegg/quest-protocol#contracts)
  - [Patterns](https://github.com/rabbitholegg/quest-protocol#patterns)
  - [Install](https://github.com/rabbitholegg/quest-protocol#install)
  - [Testing](https://github.com/rabbitholegg/quest-protocol#testing)
  - [Deployment](https://github.com/rabbitholegg/quest-protocol#deployment)
  - [Upgrading](https://github.com/rabbitholegg/quest-protocol#upgrading)
  - [Audits](https://github.com/rabbitholegg/quest-protocol#audits)
  - [Bug Bounty](https://github.com/rabbitholegg/quest-protocol#bug-bounty)
  - [License](https://github.com/rabbitholegg/quest-protocol/#license)

---

## Documentation

For more information on all docs related to the Quest Protocol, see the documentation directory [here](./docs/).

- [Overview](https://github.com/rabbitholegg/quest-protocol/tree/main/docs/overview.md)
- [Quest Claim](https://github.com/rabbitholegg/quest-protocol/tree/main/docs/quest-claim.md)
- [Quest Create](https://github.com/rabbitholegg/quest-protocol/tree/main/docs/quest-create.md)

---

## Addresses

Mainnet, Optimism, Polygon, Arbitrum, and Sepolia:

|Contract Name|Address|
|-------------|-------|
|Quest Factory|0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E|
|Quest Terminal Key|0x6Fd74033a717ebb3c60c08b37A94b6CF96DE54Ab|
|RabbitHole Tickets|0x0D380362762B0cf375227037f2217f59A4eC4b9E|

---

## Contracts

The main contracts are:

- `Quest Factory` ([code](https://github.com/rabbitholegg/quest-protocol/tree/main/contracts/QuestFactory.sol))
  - Creates new `Quest` instances of an NFT reward Quest or ERC-20 reward Quest.
- `RabbitHole Receipt` ([code](https://github.com/rabbitholegg/quest-protocol/tree/main/contracts/RabbitHoleReceipt.sol))
  - An ERC-721 contract that acts as a proof of on-chain activity. Claimed via usage of ECDSA sig/hash
- `Quest` ([code](https://github.com/rabbitholegg/quest-protocol/blob/main/contracts/Quest.sol))
  - A Quest in which the reward is an ERC-20 token
- `QuestNFT` ([code](https://github.com/rabbitholegg/quest-protocol/blob/main/contracts/QuestNFT.sol))
  - A Quest in which the reward is a NFT
- `Quest Terminal Key` ([code](https://github.com/rabbitholegg/quest-protocol/tree/main/contracts/QuestTerminalKey.sol))
  - A contract for gating access and handling discounts for the Quest Terminal

---

## Patterns

The contracts use two main patterns.

### Factory Pattern

More reading [here](https://www.tutorialspoint.com/design_pattern/factory_pattern.htm)

![image](https://user-images.githubusercontent.com/14314818/213348232-4bc57639-d281-41e7-a0c3-c3886d8e0be9.png)

### Dependency Injection

More reading [here](https://www.freecodecamp.org/news/a-quick-intro-to-dependency-injection-what-it-is-and-when-to-use-it-7578c84fa88f/)
![image](https://user-images.githubusercontent.com/14314818/213348583-fc0a94ec-cc3f-4730-90d2-5503d027c7b8.png)

### Factory Creation Pattern

More reading [here](https://dev.to/jamiescript/design-patterns-in-solidity-1i28#factory)

---

## Install

### Install dependencies

```bash
yarn
```

### Compile Contracts

```bash
yarn compile
```

---

## Testing

### Run all tests:

```bash
yarn test
```

### Run test coverage report:

```bash
yarn test:coverage
```

### Run gas test:

```bash
yarn test:gas-stories
```

---

## Deployment

### RabbitHoleReceipt and QuestFactory
- checkout from sha `ea60f723fadfb5f02edad862f56072c0c972cfc2`

### QuestTerminalKey
- checkout from sha `fbc3c0fb7fdf13713314b996fa20a2551f9d591e`

### RabbitHoleTickets
- checkout from sha `70a56a1567dcd9c4d6f7718388667c5e0564fb2f`
(must add in the deploy script manually)

then:
- `yarn hardhat deploy --network network_name`
- `yarn hardhat --network network_name etherscan-verify --api-key etherscan_api_key`


## Upgrading

All contracts except the Quest instances are upgradable contracts.

1. `yarn hardhat run --network network_name scripts/upgradeQuestFactory.js` or `scripts/upgradeRabbitHoleReceipt.js`
   1. If you get an error like `NomicLabsHardhatPluginError: Failed to send contract verification request.` It's
      usually because the contract wasn't deployed by the time verification ran. You can run verification again
      with `yarn hardhat verify --network network_name IMPLENTATION_ADDRESS` where the implementation address is in the
      output of the upgrade script.
2. go to https://defender.openzeppelin.com/#/admin and approve the upgrade proposal (the link is also in the output of
   the upgrade script)
3. After the upgrade proposal is approved, create a PR with the updates to the .openzeppelin/[network-name].json file.

---

## Audits

The following auditors reviewed the protocol.

- Code4rena (report [here](https://code4rena.com/reports/2023-01-rabbithole))

---

## Bug Bounty

All contracts except tests, interfaces, dependencies are in scope and eligible for the Quest Protocol Bug Bounty program.

The rubric we use to determine bug bounties is as follows:

| **Level**   | **Example**                                                                                                                                                                                      | **Maximum Bug Bounty** |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------- |
| 6. Severe   | - Draining or freezing of holdings protocol-wide (e.g. draining token distributor, economic attacks, reentrancy, MEV, logic errors)                                                              | Let's talk             |
| 5. Critical | - Contracts with balances can be exploited to steal holdings under specific conditions (e.g. bypass guardrails to transfer precious NFT from parties, user can steal their party's distribution) | Up to 25 ETH           |
| 4. High     | - Contracts temporarily unable to transfer holdings<br>- Users spoof each other                                                                                                                  | Up to 10 ETH           |
| 3. Medium   | - Contract consumes unbounded gas<br>- Griefing, denial of service (i.e. attacker spends as much in gas as damage to the contract)                                                               | Up to 5 ETH            |
| 2. Low      | - Contract fails to behave as expected, but doesn't lose value                                                                                                                                   | Up to 1 ETH            |
| 1. None     | - Best practices                                                                                                                                                                                 |                        |

Any vulnerability or bug discovered must be reported only to the following email: [security@rabbithole.gg](mailto:security@rabbithole.gg).

---

## License

The primary license for the Quest Protocol is the GNU General Public License 3.0 (GPL-3.0), see [LICENSE](./LICENSE).

Several interface/dependencies files from other sources maintain their original license (as indicated in their SPDX header).
All files in test/ remain MIT (as indicated in their SPDX header).
