# Quest Claim
<img width="1151" alt="image" src="https://user-images.githubusercontent.com/14314818/213346605-d45c4848-4d58-4ecd-97a2-63ebc9a4b05d.png">

Quests are created through the `QuestFactory` contract. Each Quest represents either an ERC-20 or ERC-1155 based reward.

The sequence of events is:

1. User performs the Quest action on-chain
2. Our indexer picks it up, generates an ECDSA sig/hash
3. User uses that to claim a Receipt (only 1 user <> 1 receipt)
4. User then can sell or keep the Receipt
5. User then can claim the reward if the receipt they hold hasn't claimed one yet. Something to note you can collect more Receipts on the secondary if you wanted to purchase more that hadn't had their rewards claimed yet.
