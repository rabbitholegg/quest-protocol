// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "../contracts/PowerPass.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";

contract PowerPassTest is Test {
    PowerPass internal powerPass;
    ERC1967Factory internal factory;

    uint256 claimSignerPrivateKey;
    address internal owner;

    function setUp() public virtual {
        owner = makeAddr("owner");
        Vm.Wallet memory claimSigner = vm.createWallet("claimSigner");
        claimSignerPrivateKey = claimSigner.privateKey;

        address powerPassImp = address(new PowerPass());
        factory = new ERC1967Factory();

        // initializeCallData is setting up: PowerPass.initialize(owner);
        bytes memory initializeCallData = abi.encodeWithSignature("initialize(address,address)", owner, claimSigner.addr);
        address powerPassAddr = factory.deployAndCall(powerPassImp, owner, initializeCallData);
        powerPass = PowerPass(powerPassAddr);

        vm.label(address(powerPass), "PowerPass");
    }

    // todo
}
