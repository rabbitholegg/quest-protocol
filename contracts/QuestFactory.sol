// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;
pragma experimental ABIEncoderV2;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import {ECDSA} from 'solady/src/utils/ECDSA.sol';
import {LibClone} from 'solady/src/utils/LibClone.sol';
import {SafeTransferLib} from 'solady/src/utils/SafeTransferLib.sol';
import {IQuestFactory} from './interfaces/IQuestFactory.sol';
import {IQuestUniversal} from './interfaces/IQuestUniversal.sol';
import {Quest as QuestContract} from './Quest.sol';
import {Quest1155 as Quest1155Contract} from './Quest1155.sol';
import {RabbitHoleReceipt} from './RabbitHoleReceipt.sol';
import {OwnableUpgradeable} from './OwnableUpgradeable.sol';
import {QuestTerminalKey} from "./QuestTerminalKey.sol";

/// @title QuestFactory
/// @author RabbitHole.gg
/// @dev This contract is used to create quests and mint receipts
contract QuestFactory is Initializable, OwnableUpgradeable, AccessControlUpgradeable, IQuestFactory {
    using SafeTransferLib for address;
    using LibClone for address;

    // storage vars. Insert new vars at the end to keep the storage layout the same.
    struct Quest {
        mapping(address => bool) addressMinted;
        address questAddress;
        uint totalParticipants;
        uint numberMinted;
    }
    address public claimSignerAddress;
    address public protocolFeeRecipient;
    address public erc20QuestAddress;
    address public erc1155QuestAddress;
    mapping(string => Quest) public quests;
    RabbitHoleReceipt public rabbitHoleReceiptContract;
    address public rabbitHoleTicketsContract;
    mapping(address => bool) public rewardAllowlist;
    uint16 public questFee;
    uint public mintFee;
    address public mintFeeRecipient;
    uint256 private locked;
    QuestTerminalKey private questTerminalKeyContract;
    uint public nftQuestFee;
    address public questNFTAddress;
    struct QuestData {
        address questAddress;
        address rewardToken;
        bool queued;
        uint16 questFee;
        uint startTime;
        uint endTime;
        uint totalParticipants;
        uint numberMinted;
        uint redeemedTokens;
        uint rewardAmountInWei;
        bool hasWithdrawn;
    }
    mapping(address => address[]) public ownerCollections;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(
        address claimSignerAddress_,
        address rabbitHoleReceiptContract_,
        address protocolFeeRecipient_,
        address erc20QuestAddress_,
        address payable erc1155QuestAddress_,
        address ownerAddress_,
        address questTerminalKeyAddress_,
        uint nftQuestFee_
    ) external initializer {
        __Ownable_init(ownerAddress_);
        __AccessControl_init();
        questFee = 2_000; // in BIPS
        locked = 1;
        claimSignerAddress = claimSignerAddress_;
        rabbitHoleReceiptContract = RabbitHoleReceipt(rabbitHoleReceiptContract_);
        protocolFeeRecipient = protocolFeeRecipient_;
        erc20QuestAddress = erc20QuestAddress_;
        erc1155QuestAddress = erc1155QuestAddress_;
        questTerminalKeyContract = QuestTerminalKey(questTerminalKeyAddress_);
        nftQuestFee = nftQuestFee_;
    }

    /// @dev ReentrancyGuard modifier from solmate, copied here because it was added after storage layout was finalized on first deploy
    /// @dev from https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol
    modifier nonReentrant() virtual {
        if (locked == 0) locked = 1;
        require(locked == 1, "REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }

    modifier claimChecks(string memory questId_, bytes32 hash_, bytes memory signature_) {
        Quest storage currentQuest = quests[questId_];

        if (currentQuest.numberMinted + 1 > currentQuest.totalParticipants) revert OverMaxAllowedToMint();
        if (currentQuest.addressMinted[msg.sender]) revert AddressAlreadyMinted();
        if (keccak256(abi.encodePacked(msg.sender, questId_)) != hash_) revert InvalidHash();
        if (recoverSigner(hash_, signature_) != claimSignerAddress) revert AddressNotSigned();
        _;
    }

    modifier sufficientMintFee() {
        require(msg.value >= mintFee, "Insufficient mint fee");
        _;
    }

    modifier checkQuest(string memory questId_, address rewardTokenAddress_) {
        Quest storage currentQuest = quests[questId_];
        if (currentQuest.questAddress != address(0)) revert QuestIdUsed();
        if (!rewardAllowlist[rewardTokenAddress_]) revert RewardNotAllowed();
        if (erc20QuestAddress == address(0)) revert Erc20QuestAddressNotSet();
        _;
    }

    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert ZeroAddressNotAllowed();
        _;
    }

    function createQuestInternal(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        uint256 discountTokenId_
    ) internal returns (address) {
        Quest storage currentQuest = quests[questId_];
        address newQuest = erc20QuestAddress.cloneDeterministic(keccak256(abi.encodePacked(msg.sender, questId_)));
        emit QuestCreated(
            msg.sender,
            address(newQuest),
            questId_,
            "erc20",
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmount_
        );
        uint16 protocolFee;
        currentQuest.questAddress = address(newQuest);
        currentQuest.totalParticipants = totalParticipants_;

        if(discountTokenId_ == 0){
            protocolFee = questFee;
        }else{
            protocolFee = doDiscountedFee(discountTokenId_);
        }

        QuestContract(newQuest).initialize(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmount_,
            questId_,
            address(rabbitHoleReceiptContract),
            protocolFee,
            protocolFeeRecipient
        );

        return newQuest;
    }

    function doDiscountedFee(uint tokenId_) internal returns (uint16) {
        require(questTerminalKeyContract.ownerOf(tokenId_) == msg.sender, "QuestFactory: caller is not owner of discount token");

        (uint16 discountPercentage, ) = questTerminalKeyContract.discounts(tokenId_);

        questTerminalKeyContract.incrementUsedCount(tokenId_);
        return uint16((uint(questFee) * (10000 - uint(discountPercentage))) / 10000);
    }

    /// @dev Transfer the total transfer amount to the quest contract
    /// @dev Contract must be approved to transfer first
    /// @param newQuest_ The address of the new quest
    /// @param rewardTokenAddress_ The contract address of the reward token
    function transferTokensAndQueueQuest(address newQuest_, address rewardTokenAddress_) internal {
        rewardTokenAddress_.safeTransferFrom(msg.sender, newQuest_, QuestContract(newQuest_).totalTransferAmount());
        QuestContract(newQuest_).queue();
    }

    /// @dev Create an erc20 quest
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param rewardAmount_ The reward amount for an erc20 quest
    /// @param questId_ The id of the quest
    /// @return address the quest contract address
    function createQuest(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory, // was contractType_ , currently deprecated.
        string memory questId_
    ) external checkQuest(questId_, rewardTokenAddress_) returns (address) {
        address newQuest = createQuestInternal(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmount_,
            questId_,
            0
        );

        QuestContract(newQuest).transferOwnership(msg.sender);

        return newQuest;
    }

    /// @dev Create an erc20 quest and start it at the same time. The function will transfer the reward amount to the quest contract
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param rewardAmount_ The reward amount for an erc20 quest
    /// @param questId_ The id of the quest
    /// @param jsonSpecCID The CID of the JSON spec for the quest
    /// @param discountTokenId_ The id of the discount token
    /// @return address the quest contract address
    function createQuestAndQueue(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        string memory jsonSpecCID,
        uint256 discountTokenId_
    ) external checkQuest(questId_, rewardTokenAddress_) returns (address) {
        address newQuest = createQuestInternal(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmount_,
            questId_,
            discountTokenId_
        );

        transferTokensAndQueueQuest(newQuest, rewardTokenAddress_);
        if(bytes(jsonSpecCID).length > 0) QuestContract(newQuest).setJsonSpecCID(jsonSpecCID);
        QuestContract(newQuest).transferOwnership(msg.sender);

        return newQuest;
    }

    /// @dev Create an erc1155 quest and start it at the same time. The function will transfer the reward amount to the quest contract
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param tokenId_ The reward token id of the erc1155 at rewardTokenAddress_
    /// @param questId_ The id of the quest
    /// @return address the quest contract address
    function create1155QuestAndQueue(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 tokenId_,
        string memory questId_
    ) external payable nonReentrant returns (address) {
        Quest storage currentQuest = quests[questId_];

        if (msg.value < totalQuestNFTFee(totalParticipants_)) revert MsgValueLessThanQuestNFTFee();
        if (currentQuest.questAddress != address(0)) revert QuestIdUsed();

        address payable newQuest = payable(erc1155QuestAddress.cloneDeterministic(keccak256(abi.encodePacked(msg.sender, questId_))));
        currentQuest.questAddress = address(newQuest);
        currentQuest.totalParticipants = totalParticipants_;
        currentQuest.questAddress.safeTransferETH(msg.value);

        Quest1155Contract(newQuest).initialize(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            tokenId_,
            nftQuestFee,
            protocolFeeRecipient
        );

        IERC1155(rewardTokenAddress_).safeTransferFrom(msg.sender, newQuest, tokenId_, totalParticipants_, '0x00');
        Quest1155Contract(newQuest).queue();
        Quest1155Contract(newQuest).transferOwnership(msg.sender);

        emit QuestCreated(
            msg.sender,
            address(newQuest),
            questId_,
            "erc1155",
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            tokenId_
        );

        return newQuest;
    }

    function totalQuestNFTFee(uint totalParticipants_) public view returns (uint256) {
        return nftQuestFee * totalParticipants_;
    }

    /// @dev set erc20QuestAddress
    /// @param erc20QuestAddress_ The address of the erc20 quest
    function setErc20QuestAddress(address erc20QuestAddress_) public onlyOwner {
        erc20QuestAddress = erc20QuestAddress_;
    }

    /// @dev set erc1155QuestAddress
    /// @param erc1155QuestAddress_ The address of the erc1155 quest
    function setErc1155QuestAddress(address erc1155QuestAddress_) public onlyOwner {
        erc1155QuestAddress = erc1155QuestAddress_;
    }

    /// @dev set the claim signer address
    /// @param claimSignerAddress_ The address of the claim signer
    function setClaimSignerAddress(address claimSignerAddress_) public onlyOwner {
        claimSignerAddress = claimSignerAddress_;
    }

    /// @dev set the protocol fee recipient
    /// @param protocolFeeRecipient_ The address of the protocol fee recipient
    function setProtocolFeeRecipient(address protocolFeeRecipient_) public onlyOwner {
        if (protocolFeeRecipient_ == address(0)) revert AddressZeroNotAllowed();
        protocolFeeRecipient = protocolFeeRecipient_;
    }

    /// @dev set the mintFeeRecipient
    /// @param mintFeeRecipient_ The address of the mint fee recipient
    function setMintFeeRecipient(address mintFeeRecipient_) public onlyOwner {
        if (mintFeeRecipient_ == address(0)) revert AddressZeroNotAllowed();
        mintFeeRecipient = mintFeeRecipient_;
    }

    /// @dev get the mintFeeRecipient return the protocol fee recipient if the mint fee recipient is not set
    /// @return address the mint fee recipient
    function getMintFeeRecipient() public view returns (address) {
        if (mintFeeRecipient == address(0)) {
            return protocolFeeRecipient;
        }
        return mintFeeRecipient;
    }

    /// @dev set the rabbithole receipt contract
    /// @param rabbitholeReceiptContract_ The address of the rabbithole receipt contract
    function setRabbitHoleReceiptContract(address rabbitholeReceiptContract_) external onlyOwner {
        rabbitHoleReceiptContract = RabbitHoleReceipt(rabbitholeReceiptContract_);
    }

    /// @dev set the nftQuestFee
    /// @param nftQuestFee_ The value of the nftQuestFee
    function setNftQuestFee(uint nftQuestFee_) external onlyOwner {
        nftQuestFee = nftQuestFee_;
        emit NftQuestFeeSet(nftQuestFee_);
    }

    /// @dev set questTerminalKeyContract address
    /// @param questTerminalKeyContract_ The address of the questTerminalKeyContract
    function setQuestTerminalKeyContract(address questTerminalKeyContract_) external onlyOwner {
        questTerminalKeyContract = QuestTerminalKey(questTerminalKeyContract_);
    }

    /// @dev set or remave a contract address to be used as a reward
    /// @param rewardAddress_ The contract address to set
    /// @param allowed_ Whether the contract address is allowed or not
    function setRewardAllowlistAddress(address rewardAddress_, bool allowed_) public onlyOwner {
        rewardAllowlist[rewardAddress_] = allowed_;
    }

    /// @dev set the quest fee
    /// @notice the quest fee should be in Basis Point units
    /// @param questFee_ The quest fee value
    function setQuestFee(uint16 questFee_) public onlyOwner {
        if (questFee_ > 10_000) revert QuestFeeTooHigh();
        questFee = questFee_;
    }

    /// @dev set the mint fee
    /// @notice the mint fee in ether
    /// @param mintFee_ The mint fee value
    function setMintFee(uint mintFee_) public onlyOwner {
        mintFee = mintFee_;
        emit MintFeeSet(mintFee_);
    }

    /// @dev return the number of minted receipts for a quest
    /// @param questId_ The id of the quest
    function getNumberMinted(string memory questId_) external view returns (uint) {
        return quests[questId_].numberMinted;
    }

    /// @dev return extended quest data for a questId
    /// @param questId_ The id of the quest
    function questData(string memory questId_) external view returns (QuestData memory) {
        Quest storage thisQuest = quests[questId_];
        QuestContract questContract = QuestContract(thisQuest.questAddress);

        QuestData memory data = QuestData(
            thisQuest.questAddress,
            questContract.rewardToken(),
            questContract.queued(),
            questContract.questFee(),
            questContract.startTime(),
            questContract.endTime(),
            questContract.totalParticipants(),
            thisQuest.numberMinted,
            questContract.redeemedTokens(),
            questContract.rewardAmountInWei(),
            questContract.hasWithdrawn()
        );

        return data;
    }

    /// @dev return data in the quest struct for a questId
    /// @param questId_ The id of the quest
    function questInfo(string memory questId_) external view returns (address, uint, uint) {
        Quest storage currentQuest = quests[questId_];
        return (currentQuest.questAddress, currentQuest.totalParticipants, currentQuest.numberMinted);
    }

    /// @dev return status of whether an address has minted a receipt for a quest
    /// @param questId_ The id of the quest
    /// @param address_ The address to check
    /// @return Minted status
    function getAddressMinted(string memory questId_, address address_) external view returns (bool) {
        return quests[questId_].addressMinted[address_];
    }

    /// @dev recover the signer from a hash and signature
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function recoverSigner(bytes32 hash_, bytes memory signature_) public view returns (address) {
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(hash_), signature_);
    }

    /// @dev claim rewards for a quest
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function claimRewards(string memory questId_, bytes32 hash_, bytes memory signature_) external payable nonReentrant sufficientMintFee claimChecks(questId_, hash_, signature_) {
        Quest storage currentQuest = quests[questId_];
        IQuestUniversal questContract_ = IQuestUniversal(currentQuest.questAddress);
        if (!questContract_.queued()) revert QuestNotQueued();
        if (block.timestamp < questContract_.startTime()) revert QuestNotStarted();
        if (block.timestamp > questContract_.endTime()) revert QuestEnded();

        currentQuest.addressMinted[msg.sender] = true;
        ++currentQuest.numberMinted;
        questContract_.singleClaim(msg.sender);

        if(mintFee > 0) processMintFee();

        emit QuestClaimed(msg.sender, currentQuest.questAddress, questId_, questContract_.rewardToken(), questContract_.rewardAmountInWei());
    }

    /// @dev mint a RabbitHole Receipt. Note: this contract must be set as Minter on the receipt contract
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function mintReceipt(string memory questId_, bytes32 hash_, bytes memory signature_) external payable nonReentrant claimChecks(questId_, hash_, signature_) {
        Quest storage currentQuest = quests[questId_];
        if (!QuestContract(currentQuest.questAddress).queued()) revert QuestNotQueued();
        if (block.timestamp < QuestContract(currentQuest.questAddress).startTime()) revert QuestNotStarted();
        if (block.timestamp > QuestContract(currentQuest.questAddress).endTime()) revert QuestEnded();

        currentQuest.addressMinted[msg.sender] = true;
        ++currentQuest.numberMinted;
        rabbitHoleReceiptContract.mint(msg.sender, questId_);

        emit ReceiptMinted(msg.sender, quests[questId_].questAddress, rabbitHoleReceiptContract.getTokenId(), questId_);
    }

    function processMintFee() private {
        uint change = msg.value - mintFee;
        if (change > 0) {
            // Refund any excess payment
            msg.sender.safeTransferETH(change);
            emit ExtraMintFeeReturned(msg.sender, change);
        }
        // Send the mint fee to the mint fee recipient
        getMintFeeRecipient().safeTransferETH(mintFee);
    }

    // Receive function to receive ETH
    receive() external payable {}

    // Fallback function to receive ETH when other functions are not available
    fallback() external payable {}
}
