// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "./helpers/TestUtils.sol";

contract TestQuest is Test, TestUtils {
    address rewardTokenAddress;
    uint256 END_TIME = 1_000_000_000;
    uint256 START_TIME = 1_000_000;
    uint256 TOTAL_PARTICIPANTS = 300;
    uint256 TOTAL_REWARDS_IN_WEI = 1000;
    string QUEST_ID = "QUEST_ID";
    uint16 QUEST_FEE = 2000; // 20%
    address protocolFeeRecipient = makeAddr("protocolFeeRecipient");
    uint40 DURATION_TOTAL = 1_000_000;
    address sablierMock;
    address questFactoryMock;

    function setup() public {}

    /*//////////////////////////////////////////////////////////////
                              INITIALIZE
    //////////////////////////////////////////////////////////////*/
    function test_initialize() public {}

    function test_RevertIf_initialize_EndTimeInPast() public {}

    function test_RevertIf_initialize_EndTimeLessThanOrEqualToStartTime() public {}

    /*//////////////////////////////////////////////////////////////
                                PAUSE
    //////////////////////////////////////////////////////////////*/
    function test_pause() public {}

    function test_RevertIf_pause_Unauthorized() public {}

    /*//////////////////////////////////////////////////////////////
                              UNPAUSE
    //////////////////////////////////////////////////////////////*/
    function test_unpause() public {}

    function test_RevertIf_unpause_Unauthorized() public {}

    /*//////////////////////////////////////////////////////////////
                            SINGLECLAIM
    //////////////////////////////////////////////////////////////*/
    function test_singleClaim() public {}

    function test_fuzz_singleClaim() public {}

    function test_RevertIf_singleClaim_NotQuestFactory() public {}

    function test_RevertIf_singleClaim_ClaimWindowNotStarted() public {}

    function test_RevertIf_singleClaim_whenNotPaused() public {}

    /*//////////////////////////////////////////////////////////////
                      WITHDRAWREMAININGTOKENS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawRemainingTokens() public {}

    function test_fuzz_withdrawRemainingTokens() public {}

    function test_RevertIf_withdrawRemainingToken_NoWithdrawDuringClaim() public {}

    function test_RevertIf_withdrawRemainingToken_AuthOwnerRecipient() public {}

    function test_RevertIf_withdrawRemainingToken_AlreadyWithdrawn() public {}

    /*//////////////////////////////////////////////////////////////
                                REFUND
    //////////////////////////////////////////////////////////////*/

    function test_refund() public {}

    function test_fuzz_refund() public {}

    function test_RevertIf_refund_Unauthorized() public {}

    function test_RevertIf_refund_InvalidRefundToken() public {}

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    function test_totalTransferAmount() public {}

    function test_maxTotalRewards() public {}

    function test_maxProtocolReward() public {}

    function test_protocolFee() public {}

    function test_receiptRedeemers() public {}

    function test_getRewardAmount() public {}

    function test_getRewardToken() public {}
}
