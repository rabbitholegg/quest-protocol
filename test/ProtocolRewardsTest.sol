// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "../contracts/ProtocolRewards.sol";

contract ProtocolRewardsTest is Test {
    uint256 internal constant ETH_SUPPLY = 120_200_000 ether;

    ProtocolRewards internal protocolRewards;

    address internal collector;
    address internal collector2;
    address internal creator;
    address internal owner;

    function setUp() public virtual {
        collector = makeAddr("collector");
        collector2 = makeAddr("collector2");
        creator = makeAddr("creator");
        owner = makeAddr("owner");

        vm.prank(owner);
        protocolRewards = new ProtocolRewards();
        vm.label(address(protocolRewards), "protocolRewards");
    }
}
