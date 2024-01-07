// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

contract Soulbound20 is Initializable, OwnableRoles, ERC20 {
    error TransferNotAllowed();

    event TransferAllowedSet(bool transferAllowed);

    uint256 public constant MINT_ROLE = 1;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    bool public transferAllowed;
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
        string memory name_,
        string memory symbol_
    ) external initializer {
        _initializeOwner(owner_);
        _name = name_;
        _symbol = symbol_;
    }

    /// @dev mint tokens, only callable by the allowed minter
    /// @param to_ the address to mint the ticket to
    /// @param amount_ the amount of the ticket to mint
    function mint(address to_, uint256 amount_) external onlyRoles(MINT_ROLE) {
        _mint(to_, amount_);
    }


    /*//////////////////////////////////////////////////////////////
                                  SET
    //////////////////////////////////////////////////////////////*/
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

    /*//////////////////////////////////////////////////////////////
                            INTERNAL OVERRIDE
    //////////////////////////////////////////////////////////////*/
    function _beforeTokenTransfer(address from, address to, uint256) internal virtual override {
        if(transferAllowed) return;

        // only allow minting and burning
        if (from != address(0) && to != address(0)) revert TransferNotAllowed();
    }
}