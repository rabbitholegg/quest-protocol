// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Quest} from "../contracts/Quest.sol";
import {Quest1155} from "../contracts/Quest1155.sol";
import {RabbitHoleTickets} from "../contracts/RabbitHoleTickets.sol";
import {QuestContractConstants as C} from "../contracts/libraries/QuestContractConstants.sol";
import {ProxyAdmin, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// # To Upgrade RabbitHoleTickets.sol run this command below
// ! important: make sure storage layouts are compatible first:
// forge clean && forge build && npx @openzeppelin/upgrades-core validate --contract RabbitHoleTickets
// forge script script/RabbitHoleTickets.s.sol:RabbitHoleTicketsUpgrade --rpc-url sepolia --broadcast --verify -vvvv
contract RabbitHoleTicketsUpgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        ITransparentUpgradeableProxy RabbitHoleTicketsProxy = ITransparentUpgradeableProxy(C.RABBIT_HOLE_TICKETS_ADDRESS);

        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin(C.PROXY_ADMIN_ADDRESS).upgrade(RabbitHoleTicketsProxy, address(new RabbitHoleTickets()));

        vm.stopBroadcast();
    }
}

contract RabbitHoleTicketsDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        ITransparentUpgradeableProxy RabbitHoleTicketsProxy = ITransparentUpgradeableProxy(C.RABBIT_HOLE_TICKETS_ADDRESS);
        string memory json = vm.readFile("script/deployDataBytes.json");
        bytes memory ogData = vm.parseJsonBytes(json, "$.rabbitHoleTicketsOgImpl");
        bytes memory data = vm.parseJsonBytes(json, "$.rabbitHoleTicketsData");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy OgImpl
        (bool success,) = C.DETERMINISTIC_DEPLOY_PROXY.call(ogData);
        require(success, "failed to deploy OgImpl");

        // Deploy RabbitHoleTickets
        (bool success2,) = C.DETERMINISTIC_DEPLOY_PROXY.call(data);
        require(success2, "failed to deploy RHTickets");

        // Upgrade
        ProxyAdmin(C.PROXY_ADMIN_ADDRESS).upgrade(RabbitHoleTicketsProxy, address(new RabbitHoleTickets()));

        // Initialize
        RabbitHoleTickets(C.RABBIT_HOLE_TICKETS_ADDRESS).initialize(
            owner,                                                          // royaltyRecipient_
            owner,                                                          // minterAddress_
            100,                                                            // royaltyFee_
            owner,                                                          // owner_
            "bafkreicoysyc5chqjntdpxiyfojoljabycedep3mssphpwv7opfqfrlwbq",  // imageIPFSCID_ (blue)
            "bafybeib43gbmeloa6o6hs7xxwioyvduohmuf6yyu2avusjuke7delbou3m"   // animationUrlIPFSCID_ (blue)
        );

        vm.stopBroadcast();
    }
}