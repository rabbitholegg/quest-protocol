# Quest Claim

Quests are created through the `QuestFactory` contract. This is performed
by a whitelisted account, historically the Internal RabbitHole team.

The sequence of events is:

1. Call `QuestFactory.createQuest(rewardType: [erc20|erc1155])` defined as:
   ```solidity
   function createQuest(
      string rewardType,
      address rewardAddress,
   )
   ```
    - `rewardType` will be either an ERC-1155 or an ERC-20 token.
    - `rewardAddress` is the address of the corresponding reward for completing the quest. This can be an ERC-1155 or
      ERC-20 contract address.
2. Transfer rewards to the newly created Quest. You can transfer direct or execute the `depositFullAwardAmount`
   function.
3. The Quest Factory will call the mintAndSend function for the total number of allowed recipients of Receipts.
4. Execute the markQuestAsReady function. This will validate that the Quest is ready for public and upon reaching the
   effective StartDate, will be ready for use.