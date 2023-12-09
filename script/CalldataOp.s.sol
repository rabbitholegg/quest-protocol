// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {CalldataOp} from "../contracts/test/CalldataOp.sol";

// forge script script/CalldataOp.s.sol:CalldataOpDeploy --rpc-url op_sepolia --broadcast --verify --verifier blockscout --verifier-url "https://optimism-sepolia.blockscout.com/api?module=contract&action=verify"
contract CalldataOpDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        bytes memory name = "0x1321b3a0e085d3a28c9de9d101e036f1b69ce5a603270d0fab1da300a5c03140";
        new CalldataOp(name);

        vm.stopBroadcast();
    }
}