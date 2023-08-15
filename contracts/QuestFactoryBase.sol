// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import {ECDSA} from 'solady/src/utils/ECDSA.sol';
import {LibClone} from 'solady/src/utils/LibClone.sol';
import {LibString} from 'solady/src/utils/LibString.sol';
import {SafeTransferLib} from 'solady/src/utils/SafeTransferLib.sol';
import {IQuestFactory} from './interfaces/IQuestFactory.sol';
import {IQuest} from './interfaces/IQuest.sol';
import {IQuest1155} from './interfaces/IQuest1155.sol';
import {OwnableUpgradeable} from './OwnableUpgradeable.sol';
import {IQuestTerminalKey} from './interfaces/IQuestTerminalKey.sol';

/// @title QuestFactory
/// @author RabbitHole.gg
/// @dev This contract is used to create quests and mint receipts
contract QuestFactoryBase is Initializable, OwnableUpgradeable, AccessControlUpgradeable, IQuestFactory {
    using SafeTransferLib for address;
    using LibClone for address;
    using LibString for string;
    using LibString for uint256;

    // storage vars. Insert new vars at the end to keep the storage layout the same.
    struct Quest {
        mapping(address => bool) addressMinted;
        address questAddress;
        uint totalParticipants;
        uint numberMinted;
        string questType;
    }
    address public claimSignerAddress;
    address public protocolFeeRecipient;
    address public erc20QuestAddress;
    address public erc1155QuestAddress;
    mapping(string => Quest) public quests;
    address public rabbitHoleReceiptContract;
    address public rabbitHoleTicketsContract;
    mapping(address => bool) public rewardAllowlist;
    uint16 public questFee;
    uint public mintFee;
    address public mintFeeRecipient;
    uint256 private locked;
    address private questTerminalKeyContract;
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
        uint rewardAmountOrTokenId;
        bool hasWithdrawn;
    }
    mapping(address => address[]) public ownerCollections;
    mapping(address => NftQuestFees) public nftQuestFeeList;
    struct NftQuestFees {
        uint256 fee;
        bool exists;
    }
    uint16 public referralFee;

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
        uint nftQuestFee_,
        uint16 referralFee_
    ) external initializer {
        __Ownable_init(ownerAddress_);
        __AccessControl_init();
        questFee = 2_000; // in BIPS
        locked = 1;
        claimSignerAddress = claimSignerAddress_;
        rabbitHoleReceiptContract = rabbitHoleReceiptContract_;
        protocolFeeRecipient = protocolFeeRecipient_;
        erc20QuestAddress = erc20QuestAddress_;
        erc1155QuestAddress = erc1155QuestAddress_;
        questTerminalKeyContract = questTerminalKeyAddress_;
        nftQuestFee = nftQuestFee_;
        referralFee = referralFee_;
    }

    /// @dev ReentrancyGuard modifier from solmate, copied here because it was added after storage layout was finalized on first deploy
    /// @dev from https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol
    modifier nonReentrant() virtual {
        if (locked == 0) locked = 1;
        require(locked == 1, 'REENTRANCY');
        locked = 2;
        _;
        locked = 1;
    }

    modifier claimChecks(
        string memory questId_,
        bytes32 hash_,
        bytes memory signature_,
        address ref_
    ) {
        Quest storage currentQuest = quests[questId_];
        bytes32 encodedHash;
        if (ref_ == address(0)) {
            encodedHash = keccak256(abi.encodePacked(msg.sender, questId_));
        } else {
            encodedHash = keccak256(abi.encodePacked(msg.sender, questId_, ref_));
        }

        if (currentQuest.numberMinted + 1 > currentQuest.totalParticipants) revert OverMaxAllowedToMint();
        if (currentQuest.addressMinted[msg.sender]) revert AddressAlreadyMinted();
        if (encodedHash != hash_) revert InvalidHash();
        if (recoverSigner(hash_, signature_) != claimSignerAddress) revert AddressNotSigned();
        _;
    }

    modifier sufficientMintFee() {
        require(msg.value >= mintFee, 'Insufficient mint fee');
        _;
    }

    modifier checkQuest(string memory questId_, address rewardTokenAddress_) {
        Quest storage currentQuest = quests[questId_];
        if (currentQuest.questAddress != address(0)) revert QuestIdUsed();
        if (!rewardAllowlist[rewardTokenAddress_]) revert RewardNotAllowed();
        if (erc20QuestAddress == address(0)) revert Erc20QuestAddressNotSet();
        _;
    }

    modifier nonZeroAddress(address address_) {
        if (address_ == address(0)) revert ZeroAddressNotAllowed();
        _;
    }

    function mintReceipt(string memory, bytes32, bytes memory) external pure {
        revert Deprecated();
    }

    function createERC20QuestInternal(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        uint256 discountTokenId_,
        string memory actionSpec_
    ) internal returns (address) {
        Quest storage currentQuest = quests[questId_];
        address newQuest = erc20QuestAddress.cloneDeterministic(keccak256(abi.encodePacked(msg.sender, questId_)));

        if (bytes(actionSpec_).length > 0) {
            emit QuestCreatedWithAction(
                msg.sender,
                address(newQuest),
                questId_,
                'erc20',
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                rewardAmount_,
                actionSpec_
            );
        } else {
            emit QuestCreated(
                msg.sender,
                address(newQuest),
                questId_,
                'erc20',
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                rewardAmount_
            );
        }
        uint16 protocolFee;
        currentQuest.questAddress = address(newQuest);
        currentQuest.totalParticipants = totalParticipants_;
        currentQuest.questType = 'erc20';

        if (discountTokenId_ == 0) {
            protocolFee = questFee;
        } else {
            protocolFee = doDiscountedFee(discountTokenId_);
        }

        IQuest(newQuest).initialize(
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
        require(
            IQuestTerminalKey(questTerminalKeyContract).ownerOf(tokenId_) == msg.sender,
            'QuestFactory: caller is not owner of discount token'
        );

        (uint16 discountPercentage, ) = IQuestTerminalKey(questTerminalKeyContract).discounts(tokenId_);

        IQuestTerminalKey(questTerminalKeyContract).incrementUsedCount(tokenId_);
        return uint16((uint(questFee) * (10000 - uint(discountPercentage))) / 10000);
    }

    /// @dev Transfer the total transfer amount to the quest contract
    /// @dev Contract must be approved to transfer first
    /// @param newQuest_ The address of the new quest
    /// @param rewardTokenAddress_ The contract address of the reward token
    function transferTokensAndQueueQuest(address newQuest_, address rewardTokenAddress_) internal {
        rewardTokenAddress_.safeTransferFrom(msg.sender, newQuest_, IQuest(newQuest_).totalTransferAmount());
        IQuest(newQuest_).queue();
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
        address newQuest = createERC20QuestInternal(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmount_,
            questId_,
            0,
            ''
        );

        OwnableUpgradeable(newQuest).transferOwnership(msg.sender);

        return newQuest;
    }

    /// @dev Create an erc20 quest and start it at the same time. The function will transfer the reward amount to the quest contract
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param rewardAmount_ The reward amount for an erc20 quest
    /// @param questId_ The id of the quest
    /// @param actionSpec_ The JSON action spec for the quest
    /// @param discountTokenId_ The id of the discount token
    /// @return address the quest contract address
    function createQuestAndQueue(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        string memory actionSpec_,
        uint256 discountTokenId_
    ) external checkQuest(questId_, rewardTokenAddress_) returns (address) {
        address newQuest = createERC20QuestInternal(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            rewardAmount_,
            questId_,
            discountTokenId_,
            actionSpec_
        );

        transferTokensAndQueueQuest(newQuest, rewardTokenAddress_);
        OwnableUpgradeable(newQuest).transferOwnership(msg.sender);

        return newQuest;
    }

    /// @dev this function must be implemented in child contracts
    function deploy1155Quest(address, string memory) internal virtual returns (address) {
        // revert NotImplemented();
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
        string memory questId_,
        string memory actionSpec_
    ) external payable nonReentrant returns (address) {
        Quest storage currentQuest = quests[questId_];

        if (msg.value < totalQuestNFTFee(totalParticipants_)) revert MsgValueLessThanQuestNFTFee();
        if (currentQuest.questAddress != address(0)) revert QuestIdUsed();

        address payable newQuest = payable(deploy1155Quest(erc1155QuestAddress, questId_));

        currentQuest.questAddress = newQuest;
        currentQuest.totalParticipants = totalParticipants_;
        currentQuest.questAddress.safeTransferETH(msg.value);
        currentQuest.questType = 'erc1155';

        IQuest1155(newQuest).initialize(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            tokenId_,
            getNftQuestFee(msg.sender),
            protocolFeeRecipient
        );

        IERC1155(rewardTokenAddress_).safeTransferFrom(msg.sender, newQuest, tokenId_, totalParticipants_, '0x00');
        IQuest1155(newQuest).queue();
        IQuest1155(newQuest).transferOwnership(msg.sender);

        if (bytes(actionSpec_).length > 0) {
            emit QuestCreatedWithAction(
                msg.sender,
                address(newQuest),
                questId_,
                'erc1155',
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                tokenId_,
                actionSpec_
            );
        } else {
            emit QuestCreated(
                msg.sender,
                address(newQuest),
                questId_,
                'erc1155',
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                tokenId_
            );
        }

        return newQuest;
    }

    function totalQuestNFTFee(uint totalParticipants_) public view returns (uint256) {
        return totalParticipants_ * getNftQuestFee(msg.sender);
    }

    function getNftQuestFee(address address_) public view returns (uint256) {
        return nftQuestFeeList[address_].exists ? nftQuestFeeList[address_].fee : nftQuestFee;
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

    /// @dev set the nftQuestFee
    /// @param nftQuestFee_ The value of the nftQuestFee
    function setNftQuestFee(uint nftQuestFee_) external onlyOwner {
        nftQuestFee = nftQuestFee_;
        emit NftQuestFeeSet(nftQuestFee_);
    }

    /// @dev set the referral fee
    /// @param referralFee_ The value of the referralFee
    function setReferralFee(uint16 referralFee_) external onlyOwner {
        if (referralFee_ > 10_000) revert ReferralFeeTooHigh();
        referralFee = referralFee_;
        emit ReferralFeeSet(referralFee_);
    }

    /// @dev set questTerminalKeyContract address
    /// @param questTerminalKeyContract_ The address of the questTerminalKeyContract
    function setQuestTerminalKeyContract(address questTerminalKeyContract_) external onlyOwner {
        questTerminalKeyContract = questTerminalKeyContract_;
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
        IQuest questContract = IQuest(thisQuest.questAddress);
        uint rewardAmountOrTokenId;
        uint16 erc20QuestFee;

        if (thisQuest.questType.eq('erc1155')) {
            rewardAmountOrTokenId = IQuest1155(thisQuest.questAddress).tokenId();
        } else {
            rewardAmountOrTokenId = questContract.rewardAmountInWei();
            erc20QuestFee = questContract.questFee();
        }

        QuestData memory data = QuestData(
            thisQuest.questAddress,
            questContract.rewardToken(),
            questContract.queued(),
            erc20QuestFee,
            questContract.startTime(),
            questContract.endTime(),
            questContract.totalParticipants(),
            thisQuest.numberMinted,
            questContract.redeemedTokens(),
            rewardAmountOrTokenId,
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

    /// @dev universal claim function for all quest types
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    /// @param ref_ The referral address
    function claim(string memory questId_, bytes32 hash_, bytes memory signature_, address ref_) external payable {
        if (quests[questId_].questType.eq('erc20')) {
            claimRewardsRef(questId_, hash_, signature_, ref_);
        } else if (quests[questId_].questType.eq('erc1155')) {
            claim1155RewardsRef(questId_, hash_, signature_, ref_);
        } else {
            revert QuestTypeNotSupported();
        }
    }

    /// @dev claim rewards for a quest
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function claimRewards(string memory questId_, bytes32 hash_, bytes memory signature_) external payable {
        claimRewardsRef(questId_, hash_, signature_, address(0));
    }

    /// @dev claim rewards with a referral address
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    /// @param ref_ The referral address
    function claimRewardsRef(
        string memory questId_,
        bytes32 hash_,
        bytes memory signature_,
        address ref_
    ) private nonReentrant sufficientMintFee claimChecks(questId_, hash_, signature_, ref_) {
        Quest storage currentQuest = quests[questId_];
        IQuest questContract_ = IQuest(currentQuest.questAddress);
        if (!questContract_.queued()) revert QuestNotQueued();
        if (block.timestamp < questContract_.startTime()) revert QuestNotStarted();
        if (block.timestamp > questContract_.endTime()) revert QuestEnded();

        currentQuest.addressMinted[msg.sender] = true;
        ++currentQuest.numberMinted;
        questContract_.singleClaim(msg.sender);

        if (mintFee > 0) processMintFee(ref_);

        emit QuestClaimed(
            msg.sender,
            currentQuest.questAddress,
            questId_,
            questContract_.rewardToken(),
            questContract_.rewardAmountInWei()
        );

        if (ref_ != address(0)) {
            emit QuestClaimedReferred(
                msg.sender,
                currentQuest.questAddress,
                questId_,
                questContract_.rewardToken(),
                questContract_.rewardAmountInWei(),
                ref_,
                referralFee,
                mintFee
            );
        }
    }

    /// @dev claim rewards for a quest
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function claim1155Rewards(string memory questId_, bytes32 hash_, bytes memory signature_) external payable {
        claim1155RewardsRef(questId_, hash_, signature_, address(0));
    }

    /// @dev claim rewards for a quest with a referral address
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function claim1155RewardsRef(
        string memory questId_,
        bytes32 hash_,
        bytes memory signature_,
        address ref_
    ) private nonReentrant sufficientMintFee claimChecks(questId_, hash_, signature_, ref_) {
        Quest storage currentQuest = quests[questId_];
        IQuest1155 questContract_ = IQuest1155(currentQuest.questAddress);
        if (!questContract_.queued()) revert QuestNotQueued();
        if (block.timestamp < questContract_.startTime()) revert QuestNotStarted();
        if (block.timestamp > questContract_.endTime()) revert QuestEnded();

        currentQuest.addressMinted[msg.sender] = true;
        ++currentQuest.numberMinted;
        questContract_.singleClaim(msg.sender);

        if (mintFee > 0) processMintFee(ref_);

        emit Quest1155Claimed(
            msg.sender,
            currentQuest.questAddress,
            questId_,
            questContract_.rewardToken(),
            questContract_.tokenId()
        );

        if (ref_ != address(0)) {
            emit QuestClaimedReferred(
                msg.sender,
                currentQuest.questAddress,
                questId_,
                questContract_.rewardToken(),
                questContract_.tokenId(),
                ref_,
                referralFee,
                mintFee
            );
        }
    }

    function processMintFee(address ref_) private {
        returnChange();
        if (ref_ == address(0)) {
            getMintFeeRecipient().safeTransferETH(mintFee);
            return;
        }
        uint referralAmount = (mintFee * referralFee) / 10_000;
        ref_.safeTransferETH(referralAmount);
        getMintFeeRecipient().safeTransferETH(mintFee - referralAmount);
    }

    function returnChange() private {
        uint change = msg.value - mintFee;
        if (change > 0) {
            // Refund any excess payment
            msg.sender.safeTransferETH(change);
            emit ExtraMintFeeReturned(msg.sender, change);
        }
    }

    function setNftQuestFeeList(address[] calldata toAddAddresses_, uint[] calldata fees_) external onlyOwner {
        for (uint i = 0; i < toAddAddresses_.length; i++) {
            nftQuestFeeList[toAddAddresses_[i]] = NftQuestFees(fees_[i], true);
        }
        emit NftQuestFeeListSet(toAddAddresses_, fees_);
    }

    // Receive function to receive ETH
    receive() external payable {}

    // Fallback function to receive ETH when other functions are not available
    fallback() external payable {}
}
