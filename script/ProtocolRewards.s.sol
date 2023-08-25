// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {ProtocolRewards} from "../contracts/ProtocolRewards.sol";
import {ERC1967FactoryConstants} from "solady/src/utils/ERC1967FactoryConstants.sol";
import {ERC1967Factory} from "solady/src/utils/ERC1967Factory.sol";

// # To deploy and verify this contract run this below, replacing sepolia with the rpc alias of the network you are deploying on
// forge script script/ProtocolRewards.s.sol:ProtocolRewardsScript --rpc-url sepolia --broadcast --verify -vvvv
// this should deploy to 0x168437d131f8def2d94b555ff34f4539458dd6f9

// to upgrade this contract
// 1. deploy a new implementation (script todo)
// 2. use the functions in the erc1967factory to upgrade it. This is deployed everywhere at 0x0000000000006396FF2a80c067f99B3d2Ab4Df24

contract ProtocolRewardsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.envAddress("MAINNET_PRIVATE_KEY_PUBLIC_ADDRESS");
        address protocolRewardsImp = address(new ProtocolRewards());
        ERC1967Factory factory = ERC1967Factory(ERC1967FactoryConstants.ADDRESS);
        bytes memory initializeCallData = abi.encodeWithSignature("initialize(address)", owner);
        // The factory will revert if the the caller is not the first 20 bytes of the salt; preventing front-running
        bytes32 salt = bytes32(bytes20(owner));

        factory.deployDeterministicAndCall(protocolRewardsImp, owner, salt, initializeCallData);

        vm.stopBroadcast();
    }
}