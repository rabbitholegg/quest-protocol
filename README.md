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

Mainnet, Optimism, Polygon, Arbitrum, Base, Mantle and Sepolia:

|Contract Name|Address|
|-------------|-------|
|Quest Factory|0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E|
|RabbitHole Tickets|0x0D380362762B0cf375227037f2217f59A4eC4b9E|
|Protocol Rewards|0x168437d131f8deF2d94B555FF34f4539458DD6F9|

---

## Contracts

The main contracts are:

- `Quest Factory` ([code](https://github.com/rabbitholegg/quest-protocol/tree/main/contracts/QuestFactory.sol))
  - Creates new `Quest` instances of an NFT reward Quest or ERC-20 reward Quest.
- `Quest` ([code](https://github.com/rabbitholegg/quest-protocol/blob/main/contracts/Quest.sol))
  - A Quest in which the reward is an ERC-20 token
- `QuestNFT` ([code](https://github.com/rabbitholegg/quest-protocol/blob/main/contracts/QuestNFT.sol))
  - A Quest in which the reward is a NFT
- `Protocol Rewards` ([code](https://github.com/rabbitholegg/quest-protocol/tree/main/contracts/ProtocolRewards.sol))
  - An escrow like contract in which funds are deposited into account balances.

### Contract Structure

Contracts are layed out in the following order:

1. Use statements (i.e. `using SafeTransferLib for address;`)
2. Contract storage - we use upgradable architecture so pay special attention to preserving the order of contract storage, and only add to the end.
3. Contract constructors and initialization functions
4. Modifiers
5. External Update functions - anything that modifies contract state
6. External View Functions - self explanatory
7. Internal Update functions
8. Internal View functions

Interfaces should be used to hold the following:

1. Events
2. Errors
3. Structs

### Best Practices
For anything not covered here please refer to the [Foundry Best Practices](https://book.getfoundry.sh/tutorials/best-practices) for more information.
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
bun install
forge install
```

### Compile Contracts

```bash
forge build
```

---

## Testing

### Run all tests:

```bash
forge test
```

### Run test coverage report:

```bash
forge coverage --report lcov
```

### Run gas test:

```bash
forge snapshot
```

### Gotchas
If you see something like this `expected error: 0xdd8133e6 != 0xce3f0005` in Forge logging, your best bet is to search for the hex string (`ce3f0005` don't prepend `0x`) in `Errors.json` within the build artifacts - that should have most error strings in it.
---

## Deployment
1. Deploy the ProxyAdmin
`forge script script/ProxyAdmin.s.sol:ProxyAdminDeploy --rpc-url sepolia --broadcast --verify -vvvv`
1. Deploy QuestFactory (this also upgrades it to the latest version, and deployes the latest Quest and Quest1155 implementation contracts)
`forge script script/QuestFactory.s.sol:QuestFactoryDeploy --rpc-url sepolia --broadcast --verify -vvvv`
1. Deploy RabbitHoleTickets (this also upgrades it to the latest version)
`forge script script/RabbitHoleTickets.s.sol:RabbitHoleTicketsDeploy --rpc-url sepolia --broadcast --verify -vvvv`
1. Set any storage variables manually if need be (most likely the `protocolFeeRecipient` will need to be set)

### with mantel, add:
`--legacy --verifier blockscout --verifier-url "https://explorer.mantle.xyz/api?module=contract&action=verify"`
if you get `(code: -32000, message: invalid transaction: nonce too low, data: None)` try rerunning with the `--resume` flag

### with scroll, add:
`--legacy --verifier blockscout --verifier-url "https://blockscout.scroll.io/api?module=contract&action=verify"`

### verify OZ TransparentProxy
Note: This might not be needed, there is currently a bug in the mantle explorer that prevents it from marking create2 contracts as contracts
```
forge verify-contract --verifier blockscout --verifier-url "https://explorer.mantle.xyz/api?module=contract&action=verify" --num-of-optimizations 999999 --chain 5000 --compiler-version "0.8.10+commit.fc410830" 0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy
```

## Upgrading

important: make sure storage layouts are compatible, by running the upgrades-core validate script on the contract you are upgrading, for example:
`forge clean && forge build && bunx @openzeppelin/upgrades-core validate --contract RabbitHoleTickets`

Then to upgrade a contract, run one of the following commands:
`forge script script/QuestFactory.s.sol:QuestFactoryUpgrade --rpc-url sepolia --broadcast --verify -vvvv`
`forge script script/RabbitHoleTickets.s.sol:RabbitHoleTicketsUpgrade --rpc-url sepolia --broadcast --verify -vvvv`
`forge script script/Quest.s.sol:QuestDeploy --rpc-url sepolia --broadcast --verify -vvvv`
`forge script script/Quest.s.sol:Quest1155Deploy --rpc-url sepolia --broadcast --verify -vvvv`

or one command to run them all:
`echo "sepolia mainnet arbitrum optimism polygon base" | xargs -n 1 -I {} forge script script/QuestFactory.s.sol:QuestFactoryUpgrade --broadcast --verify -vvvv --rpc-url {}`
and for our mantle:
`forge script script/QuestFactory.s.sol:QuestFactoryUpgrade --broadcast --verify -vvvv --rpc-url mantle --legacy --verifier blockscout --
verifier-url "https://explorer.mantle.xyz/api?module=contract&action=verify"`

Note the extra options to use with mantel and scroll above.

---

### NFT image IPFS CIDs

red animation: bafybeietacfcrgwetjwcexdakfhmig4fgsdsb7o62n2qcpybkbiupqlkxq
red image: bafkreiafob6tgwkb4jla5ent7d7rw4ps7tjdhe32tlbdenyrc3lch76qfe
blue animation: bafybeib43gbmeloa6o6hs7xxwioyvduohmuf6yyu2avusjuke7delbou3m
blue image: bafkreicoysyc5chqjntdpxiyfojoljabycedep3mssphpwv7opfqfrlwbq

`https://cloudflare-ipfs.com/ipfs/` is a good public IPFS gateway

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
