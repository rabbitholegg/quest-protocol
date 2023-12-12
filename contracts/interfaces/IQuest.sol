// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IQuest {
    event Queued(uint256 timestamp);
    event JsonSpecCIDSet(string cid);
    event ProtocolFeeDistributed(string questId, address rewardToken, address protocolOwner, uint256 feeAmountToProtocolOwner, address questOwner, uint256 feeAmountToQuestOwner);

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
    error AddressNotSigned();
    error InvalidClaimFee();
    error OverMaxAllowedToMint();
    error AddressAlreadyMinted();
    error QuestEnded();

    function initialize(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmountInWei_,
        string memory questId_,
        uint16 questFee_,
        address protocolFeeRecipient_,
        uint40 durationTotal_,
        address sablierV2LockupLinearAddress_
    ) external;
    function getRewardAmount() external view returns (uint256);
    function getRewardToken() external view returns (address);
    function queued() external view returns (bool);
    function startTime() external view returns (uint256);
    function endTime() external view returns (uint256);
    function singleClaim(address account) external;
    function rewardToken() external view returns (address);
    function rewardAmountInWei() external view returns (uint256);
    function totalTransferAmount() external view returns (uint256);
    function questFee() external view returns (uint16);
    function totalParticipants() external view returns (uint256);
    function hasWithdrawn() external view returns (bool);
    function questId() external view returns (string memory);
}
