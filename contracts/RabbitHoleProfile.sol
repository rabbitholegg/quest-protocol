// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract RabbitHoleProfile is Initializable, Ownable, ERC721 {
    using LibString for uint256;
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public claimSignerAddress;
    uint256 private _tokenIdCounter;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error AddressNotSigned();
    error TokenNotTransferable();
    error AddressAlreadyMinted();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line func-visibility
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address claimSignerAddress_
    ) external initializer {
        _initializeOwner(owner_);
        claimSignerAddress = claimSignerAddress_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL UPDATE
    //////////////////////////////////////////////////////////////*/
    /// @dev universal dynamic mint function
    /// @param signature_ The signature of the data
    /// @param data_ The data to decode for the claim
    function mint(bytes calldata signature_, bytes calldata data_) external payable {
        address to_ = abi.decode(data_, (address));
        if (recoverSigner(keccak256(data_), signature_) != claimSignerAddress) revert AddressNotSigned();
        if (balanceOf(to_) > 0) revert AddressAlreadyMinted();

        _tokenIdCounter += 1;
        _mint(to_, _tokenIdCounter);
    }

    /// @dev set the claim signer address
    /// @param claimSignerAddress_ The address of the claim signer
    function setClaimSignerAddress(address claimSignerAddress_) external onlyOwner {
        claimSignerAddress = claimSignerAddress_;
    }

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the token collection name.
    function name() public pure override returns (string memory){
        return "RabbitHole Profile";
    }

    /// @dev Returns the token collection symbol.
    function symbol() public pure override returns (string memory){
        return "RHP";
    }

    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function tokenURI(uint256 id) public pure override returns (string memory){
        return LibString.concat("https://api.rabbithole.gg/profiles/", id.toString());
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    /// @dev recover the signer from a hash and signature
    /// @param hash_ The hash of the message
    /// @param signature_ The signature of the hash
    function recoverSigner(bytes32 hash_, bytes memory signature_) public view returns (address) {
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(hash_), signature_);
    }

    /// @dev soulbound tokens are not transferable
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        if (from != address(0)) revert TokenNotTransferable();
        super._beforeTokenTransfer(from, to, tokenId);
    }

}
