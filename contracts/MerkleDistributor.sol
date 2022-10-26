// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IMerkleDistributor} from "./interfaces/IMerkleDistributor.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

error AlreadyClaimed();
error InvalidProof();

contract MerkleDistributor is IMerkleDistributor, Ownable, Initializable {
    using SafeERC20 for IERC20;

    address public immutable override token;
    bytes32 public override merkleRoot;

    // This is a packed array of booleans.
    mapping(address => bool) private claimedList;

    constructor(address token_) public {
      token = token_;
    }

    function setMerkleRoot(bytes32 merkleRoot_) public onlyOwner {
      merkleRoot = merkleRoot_;
    }

    function isClaimed(address account) public view override returns (bool) {
      return claimedList[account] && claimedList[account] == true;
    }

    function _setClaimed(address account) private {
      claimedList[account] = true;
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) public virtual override {
      if (isClaimed(account)) revert AlreadyClaimed();

      // Verify the merkle proof.
      bytes32 node = keccak256(abi.encodePacked(index, account, amount));
      if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert InvalidProof();

      // Mark it claimed and send the token.
      _setClaimed(account);
      IERC20(token).safeTransfer(account, amount);

      emit Claimed(index, account, amount);
    }
}
