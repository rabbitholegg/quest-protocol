// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {LibString} from "solady/utils/LibString.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract BoostPass is Initializable, Ownable, ERC721 {
    using LibString for *;
    using SafeTransferLib for address;
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public claimSignerAddress;
    uint256 private _tokenIdCounter;
    uint256 public mintFee;
    address public treasuryAddress;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error AddressNotSigned();
    error TokenNotTransferable();
    error AddressAlreadyMinted();
    error InvalidMintFee();
    error ToAddressIsNotSender();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event BoostPassMinted(address indexed minter, address indexed referrer, uint256 referrerFee, uint256 treasuryFee, uint256 tokenId);

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
        address claimSignerAddress_,
        uint256 mintFee_,
        address treasuryAddress_
    ) external initializer {
        _initializeOwner(owner_);
        claimSignerAddress = claimSignerAddress_;
        mintFee = mintFee_;
        treasuryAddress = treasuryAddress_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL UPDATE
    //////////////////////////////////////////////////////////////*/
    /// @dev universal dynamic mint function
    /// @param signature_ The signature of the data
    /// @param data_ The data to decode for the claim
    function mint(bytes calldata signature_, bytes calldata data_) external payable {
        (address to_, address referrer_) = abi.decode(data_, (address, address));
        if (to_ != msg.sender) revert ToAddressIsNotSender();
        if (recoverSigner(keccak256(data_), signature_) != claimSignerAddress) revert AddressNotSigned();
        if (balanceOf(to_) > 0) revert AddressAlreadyMinted();
        if (msg.value < mintFee) revert InvalidMintFee();

        unchecked {
            _tokenIdCounter += 1;
        }

        _mint(to_, _tokenIdCounter);

        uint256 referralFee = 0;

        if (referrer_ != address(0) && referrer_ != to_) {
            referralFee = mintFee / 2;
        } else {
            referrer_ = address(0);
        }

        if (referralFee > 0) {
            referrer_.safeTransferETH(referralFee);
        }

        uint256 treasuryFee = mintFee - referralFee;
        treasuryAddress.safeTransferETH(treasuryFee);

        emit BoostPassMinted(to_, referrer_, referralFee, treasuryFee, _tokenIdCounter);
    }

    /// @dev set the claim signer address
    /// @param claimSignerAddress_ The address of the claim signer
    function setClaimSignerAddress(address claimSignerAddress_) external onlyOwner {
        claimSignerAddress = claimSignerAddress_;
    }

    /// @dev set the mint fee
    /// @param mintFee_ The fee required to mint the Boost Pass
    function setMintFee(uint256 mintFee_) external onlyOwner {
        mintFee = mintFee_;
    }

    /// @dev set the treasury address
    /// @param treasuryAddress_ The address of the treasury
    function setTreasuryAddress(address treasuryAddress_) external onlyOwner {
        treasuryAddress = treasuryAddress_;
    }

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the token collection name.
    function name() public pure override returns (string memory){
        return "Boost Pass";
    }

    /// @dev Returns the token collection symbol.
    function symbol() public pure override returns (string memory){
        return "BP";
    }

    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function tokenURI(uint256 id) public view override returns (string memory){
        address owner = ownerOf(id);
        return LibString.concat("https://api.rabbithole.gg/v1/boostpass/", owner.toHexString()).concat("?id=").concat(id.toString());
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
