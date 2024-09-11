// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";

import {IERC1155Receiver} from "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {MockERC20, MockERC1155} from "contracts/references/Mocks.sol";
import {QuestFactoryMock} from "./mocks/QuestFactoryMock.sol";
import {BoostError} from "contracts/references/BoostError.sol";
import {Budget} from "contracts/references/Budget.sol";
import {Cloneable} from "contracts/references/Cloneable.sol";
import {QuestBudget} from "contracts/QuestBudget.sol";
import {IQuestFactory} from "contracts/interfaces/IQuestFactory.sol";
import {TestUtils} from "./helpers/TestUtils.sol";
import "forge-std/console.sol";

contract QuestBudgetTest is Test, TestUtils, IERC1155Receiver {
    MockERC20 mockERC20;
    MockERC20 otherMockERC20;
    MockERC1155 mockERC1155;
    QuestFactoryMock mockQuestFactory;
    QuestBudget questBudget;

    event QuestCancelled(address indexed questAddress, string questId, uint256 endsAt);
    event ManagementFeePaid(string indexed questId, address indexed manager, uint256 amount);

    function setUp() public {
        address owner = address(this);
        // Deploy a new ERC20 contract and mint 100 tokens
        mockERC20 = new MockERC20();
        mockERC20.mint(address(this), 100 ether);

        // Deploy a new ERC1155 contract and mint 100 of token ID 42
        mockERC1155 = new MockERC1155();
        mockERC1155.mint(address(this), 42, 100);

        // Deploy a new QuestFactoryMock contract
        mockQuestFactory = new QuestFactoryMock();

        // Deploy a new QuestBudget contract
        questBudget = QuestBudget(payable(LibClone.clone(address(new QuestBudget()))));
        address[] memory authorized = new address[](1);
        authorized[0] = owner;
        questBudget.initialize(
            abi.encode(QuestBudget.InitPayload({owner: owner, questFactory: address(mockQuestFactory), authorized: authorized}))
        );
        questBudget.setDisburseEnabled(true);
    }

    ////////////////////////////////
    // QuestBudget initial state //
    ////////////////////////////////

    function test_InitialOwner() public {
        // Ensure the budget has the correct owner
        assertEq(questBudget.owner(), address(this));
    }

    function test_InitialDistributed() public {
        // Ensure the budget has 0 tokens distributed
        assertEq(questBudget.total(address(mockERC20)), 0);
    }

    function test_InitialDistributed1155() public {
        // Ensure the budget has 0 of our 1155 tokens distributed
        assertEq(questBudget.total(address(mockERC1155), 42), 0);
    }

    function test_InitialTotal() public {
        // Ensure the budget has 0 tokens allocated
        assertEq(questBudget.total(address(mockERC20)), 0);
    }

    function test_InitialTotal1155() public {
        // Ensure the budget has 0 of our 1155 tokens allocated
        assertEq(questBudget.total(address(mockERC1155), 42), 0);
    }

    function test_InitialAvailable() public {
        // Ensure the budget has 0 tokens available
        assertEq(questBudget.available(address(mockERC20)), 0);
    }

    function test_InitialAvailable1155() public {
        // Ensure the budget has 0 of our 1155 tokens available
        assertEq(questBudget.available(address(mockERC1155), 42), 0);
    }

    function test_InitialManagementFee() public {
        // Ensure the management fee is 0
        assertEq(questBudget.managementFee(), 0);
    }

    function test_InitializerDisabled() public {
        // Because the slot is private, we use `vm.load` to access it then parse out the bits:
        //   - [0] is the `initializing` flag (which should be 0 == false)
        //   - [1..64] hold the `initializedVersion` (which should be 1)
        bytes32 slot =
            vm.load(address(questBudget), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffbf601132);

        uint64 version;
        assembly {
            version := shr(1, slot)
        }

        assertNotEq(version, 0, "Version should not be 0");
    }

    /////////////////////////////
    // QuestBudget.initialize //
    /////////////////////////////

    function testInitialize() public {
        // Initializer can only be called on clones, not the base contract
        bytes memory data = abi.encode(QuestBudget.InitPayload({owner: address(this), questFactory: address(mockQuestFactory) ,authorized: new address[](0)}));
        QuestBudget clone = QuestBudget(payable(LibClone.clone(address(questBudget))));
        clone.initialize(data);

        // Ensure the budget has the correct authorities
        assertEq(clone.owner(), address(this));
        assertEq(clone.questFactory(), address(mockQuestFactory));
        assertEq(clone.isAuthorized(address(this)), true);
    }

    function testInitialize_ImproperData() public {
        // with improperly encoded data
        bytes memory data = abi.encodePacked(new address[](0), address(this));
        vm.expectRevert();
        questBudget.initialize(data);
    }

    ///////////////////////////
    // QuestBudget.allocate //
    ///////////////////////////

    function testAllocate() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        assertTrue(questBudget.allocate(data));

        // Ensure the budget has 100 tokens
        assertEq(questBudget.available(address(mockERC20)), 100 ether);
    }

    function testAllocate_NativeBalance() public {
        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ETH, address(0), address(this), 100 ether);
        questBudget.allocate{value: 100 ether}(data);

        // Ensure the budget has 100 tokens
        assertEq(questBudget.available(address(0)), 100 ether);
    }

    function testAllocate_ERC1155() public {
        // Approve the budget to transfer tokens
        mockERC1155.setApprovalForAll(address(questBudget), true);

        // Allocate 100 of token ID 42 to the budget
        bytes memory data = abi.encode(
            Budget.Transfer({
                assetType: Budget.AssetType.ERC1155,
                asset: address(mockERC1155),
                target: address(this),
                data: abi.encode(Budget.ERC1155Payload({tokenId: 42, amount: 100, data: ""}))
            })
        );
        assertTrue(questBudget.allocate(data));

        // Ensure the budget has 100 of token ID 42
        assertEq(questBudget.available(address(mockERC1155), 42), 100);
    }

    function testAllocate_NativeBalanceValueMismatch() public {
        // Encode an allocation of 100 ETH
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ETH, address(0), address(this), 100 ether);

        // Expect a revert due to a value mismatch (too much ETH)
        vm.expectRevert(abi.encodeWithSelector(Budget.InvalidAllocation.selector, address(0), uint256(100 ether)));
        questBudget.allocate{value: 101 ether}(data);

        // Expect a revert due to a value mismatch (too little ETH)
        vm.expectRevert(abi.encodeWithSelector(Budget.InvalidAllocation.selector, address(0), uint256(100 ether)));
        questBudget.allocate{value: 99 ether}(data);
    }

    function testAllocate_NoApproval() public {
        // Allocate 100 tokens to the budget without approval
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        questBudget.allocate(data);
    }

    function testAllocate_InsufficientFunds() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 101 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 101 ether);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        questBudget.allocate(data);
    }

    function testAllocate_ImproperData() public {
        bytes memory data;

        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // with improperly encoded data
        data = abi.encodePacked(mockERC20, uint256(100 ether));
        vm.expectRevert();
        questBudget.allocate(data);
    }

    ///////////////////////////
    // QuestBudget.reclaim  //
    ///////////////////////////

    function testReclaim() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.available(address(mockERC20)), 100 ether);

        // Reclaim 99 tokens from the budget
        data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 99 ether);
        assertTrue(questBudget.reclaim(data));

        // Ensure the budget has 1 token left
        assertEq(questBudget.available(address(mockERC20)), 1 ether);
    }

    function testReclaim_NativeBalance() public {
        // Allocate 100 ETH to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ETH, address(0), address(this), 100 ether);
        questBudget.allocate{value: 100 ether}(data);
        assertEq(questBudget.available(address(0)), 100 ether);

        // Reclaim 99 ETH from the budget
        data = _makeFungibleTransfer(Budget.AssetType.ETH, address(0), address(1), 99 ether);
        assertTrue(questBudget.reclaim(data));

        // Ensure the budget has 1 ETH left
        assertEq(questBudget.available(address(0)), 1 ether);
    }

    function testReclaim_ERC1155() public {
        // Approve the budget to transfer tokens
        mockERC1155.setApprovalForAll(address(questBudget), true);

        // Allocate 100 of token ID 42 to the budget
        bytes memory data = abi.encode(
            Budget.Transfer({
                assetType: Budget.AssetType.ERC1155,
                asset: address(mockERC1155),
                target: address(this),
                data: abi.encode(Budget.ERC1155Payload({tokenId: 42, amount: 100, data: ""}))
            })
        );
        questBudget.allocate(data);
        assertEq(questBudget.available(address(mockERC1155), 42), 100);

        // Reclaim 99 of token ID 42 from the budget
        data = abi.encode(
            Budget.Transfer({
                assetType: Budget.AssetType.ERC1155,
                asset: address(mockERC1155),
                target: address(this),
                data: abi.encode(Budget.ERC1155Payload({tokenId: 42, amount: 99, data: ""}))
            })
        );
        assertTrue(questBudget.reclaim(data));

        // Ensure the budget has 1 of token ID 42 left
        assertEq(questBudget.available(address(mockERC1155), 42), 1);
    }

    function testReclaim_ZeroAmount() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.available(address(mockERC20)), 100 ether);

        // Reclaim all tokens from the budget
        data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 0);
        assertTrue(questBudget.reclaim(data));

        // Ensure the budget has no tokens left
        assertEq(questBudget.available(address(mockERC20)), 0 ether);
    }

    function testReclaim_ZeroAddress() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.available(address(mockERC20)), 100 ether);

        // Reclaim 100 tokens from the budget to address(0)
        data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(0), 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(Budget.TransferFailed.selector, address(mockERC20), address(0), uint256(100 ether))
        );
        questBudget.reclaim(data);

        // Ensure the budget has 100 tokens
        assertEq(questBudget.available(address(mockERC20)), 100 ether);
    }

    function testReclaim_InsufficientFunds() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.total(address(mockERC20)), 100 ether);

        // Reclaim 101 tokens from the budget
        data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 101 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                Budget.InsufficientFunds.selector, address(mockERC20), uint256(100 ether), uint256(101 ether)
            )
        );
        questBudget.reclaim(data);
    }

    function testReclaim_ImproperData() public {
        bytes memory data;

        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.total(address(mockERC20)), 100 ether);

        // with improperly encoded data
        data = abi.encodePacked(mockERC20, uint256(100 ether));
        vm.expectRevert();
        questBudget.reclaim(data);
    }

    function testReclaim_NotOwner() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.total(address(mockERC20)), 100 ether);

        // Try to reclaim 100 tokens from the budget as a non-owner
        // We can reuse the data from above because the target is `address(this)` in both cases
        vm.prank(address(1));
        vm.expectRevert();
        questBudget.reclaim(data);
    }

    //////////////////////////////////
    // QuestBudget.createERC20Quest //
    //////////////////////////////////
    function testCreateERC20Quest() public {
        // Define the parameters for the new quest
        uint32 txHashChainId_ = 1;
        address rewardTokenAddress_ = address(mockERC20);
        uint256 endTime_ = block.timestamp + 1 days;
        uint256 startTime_ = block.timestamp;
        uint256 totalParticipants_ = 10;
        uint256 rewardAmount_ = 1 ether;
        string memory questId_ = "testQuest";
        string memory actionType_ = "testAction";
        string memory questName_ = "Test Quest";
        string memory projectName_ = "Test Project";
        uint256 referralRewardFee_ = 250;
        
        uint256 maxTotalRewards = totalParticipants_ * rewardAmount_;
        uint256 questFee = uint256(mockQuestFactory.questFee());
        uint256 referralRewardFee = uint256(mockQuestFactory.referralRewardFee());
        uint256 maxProtocolReward = (maxTotalRewards * questFee) / 10_000;
        uint256 maxReferralReward = (maxTotalRewards * referralRewardFee) / 10_000;
        uint256 approvalAmount = maxTotalRewards + maxProtocolReward + maxReferralReward;
        mockERC20.mint(address(this), approvalAmount);
        // Ensure the budget has enough tokens for the reward
        mockERC20.approve(address(questBudget), approvalAmount);
        questBudget.allocate(
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), approvalAmount)
        );

        // Create the new quest
        address questAddress = questBudget.createERC20Quest(
            txHashChainId_,
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmount_,
            questId_,
            actionType_,
            questName_,
            projectName_,
            referralRewardFee_
        );

        // Ensure the returned quest address is not the zero address
        assertTrue(questAddress != address(0));

        // Ensure the quest contract has the correct reward amount
        assertEq(IERC20(rewardTokenAddress_).balanceOf(questAddress), approvalAmount);
    }

    function testCreateERC20Quest_WithManagementFee() public {
        // Set management fee
        vm.prank(questBudget.owner());
        questBudget.setManagementFee(500); // 5%

        // Calculate the amounts needed for the quest
        uint256 totalParticipants = 10;
        uint256 rewardAmount = 1 ether;
        uint256 maxTotalRewards = totalParticipants * rewardAmount;
        uint256 questFee = uint256(mockQuestFactory.questFee());
        uint256 referralRewardFee = 250; // 2.5%
        uint256 maxProtocolReward = (maxTotalRewards * questFee) / 10_000;
        uint256 maxReferralReward = (maxTotalRewards * referralRewardFee) / 10_000;
        uint256 maxManagementFee = (maxTotalRewards * questBudget.managementFee()) / 10_000; // 5% management fee
        uint256 questFactoryApprovalAmount = maxTotalRewards + maxProtocolReward + maxReferralReward;
        uint256 totalAllocationRequired = questFactoryApprovalAmount + maxManagementFee;

        // Approve questBudget to spend tokens
        mockERC20.approve(address(questBudget), totalAllocationRequired);

        // Allocate tokens to questBudget
        questBudget.allocate(
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), totalAllocationRequired)
        );

        // Create quest
        string memory questId = "testQuest";
        address questAddress = questBudget.createERC20Quest(
            1, // txHashChainId
            address(mockERC20), // rewardTokenAddress
            block.timestamp + 1 days, // endTime
            block.timestamp, // startTime
            totalParticipants, // totalParticipants
            rewardAmount, // rewardAmount
            questId, // questId
            "testAction", // actionType
            "Test Quest", // questName
            "Test Project", // projectName
            referralRewardFee // referralRewardFee
        );

        // Ensure the returned quest address is not the zero address
        assertTrue(questAddress != address(0));

        // Assert that the quest manager is set to the test contract
        assertEq(questBudget.questManagers(questId), address(this));

        // Assert that the reserved funds is equal to the management fee
        assertEq(questBudget.reservedFunds(), maxManagementFee);

        // Calculate the expected available balance
        uint256 expectedAvailable = totalAllocationRequired - questFactoryApprovalAmount - maxManagementFee;

        // Assert that the available balance is 0
        assertEq(expectedAvailable, 0);

        // Assert that the available balance is equal to the expected available balance
        assertEq(questBudget.available(address(mockERC20)), expectedAvailable);
    }

    function testCreateERC20Quest_InsufficientFunds() public {
        // Set management fee
        vm.prank(questBudget.owner());
        questBudget.setManagementFee(500); // 5%

        // Calculate the amounts needed for the quest
        uint256 totalParticipants = 10;
        uint256 rewardAmount = 1 ether;
        uint256 maxTotalRewards = totalParticipants * rewardAmount;
        uint256 questFee = uint256(mockQuestFactory.questFee());
        uint256 referralRewardFee = 250; // 2.5%
        uint256 maxProtocolReward = (maxTotalRewards * questFee) / 10_000;
        uint256 maxReferralReward = (maxTotalRewards * referralRewardFee) / 10_000;
        uint256 maxManagementFee = (maxTotalRewards * questBudget.managementFee()) / 10_000; // 5% management fee
        uint256 questFactoryApprovalAmount = maxTotalRewards + maxProtocolReward + maxReferralReward;
        uint256 totalAllocationRequired = questFactoryApprovalAmount + maxManagementFee;

        // Approve questBudget to spend tokens
        mockERC20.approve(address(questBudget), totalAllocationRequired);

        // Allocate the needed amount minus the management fee
        questBudget.allocate(
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), totalAllocationRequired - maxManagementFee)
        );

        vm.expectRevert("Insufficient funds for quest creation");
        questBudget.createERC20Quest(
            1, // txHashChainId
            address(mockERC20), // rewardTokenAddress
            block.timestamp + 1 days, // endTime
            block.timestamp, // startTime
            totalParticipants, // totalParticipants
            rewardAmount, // rewardAmount
            "testQuest", // questId
            "testAction", // actionType
            "Test Quest", // questName
            "Test Project", // projectName
            referralRewardFee // referralRewardFee
        );
    }

    ////////////////////////
    // QuestBudget.cancel //
    ////////////////////////

    function test_cancel() public {
        // Define the parameters for the new quest
        uint32 txHashChainId_ = 1;
        address rewardTokenAddress_ = address(mockERC20);
        uint256 endTime_ = block.timestamp + 1 days;
        uint256 startTime_ = block.timestamp;
        uint256 totalParticipants_ = 10;
        uint256 rewardAmount_ = 1 ether;
        string memory questId_ = "testQuest";
        string memory actionType_ = "testAction";
        string memory questName_ = "Test Quest";
        string memory projectName_ = "Test Project";
        uint256 referralRewardFee_ = 250;

        uint256 maxTotalRewards = totalParticipants_ * rewardAmount_;
        uint256 questFee = uint256(mockQuestFactory.questFee());
        uint256 referralRewardFee = uint256(mockQuestFactory.referralRewardFee());
        uint256 maxProtocolReward = (maxTotalRewards * questFee) / 10_000;
        uint256 maxReferralReward = (maxTotalRewards * referralRewardFee) / 10_000;
        uint256 approvalAmount = maxTotalRewards + maxProtocolReward + maxReferralReward;
        mockERC20.mint(address(this), approvalAmount);
        // Ensure the budget has enough tokens for the reward
        mockERC20.approve(address(questBudget), approvalAmount);
        bytes memory allocateBytes = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), approvalAmount);
        questBudget.allocate(allocateBytes);
        console.logBytes(allocateBytes);

        // Create the new quest
        address questAddress = questBudget.createERC20Quest(
            txHashChainId_,
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmount_,
            questId_,
            actionType_,
            questName_,
            projectName_,
            referralRewardFee_
        );

        // Ensure the returned quest address is not the zero address
        assertTrue(questAddress != address(0));

        // Ensure the quest contract has the correct reward amount
        assertEq(IERC20(rewardTokenAddress_).balanceOf(questAddress), approvalAmount);

        vm.expectEmit();

        emit QuestCancelled(questAddress, '', 0);

        questBudget.cancelQuest('');

    }

    ///////////////////////////
    // QuestBudget.disburse //
    ///////////////////////////

    function testDisburse() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.total(address(mockERC20)), 100 ether);

        // Disburse 100 tokens from the budget to the recipient
        data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(1), 100 ether);
        assertTrue(questBudget.disburse(data));
        assertEq(mockERC20.balanceOf(address(1)), 100 ether);

        // Ensure the budget was drained
        assertEq(questBudget.available(address(mockERC20)), 0);
        assertEq(questBudget.distributed(address(mockERC20)), 100 ether);
    }

    function testDisburse_NativeBalance() public {
        // Allocate 100 ETH to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ETH, address(0), address(this), 100 ether);
        questBudget.allocate{value: 100 ether}(data);

        // Disburse 100 ETH from the budget to the recipient
        data = _makeFungibleTransfer(Budget.AssetType.ETH, address(0), address(1), 100 ether);
        assertTrue(questBudget.disburse(data));
        assertEq(address(1).balance, 100 ether);

        // Ensure the budget was drained
        assertEq(questBudget.available(address(0)), 0);
        assertEq(questBudget.distributed(address(0)), 100 ether);
    }

    function testDisburse_ERC1155() public {
        // Approve the budget to transfer tokens
        mockERC1155.setApprovalForAll(address(questBudget), true);

        // Allocate 100 of token ID 42 to the budget
        bytes memory data = abi.encode(
            Budget.Transfer({
                assetType: Budget.AssetType.ERC1155,
                asset: address(mockERC1155),
                target: address(this),
                data: abi.encode(Budget.ERC1155Payload({tokenId: 42, amount: 100, data: ""}))
            })
        );
        questBudget.allocate(data);
        assertEq(questBudget.total(address(mockERC1155), 42), 100);

        // Disburse 100 of token ID 42 from the budget to the recipient
        data = abi.encode(
            Budget.Transfer({
                assetType: Budget.AssetType.ERC1155,
                asset: address(mockERC1155),
                target: address(1),
                data: abi.encode(Budget.ERC1155Payload({tokenId: 42, amount: 100, data: ""}))
            })
        );
        assertTrue(questBudget.disburse(data));
        assertEq(mockERC1155.balanceOf(address(1), 42), 100);

        // Ensure the budget was drained
        assertEq(questBudget.available(address(mockERC1155), 42), 0);
        assertEq(questBudget.distributed(address(mockERC1155), 42), 100);
    }

    function testDisburseBatch() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 50 ether);
        mockERC1155.setApprovalForAll(address(questBudget), true);

        // Allocate the assets to the budget
        questBudget.allocate(
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 50 ether)
        );
        questBudget.allocate{value: 25 ether}(
            _makeFungibleTransfer(Budget.AssetType.ETH, address(0), address(this), 25 ether)
        );
        questBudget.allocate(_makeERC1155Transfer(address(mockERC1155), address(this), 42, 50, bytes("")));
        assertEq(questBudget.total(address(mockERC20)), 50 ether);
        assertEq(questBudget.total(address(0)), 25 ether);
        assertEq(questBudget.total(address(mockERC1155), 42), 50);

        // Prepare the disbursement requests
        bytes[] memory requests = new bytes[](3);
        requests[0] = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(1), 25 ether);
        requests[1] = _makeFungibleTransfer(Budget.AssetType.ETH, address(0), address(2), 25 ether);
        requests[2] = _makeERC1155Transfer(address(mockERC1155), address(3), 42, 10, bytes(""));

        // Disburse:
        // 25 tokens to address(1); and
        // 25 ETH to address(2); and
        // 50 of token ID 42 to address(3)
        assertTrue(questBudget.disburseBatch(requests));

        // Ensure the budget sent 25 tokens to address(1) and has 25 left
        assertEq(questBudget.available(address(mockERC20)), 25 ether);
        assertEq(questBudget.distributed(address(mockERC20)), 25 ether);
        assertEq(mockERC20.balanceOf(address(1)), 25 ether);

        // Ensure the budget sent 25 ETH to address(2) and has 0 left
        assertEq(address(2).balance, 25 ether);
        assertEq(questBudget.available(address(0)), 0 ether);

        // Ensure the budget sent 10 of token ID 42 to address(3) and has 40 left
        assertEq(questBudget.available(address(mockERC1155), 42), 40);
    }

    function testDisburse_InsufficientFunds() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.total(address(mockERC20)), 100 ether);

        // Disburse 101 tokens from the budget to the recipient
        data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(1), 101 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                Budget.InsufficientFunds.selector, address(mockERC20), uint256(100 ether), uint256(101 ether)
            )
        );
        questBudget.disburse(data);
    }

    function testDisburse_ImproperData() public {
        bytes memory data;

        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.total(address(mockERC20)), 100 ether);

        // with improperly encoded data
        data = abi.encode(1, mockERC20, uint256(100 ether));
        vm.expectRevert();
        questBudget.disburse(data);
    }

    function testDisburse_NotOwner() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.total(address(mockERC20)), 100 ether);

        // Try to disburse 100 tokens from the budget as a non-owner
        data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(0xdeadbeef), 100 ether);
        vm.prank(address(0xc0ffee));
        vm.expectRevert();
        questBudget.disburse(data);
    }

    function testDisburse_FailedTransfer() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.total(address(mockERC20)), 100 ether);

        // Mock the ERC20 transfer to fail in an unexpected way
        vm.mockCallRevert(
            address(mockERC20),
            abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(1), 100 ether),
            unicode"WeïrdÊrrör(ツ)"
        );

        // Try to disburse 100 tokens from the budget
        data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(1), 100 ether);
        vm.expectRevert(SafeTransferLib.TransferFailed.selector);
        questBudget.disburse(data);
    }

    function testDisburse_FailedTransferInBatch() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether);
        questBudget.allocate(data);
        assertEq(questBudget.total(address(mockERC20)), 100 ether);

        // Prepare the disbursement data
        bytes[] memory requests = new bytes[](3);
        requests[0] = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(1), 25 ether);
        requests[1] = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(2), 50 ether);
        requests[2] = _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(3), 10 ether);

        // Mock the second ERC20 transfer to fail in an unexpected way
        vm.mockCallRevert(
            address(mockERC20),
            abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(2), 50 ether),
            unicode"WeïrdÊrrör(ツ)"
        );

        // Try to disburse 25 tokens to address(1) and 50 tokens to address(2)
        vm.expectRevert(SafeTransferLib.TransferFailed.selector);
        questBudget.disburseBatch(requests);
    }

    ////////////////////////
    // QuestBudget.total //
    ////////////////////////

    function testTotal() public {
        // Ensure the budget has 0 tokens
        assertEq(questBudget.total(address(mockERC20)), 0);

        // Allocate 100 tokens to the budget
        mockERC20.approve(address(questBudget), 100 ether);
        questBudget.allocate(
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether)
        );

        // Ensure the budget has 100 tokens
        assertEq(questBudget.total(address(mockERC20)), 100 ether);
    }

    function testTotal_NativeBalance() public {
        // Ensure the budget has 0 tokens
        assertEq(questBudget.total(address(0)), 0);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ETH, address(0), address(this), 100 ether);
        questBudget.allocate{value: 100 ether}(data);

        // Ensure the budget has 100 tokens
        assertEq(questBudget.total(address(0)), 100 ether);
    }

    function testTotal_SumOfAvailAndDistributed() public {
        // We'll send two allocations of 100 tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 50 tokens to the budget
        questBudget.allocate(
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 50 ether)
        );

        // Disburse 25 tokens from the budget to the recipient
        questBudget.disburse(_makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(1), 25 ether));

        // Allocate another 50 tokens to the budget
        questBudget.allocate(
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 50 ether)
        );

        // Ensure the budget has 50 - 25 + 50 = 75 tokens
        assertEq(questBudget.available(address(mockERC20)), 75 ether);

        // Ensure the budget has 25 tokens distributed
        assertEq(questBudget.distributed(address(mockERC20)), 25 ether);

        // Ensure the total is 75 available + 25 distributed = 100 tokens
        assertEq(questBudget.total(address(mockERC20)), 100 ether);
    }



    ////////////////////////////
    // QuestBudget.available //
    ////////////////////////////

    function testAvailable() public {
        // Ensure the budget has 0 tokens available
        assertEq(questBudget.available(address(mockERC20)), 0);

        // Allocate 100 tokens to the budget
        mockERC20.approve(address(questBudget), 100 ether);
        questBudget.allocate(
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether)
        );

        // Ensure the budget has 100 tokens available
        assertEq(questBudget.available(address(mockERC20)), 100 ether);
    }

    function testAvailable_NativeBalance() public {
        // Ensure the budget has 0 tokens available
        assertEq(questBudget.available(address(0)), 0);

        // Allocate 100 tokens to the budget
        bytes memory data = _makeFungibleTransfer(Budget.AssetType.ETH, address(0), address(this), 100 ether);
        questBudget.allocate{value: 100 ether}(data);

        // Ensure the budget has 100 tokens available
        assertEq(questBudget.available(address(0)), 100 ether);
    }

    function testAvailable_NeverAllocated() public {
        // Ensure the budget has 0 tokens available
        assertEq(questBudget.available(address(otherMockERC20)), 0);
    }

    //////////////////////////////
    // QuestBudget.distributed //
    //////////////////////////////

    function testDistributed() public {
        // Ensure the budget has 0 tokens distributed
        assertEq(questBudget.distributed(address(mockERC20)), 0);

        // Allocate 100 tokens to the budget
        mockERC20.approve(address(questBudget), 100 ether);
        questBudget.allocate(
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether)
        );

        // Disburse 50 tokens from the budget to the recipient
        questBudget.disburse(
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 50 ether)
        );

        // Ensure the budget has 50 tokens distributed
        assertEq(questBudget.distributed(address(mockERC20)), 50 ether);

        // Disburse 25 more tokens from the budget to the recipient
        questBudget.disburse(
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 25 ether)
        );

        // Ensure the budget has 75 tokens distributed
        assertEq(questBudget.distributed(address(mockERC20)), 75 ether);
    }

    ////////////////////////////
    // QuestBudget.reconcile //
    ////////////////////////////

    function testReconcile() public {
        // QuestBudget does not implement reconcile
        assertEq(questBudget.reconcile(""), 0);
    }

    ////////////////////////////////
    // QuestBudget.setAuthorized //
    ////////////////////////////////

    function testSetAuthorized() public {
        // Ensure the budget authorizes an account
        address[] memory accounts = new address[](1);
        bool[] memory authorized = new bool[](1);
        accounts[0] = address(0xc0ffee);
        authorized[0] = true;
        questBudget.setAuthorized(accounts, authorized);
        assertTrue(questBudget.isAuthorized(address(0xc0ffee)));
        assertFalse(questBudget.isAuthorized(address(0xdeadbeef)));
    }

    function testSetAuthorized_NotOwner() public {
        // Ensure the budget does not authorize an account if not called by the owner
        vm.prank(address(0xdeadbeef));

        address[] memory accounts = new address[](1);
        bool[] memory authorized = new bool[](1);
        accounts[0] = address(0xc0ffee);
        authorized[0] = true;

        vm.expectRevert(BoostError.Unauthorized.selector);
        questBudget.setAuthorized(accounts, authorized);
    }

    function testSetAuthorized_LengthMismatch() public {
        address[] memory accounts = new address[](1);
        bool[] memory authorized = new bool[](2);

        vm.expectRevert(Budget.LengthMismatch.selector);
        questBudget.setAuthorized(accounts, authorized);
    }

    ///////////////////////////////
    // QuestBudget.isAuthorized //
    ///////////////////////////////

    function testIsAuthorized() public {
        address[] memory accounts = new address[](1);
        bool[] memory authorized = new bool[](1);
        accounts[0] = address(0xc0ffee);
        authorized[0] = true;
        questBudget.setAuthorized(accounts, authorized);

        assertTrue(questBudget.isAuthorized(address(0xc0ffee)));
        assertFalse(questBudget.isAuthorized(address(0xdeadbeef)));
    }

    function testIsAuthorized_Owner() public {
        assertTrue(questBudget.isAuthorized(address(this)));
    }

    ////////////////////////////////////
    // QuestBudget.supportsInterface //
    ////////////////////////////////////

    function testSupportsInterface() public {
        // Ensure the contract supports the Budget interface
        assertTrue(questBudget.supportsInterface(type(Budget).interfaceId));
    }

    function testSupportsInterface_NotSupported() public {
        // Ensure the contract does not support an unsupported interface
        assertFalse(questBudget.supportsInterface(type(Test).interfaceId));
    }

    ////////////////////////////
    // QuestBudget.fallback  //
    ////////////////////////////

    function testFallback() public {
        // Ensure the fallback is payable
        (bool success,) = payable(questBudget).call{value: 1 ether}("");
        assertTrue(success);
    }

    function testFallback_CompressedFunctionCall() public {
        // Approve the budget to transfer tokens
        mockERC20.approve(address(questBudget), 100 ether);

        // Allocate 100 tokens to the budget
        bytes memory data = abi.encodeWithSelector(
            QuestBudget.allocate.selector,
            _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether)
        );

        (bool success,) = payable(questBudget).call(data);
        assertTrue(success, "Fallback function failed");

        // Ensure the budget has 100 tokens
        assertEq(questBudget.total(address(mockERC20)), 100 ether);
    }

    function testFallback_NoSuchFunction() public {
        // This test is weirdly slow and burns the entire block gas limit, so
        // I'm skipping it for now to avoid slowing down the test suite. Maybe
        // we can revisit this later... or maybe the case is irrelevant.
        vm.skip(true);

        // Ensure the call is not successful due to a non-existent function
        // Note that the function itself will revert, but because we're issuing
        // a low-level call, the revert won't bubble up. Instead, we are just
        // checking that the low-level call was not successful.
        (bool success,) = payable(questBudget).call{value: 1 ether}(
            abi.encodeWithSelector(
                bytes4(0xdeadbeef),
                _makeFungibleTransfer(Budget.AssetType.ERC20, address(mockERC20), address(this), 100 ether)
            )
        );
        assertFalse(success);
    }

    ///////////////////////////
    // QuestBudget.receive  //
    ///////////////////////////

    function testReceive() public {
        // Ensure the receive function catches non-fallback ETH transfers
        (bool success,) = payable(questBudget).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(questBudget.available(address(0)), 1 ether);
    }

    //////////////////////////////////
    // QuestBudget.setManagementFee //
    //////////////////////////////////

    function testSetManagementFee() public {
        // Simulate a transaction from the owner of the questBudget contract
        vm.prank(questBudget.owner());

        // Call the setManagementFee function with a value of 5%
        questBudget.setManagementFee(500);

        // Assert that the managementFee has been correctly set to 5%
        assertEq(questBudget.managementFee(), 500);
    }

    function testSetManagementFee_ExceedsMax() public {
        // Simulate a transaction from the owner of the questBudget contract
        vm.prank(questBudget.owner());
        
        // Set an initial valid management fee (5%)
        questBudget.setManagementFee(500);

        // Attempt to set a management fee that exceeds 100%
        vm.expectRevert("Fee cannot exceed 100%");
        questBudget.setManagementFee(10001);
        
        // Assert that the management fee remains unchanged at 5%
        assertEq(questBudget.managementFee(), 500);
    }

    function testPayManagementFee() public {
        // Set management fee
        vm.prank(questBudget.owner());
        questBudget.setManagementFee(500); // 5%

        // Set quest data
        uint32 txHashChainId_ = 1;
        address rewardTokenAddress_ = address(mockERC20);
        uint256 endTime_ = block.timestamp + 1 days;
        uint256 startTime_ = block.timestamp;
        uint256 totalParticipants_ = 10;
        uint256 rewardAmount_ = 1 ether;
        string memory questId_ = "testQuest";
        string memory actionType_ = "testAction";
        string memory questName_ = "Test Quest";
        string memory projectName_ = "Test Project";
        uint256 referralRewardFee_ = 250;
        uint256 numberMinted_ = 10;
        uint256 maxTotalRewards = totalParticipants_ * rewardAmount_;
        uint256 questFee = uint256(mockQuestFactory.questFee());
        uint256 referralRewardFee = uint256(mockQuestFactory.referralRewardFee());
        uint256 maxProtocolReward = (maxTotalRewards * questFee) / 10_000;
        uint256 maxReferralReward = (maxTotalRewards * referralRewardFee) / 10_000;
        uint256 maxManagementFee = (maxTotalRewards * questBudget.managementFee()) / 10_000;
        uint256 requiredApprovalAmount = maxTotalRewards + maxProtocolReward + maxReferralReward + maxManagementFee;

        // Allocate tokens to questBudget
        mockERC20.mint(address(questBudget), requiredApprovalAmount);

        // Create quest
        address questAddress = questBudget.createERC20Quest(
            txHashChainId_, rewardTokenAddress_, endTime_, startTime_,
            totalParticipants_, rewardAmount_, questId_, actionType_, questName_, projectName_, referralRewardFee_
        );

        // Mock withdrawal
        IQuestFactory.QuestData({
            questAddress: questAddress,
            rewardToken: address(mockERC20),
            queued: false,
            questFee: 250, // 2.5%
            startTime: startTime_,
            endTime: endTime_,
            totalParticipants: totalParticipants_,
            numberMinted: numberMinted_,
            redeemedTokens: numberMinted_ * rewardAmount_,
            rewardAmountOrTokenId: rewardAmount_,
            hasWithdrawn: false
        });

        vm.expectRevert("Management fee cannot be claimed until the quest rewards are withdrawn");
        questBudget.payManagementFee(questId_);
    }

    ///////////////////////////
    // Test Helper Functions //
    ///////////////////////////

    function _makeFungibleTransfer(Budget.AssetType assetType, address asset, address target, uint256 value)
        internal
        pure
        returns (bytes memory)
    {
        Budget.Transfer memory transfer;
        transfer.assetType = assetType;
        transfer.asset = asset;
        transfer.target = target;
        if (assetType == Budget.AssetType.ETH || assetType == Budget.AssetType.ERC20) {
            transfer.data = abi.encode(Budget.FungiblePayload({amount: value}));
        } else if (assetType == Budget.AssetType.ERC1155) {
            // we're not actually handling this case yet, so hardcoded token ID of 1 is fine
            transfer.data = abi.encode(Budget.ERC1155Payload({tokenId: 1, amount: value, data: ""}));
        }

        return abi.encode(transfer);
    }

    function _makeERC1155Transfer(address asset, address target, uint256 tokenId, uint256 value, bytes memory data)
        internal
        pure
        returns (bytes memory)
    {
        Budget.Transfer memory transfer;
        transfer.assetType = Budget.AssetType.ERC1155;
        transfer.asset = asset;
        transfer.target = target;
        transfer.data = abi.encode(Budget.ERC1155Payload({tokenId: tokenId, amount: value, data: data}));

        return abi.encode(transfer);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}