// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Inherits
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {LegacyStorage} from "./libraries/LegacyStorage.sol";
import {OwnableRoles} from "solady/src/auth/OwnableRoles.sol";
// Implements
import {IQuestFactory} from "./interfaces/IQuestFactory.sol";
// Leverages
import {ECDSA} from "solady/src/utils/ECDSA.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
// References
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IQuestOwnable} from "./interfaces/IQuestOwnable.sol";
import {IQuest1155Ownable} from "./interfaces/IQuest1155Ownable.sol";

/// @title QuestFactory
/// @author RabbitHole.gg
/// @dev This contract is used to create quests and handle claims
// solhint-disable-next-line max-states-count
/// @custom:oz-upgrades-from QuestFactoryV0
contract QuestFactory is Initializable, LegacyStorage, OwnableRoles, IQuestFactory {
    /*//////////////////////////////////////////////////////////////
                                 USING
    //////////////////////////////////////////////////////////////*/
    using SafeTransferLib for address;
    using LibClone for address;
    using LibString for string;
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public claimSignerAddress;
    address public protocolFeeRecipient;
    address public erc20QuestAddress;
    address public erc1155QuestAddress;
    mapping(string => Quest) public quests;
    address public rabbitHoleReceiptContract;
    address public rabbitHoleTicketsContract;
    mapping(address => bool) public rewardAllowlist;
    uint16 public questFee;
    uint256 public mintFee;
    /// @custom:oz-renamed-from mintFeeRecipient
    address public defaultMintFeeRecipient;
    uint256 private locked;
    /// @custom:oz-renamed-from questTerminalKeyContract
    address public defaultReferralFeeRecipient;
    uint256 public nftQuestFee;
    address public questNFTAddress;
    mapping(address => address[]) public ownerCollections;
    mapping(address => NftQuestFees) public nftQuestFeeList;
    uint16 public referralFee;
    address public sablierV2LockupLinearAddress;
    mapping(address => address) public mintFeeRecipientList;
    // insert new vars here at the end to keep the storage layout the same

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() initializer {}

    function initialize(
        address claimSignerAddress_,
        address protocolFeeRecipient_,
        address erc20QuestAddress_,
        address payable erc1155QuestAddress_,
        address ownerAddress_,
        address defaultReferralFeeRecipientAddress_,
        address sablierV2LockupLinearAddress_,
        uint256 nftQuestFee_,
        uint16 referralFee_,
        uint256 mintFee_
    ) external initializer {
        _initializeOwner(ownerAddress_);
        questFee = 2000; // in BIPS
        locked = 1;
        claimSignerAddress = claimSignerAddress_;
        protocolFeeRecipient = protocolFeeRecipient_;
        erc20QuestAddress = erc20QuestAddress_;
        erc1155QuestAddress = erc1155QuestAddress_;
        defaultReferralFeeRecipient = defaultReferralFeeRecipientAddress_;
        sablierV2LockupLinearAddress = sablierV2LockupLinearAddress_;
        nftQuestFee = nftQuestFee_;
        referralFee = referralFee_;
        mintFee = mintFee_;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier checkQuest(string memory questId_, address rewardTokenAddress_) {
        Quest storage currentQuest = quests[questId_];
        if (currentQuest.questAddress != address(0)) revert QuestIdUsed();
        if (!rewardAllowlist[rewardTokenAddress_]) revert RewardNotAllowed();
        if (erc20QuestAddress == address(0)) revert Erc20QuestAddressNotSet();
        _;
    }

    modifier claimChecks(ClaimData memory claimData_) {
        Quest storage currentQuest = quests[claimData_.questId];
        bytes memory hashc = abi.encodePacked(msg.sender, claimData_.questId);

        if (claimData_.ref != address(0)) {
            hashc = abi.encodePacked(hashc, claimData_.ref);
        }

        bytes32 encodedHash = keccak256(hashc);

        if (currentQuest.numberMinted + 1 > currentQuest.totalParticipants) revert OverMaxAllowedToMint();
        if (currentQuest.addressMinted[msg.sender]) revert AddressAlreadyMinted();
        if (encodedHash != claimData_.hashBytes) revert InvalidHash();
        if (recoverSigner(claimData_.hashBytes, claimData_.signature) != claimSignerAddress) revert AddressNotSigned();
        _;
    }

    /// @dev ReentrancyGuard modifier from solmate, copied here because it was added after storage layout was finalized on first deploy
    /// @dev from https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol
    modifier nonReentrant() virtual {
        if (locked != 1) revert Reentrancy();
        locked = 2;
        _;
        locked = 1;
    }

    modifier nonZeroAddress(address address_) {
        if (address_ == address(0)) revert ZeroAddressNotAllowed();
        _;
    }

    modifier sufficientMintFee() {
        if (msg.value < mintFee) revert InvalidMintFee();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL UPDATE
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                 CREATE
    //////////////////////////////////////////////////////////////*/

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

        address payable newQuest =
            payable(erc1155QuestAddress.cloneDeterministic(keccak256(abi.encodePacked(msg.sender, questId_))));
        currentQuest.questAddress = address(newQuest);
        currentQuest.totalParticipants = totalParticipants_;
        currentQuest.questAddress.safeTransferETH(msg.value);
        currentQuest.questType = "erc1155";
        currentQuest.questCreator = msg.sender;
        IQuest1155Ownable questContract = IQuest1155Ownable(newQuest);

        questContract.initialize(
            rewardTokenAddress_,
            endTime_,
            startTime_,
            totalParticipants_,
            tokenId_,
            getNftQuestFee(msg.sender),
            protocolFeeRecipient
        );

        IERC1155(rewardTokenAddress_).safeTransferFrom(msg.sender, newQuest, tokenId_, totalParticipants_, "0x00");
        questContract.queue();
        questContract.transferOwnership(msg.sender);

        if (bytes(actionSpec_).length > 0) {
            emit QuestCreatedWithAction(
                msg.sender,
                address(newQuest),
                questId_,
                "erc1155",
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
                "erc1155",
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                tokenId_
                );
        }

        return newQuest;
    }

    /// @dev Create a sablier stream reward quest and start it at the same time.
    /// @notice The function will transfer the reward amount to the quest contract
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param rewardAmount_ The reward amount for an erc20 quest
    /// @param questId_ The id of the quest
    /// @param actionSpec_ The JSON action spec for the quest
    /// @param durationTotal_ The duration of the sablier stream
    /// @return address the quest contract address
    function createERC20StreamQuest(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        string memory actionSpec_,
        uint40 durationTotal_
    ) external checkQuest(questId_, rewardTokenAddress_) returns (address) {
        address newQuest = createERC20QuestInternal(
            ERC20QuestData(
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                rewardAmount_,
                questId_,
                actionSpec_,
                durationTotal_,
                "erc20Stream"
            )
        );
        transferTokensAndOwnership(newQuest, rewardTokenAddress_);
        return newQuest;
    }

    // Note: Should probably be called `createQuest()`
    /// @dev Create an erc20 quest and start it at the same time. The function will transfer the reward amount to the quest contract
    /// @param rewardTokenAddress_ The contract address of the reward token
    /// @param endTime_ The end time of the quest
    /// @param startTime_ The start time of the quest
    /// @param totalParticipants_ The total amount of participants (accounts) the quest will have
    /// @param rewardAmount_ The reward amount for an erc20 quest
    /// @param questId_ The id of the quest
    /// @param actionSpec_ The JSON action spec for the quest
    /// @return address the quest contract address
    function createQuestAndQueue(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmount_,
        string memory questId_,
        string memory actionSpec_,
        uint256
    ) external checkQuest(questId_, rewardTokenAddress_) returns (address) {
        address newQuest = createERC20QuestInternal(
            ERC20QuestData(
                rewardTokenAddress_,
                endTime_,
                startTime_,
                totalParticipants_,
                rewardAmount_,
                questId_,
                actionSpec_,
                0,
                "erc20"
            )
        );
        transferTokensAndOwnership(newQuest, rewardTokenAddress_);
        return newQuest;
    }

    /*//////////////////////////////////////////////////////////////
                                 CLAIM
    //////////////////////////////////////////////////////////////*/


    /// @dev universal claim function for all quest types
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    /// @param ref_ The referral address
    function claim(string memory questId_, bytes32 hash_, bytes memory signature_, address ref_) external payable {
        if (quests[questId_].questType.eq("erc1155")) {
            claim1155RewardsRef(ClaimData(questId_, hash_, signature_, ref_, 0));
        } else { // erc20, erc20Stream
            claimRewardsRef(ClaimData(questId_, hash_, signature_, ref_, 0));
        }
    }

    /// @dev claim rewards for a quest
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function claim1155Rewards(string memory questId_, bytes32 hash_, bytes memory signature_) external payable {
        claim1155RewardsRef(ClaimData(questId_, hash_, signature_, address(0), 0));
    }

    /// @dev claim rewards for a quest
    /// @param questId_ The id of the quest
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function claimRewards(string memory questId_, bytes32 hash_, bytes memory signature_) external payable {
        claimRewardsRef(ClaimData(questId_, hash_, signature_, address(0), 0));
    }

    /*//////////////////////////////////////////////////////////////
                                  SET
    //////////////////////////////////////////////////////////////*/

    /// @dev temporary function to set owner for solady ownable
    function setOwnerOnce() external {
        _initializeOwner(0x017F8Ad14A2E745ea0F756Bd57CD4852400be78c);
    }

    /// @dev set the claim signer address
    /// @param claimSignerAddress_ The address of the claim signer
    function setClaimSignerAddress(address claimSignerAddress_) external onlyOwner {
        claimSignerAddress = claimSignerAddress_;
    }

    /// @dev set erc1155QuestAddress
    /// @param erc1155QuestAddress_ The address of the erc1155 quest
    function setErc1155QuestAddress(address erc1155QuestAddress_) external onlyOwner {
        erc1155QuestAddress = erc1155QuestAddress_;
    }

    /// @dev set erc20QuestAddress
    /// @param erc20QuestAddress_ The address of the erc20 quest
    function setErc20QuestAddress(address erc20QuestAddress_) external onlyOwner {
        erc20QuestAddress = erc20QuestAddress_;
    }

    /// @dev set the mint fee
    /// @notice the mint fee in ether
    /// @param mintFee_ The mint fee value
    function setMintFee(uint256 mintFee_) external onlyOwner {
        mintFee = mintFee_;
        emit MintFeeSet(mintFee_);
    }

    /// @dev set the nftQuestFee
    /// @param nftQuestFee_ The value of the nftQuestFee
    function setNftQuestFee(uint256 nftQuestFee_) external onlyOwner {
        nftQuestFee = nftQuestFee_;
        emit NftQuestFeeSet(nftQuestFee_);
    }

    /// @dev set the protocol fee recipient
    /// @param protocolFeeRecipient_ The address of the protocol fee recipient
    function setProtocolFeeRecipient(address protocolFeeRecipient_) external onlyOwner {
        if (protocolFeeRecipient_ == address(0)) revert AddressZeroNotAllowed();
        protocolFeeRecipient = protocolFeeRecipient_;
    }

    /// @dev set the quest fee
    /// @notice the quest fee should be in Basis Point units
    /// @param questFee_ The quest fee value
    function setQuestFee(uint16 questFee_) external onlyOwner {
        if (questFee_ > 10_000) revert QuestFeeTooHigh();
        questFee = questFee_;
    }

    /// @dev set the referral fee
    /// @param referralFee_ The value of the referralFee
    function setReferralFee(uint16 referralFee_) external onlyOwner {
        if (referralFee_ > 10_000) revert ReferralFeeTooHigh();
        referralFee = referralFee_;
        emit ReferralFeeSet(referralFee_);
    }

    /// @dev set sablierV2LockupLinearAddress
    /// @param sablierV2LockupLinearAddress_ The address of the sablierV2LockupLinear contract
    function setSablierV2LockupLinearAddress(address sablierV2LockupLinearAddress_) external onlyOwner {
        sablierV2LockupLinearAddress = sablierV2LockupLinearAddress_;
        emit SablierV2LockupLinearAddressSet(sablierV2LockupLinearAddress_);
    }

    /// @dev set or remave a contract address to be used as a reward
    /// @param rewardAddress_ The contract address to set
    /// @param allowed_ Whether the contract address is allowed or not
    function setRewardAllowlistAddress(address rewardAddress_, bool allowed_) external onlyOwner {
        rewardAllowlist[rewardAddress_] = allowed_;
    }

    /// @dev set the mintFeeRecipient
    /// @param mintFeeRecipient_ The address of the mint fee recipient
    function setDefaultMintFeeRecipient(address mintFeeRecipient_) external onlyOwner {
        if (mintFeeRecipient_ == address(0)) revert AddressZeroNotAllowed();
        defaultMintFeeRecipient = mintFeeRecipient_;
    }

    /// @dev set a mintFeeRecipient for a specific address
    /// @param address_ The address of the account
    /// @param mintFeeRecipient_ The address of the mint fee recipient
    function setMintFeeRecipientForAddress(address address_, address mintFeeRecipient_) external onlyOwner {
        mintFeeRecipientList[address_] = mintFeeRecipient_;
    }

    /// @dev set the nft quest fee for a list of addresses
    /// @param toAddAddresses_ The list of addresses to set the nft quest fee for
    /// @param fees_ The list of fees to set
    function setNftQuestFeeList(address[] calldata toAddAddresses_, uint256[] calldata fees_) external onlyOwner {
        for (uint256 i = 0; i < toAddAddresses_.length; i++) {
            nftQuestFeeList[toAddAddresses_[i]] = NftQuestFees(fees_[i], true);
        }
        emit NftQuestFeeListSet(toAddAddresses_, fees_);
    }

    /// @dev set the default referral fee recipient
    /// @param defaultReferralFeeRecipient_ The address of the default referral fee recipient
    function setDefaultReferralFeeRecipient(address defaultReferralFeeRecipient_) external onlyOwner {
        defaultReferralFeeRecipient = defaultReferralFeeRecipient_;
    }

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice This function name is a bit of a misnomer - gets whether an address has claimed a quest yet.
    /// @dev return status of whether an address has claimed a quest
    /// @param questId_ The id of the quest
    /// @param address_ The address to check
    /// @return claimed status
    function getAddressMinted(string memory questId_, address address_) external view returns (bool) {
        return quests[questId_].addressMinted[address_];
    }

    /// @dev get the mintFeeRecipient return the protocol fee recipient if the mint fee recipient is not set
    /// @param questCreatorAddress_ The address of the quest creator, to get the mintFee
    /// @return address the mint fee recipient
    function getMintFeeRecipient(address questCreatorAddress_) public view returns (address) {
        address _mintFeeRecipient = mintFeeRecipientList[questCreatorAddress_];
        return _mintFeeRecipient == address(0) ? defaultMintFeeRecipient : _mintFeeRecipient;
    }

    function getNftQuestFee(address address_) public view returns (uint256) {
        return nftQuestFeeList[address_].exists ? nftQuestFeeList[address_].fee : nftQuestFee;
    }

    /// @notice Right now this is a misnomer - it tracks total claims vs receipts minted
    /// @dev return the number of quest claims submitted
    /// @param questId_ The id of the quest
    /// @return uint Total quests claimed
    function getNumberMinted(string memory questId_) external view returns (uint256) {
        return quests[questId_].numberMinted;
    }

    /// @dev return extended quest data for a questId
    /// @param questId_ The id of the quest
    function questData(string memory questId_) external view returns (QuestData memory) {
        Quest storage thisQuest = quests[questId_];
        IQuestOwnable questContract = IQuestOwnable(thisQuest.questAddress);
        uint256 rewardAmountOrTokenId;
        uint16 erc20QuestFee;

        if (thisQuest.questType.eq("erc1155")) {
            rewardAmountOrTokenId = IQuest1155Ownable(thisQuest.questAddress).tokenId();
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
    function questInfo(string memory questId_) external view returns (address, uint256, uint256) {
        Quest storage currentQuest = quests[questId_];
        return (currentQuest.questAddress, currentQuest.totalParticipants, currentQuest.numberMinted);
    }

    /// @dev recover the signer from a hash and signature
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function recoverSigner(bytes32 hash_, bytes memory signature_) public view returns (address) {
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(hash_), signature_);
    }

    function totalQuestNFTFee(uint256 totalParticipants_) public view returns (uint256) {
        return totalParticipants_ * getNftQuestFee(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL UPDATE
    //////////////////////////////////////////////////////////////*/

    /// @dev claim rewards for a quest with a referral address
    /// @param claimData_ The claim data struct
    function claim1155RewardsRef(ClaimData memory claimData_) private
        nonReentrant
        sufficientMintFee
        claimChecks(claimData_)
    {
        Quest storage currentQuest = quests[claimData_.questId];
        IQuest1155Ownable questContract_ = IQuest1155Ownable(currentQuest.questAddress);
        if (!questContract_.queued()) revert QuestNotQueued();
        if (block.timestamp < questContract_.startTime()) revert QuestNotStarted();
        if (block.timestamp > questContract_.endTime()) revert QuestEnded();

        currentQuest.addressMinted[msg.sender] = true;
        ++currentQuest.numberMinted;
        questContract_.singleClaim(msg.sender);

        if (mintFee > 0) processMintFee(claimData_.ref, currentQuest.questCreator, claimData_.questId);

        emit Quest1155Claimed(
            msg.sender, currentQuest.questAddress, claimData_.questId, questContract_.rewardToken(), questContract_.tokenId()
        );

        if (claimData_.ref != address(0)) {
            emit QuestClaimedReferred(
                msg.sender,
                currentQuest.questAddress,
                claimData_.questId,
                questContract_.rewardToken(),
                questContract_.tokenId(),
                claimData_.ref,
                3333, //referralFee,
                mintFee
                );
        }
    }

    /// @dev claim rewards with a referral address
    /// @param claimData_ The claim data struct
    function claimRewardsRef(ClaimData memory claimData_) private
        nonReentrant
        sufficientMintFee
        claimChecks(claimData_)
    {
        Quest storage currentQuest = quests[claimData_.questId];
        IQuestOwnable questContract_ = IQuestOwnable(currentQuest.questAddress);
        if (!questContract_.queued()) revert QuestNotQueued();
        if (block.timestamp < questContract_.startTime()) revert QuestNotStarted();
        if (block.timestamp > questContract_.endTime()) revert QuestEnded();

        currentQuest.addressMinted[msg.sender] = true;
        ++currentQuest.numberMinted;
        questContract_.singleClaim(msg.sender);

        if (mintFee > 0) processMintFee(claimData_.ref, currentQuest.questCreator, claimData_.questId);

        emit QuestClaimed(
            msg.sender,
            currentQuest.questAddress,
            claimData_.questId,
            questContract_.rewardToken(),
            questContract_.rewardAmountInWei()
        );

        if (claimData_.ref != address(0)) {
            emit QuestClaimedReferred(
                msg.sender,
                currentQuest.questAddress,
                claimData_.questId,
                questContract_.rewardToken(),
                questContract_.rewardAmountInWei(),
                claimData_.ref,
                3333, //referralFee,
                mintFee
            );
        }
    }

    /// @dev Internal function to create an erc20 quest
    /// @param data_ The erc20 quest data struct
    function createERC20QuestInternal(ERC20QuestData memory data_) internal returns (address) {
        Quest storage currentQuest = quests[data_.questId];
        address newQuest = erc20QuestAddress.cloneDeterministic(keccak256(abi.encodePacked(msg.sender, data_.questId)));

        currentQuest.questAddress = address(newQuest);
        currentQuest.totalParticipants = data_.totalParticipants;
        currentQuest.questCreator = msg.sender;
        currentQuest.durationTotal = data_.durationTotal;
        currentQuest.questType = data_.questType;

        if (bytes(data_.actionSpec).length > 0) {
            emit QuestCreatedWithAction(
                msg.sender,
                address(newQuest),
                data_.questId,
                currentQuest.questType,
                data_.rewardTokenAddress,
                data_.endTime,
                data_.startTime,
                data_.totalParticipants,
                data_.rewardAmount,
                data_.actionSpec
            );
        } else {
            emit QuestCreated(
                msg.sender,
                address(newQuest),
                data_.questId,
                currentQuest.questType,
                data_.rewardTokenAddress,
                data_.endTime,
                data_.startTime,
                data_.totalParticipants,
                data_.rewardAmount
            );
        }

        IQuestOwnable(newQuest).initialize(
            data_.rewardTokenAddress,
            data_.endTime,
            data_.startTime,
            data_.totalParticipants,
            data_.rewardAmount,
            data_.questId,
            questFee,
            protocolFeeRecipient,
            data_.durationTotal,
            sablierV2LockupLinearAddress
        );

        return newQuest;
    }

    function processMintFee(address ref_, address mintFeeRecipient_, string memory questId_) private {
        returnChange();
        uint256 oneThirdMintfee = mintFee / 3;

        if(ref_ == address(0)){
            protocolFeeRecipient.safeTransferETH(oneThirdMintfee * 2);
            mintFeeRecipient_.safeTransferETH(oneThirdMintfee);

            emit MintFeePaid(questId_, protocolFeeRecipient, oneThirdMintfee * 2, mintFeeRecipient_, oneThirdMintfee, ref_, 0);
        } else {
            protocolFeeRecipient.safeTransferETH(oneThirdMintfee);
            mintFeeRecipient_.safeTransferETH(oneThirdMintfee);
            ref_.safeTransferETH(oneThirdMintfee);

            emit MintFeePaid(questId_, protocolFeeRecipient, oneThirdMintfee, mintFeeRecipient_, oneThirdMintfee, ref_, oneThirdMintfee);
        }
    }

    function returnChange() private {
        uint256 change = msg.value - mintFee;
        if (change > 0) {
            // Refund any excess payment
            msg.sender.safeTransferETH(change);
            emit ExtraMintFeeReturned(msg.sender, change);
        }
    }

    /// @dev Transfer the total transfer amount to the quest contract
    /// @dev Contract must be approved to transfer first
    /// @param newQuest_ The address of the new quest
    /// @param rewardTokenAddress_ The contract address of the reward token
    function transferTokensAndOwnership(address newQuest_, address rewardTokenAddress_) internal {
        address sender = msg.sender;
        IQuestOwnable questContract = IQuestOwnable(newQuest_);
        rewardTokenAddress_.safeTransferFrom(sender, newQuest_, questContract.totalTransferAmount());
        questContract.transferOwnership(sender);
    }

    /*//////////////////////////////////////////////////////////////
                                DEFAULTS
    //////////////////////////////////////////////////////////////*/
    // Receive function to receive ETH
    receive() external payable {}

    // Fallback function to receive ETH when other functions are not available
    fallback() external payable {}
}