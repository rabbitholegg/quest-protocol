// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev contract addresess on every chain
library QuestContractConstants {
    address payable internal constant QUEST_FACTORY_ADDRESS = payable(0x52629961F71C1C2564C5aa22372CB1b9fa9EBA3E);
    address payable internal constant RABBIT_HOLE_TICKETS_ADDRESS = payable(0x0D380362762B0cf375227037f2217f59A4eC4b9E);
    address internal constant PROTOCOL_REWARDS_ADDRESS = 0x168437d131f8deF2d94B555FF34f4539458DD6F9;
    address internal constant PROXY_ADMIN_ADDRESS = 0xD28fbF7569f31877922cDc31a1A5B3C504E8faa1;
    address internal constant DETERMINISTIC_DEPLOY_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
}
