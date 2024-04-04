// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Inherits
import {Ownable} from "solady/auth/Ownable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {QuestClaimable} from "./libraries/QuestClaimable.sol";
// Implements
import {IQuest} from "./interfaces/IQuest.sol";
// Leverages
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
// References
import {IQuestFactory} from "./interfaces/IQuestFactory.sol";
import {IPoints} from "./interfaces/IPoints.sol";
/// @title Quest
/// @author RabbitHole.gg
/// @notice This contract is the Erc20Quest contract. It is a quest that is redeemable for ERC20 tokens
// solhint-disable-next-line max-states-count
contract Quest is ReentrancyGuardUpgradeable, PausableUpgradeable, Ownable, IQuest, QuestClaimable {


    /*//////////////////////////////////////////////////////////////
                                 USING
    //////////////////////////////////////////////////////////////*/
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    IQuestFactory public questFactoryContract;
    IPoints public pointsContract;
    address public rewardToken;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public totalParticipants;
    uint256 public rewardAmountInWei;
    bool public queued;
    string public questId;
    uint16 public questFee;
    bool public hasWithdrawn;
    address public protocolFeeRecipient;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmountInWei_,
        string memory questId_,
        uint16 questFee_,
        address protocolFeeRecipient_
    ) external initializer {
        // Validate inputs
        if (endTime_ <= block.timestamp) revert EndTimeInPast();
        if (endTime_ <= startTime_) revert EndTimeLessThanOrEqualToStartTime();
        
        // Process input parameters
        rewardToken = rewardTokenAddress_;
        endTime = endTime_;
        startTime = startTime_;
        totalParticipants = totalParticipants_;
        rewardAmountInWei = rewardAmountInWei_;
        questId = questId_;
        questFee = questFee_;
        protocolFeeRecipient = protocolFeeRecipient_;

        // Setup default state
        questFactoryContract = IQuestFactory(payable(msg.sender));
        pointsContract = IPoints(rewardTokenAddress_);
        queued = true;
        _initializeOwner(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Prevents reward withdrawal until the Quest has ended
    modifier onlyWithdrawAfterEnd() {
        if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
        _;
    }

    /// @notice Checks if quest has started both at the function level and at the start time
    modifier onlyQuestActive() {
        if (block.timestamp < startTime) revert ClaimWindowNotStarted();
        _;
    }

    /// @notice Checks if the quest end time has not passed
    modifier whenNotEnded() {
        if (block.timestamp > endTime) revert QuestEnded();
        _;
    }

    modifier onlyQuestFactory() {
        if (msg.sender != address(questFactoryContract)) revert NotQuestFactory();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL UPDATE
    //////////////////////////////////////////////////////////////*/
    /// @notice Pauses the Quest
    /// @dev Only the owner of the Quest can call this function. Also requires that the Quest has started (not by date, but by calling the start function)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the Quest
    /// @dev Only the owner of the Quest can call this function. Also requires that the Quest has started (not by date, but by calling the start function)
    function unPause() external onlyOwner {
        _unpause();
    }

    /// @dev transfers rewards to the account, can only be called once per account per quest and only by the quest factory
    /// @param account_ The account to transfer rewards to
    function singleClaim(address account_)
        external
        virtual
        nonReentrant
        onlyQuestActive
        whenNotPaused
        onlyQuestFactory
    {
        uint256 totalRedeemableRewards = rewardAmountInWei;
        _transferRewards(account_, totalRedeemableRewards);
    }

    function claimFromFactory(address claimer_, address ref_) external payable whenNotEnded onlyQuestFactory {
        _transferRewards(claimer_, rewardAmountInWei);
        if (ref_ != address(0)) ref_.safeTransferETH(_claimFee() / 3);
    }

    /// @notice Function that transfers all 1155 tokens in the contract to the owner (creator), and eth to the protocol fee recipient and the owner
    /// @dev Can only be called after the quest has ended
    function withdrawRemainingTokens() external onlyWithdrawAfterEnd {
        if (hasWithdrawn) revert AlreadyWithdrawn();
        hasWithdrawn = true;

        uint256 ownerPayout = (_claimFee() * _redeemedTokens()) / 3;
        uint256 protocolPayout = address(this).balance - ownerPayout;

        owner().safeTransferETH(ownerPayout);
        protocolFeeRecipient.safeTransferETH(protocolPayout);

        // transfer reward tokens
        uint256 protocolFeeForRecipient = this.protocolFee() / 2;
        pointsContract.issue(protocolFeeRecipient, protocolFeeForRecipient);

        uint256 remainingBalanceForOwner = rewardToken.balanceOf(address(this));
        pointsContract.issue(owner(), remainingBalanceForOwner);

        questFactoryContract.withdrawCallback(questId, protocolFeeRecipient, protocolPayout, address(owner()), ownerPayout);
    }

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/
    /// @dev The amount of tokens the quest needs to pay all redeemers plus the protocol fee
    function totalTransferAmount() external view returns (uint256) {
        return this.maxTotalRewards() + this.maxProtocolReward();
    }

    /// @dev Function that gets the maximum amount of rewards that can be claimed by all users. It does not include the protocol fee
    /// @return The maximum amount of rewards that can be claimed by all users
    function maxTotalRewards() external view returns (uint256) {
        return totalParticipants * rewardAmountInWei;
    }

    /// @notice Function that gets the maximum amount of rewards that can be claimed by the protocol or the quest deployer
    /// @dev The 10_000 comes from Basis Points: https://www.investopedia.com/terms/b/basispoint.asp
    /// @return The maximum amount of rewards that can be claimed by the protocol or the quest deployer
    function maxProtocolReward() external view returns (uint256) {
        return (this.maxTotalRewards() * questFee) / 10_000;
    }

    /// @notice Function that calculates the protocol fee
    function protocolFee() external view returns (uint256) {
        return (_redeemedTokens() * rewardAmountInWei * questFee) / 10_000;
    }

    /// @dev Returns the reward amount
    function getRewardAmount() external view returns (uint256) {
        return rewardAmountInWei;
    }

    /// @dev Returns the reward token address
    function getRewardToken() external view returns (address) {
        return rewardToken;
    }

    function getQuestFactoryContract() public view override returns (IQuestFactory){
        return questFactoryContract;
    }

    function getQuestId() public view override returns (string memory){
        return questId;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL UPDATE
    //////////////////////////////////////////////////////////////*/
    /// @notice Internal function that transfers the rewards to the msg.sender
    /// @param sender_ The address to send the rewards to
    /// @param amount_ The amount of rewards to transfer
    function _transferRewards(address sender_, uint256 amount_) internal {
        pointsContract.issue(sender_, amount_);
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL VIEW
    //////////////////////////////////////////////////////////////*/
    function _redeemedTokens() internal view returns (uint256) {
        return questFactoryContract.getNumberMinted(questId);
    }

    function _claimFee() internal view returns (uint256) {
        return questFactoryContract.mintFee();
    }

    /*//////////////////////////////////////////////////////////////
                                DEFAULTS
    //////////////////////////////////////////////////////////////*/
    receive() external payable {}
    fallback() external payable {}
}
