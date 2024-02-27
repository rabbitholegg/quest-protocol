// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {BoostPass} from "./BoostPass.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {IERC5805} from "openzeppelin-contracts/interfaces/IERC5805.sol";
import {EIP712,ECDSA as Ecdsa} from "openzeppelin-contracts/utils/cryptography/EIP712.sol";
import {Checkpoints} from 'openzeppelin-contracts/utils/Checkpoints.sol';
import {Counters} from 'openzeppelin-contracts/utils/Counters.sol';
import {Context} from 'openzeppelin-contracts/utils/Context.sol';

contract BoostPassVotes is Context, EIP712, IERC5805 {
    using Checkpoints for Checkpoints.Trace224;
    using Counters for Counters.Counter;

    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping(address => address) private _delegation;
    mapping(address => Checkpoints.Trace224) private _delegateCheckpoints;

    Checkpoints.Trace224 private _totalCheckpoints;

    mapping(address => Counters.Counter) private _nonces;

    address public boostPassAddress;
    uint256 public boostPassCheckpoint;
    uint256 public boostPassSupplyAtCheckpoint;

    error MsgSenderIsNotBoostPass();
    error MsgSenderIsNotBoostPassOwner();

    // errors grabbed from OZ v5 Votes.sol 
    error ERC5805FutureLookup(uint256 timepoint, uint48 clock);
    error VotesExpiredSignature(uint256 expiry);

    modifier onlyBoostPass() {
        if (msg.sender != boostPassAddress) {
            revert MsgSenderIsNotBoostPass();
        }
        _;
    }

    modifier onlyBoostPassOwner() {
        if (msg.sender != BoostPass(boostPassAddress).owner()) {
            revert MsgSenderIsNotBoostPassOwner();
        }
        _;
    }

    constructor(address boostPassAddress_) EIP712("BoostPassVotes", "1") {
        boostPassAddress = boostPassAddress_;
    }

    function setTimestampAndSupply() external onlyBoostPassOwner {
        boostPassCheckpoint = block.timestamp;
        boostPassSupplyAtCheckpoint = BoostPass(boostPassAddress).totalSupply();
    }

    function clock() public view returns (uint48) {
        return SafeCastLib.toUint48(block.timestamp);
    }

    function CLOCK_MODE() public pure returns (string memory) {
        return "mode=timestamp";
    }

    function getVotes(address account) external view returns (uint256) {
        return _delegateCheckpoints[account].latest() + BoostPass(boostPassAddress).balanceOf(account);
    }

    function getPastVotes(address account, uint256 timepoint) public view returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }

        uint256 pastVotes = _delegateCheckpoints[account].upperLookupRecent(SafeCastLib.toUint32(timepoint));

        if (pastVotes != 0) {
            return pastVotes;
        }

        return this.getVotes(account);
    }

    function getPastTotalSupply(uint256 timepoint) public view virtual override returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }

        if (timepoint <= boostPassCheckpoint) {
            return boostPassSupplyAtCheckpoint;
        }

        uint256 pastTotalSupplyAfterCheckpoint = _totalCheckpoints.upperLookupRecent(SafeCastLib.toUint32(timepoint));
        
        // if (pastTotalSupply != 0) {
        //     return pastTotalSupply;
        // }

        // return BoostPass(boostPassAddress).totalSupply();
        return boostPassSupplyAtCheckpoint + pastTotalSupplyAfterCheckpoint;
    }

    function delegates(address account) public view returns (address) {
        return _delegation[account];
    }

    function delegate(address delegatee) public {
        address account = _msgSender();
        _delegate(account, delegatee);
    }

    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) public {
        if (block.timestamp > expiry) {
            revert VotesExpiredSignature(expiry);
        }
        address signer = Ecdsa.recover(
            _hashTypedDataV4(keccak256(abi.encode(_DELEGATION_TYPEHASH, delegatee, nonce, expiry))),
            v,
            r,
            s
        );
        require(nonce == _useNonce(signer), "Votes: invalid nonce");
        _delegate(signer, delegatee);
    }

    function _delegate(address account, address delegatee) internal virtual {
        address oldDelegate = delegates(account);
        _delegation[account] = delegatee;

        emit DelegateChanged(account, oldDelegate, delegatee);
        _moveDelegateVotes(oldDelegate, delegatee, _getVotingUnits(account));
    }

    function _transferVotingUnits(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) {
            _push(_totalCheckpoints, _add, SafeCastLib.toUint224(amount));
        }
        if (to == address(0)) {
            _push(_totalCheckpoints, _subtract, SafeCastLib.toUint224(amount));
        }
        // we don't need to move delegate votes upon mint
        // _moveDelegateVotes(delegates(from), delegates(to), amount);
    }

    function _moveDelegateVotes(address from, address to, uint256 amount) private {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpoints[from],
                    _subtract,
                    SafeCastLib.toUint224(amount)
                );
                emit DelegateVotesChanged(from, oldValue, newValue);
            }
            if (to != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpoints[to],
                    _add,
                    SafeCastLib.toUint224(amount)
                );
                emit DelegateVotesChanged(to, oldValue, newValue);
            }
        }
    }

    function _push(
        Checkpoints.Trace224 storage store,
        function(uint224, uint224) view returns (uint224) op,
        uint224 delta
    ) private returns (uint224, uint224) {
        return store.push(SafeCastLib.toUint32(clock()), op(store.latest(), delta));
    }

    function _add(uint224 a, uint224 b) private pure returns (uint224) {
        return a + b;
    }

    function _subtract(uint224 a, uint224 b) private pure returns (uint224) {
        return a - b;
    }

    function _useNonce(address owner) internal virtual returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }

    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner].current();
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
   
    function afterTokenTransfer(
        address from,
        address to
    ) public onlyBoostPass {
        _transferVotingUnits(from, to, 1);
    }

    function _getVotingUnits(address account) internal view virtual returns (uint256) {
        return BoostPass(boostPassAddress).balanceOf(account);
    }
}
