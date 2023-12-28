// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract Soulbound20 is Initializable, Ownable, ERC20 {
    error OnlyMinter();
    error TransferNotAllowed();

    event MinterAddressSet(address indexed minterAddress);
    event TransferAllowedSet(bool transferAllowed);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    bool public transferAllowed;
    address public minterAddress;
    string private _name;
    string private _symbol;
    // insert new vars here at the end to keep the storage layout the same

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address minterAddress_,
        string memory name_,
        string memory symbol_
    ) external initializer {
        _initializeOwner(owner_);
        minterAddress = minterAddress_;
        _name = name_;
        _symbol = symbol_;
    }

    /// @dev mint tokens, only callable by the allowed minter
    /// @param to_ the address to mint the ticket to
    /// @param amount_ the amount of the ticket to mint
    function mint(address to_, uint256 amount_) external {
        if (msg.sender != minterAddress) revert OnlyMinter();

        _mint(to_, amount_);
    }


    /*//////////////////////////////////////////////////////////////
                                  SET
    //////////////////////////////////////////////////////////////*/
    /// @dev set the minter address, only callable by the owner
    /// @param minterAddress_ the address of the minter
    function setMinterAddress(address minterAddress_) external onlyOwner {
        minterAddress = minterAddress_;
        emit MinterAddressSet(minterAddress_);
    }

    /// @dev set the transfer allowed bool, only callable by the owner
    /// @param transferAllowed_ the bool to set transferAllowed to
    function setTransferAllowed(bool transferAllowed_) external onlyOwner {
        transferAllowed = transferAllowed_;
        emit TransferAllowedSet(transferAllowed_);
    }

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// soulbound
    function _beforeTokenTransfer(address from, address to, uint256) internal virtual override {
        if(transferAllowed) return;

        // only allow minting and burning
        if (from != address(0) && to != address(0)) revert TransferNotAllowed();
    }
}
