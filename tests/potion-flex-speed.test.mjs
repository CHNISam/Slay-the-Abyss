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
 buildLuaData();const seen=[];
 for(const [file,first,last]of [
  ['potion_flex_speed.lua',1,3],['potion_flex_speed_slice_2.lua',4,7],
  ['potion_flex_speed_slice_3.lua',8,10],['potion_flex_speed_slice_4.lua',11,11],
 ]){
  const started=Date.now(),r=runLua('tests/fixtures/js-owned/tests/lua/'+file);
  assert.equal(r.status,0,r.stderr||r.stdout);
  assert.match(r.stdout,new RegExp('^LUA_POTION_FLEX_SPEED_PASS '+(last-first+1)+'$','m'));
  const indices=[...r.stdout.matchAll(/^ok Flex Speed (\d+) - /gm)].map(m=>Number(m[1]));
  assert.deepEqual(indices,Array.from({length:last-first+1},(_,i)=>first+i));
  seen.push(...indices);console.log('Flex/Speed '+first+'-'+last+': '+(Date.now()-started)+'ms');
 }
 assert.equal(seen.length,11);assert.deepEqual(seen,Array.from({length:11},(_,i)=>i+1));
});
