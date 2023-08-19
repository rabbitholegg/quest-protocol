// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../ProtocolRewardsTest.sol";
// import console.log
// import "forge-std/console.sol";

contract IncreaseBalance is ProtocolRewardsTest {
    function setUp() public override {
        super.setUp();

        vm.deal(collector, 40 ether);
        vm.deal(creator, 20 ether);
        vm.deal(owner, 10 ether);

        vm.prank(collector);
        protocolRewards.deposit{value: 10 ether}(creator, "", "");
        (bool success,) = address(protocolRewards).call{value: 20 ether}("");
        require(success, "deposit failed");
    }

    function testExcessSupply() public {
        assertEq(protocolRewards.totalBalance(), 10 ether);
        assertEq(protocolRewards.excessSupply(), 20 ether);
    }

    function testIncreaseBalance() public {
        vm.prank(owner);
        protocolRewards.increaseBalance(collector, 5 ether);

        assertEq(protocolRewards.balanceOf(collector), 5 ether);
        assertEq(protocolRewards.totalBalance(), 15 ether);
        assertEq(protocolRewards.excessSupply(), 15 ether);
    }

    function testIncreaseBalance_with_error_INVALID_AMOUNT() public {
        vm.expectRevert(abi.encodeWithSignature("INVALID_AMOUNT()"));

        vm.prank(owner);
        protocolRewards.increaseBalance(collector, 100 ether);
    }

    function testIncreaseBalanceBatch() public {
        address[] memory addresses = new address[](2);
        addresses[0] = collector;
        addresses[1] = collector2;

        uint256[] memory values = new uint256[](2);
        values[0] = uint256(5 ether);
        values[1] = uint256(3 ether);

        vm.prank(owner);
        protocolRewards.increaseBalanceBatch(addresses, values);

        assertEq(protocolRewards.balanceOf(collector), 5 ether);
        assertEq(protocolRewards.balanceOf(collector2), 3 ether);
        assertEq(protocolRewards.totalBalance(), 18 ether);
        assertEq(protocolRewards.excessSupply(), 12 ether);
    }


    function testIncreaseBalanceBatch_with_error_INVALID_AMOUNT() public {
        vm.expectRevert(abi.encodeWithSignature("INVALID_AMOUNT()"));

        address[] memory addresses = new address[](2);
        addresses[0] = collector;
        addresses[1] = collector2;

        uint256[] memory values = new uint256[](2);
        values[0] = uint256(5 ether);
        values[1] = uint256(300 ether);

        vm.prank(owner);
        protocolRewards.increaseBalanceBatch(addresses, values);
    }
}
