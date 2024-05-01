// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

// solhint-disable no-global-import, no-console
import "forge-std/Test.sol";
import "forge-std/console.sol";

import {BlastQuestFactory} from "contracts/BlastQuestFactory.sol";
import {QuestFactory} from "contracts/QuestFactory.sol";
import {IQuestFactory} from "contracts/interfaces/IQuestFactory.sol";
import {Quest} from "contracts/Quest.sol";
import {Quest1155} from "contracts/Quest1155.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {LibString} from "solady/utils/LibString.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {LibZip} from "solady/utils/LibZip.sol";
import {JSONParserLib} from "solady/utils/JSONParserLib.sol";
import {Errors} from "./helpers/Errors.sol";
import {Events} from "./helpers/Events.sol";
import {TestUtils} from "./helpers/TestUtils.sol";
import {QuestContractConstants as C} from "../contracts/libraries/QuestContractConstants.sol";
import {ProxyAdmin, ITransparentUpgradeableProxy} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
 
interface IBlastPoints {
  function configurePointsOperator(address operator) external;
  function configurePointsOperatorOnBehalf(address contractAddress, address operator) external;
  function operators(address operator) external returns (address);
}
 
// forge test --fork-url https://rpc.blast.io --match-path test/BlastQuestFactory.t.sol
contract TestQuestFactory is Test, Errors, Events, TestUtils {
    using LibClone for address;
    using LibString for address;
    using LibString for string;
    using JSONParserLib for string;
    using LibString for uint256;

    QuestFactory questFactory;
    BlastQuestFactory blastQuestFactory;
    address owner;
    address random = makeAddr("random");
    address blastPointsAddress = 0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800; // BlastPoints Mainnet address

    function setUp() public {
        questFactory = QuestFactory(C.QUEST_FACTORY_ADDRESS);
        owner = questFactory.owner();

        vm.startPrank(owner);
        // upgrade QuestFactory to BlastQuestFactory
        ITransparentUpgradeableProxy questfactoryProxy = ITransparentUpgradeableProxy(C.QUEST_FACTORY_ADDRESS);
        ProxyAdmin(C.PROXY_ADMIN_ADDRESS).upgrade(questfactoryProxy, address(new BlastQuestFactory()));
        blastQuestFactory = BlastQuestFactory(C.QUEST_FACTORY_ADDRESS);
        vm.stopPrank();
    }

    function test_configurePointsOperator() public {
        vm.deal(random, 1 ether);

        vm.prank(random);
        vm.expectRevert();
        blastQuestFactory.configurePointsOperator(random);

        vm.prank(owner);
        blastQuestFactory.configurePointsOperator(owner);

        address operatorAddress = IBlastPoints(blastPointsAddress).operators(C.QUEST_FACTORY_ADDRESS);
        assertEq(operatorAddress, owner);
    }

}