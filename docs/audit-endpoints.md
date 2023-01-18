# Audit Endpoints
There are a couple of endpoints that will allow users to be able to get the ECDSA hash and signature that can be used to mint a Receipt. These endpoints were created so that the audit flow would be easier to go through the off-chain steps.

The ECDSA stuff basically follows [this Alchemy guide](https://docs.alchemy.com/docs/how-to-create-an-off-chain-nft-allowlist "this Alchemy guide").

## 1. Add an address to a Quest's Allowlist

HTTP POST:
https://api.staging.rabbithole.gg/audit/allowlist

Body:
```
{
	"questId": "...",
	"address": "0x..."
}
```
Response:
```
{
	"success": true
}
```
The `questId` is the uuid of the Quest in our db. It is also used when creating Quests through the Quest Factory contract. The `address` any address you'd like to add onto the allowlist.

## 2. Get ECDSA Hash + Signature

HTTP POST:
https://api.staging.rabbithole.gg/audit/mint-receipt

Body:
```
{
	"questId": "...",
	"address": "0x..."
}
```

Response:
```
{
	"signature": "0x...",
	"hash": "0x..."
}
```

The body params are the same as the allowlist endpoint above. This endpoint will check that an address is on the Quest allowlist before sending out the hash and signature. The only difference between this audit endpoint and the actual endpoint is that the actual endpoint will check if a user has completed a Quest's tasks.