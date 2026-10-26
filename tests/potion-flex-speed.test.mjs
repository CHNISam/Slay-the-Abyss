import test from 'node:test';
import assert from 'node:assert/strict';
import {loadContent,validateContent} from '../scripts/validate-data.mjs';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('source Flex and Speed are base-five common self potions in the complete source pool',()=>{
 const data=loadContent('data');assert.deepEqual(validateContent(data),[]);
 for(const [id,op,status] of [['flex_potion','gainTemporaryStrength','strength'],['speed_potion','gainTemporaryDexterity','dexterity']]){
  const p=data.potions.potions.find(p=>p.id===id);assert(p,id);
  assert.equal(p.rarity,'common');assert.equal(p.targetPolicy,'self');assert.equal(p.acquisitionPending,undefined);
  assert.deepEqual(p.effects,[{op,status,value:5}]);
 }
});
test('real Run use preserves source delayed-loss and Artifact order',()=>{
 buildLuaData();const r=runLua('tests/lua/potion_flex_speed.lua');
 assert.equal(r.status,0,r.stderr||r.stdout);assert.match(r.stdout,/LUA_POTION_FLEX_SPEED_PASS 11/);
});
