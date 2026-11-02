import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import luaparse from 'luaparse';

const expected={
  "new": [
    "data",
    "seed",
    "options"
  ],
  "transaction": [
    "run",
    "command"
  ],
  "advanceAct": [
    "run"
  ],
  "freezeMapContext": [
    "run"
  ],
  "mapContext": [
    "run"
  ],
  "gainGold": [
    "run",
    "value"
  ],
  "eventDamage": [
    "run",
    "value"
  ],
  "eventNormalDamage": [
    "run",
    "value"
  ],
  "heal": [
    "run",
    "value"
  ],
  "increaseMaxHp": [
    "run",
    "value"
  ],
  "decreaseMaxHp": [
    "run",
    "value"
  ],
  "prepareCard": [
    "run",
    "id",
    "options"
  ],
  "commitCard": [
    "run",
    "offer"
  ],
  "obtainCard": [
    "run",
    "id",
    "options"
  ],
  "removeCard": [
    "run",
    "uid"
  ],
  "obtainRelic": [
    "run",
    "id"
  ],
  "prepareRelic": [
    "run",
    "options"
  ],
  "startCombat": [
    "run",
    "encounterId"
  ],
  "roomStreams": [
    "run",
    "floor"
  ],
  "prepareEventEncounter": [
    "run",
    "source",
    "floor",
    "misc"
  ],
  "startEventCombat": [
    "run"
  ],
  "startRoomCombat": [
    "run",
    "tier",
    "emeraldBoost"
  ],
  "snapshotEncounters": [
    "run"
  ],
  "restoreEncounters": [
    "run",
    "snapshot"
  ],
  "finishCombat": [
    "run"
  ],
  "proceedEnding": [
    "run",
    "expectedOwner"
  ],
  "rewardOptions": [
    "run"
  ],
  "claimCardReward": [
    "run",
    "choice"
  ],
  "claimRelicReward": [
    "run",
    "index"
  ],
  "claimEmeraldKey": [
    "run"
  ],
  "canClaimEmeraldKey": [
    "run"
  ],
  "claimGoldReward": [
    "run"
  ],
  "claimStolenGoldReward": [
    "run"
  ],
  "leaveCombatRewards": [
    "run"
  ],
  "reopenCombatRewards": [
    "run"
  ],
  "claimPotionReward": [
    "run"
  ],
  "skipPotionReward": [
    "run"
  ],
  "chooseCard": [
    "run",
    "token",
    "uid"
  ],
  "play": [
    "run",
    "uid",
    "targetIndex",
    "commandId"
  ],
  "chooseDiscard": [
    "run",
    "uids",
    "token",
    "generation"
  ],
  "choosePile": [
    "run",
    "uids",
    "token",
    "generation"
  ],
  "chooseScry": [
    "run",
    "uids",
    "token",
    "generation"
  ],
  "chooseHand": [
    "run",
    "uids",
    "token",
    "generation"
  ],
  "endTurn": [
    "run"
  ],
  "choosePotionStance": [
    "run",
    "selected",
    "token",
    "generation",
    "battle"
  ],
  "potionCapacity": [
    "run"
  ],
  "potionCount": [
    "run"
  ],
  "obtainPotion": [
    "run",
    "id"
  ],
  "discardPotion": [
    "run",
    "slot"
  ],
  "usePotion": [
    "run",
    "slot",
    "targetIndex",
    "afterPotionActions"
  ],
  "potionView": [
    "run"
  ],
  "canUpgradeCard": [
    "run",
    "uid"
  ],
  "upgradeCard": [
    "run",
    "uid"
  ]
};

test('Run public method names and named parameters preserve the pre-refactor contract',()=>{
 const actual={};
 function visit(node){
  if(!node||typeof node!=='object')return;
  const id=node.identifier;
  if(node.type==='FunctionDeclaration'&&id?.type==='MemberExpression'&&['M','Run'].includes(id.base.name)){
   const name=id.identifier.name;
   if(name!=='install'){assert.equal(actual[name],undefined,'duplicate API '+name);actual[name]=node.parameters.map(p=>p.name??p.type);}
  }
  for(const value of Object.values(node))if(Array.isArray(value))value.forEach(visit);else if(value&&typeof value==='object')visit(value);
 }
 // Explicit read inputs also let related-test selection see every API owner.
 const inputs=['src/lua/abyss_run.lua','src/lua/abyss_run_initialization.lua',
  'src/lua/abyss_run_transition.lua','src/lua/abyss_run_rooms.lua',
  'src/lua/abyss_run_settlement.lua','src/lua/abyss_run_potions.lua'];
 // Inspect today's real API directly. These explicit event additions extend
 // the old contract; #412 adds the read-only resultScore(run) query.
 // Every original method/parameter remains exact.
 for(const file of inputs)visit(luaparse.parse(readFileSync(file,'utf8'),{luaVersion:'5.3'}));
 assert.deepEqual(actual,{...expected,prepareCardCopy:['run','uid'],obtainCardCopy:['run','uid'],loseRelic:['run','id'],resultScore:['run'],potionSlotView:['run','slot']});
});
