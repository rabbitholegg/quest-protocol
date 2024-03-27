// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

contract Errors {
    error AlreadyClaimed();
    error AlreadyWithdrawn();
    error AmountExceedsBalance();
    error ClaimWindowNotStarted();
    error EndTimeInPast();
    error EndTimeLessThanOrEqualToStartTime();
    error InvalidRefundToken();
    error MustImplementInChild();
    error NotQuestFactory();
    error NoWithdrawDuringClaim();
    error NotStarted();
    error TotalAmountExceedsBalance();
    error AuthOwnerRecipient();
    error Unauthorized();
    error EnforcedPause();
    error txOriginMismatch();

    // Quest1155
    error InsufficientTokenBalance();
    error InsufficientETHBalance();
    error NotEnded();
    error NotQueued();

    // RabbitHoleTickets
    error OnlyMinter();

    // QuestFactory
    error QuestIdUsed();
    error Erc20QuestAddressNotSet();
    error QuestNotStarted();
    error InvalidHash();
    error AddressAlreadyMinted();
    error QuestEnded();
    error InvalidMintFee();
    error MsgValueLessThanQuestNFTFee();
}
