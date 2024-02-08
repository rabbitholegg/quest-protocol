// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {BoostPass} from "../contracts/BoostPass.sol";
import {QuestContractConstants as C} from "../contracts/libraries/QuestContractConstants.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";

// # To deploy and verify BoostPass.sol run this command below
// forge script script/BoostPass.s.sol:BoostPassDeploy --rpc-url sepolia --broadcast --verify -vvvv
contract BoostPassDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.envAddress("MAINNET_PRIVATE_KEY_PUBLIC_ADDRESS");
        address claimSignerAddress = vm.envAddress("CLAIM_SIGNER_ADDRESS");
        address treasuryAddress = 0x48E6a039bcF6d99806Ce4595fC59e4A7C0CaAB19; // llama treasury address
        string memory baseURI = "https://api.rabbithole.gg/v1/boost-pass/";
        bytes memory initializeCallData = abi.encodeWithSignature("initialize(address,address,uint256,address,string)", owner, claimSignerAddress, 2000000000000000, treasuryAddress, baseURI);
        address boostPassImpAddress = address(new BoostPass());
        // The factory will revert if the the caller is not the first 20 bytes of the salt; preventing front-running
        bytes32 salt = bytes32(abi.encodePacked(bytes20(owner), bytes12("BoostPass3")));

        ERC1967Factory(ERC1967FactoryConstants.ADDRESS).deployDeterministicAndCall(boostPassImpAddress, owner, salt, initializeCallData);

        vm.stopBroadcast();
    }
}

// to upgrade BoostPass, run the commands below:
// ! important: make sure storage layouts are compatible first:
// forge clean && forge build && npx @openzeppelin/upgrades-core validate --contract BoostPass
// forge script script/BoostPass.s.sol:BoostPassUpgrade --rpc-url sepolia --broadcast --verify -vvvv
contract BoostPassUpgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        ERC1967Factory(ERC1967FactoryConstants.ADDRESS).upgrade(C.BOOST_PASS_ADDRESS, address(new BoostPass()));

        vm.stopBroadcast();
    }
}