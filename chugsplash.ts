let QFRoles = {
  "0x00": { "0xE662f9575634dbbca894B756d1A19A851c824f00": true }, // 'DEFAULT_ADMIN_ROLE' https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol#L57
  "0xf9ca453be4e83785e69957dffc5e557020ebe7df32422c6d32ccad977982cadd": { "0xE662f9575634dbbca894B756d1A19A851c824f00": true } //  keccak256('CREATE_QUEST_ROLE');
}

{
  options: {
    projectName: "RabbitHole Quest Protocol"
  }
  contracts: {
    ReceiptRenderer: {
      contract: "ReceiptRenderer"
    }
    RabbitHoleReceipt: {
      contract: "RabbitHoleReceipt"
      variables: {
        _owner: 0xE662f9575634dbbca894B756d1A19A851c824f00
        _name: "RabbitHoleReceipt"
        _symbol: "RHR"
        royaltyRecipient: 0xC4a68e2c152bCA2fE5E8D26FFb8AA44bCE1B56b0
        minterAddress: 0x37A4a767269B5D1651E544Cd2f56BDfeADC37B05 // change after deploy to QuestFactory address
        royaltyFee: 100
        ReceiptRendererContract: {{ 'ReceiptRenderer' }}
      }
    }
    QuestFactory: {
      contract: 'QuestFactory' // Contract name in your Solidity source file
      variables: {
        _owner: '0xE662f9575634dbbca894B756d1A19A851c824f00'
        _roles: QFRoles
        rabbitholeReceiptContract: {{ 'RabbitHoleReceipt' }}
        rabbitholeReceiptContract: '0x97a1F6Eb42DDD89ddf7E2745472D8b393970e011'
        protocolFeeRecipient: '0xC4a68e2c152bCA2fE5E8D26FFb8AA44bCE1B56b0'
        questIdCount: 1
        questFee: 2000
      }
    }
  }
}