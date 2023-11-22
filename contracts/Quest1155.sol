// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC1155} from "openzeppelin-contracts/token/ERC1155/IERC1155.sol";
import {IQuest1155} from "./interfaces/IQuest1155.sol";
import {ERC1155Holder} from "openzeppelin-contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {QuestFactory} from "./QuestFactory.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

/// @title Quest
/// @author RabbitHole.gg
/// @notice This contract is the Erc1155Quest contract. It is a quest that is redeemable for ERC1155 tokens.
/// @dev This contract will not work with RabbitHoleReceipt
contract Quest1155 is ERC1155Holder, ReentrancyGuardUpgradeable, PausableUpgradeable, Ownable, IQuest1155 {
    /*//////////////////////////////////////////////////////////////
                                 USING
    //////////////////////////////////////////////////////////////*/
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    QuestFactory public questFactoryContract;
    bool public queued;
    bool public hasWithdrawn;
    address public protocolFeeRecipient;
    address public rewardToken;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public totalParticipants;
    uint256 public tokenId;
    uint256 public questFee;
    string public questId;
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
        uint256 tokenId_,
        address protocolFeeRecipient_,
        string calldata questId_
    ) external initializer {
        if (endTime_ <= block.timestamp) revert EndTimeInPast();
        if (endTime_ <= startTime_) revert EndTimeLessThanOrEqualToStartTime();
        endTime = endTime_;
        startTime = startTime_;
        rewardToken = rewardTokenAddress_;
        totalParticipants = totalParticipants_;
        tokenId = tokenId_;
        questFactoryContract = QuestFactory(payable(msg.sender));
        questId = questId_;
        protocolFeeRecipient = protocolFeeRecipient_;
        _initializeOwner(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Checks if the quest end time is passed
    modifier onlyEnded() {
        if (block.timestamp < endTime) revert NotEnded();
        _;
    }

    modifier onlyQuestFactory() {
        if (msg.sender != address(questFactoryContract)) revert NotQuestFactory();
        _;
    }

    /// @notice Checks if the quest has been queued
    modifier onlyQueued() {
        if (!queued) revert NotQueued();
        _;
    }

    /// @notice Checks if the quest start time is passed
    modifier onlyStarted() {
        if (block.timestamp < startTime) revert NotStarted();
        _;
    }

    /// @notice Checks if the quest end time has not passed
    modifier whenNotEnded() {
        if (block.timestamp > endTime) revert QuestEnded();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL UPDATE
    //////////////////////////////////////////////////////////////*/
    /// @notice Pauses the Quest
    /// @dev Only the owner of the Quest can call this function. Also requires that the Quest has started (not by date, but by calling the start function)
    function pause() external onlyOwner onlyStarted {
        _pause();
    }

    /// @notice Queues the quest by marking it ready to start at the contract level. Marking a quest as queued does not mean that it is live. It also requires that the start time has passed
    /// @dev Requires that the balance of the rewards in the contract is greater than or equal to the maximum amount of rewards that can be claimed by all users and the protocol
    function queue() external virtual onlyOwner {
        if (IERC1155(rewardToken).balanceOf(address(this), tokenId) < totalParticipants) {
            revert InsufficientTokenBalance();
        }
        if (address(this).balance < this.maxProtocolReward()) revert InsufficientETHBalance();
        queued = true;
        emit Queued(block.timestamp);
    }

    function claimFromFactory(address claimer_, address ref_) external payable whenNotEnded onlyQuestFactory {
        _transferRewards(claimer_, 1);
        if (ref_ != address(0)) ref_.safeTransferETH(_claimFee() / 3);
    }

    /// @dev transfers rewards to the account, can only be called once per account per quest and only by the quest factory
    /// @param account_ The account to transfer rewards to
    function singleClaim(address account_)
        external
        virtual
        nonReentrant
        whenNotPaused
        whenNotEnded
        onlyStarted
        onlyQueued
        onlyQuestFactory
    {
        _transferRewards(account_, 1);
        if (questFee > 0) protocolFeeRecipient.safeTransferETH(questFee);
    }

    /// @notice Unpauses the Quest
    /// @dev Only the owner of the Quest can call this function. Also requires that the Quest has started (not by date, but by calling the start function)
    function unPause() external onlyOwner onlyStarted {
        _unpause();
    }

    /// @dev Function that transfers all 1155 tokens in the contract to the owner (creator), and eth to the protocol fee recipient and the owner
    /// @notice This function can only be called after the quest end time.
    function withdrawRemainingTokens() external onlyEnded {
        if (hasWithdrawn) revert AlreadyWithdrawn();
        hasWithdrawn = true;

        uint ownerPayout = (_claimFee() * _redeemedTokens()) / 3;
        uint protocolPayout = address(this).balance - ownerPayout;

        owner().safeTransferETH(ownerPayout);
        protocolFeeRecipient.safeTransferETH(protocolPayout);
        _transferRewards(owner(), IERC1155(rewardToken).balanceOf(address(this), tokenId));

        questFactoryContract.withdrawCallback(questId, protocolFeeRecipient, protocolPayout, address(owner()), ownerPayout);
    }

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/
    /// @notice Function that gets the maximum amount of rewards that can be claimed by the protocol or the quest deployer
    /// @return The maximum amount of rewards that can be claimed by the protocol or the quest deployer
    function maxProtocolReward() external view returns (uint256) {
        return (totalParticipants);
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
                            INTERNAL UPDATE
    //////////////////////////////////////////////////////////////*/
    /// @notice Internal function that transfers rewards from this contract
    /// @param to_ The address to send the rewards to
    /// @param amount_ The amount of rewards to transfer
    function _transferRewards(address to_, uint256 amount_) internal {
        IERC1155(rewardToken).safeTransferFrom(address(this), to_, tokenId, amount_, "0x00");
    }

    /*//////////////////////////////////////////////////////////////
                                DEFAULTS
    //////////////////////////////////////////////////////////////*/
    receive() external payable {}
    fallback() external payable {}
}
