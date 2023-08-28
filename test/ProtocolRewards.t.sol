// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "../contracts/ProtocolRewards.sol";
import {ERC1967Factory} from "solady/src/utils/ERC1967Factory.sol";

contract ProtocolRewardsTest is Test {
    ProtocolRewards internal protocolRewards;
    ERC1967Factory internal factory;

    address internal collector;
    address internal collector2;
    address internal creator;
    address internal owner;

    event IncreaseBalance(address indexed to, uint256 amount);
    event Withdraw(address indexed from, address indexed to, uint256 amount);

    function setUp() public virtual {
        collector = makeAddr("collector");
        collector2 = makeAddr("collector2");
        creator = makeAddr("creator");
        owner = makeAddr("owner");

        address protocolRewardsImp = address(new ProtocolRewards());
        factory = new ERC1967Factory();

        // initializeCallData is setting up: protocolRewards.initialize(owner);
        bytes memory initializeCallData = abi.encodeWithSignature("initialize(address)", owner);
        address payable protocolRewardsAddr = payable(factory.deployAndCall(protocolRewardsImp, owner, initializeCallData));
        protocolRewards = ProtocolRewards(protocolRewardsAddr);

        vm.label(address(protocolRewards), "protocolRewards");

        vm.deal(collector, 40 ether);
        vm.deal(creator, 20 ether);
        vm.deal(owner, 10 ether);

        vm.prank(collector);
        protocolRewards.deposit{value: 10 ether}(creator, "", "");
        (bool success,) = address(protocolRewards).call{value: 20 ether}("");
        require(success, "deposit failed");
    }

    // increase balance tests
    function test_excessSupply() public {
        assertEq(protocolRewards.totalBalance(), 10 ether);
        assertEq(protocolRewards.excessSupply(), 20 ether);
    }

    function test_increaseBalance() public {
        vm.prank(owner);

        vm.expectEmit();
        emit IncreaseBalance(collector, 5 ether);

        protocolRewards.increaseBalance(collector, 5 ether);

        assertEq(protocolRewards.balanceOf(collector), 5 ether);
        assertEq(protocolRewards.totalBalance(), 15 ether);
        assertEq(protocolRewards.excessSupply(), 15 ether);
    }

    function test_RevertIf_increaseBalance_INVALID_AMOUNT() public {
        vm.expectRevert(abi.encodeWithSignature("INVALID_AMOUNT()"));

        vm.prank(owner);
        protocolRewards.increaseBalance(collector, 100 ether);
    }

    function test_increaseBalanceBatch() public {
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


    function test_RevertIf_increaseBalanceBatch_INVALID_AMOUNT() public {
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

    // withdraw tests
    function getDomainSeparator() internal view virtual returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ProtocolRewards")),
                keccak256(bytes("1")),
                block.chainid,
                address(protocolRewards)
            )
        );
    }

    function test_withdraw() public {
        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.prank(creator);

        vm.expectEmit();
        emit Withdraw(creator, creator, creatorRewardsBalance);

        protocolRewards.withdraw(creator, creatorRewardsBalance);

        assertEq(creator.balance, beforeCreatorBalance + creatorRewardsBalance);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - creatorRewardsBalance);
    }

    function test_fuzz_withdraw(uint256 amount) public {
        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        amount = bound(amount, 1,  protocolRewards.balanceOf(creator));
        vm.prank(creator);

        protocolRewards.withdraw(creator, amount);

        assertEq(creator.balance, beforeCreatorBalance + amount);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - amount);
    }


    function test_withdrawFullBalance() public {
        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.prank(creator);
        protocolRewards.withdraw(creator, 0);

        assertEq(creator.balance, beforeCreatorBalance + creatorRewardsBalance);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - creatorRewardsBalance);
    }

    function test_RevertIf_withdraw_ADDRESS_ZERO() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.expectRevert(abi.encodeWithSignature("ADDRESS_ZERO()"));
        vm.prank(creator);
        protocolRewards.withdraw(address(0), creatorRewardsBalance);
    }

    function test_RevertIf_withdraw_INVALID_WITHDRAW() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.expectRevert(abi.encodeWithSignature("INVALID_WITHDRAW()"));
        vm.prank(creator);
        protocolRewards.withdraw(creator, creatorRewardsBalance + 1);
    }

    function test_withdrawFor() public {
        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        protocolRewards.withdrawFor(creator, creatorRewardsBalance);

        assertEq(creator.balance, beforeCreatorBalance + creatorRewardsBalance);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - creatorRewardsBalance);
    }

    function test_Fuzz_withdrawFor(uint256 amount) public {
        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        amount = bound(amount, 1,  protocolRewards.balanceOf(creator));
        protocolRewards.withdrawFor(creator, amount);

        assertEq(creator.balance, beforeCreatorBalance + amount);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - amount);
    }

    function test_withdrawForFullBalance() public {
        uint256 beforeCreatorBalance = creator.balance;
        uint256 beforeTotalSupply = protocolRewards.totalSupply();

        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        protocolRewards.withdrawFor(creator, 0);

        assertEq(creator.balance, beforeCreatorBalance + creatorRewardsBalance);
        assertEq(protocolRewards.totalSupply(), beforeTotalSupply - creatorRewardsBalance);
    }

    function test_RevertIf_withdrawFor_INVALID_WITHDRAW() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.expectRevert(abi.encodeWithSignature("INVALID_WITHDRAW()"));
        protocolRewards.withdrawFor(creator, creatorRewardsBalance + 1);
    }

    function test_RevertIf_withdrawFor_ADDRESS_ZERO() public {
        uint256 creatorRewardsBalance = protocolRewards.balanceOf(creator);

        vm.expectRevert(abi.encodeWithSignature("ADDRESS_ZERO()"));
        protocolRewards.withdrawFor(address(0), creatorRewardsBalance);
    }
}
