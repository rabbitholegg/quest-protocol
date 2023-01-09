# Quest Protocol

[![Tests](https://github.com/rabbitholegg/quest-protocol/workflows/Tests/badge.svg)](https://github.com/rabbitholegg/quest-protocol/actions?query=workflow%3ATests)
[![Lint](https://github.com/rabbitholegg/quest-protocol/workflows/Lint/badge.svg)](https://github.com/rabbitholegg/quest-protocol/actions?query=workflow%3ALint)

## Overview

Quest Protocol makes it easy to attach a token reward to any on-chain action. It's currently used to create quests on RabbitHole.

---

## Table of Contents

- [Quest Protocol](https://github.com/rabbitholegg/quest-protocol#quest-protocol)
    - [Table of Contents](https://github.com/rabbitholegg/quest-protocol#table-of-contents)
    - [Documentation](https://github.com/rabbitholegg/quest-protocol#documentation)
    - [Layout](https://github.com/rabbitholegg/quest-protocol#layout)
    - [Deployments](https://github.com/rabbitholegg/quest-protocol#deployments)
    - [Install](https://github.com/rabbitholegg/quest-protocol#install)
    - [Testing](https://github.com/rabbitholegg/quest-protocol#testing)
    - [Upgrading](https://github.com/rabbitholegg/quest-protocol#upgrading)
    - [Audits](https://github.com/rabbitholegg/quest-protocol#audits)
    - [Bug Bounty](https://github.com/rabbitholegg/quest-protocol#bug-bounty)
    - [License](https://github.com/PartyDAO/quest-protocol#license)

---
## Documentation

For more information on all docs related to the Quest Protocol, see the documentation directory [here](./docs/).

- [Overview](./docs/overview.md)
- [Quest Claim](./docs/quest-claim.md)
- [Quest Create](./docs/quest-create.md)

---

## Layout

```
docs/ # Start here
├── overview.md
├── quest-creation.md
└── quest-claim.md
test/ # TS tests
```

---

## Deployments

|Chain           |Quest Factory Contract|
|----------------|----------------------|
|Ethereum        |0x0                   |
|Goerli          |0x0                   |
|Polygon Mainnet |0x0                   |
|Polygon Testnet |0x0                   |
|Optimism        |0x0                   |
|Optimism Testnet|0x0                   |
|Arbitrum        |0x0                   |
|Arbitrum Testnet|0x0                   |

---

## Contracts

The main contracts involved in this phase are:

- `Quest Factory` ([code](./contracts/QuestFactory.sol))
    - Creates new `Quest` instances of an ERC-1155 reward Quest or ERC-20 reward Quest.
- `RabbitHole Receipt` ([code](./contracts/RabbitHoleReceipt.sol))
    - TBD
- `ERC-20 Quest` ([code](./contracts/Erc20Quest.sol))
    - TBD
- `ERC-1155 Quest` ([code](./contracts/Erc1155Quest.sol))
    - TBD

// Put In diagram here

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

---

## Upgrading

The Quest Factory is an upgradable contract. Over time as the space evolves there will be more than just ERC-20 or
ERC-1155 rewards and we want to be non-limiting in our compatibility.

1. `yarn hardhat run --network goerli scripts/upgradeQuestFactory.js` or `scripts/upgradeRabbitHoleReceipt.js` and
   replace the network with `mainnet` if you are upgrading on mainnet.
    1. If you get an error like `NomicLabsHardhatPluginError: Failed to send contract verification request.` It's
       usually because the contract wasn't deployed by the time verification ran. You can run verification again
       with `yarn hardhat verify --network goerli IMPLENTATION_ADDRESS` where the implementation address is in the
       output of the upgrade script.
2. go to https://defender.openzeppelin.com/#/admin and approve the upgrade proposal (the link is also in the output of
   the upgrade script)
3. After the upgrade proposal is approved, create a PR with the updates to the .openzeppelin/[network-name].json file.

---

## Audits

The following auditors reviewed the protocol. You can see reports in `/audits` directory:

- Code4rena TBD (report [here](/audits/))

---
## Bug Bounty
TBD

---
## License
TBD