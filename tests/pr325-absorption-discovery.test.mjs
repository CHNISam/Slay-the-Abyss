import test from 'node:test';
import assert from 'node:assert/strict';
import {readdirSync} from 'node:fs';
import {discoverJs,jsShard,timings} from '../scripts/ci-shards.mjs';
import {shardLuaScripts} from '../scripts/test-lua.mjs';
import {luaSchedulingWeight,serialThresholdMs} from '../scripts/lua-workers.mjs';

const rawEntries=['tests/lua/pr323_preserved_safety.lua','tests/lua/pr323_deck_lifecycle.lua'];
const nodeEntries=['tests/pr323-preserved-safety.test.mjs','tests/pr323-deck-lifecycle.test.mjs','tests/pr325-absorption-discovery.test.mjs'];
test('absorbed PR325 safety and lifecycle fixtures remain discovered exactly once in every hosted plan',()=>{
 const raw=readdirSync('tests/lua').filter(name=>name.endsWith('.lua')).map(name=>'tests/lua/'+name);
 for(const path of rawEntries)assert.equal(raw.filter(entry=>entry===path).length,1,path);
 for(const workers of [1,2]){
  const plan=Array.from({length:8},(_,i)=>shardLuaScripts(raw,`${i+1}/8`,timings,workers)).flat();
  for(const path of rawEntries)assert.equal(plan.filter(entry=>entry===path).length,1,`${path}: ${workers} worker(s)`);
 }
 const js=discoverJs();
 for(const [platform,count]of [['win32',8],['linux',4]]){
  const plan=Array.from({length:count},(_,i)=>jsShard(js,`${i+1}/${count}`,platform).files).flat();
  for(const path of nodeEntries)assert.equal(plan.filter(entry=>entry===path).length,1,`${path}: ${platform}`);
 }
});
test('new raw fixtures retain conservative unknown-fixture exclusive worker scheduling',()=>{
 for(const path of rawEntries){
  assert.equal(timings.lua[path],undefined,'no unmeasured timing or budget is invented');
  const workerWeight=timings.lua[path]??10000;
  assert.ok(workerWeight>=serialThresholdMs,'unknown fixtures execute alone with two workers');
  assert.equal(luaSchedulingWeight(workerWeight,2),workerWeight*2);
 }
});
