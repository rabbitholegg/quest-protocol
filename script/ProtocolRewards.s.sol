// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {ProtocolRewards} from "../contracts/ProtocolRewards.sol";
import {QuestContractConstants as C} from "../contracts/libraries/QuestContractConstants.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";

// # To deploy and verify ProtocolRewards.sol run this command below
// forge script script/ProtocolRewards.s.sol:ProtocolRewardsDeploy --rpc-url sepolia --broadcast --verify -vvvv
contract ProtocolRewardsDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.envAddress("MAINNET_PRIVATE_KEY_PUBLIC_ADDRESS");
        address protocolRewardsImp = address(new ProtocolRewards());
        bytes memory initializeCallData = abi.encodeWithSignature("initialize(address)", owner);
        // The factory will revert if the the caller is not the first 20 bytes of the salt; preventing front-running
        bytes32 salt = bytes32(bytes20(owner));

        ERC1967Factory(ERC1967FactoryConstants.ADDRESS).deployDeterministicAndCall(protocolRewardsImp, owner, salt, initializeCallData);

        vm.stopBroadcast();
    }
}

// to upgrade ProtocolRewards, run the commands below:
// ! important: make sure storage layouts are compatible first:
// forge clean && forge build && npx @openzeppelin/upgrades-core validate --contract ProtocolRewards
// forge script script/ProtocolRewards.s.sol:ProtocolRewardsUpgrade --rpc-url sepolia --broadcast --verify -vvvv
contract ProtocolRewardsUpgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        ERC1967Factory(ERC1967FactoryConstants.ADDRESS).upgrade(C.PROTOCOL_REWARDS_ADDRESS, address(new ProtocolRewards()));

        vm.stopBroadcast();
    }
}