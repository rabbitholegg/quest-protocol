// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Quest} from "./Quest.sol";

contract QuestFactory is Initializable, OwnableUpgradeable {
    UpgradeableBeacon public beacon;

    event QuestCreated(
        address indexed creator,
        address indexed contractAddress,
        string name,
        string symbol,
        string contractType
    );

    // always be initialized
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(
        address _currentQuestImplementation
    ) public initializer {
        __Ownable_init();
        beacon = new UpgradeableBeacon(_currentQuestImplementation);
        beacon.transferOwnership(msg.sender);
    }


    function createContract(string memory rewardToken_, uint256 endTime_, uint256 startTime_, uint256 totalAmount_, string memory allowList_) public onlyOwner returns (address clone)
    {
        clone = address(new BeaconProxy(address(beacon), ""));
        Quest(clone).initialize(
            rewardToken_,
            endTime_,
            startTime_,
            totalAmount_,
            allowList_
        );
        Quest(clone).transferOwnership(msg.sender);

//        emit QuestCreated(msg.sender, clone, _name, _symbol, _type);
    }
}