// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "../contracts/RabbitHoleProfile.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";

contract RabbitHoleProfileTest is Test {
    RabbitHoleProfile internal rabbitHoleProfile;
    ERC1967Factory internal factory;

    uint256 claimSignerPrivateKey;
    address internal owner;

    function setUp() public virtual {
        owner = makeAddr("owner");
        Vm.Wallet memory claimSigner = vm.createWallet("claimSigner");
        claimSignerPrivateKey = claimSigner.privateKey;

        address rabbitHoleProfileImp = address(new RabbitHoleProfile());
        factory = new ERC1967Factory();

        // initializeCallData is setting up: RabbitHoleProfile.initialize(owner);
        bytes memory initializeCallData = abi.encodeWithSignature("initialize(address,address)", owner, claimSigner.addr);
        address rabbitHoleProfileAddr = factory.deployAndCall(rabbitHoleProfileImp, owner, initializeCallData);
        rabbitHoleProfile = RabbitHoleProfile(rabbitHoleProfileAddr);

        vm.label(address(rabbitHoleProfile), "RabbitHoleProfile");
    }

    // todo
}
