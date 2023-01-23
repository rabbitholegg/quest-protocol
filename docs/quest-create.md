# Quest Create
<img width="995" alt="image" src="https://user-images.githubusercontent.com/14314818/213344188-e1497f22-a69b-4738-97e7-43cc26ad09fa.png">


Quests are created through the `QuestFactory` contract. This is performed
by a whitelisted account, historically the Internal RabbitHole team.

The sequence of events is:

1. Call `QuestFactory.createQuest(rewardType: [erc20|erc1155])` defined as:
   ```solidity
    function createQuest(
        address rewardTokenAddress_,
        uint256 endTime_,
        uint256 startTime_,
        uint256 totalParticipants_,
        uint256 rewardAmountOrTokenId_,
        string memory contractType_,
        string memory questId_
    )
   ```
    - `rewardTokenAddress_`is the contract address for the token reward (can be an 1155 or erc20 address)
    - `endTime` is the end time in unix for the Quest.
    - `startTime` is the start time in unix for the Quest.
    - `totalParticipants` is the total number of accounts that can participate in the Quest.
    - `rewardAmountOrTokenId_` is the reward amount if it's an ERC-20 token (ie. 1 UNI token out of the 1,000 total) or the tokenId if it's an 1155 reward.
    - `contractType_` will be either an ERC-1155 or an ERC-20 token.
    - `questId` is an internal UUID that connects multiple systems and acts as a universal UUID
2. Transfer rewards to the newly created Quest. You can just transfer in rewards directly.
3. The Quest Factory will keep track of receipts for a given user and quest. There is a finite amount of particpants allowed which is calculated by taking the totalRewards / rewardAmountOrTokenId if it's an ERC-20. If it's an ERC-1155 this will be totalRewards / 1 (since each is given 1 1155)
4. Execute the start function. This will validate that the Quest is ready for public and upon reaching the effective StartDate, will be ready for use. We may change the name to this as it's misleading before we go live. If a quest is not marked as started before the startDate all claims should revert.

Please note - currently the createQuest has access control restrictions as we dogfood the protocol and work on onboarding new partners in the coming weeks/months. If you're interested in exploring it exploring partnerships please reach out to us here:
