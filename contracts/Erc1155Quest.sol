// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IQuest} from "./interfaces/IQuest.sol";
import {RabbitHoleReceipt} from "./RabbitHoleReceipt.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Erc1155Quest is Initializable, OwnableUpgradeable, IQuest {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    RabbitHoleReceipt public rabbitholeReceiptContract;

    address public rewardToken;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public totalAmount;
    uint256 public rewardTokenId;
    bool public hasStarted;
    bool public isPaused;
    string public allowList;
    string public questId;

    mapping(uint256 => bool) private claimedList;

    function initialize(
        address erc20TokenAddress_, uint256 endTime_,
        uint256 startTime_, uint256 totalAmount_, string memory allowList_,
        uint256 rewardTokenId_, string memory questId_, address receiptContractAddress_) public initializer {
        __Ownable_init();
        if (endTime_ <= block.timestamp) revert EndTimeInPast();
        if (startTime_ <= block.timestamp) revert StartTimeInPast();
        endTime = endTime_;
        startTime = startTime_;
        rewardToken = erc20TokenAddress_;
        totalAmount = totalAmount_;
        rewardTokenId = rewardTokenId_;
        allowList = allowList_;
        questId = questId_;
        rabbitholeReceiptContract = RabbitHoleReceipt(receiptContractAddress_);
    }

    function start() public onlyOwner {
        if (IERC1155(rewardToken).balanceOf(address(this), rewardTokenId) < totalAmount) revert TotalAmountExceedsBalance();
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

    function _setClaimed(uint256[] memory tokenIds_) private {
        for (uint i = 0; i < tokenIds_.length; i++) {
            claimedList[tokenIds_[i]] = true;
        }
    }

    function claim() public virtual {
        if (hasStarted == false) revert NotStarted();
        if (isPaused == true) revert QuestPaused();
        if (block.timestamp < startTime) revert ClaimWindowNotStarted();
        if (IERC1155(rewardToken).balanceOf(address(this), rewardTokenId) < totalAmount) revert AmountExceedsBalance();

        uint[] memory tokens = rabbitholeReceiptContract.getOwnedTokenIdsOfQuest(questId, msg.sender);

        if (tokens.length == 0) revert NoTokensToClaim();

        uint256 redeemableTokenCount = 0;

        for (uint i = 0; i < tokens.length; i++) {
            if (!isClaimed(tokens[i])) {
                redeemableTokenCount++;
            }
        }

        if (redeemableTokenCount == 0) revert AlreadyClaimed();

        uint256 totalReedemableTokens = redeemableTokenCount;

        IERC1155(rewardToken).safeTransferFrom(address(this), msg.sender, rewardTokenId, totalReedemableTokens, "0x0");
        _setClaimed(tokens);

        emit Claimed(msg.sender, redeemableTokenCount);
    }

    function isClaimed(uint256 tokenId_) public view returns (bool) {
        return claimedList[tokenId_] && claimedList[tokenId_] == true;
    }

    function withdraw() public onlyOwner {
        if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
        IERC1155(rewardToken).safeTransferFrom(address(this), msg.sender, rewardTokenId, IERC1155(rewardToken).balanceOf(address(this), rewardTokenId), "0x0");
    }
}
