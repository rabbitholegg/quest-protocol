// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {PowerPass} from "../contracts/PowerPass.sol";
import {QuestContractConstants as C} from "../contracts/libraries/QuestContractConstants.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";

// # To deploy and verify PowerPass.sol run this command below
// forge script script/PowerPass.s.sol:PowerPassDeploy --rpc-url sepolia --broadcast --verify -vvvv
contract PowerPassDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.envAddress("MAINNET_PRIVATE_KEY_PUBLIC_ADDRESS");
        address claimSignerAddress = vm.envAddress("CLAIM_SIGNER_ADDRESS");
        bytes memory initializeCallData = abi.encodeWithSignature("initialize(address,address)", owner, claimSignerAddress);
        address powerPassImpAddress = address(new PowerPass());
        // The factory will revert if the the caller is not the first 20 bytes of the salt; preventing front-running
        bytes32 salt = bytes32(abi.encodePacked(bytes20(owner), bytes12("PowerPass")));

        ERC1967Factory(ERC1967FactoryConstants.ADDRESS).deployDeterministicAndCall(powerPassImpAddress, owner, salt, initializeCallData);

        vm.stopBroadcast();
    }
}

// to upgrade PowerPass, run the commands below:
// ! important: make sure storage layouts are compatible first:
// forge clean && forge build && npx @openzeppelin/upgrades-core validate --contract PowerPass
// forge script script/PowerPass.s.sol:PowerPassUpgrade --rpc-url sepolia --broadcast --verify -vvvv
contract PowerPassUpgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        ERC1967Factory(ERC1967FactoryConstants.ADDRESS).upgrade(C.POWER_PASS_ADDRESS, address(new PowerPass()));

        vm.stopBroadcast();
    }
}