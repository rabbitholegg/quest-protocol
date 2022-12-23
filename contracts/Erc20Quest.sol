// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20Upgradeable, SafeERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import {MerkleProofUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IQuest} from './interfaces/IQuest.sol';
import {RabbitHoleReceipt} from './RabbitHoleReceipt.sol';
import '@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol';

contract Erc20Quest is Initializable, OwnableUpgradeable, IQuest {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    RabbitHoleReceipt public rabbitholeReceiptContract;

    address public rewardToken;
    address public claimSignerAddress;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public totalAmount;
    uint256 public rewardAmountInWei;
    bool public hasStarted;
    bool public isPaused;
    string public allowList;
    string public questId;

    mapping(uint256 => bool) private claimedList;

    function initialize(
        address erc20TokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalAmount_,
        string memory allowList_,
        uint256 rewardAmountInWei_,
        string memory questId_,
        address receiptContractAddress_,
        address claimSignerAddress_
    ) public initializer {
        __Ownable_init();
        if (endTime_ <= block.timestamp) revert EndTimeInPast();
        if (startTime_ <= block.timestamp) revert StartTimeInPast();
        endTime = endTime_;
        startTime = startTime_;
        rewardToken = erc20TokenAddress_;
        totalAmount = totalAmount_;
        rewardAmountInWei = rewardAmountInWei_;
        allowList = allowList_;
        questId = questId_;
        rabbitholeReceiptContract = RabbitHoleReceipt(receiptContractAddress_);
        claimSignerAddress = claimSignerAddress_;
    }

    function start() public onlyOwner {
        if (IERC20Upgradeable(rewardToken).balanceOf(address(this)) < totalAmount) revert TotalAmountExceedsBalance();
        isPaused = false;
        hasStarted = true;
    }

    function pause() public onlyOwner {
        if (hasStarted == false) revert NotStarted();
        isPaused = true;
    }

    function unPause() public onlyOwner {
        if (hasStarted == false) revert NotStarted();
        isPaused = false;
    }

    function setAllowList(string memory allowList_) public onlyOwner {
        allowList = allowList_;
    }

    function setClaimSignerAddress(address claimSignerAddress_) public onlyOwner {
        claimSignerAddress = claimSignerAddress_;
    }

    function _setClaimed(uint256[] memory tokenIds_) private {
        for (uint i = 0; i < tokenIds_.length; i++) {
            claimedList[tokenIds_[i]] = true;
        }
    }

    function recoverSigner(bytes32 hash_, bytes memory signature_) public pure returns (address) {
        bytes32 messageDigest = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', hash_));
        return ECDSAUpgradeable.recover(messageDigest, signature_);
    }

    function claim(uint timestamp_, bytes32 hash_, bytes memory signature_) public virtual {
        if (hasStarted == false) revert NotStarted();
        if (isPaused == true) revert QuestPaused();
        if (block.timestamp < startTime) revert ClaimWindowNotStarted();
        if (IERC20Upgradeable(rewardToken).balanceOf(address(this)) < rewardAmountInWei) revert AmountExceedsBalance();
        if (keccak256(abi.encodePacked(msg.sender, questId, timestamp_)) != hash_) revert InvalidHash();
        if (recoverSigner(hash_, signature_) != claimSignerAddress) revert AddressNotSigned();

        uint[] memory tokens = rabbitholeReceiptContract.getOwnedTokenIdsOfQuest(questId, msg.sender);

        if (tokens.length == 0) revert NoTokensToClaim();

        uint256 redeemableTokenCount = 0;

        for (uint i = 0; i < tokens.length; i++) {
            if (!isClaimed(tokens[i])) {
                redeemableTokenCount++;
            }
        }

        if (redeemableTokenCount == 0) revert AlreadyClaimed();

        uint256 totalReedemableRewards = redeemableTokenCount * rewardAmountInWei;

        IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, totalReedemableRewards);
        _setClaimed(tokens);

        emit Claimed(msg.sender, totalReedemableRewards);
    }

    function isClaimed(uint256 tokenId_) public view returns (bool) {
        return claimedList[tokenId_] && claimedList[tokenId_] == true;
    }

    function withdraw() public onlyOwner {
        if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
        IERC20Upgradeable(rewardToken).safeTransfer(
            msg.sender,
            IERC20Upgradeable(rewardToken).balanceOf(address(this))
        );
    }
}
