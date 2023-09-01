// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Quest} from "../contracts/Quest.sol";
import {Quest1155} from "../contracts/Quest1155.sol";
import {RabbitHoleTickets} from "../contracts/RabbitHoleTickets.sol";
import {ProxyAdmin, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// # To Upgrade RabbitHoleTickets.sol run this command below
// ! important: make sure storage layouts are compatible first:
// forge clean && forge build && npx @openzeppelin/upgrades-core validate --contract RabbitHoleTickets
// forge script script/RabbitHoleTickets.s.sol:RabbitHoleTicketsUpgrade --rpc-url sepolia --broadcast --verify -vvvv
contract RabbitHoleTicketsUpgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        address rabbitHoleTicketsAddress = 0x0D380362762B0cf375227037f2217f59A4eC4b9E;
        address proxyAdminAddress = 0xD28fbF7569f31877922cDc31a1A5B3C504E8faa1;
        ITransparentUpgradeableProxy RabbitHoleTicketsProxy = ITransparentUpgradeableProxy(payable(rabbitHoleTicketsAddress));

        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin(proxyAdminAddress).upgrade(RabbitHoleTicketsProxy, address(new RabbitHoleTickets()));

        vm.stopBroadcast();
    }
}