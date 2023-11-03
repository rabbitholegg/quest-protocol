// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Inherits
import {Ownable} from "solady/auth/Ownable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// Implements
import {IQuest} from "./interfaces/IQuest.sol";
// Leverages
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {LockupLinear} from "sablier/types/DataTypes.sol";
// References
import {IQuestFactory} from "./interfaces/IQuestFactory.sol";
import {ISablierV2LockupLinear} from "sablier/interfaces/ISablierV2LockupLinear.sol";
import {IERC20} from "sablier/types/Tokens.sol";

/// @title Quest
/// @author RabbitHole.gg
/// @notice This contract is the Erc20Quest contract. It is a quest that is redeemable for ERC20 tokens
// solhint-disable-next-line max-states-count
contract Quest is ReentrancyGuardUpgradeable, PausableUpgradeable, Ownable, IQuest {
    /*//////////////////////////////////////////////////////////////
                                 USING
    //////////////////////////////////////////////////////////////*/
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public rabbitHoleReceiptContract; // Deprecated - do not use
    IQuestFactory public questFactoryContract;
    address public rewardToken;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public totalParticipants;
    uint256 public rewardAmountInWei;
    bool public queued;
    string public questId;
    uint256 public redeemedTokens;
    uint16 public questFee;
    bool public hasWithdrawn;
    address public protocolFeeRecipient;
    mapping(uint256 => bool) private claimedList;
    string public jsonSpecCID;
    uint40 public durationTotal;
    mapping(address => uint256) public streamIdForAddress;
    ISablierV2LockupLinear public sablierV2LockupLinearContract;
    // insert new vars here at the end to keep the storage layout the same

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
        address protocolFeeRecipient_,
        uint40 durationTotal_,
        address sablierV2LockupLinearAddress_
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
        durationTotal = durationTotal_;
        sablierV2LockupLinearContract = ISablierV2LockupLinear(sablierV2LockupLinearAddress_);

        // Setup default state
        questFactoryContract = IQuestFactory(payable(msg.sender));
        // Note: this is redundant
        hasWithdrawn = false;
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

    modifier onlyProtocolFeeRecipientOrOwner() {
        if (msg.sender != protocolFeeRecipient && msg.sender != owner()) revert AuthOwnerRecipient();
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
        redeemedTokens = redeemedTokens + 1;
    }

    /// @notice Function to withdraw the remaining tokens in the contract, distributes the protocol fee and returns remaining tokens to owner
    /// @dev Can only be called after the quest has ended
    function withdrawRemainingTokens() external onlyWithdrawAfterEnd {
        if (hasWithdrawn) revert AlreadyWithdrawn();
        hasWithdrawn = true;

        uint256 protocolFeeForRecipient = this.protocolFee() / 2;
        rewardToken.safeTransfer(protocolFeeRecipient, protocolFeeForRecipient);

        uint256 remainingBalanceForOwner = rewardToken.balanceOf(address(this));
        rewardToken.safeTransfer(owner(), remainingBalanceForOwner);

        emit ProtocolFeeDistributed(questId, rewardToken, protocolFeeRecipient, protocolFeeForRecipient, owner(), remainingBalanceForOwner);
    }

    /// @dev transfer all coins and tokens that is not the rewardToken to the contract owner.
    /// @param erc20Address_ The address of the ERC20 token to refund
    function refund(address erc20Address_) external onlyOwner {
        if (erc20Address_ == rewardToken) revert InvalidRefundToken();

        uint256 balance = address(this).balance;
        if (balance > 0) payable(msg.sender).transfer(balance);

        uint256 erc20Balance = erc20Address_.balanceOf(address(this));
        if (erc20Balance > 0) erc20Address_.safeTransfer(msg.sender, erc20Balance);
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
        return (_receiptRedeemers() * rewardAmountInWei * questFee) / 10_000;
    }

    /// @notice This no longer indicates a number of receipts minted but gives an accurate count of total claims
    /// @return total number of claims submitted
    function receiptRedeemers() external view returns (uint256) {
        return _receiptRedeemers();
    }

    /// @dev Returns the reward amount
    function getRewardAmount() external view returns (uint256) {
        return rewardAmountInWei;
    }

    /// @dev Returns the reward token address
    function getRewardToken() external view returns (address) {
        return rewardToken;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL UPDATE
    //////////////////////////////////////////////////////////////*/
    function _createLockupLinearStream(address recepient_, uint256 totalAmount_) internal {
        // Approve the Sablier contract to spend reward tokens
        rewardToken.safeApprove(address(sablierV2LockupLinearContract), totalAmount_);

        LockupLinear.CreateWithDurations memory params;

        params.sender = msg.sender; // The sender will be able to cancel the stream, this is the QuestFactory contract
        params.recipient = recepient_; // The recipient of the streamed assets
        params.totalAmount = uint128(totalAmount_); // Total amount is the amount inclusive of all fees
        params.asset = IERC20(rewardToken); // The streaming asset
        params.durations = LockupLinear.Durations({cliff: 0, total: durationTotal});

        // Create the Sablier stream using a function that sets the start time to `block.timestamp`
        uint256 streamId = sablierV2LockupLinearContract.createWithDurations(params);

        streamIdForAddress[recepient_] = streamId;
    }

    /// @notice Internal function that transfers the rewards to the msg.sender
    /// @param sender_ The address to send the rewards to
    /// @param amount_ The amount of rewards to transfer
    function _transferRewards(address sender_, uint256 amount_) internal {
        if (durationTotal > 0) {
            _createLockupLinearStream(sender_, amount_);
        } else {
            rewardToken.safeTransfer(sender_, amount_);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL VIEW
    //////////////////////////////////////////////////////////////*/
    function _receiptRedeemers() internal view returns (uint256) {
        return questFactoryContract.getNumberMinted(questId);
    }
}
