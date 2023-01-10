// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract RabbitHoleTickets is Initializable, ERC1155Upgradeable, OwnableUpgradeable, ERC1155BurnableUpgradeable {
    // storage
    mapping(uint => string) public questIdForTokenId;
    address public minterAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address minterAddress_) initializer public {
        __ERC1155_init("https::??");
        __Ownable_init();
        __ERC1155Burnable_init();
        minterAddress = minterAddress_;
    }

    modifier onlyMinter() {
        msg.sender == minterAddress;
        _;
    }

    function setMinterAddress(address minterAddress_) public onlyOwner {
        minterAddress = minterAddress_;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(string memory _questId, address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyMinter
    {
        if(bytes(questIdForTokenId[id]).length == 0) {
            questIdForTokenId[id] = _questId;
        }
        _mint(account, id, amount, data);
    }
}
