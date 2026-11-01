import {createHash} from 'node:crypto';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
import {validateLaunchContent} from '../scripts/verify-launch-content.mjs';

test('current launch ledger validates all production relics and both special curses without historical projection',()=>{
 const manifest=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
 const definitions=JSON.parse(readFileSync('data/relics.json','utf8')).relics;
 assert.equal(definitions.length,153);
 const added=["cultist_mask","face_of_cleric","gremlin_mask","nloths_mask","ssserpent_head","nloths_gift","bloody_idol","mutagenic_strength","necronomicon","enchiridion","nilrys_codex"];
 const prior=definitions.filter(row=>!added.includes(row.id));
 assert.equal(prior.length,142);
 // Exact original 1fcd321 ID inventory, checked directly against current data, not projected.
 assert.equal(createHash('sha256').update(JSON.stringify(prior.map(row=>row.id).sort())).digest('hex'),'4cbcf542495317a582b33fe066f1f77f39023099ea6998a37e11db8a10db7758');
 const queues=JSON.parse(readFileSync('data/catalogs/sts1-relic-queues.json','utf8')).queues;
 const ordinary=['common','uncommon','rare','shop','boss'].flatMap(tier=>queues[tier]);
 assert.equal(ordinary.length,130);assert.equal(new Set(ordinary).size,130);
 for(const id of added){
  const rows=definitions.filter(row=>row.id===id);assert.equal(rows.length,1);
  assert.equal(rows[0].rarity,'special');assert.ok(!ordinary.includes(rows[0].sourceId));
 }

 assert.deepEqual(manifest.relics.map(row=>row.id).sort(),definitions.map(row=>row.id).sort());
 assert.equal(manifest.generatedCards.find(row=>row.id==='curse_of_the_bell').sourceId,'CurseOfTheBell');
 assert.equal(manifest.generatedCards.filter(row=>row.id==='necronomicurse').length,1);
 assert.deepEqual(validateLaunchContent(manifest,{root:process.cwd()}),[]);
});

test('Calling Bell ledger rejects ordinary transformation channels, wrong identity and removability',()=>{
 for(const mutate of [
  row=>{row.channels=['explicit_event:transmogrifier:change','explicit:Run.obtainCard'];},
  row=>{row.channels=['explicit_event:living_wall:change','explicit:Run.obtainCard'];},
  row=>{row.sourceId='Regret';},
  row=>{row.unremovable=false;},
 ]){
  const manifest=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
  mutate(manifest.generatedCards.find(row=>row.id==='curse_of_the_bell'));
  assert.ok(validateLaunchContent(manifest,{runtime:false}).some(error=>error.includes('generatedCards/curse_of_the_bell')));
 }
});

test('current runtime retains all130 ordinary bindings and excludes eleven new SPECIAL dependencies',()=>{
 buildLuaData();writeFileSync('build/lua/current_event_relic_inventory.lua',`
local Run,D,Rewards=require('abyss_run'),require('abyss_data'),require('abyss_relic_rewards')
local r=Run.new(D,42);local n=0;local special={cultist_mask=true,face_of_cleric=true,gremlin_mask=true,nloths_mask=true,ssserpent_head=true,nloths_gift=true,bloody_idol=true,mutagenic_strength=true,necronomicon=true,enchiridion=true,nilrys_codex=true}
for _,tier in ipairs({'common','uncommon','rare','shop','boss'})do
 for _,source in ipairs(r.relicPool.catalog.queues[tier])do
  local d=assert(Rewards.definition(r,source),'ordinary source binding disappeared '..source)
  assert(d.rarity==tier and not special[d.id],'special event dependency leaked into ordinary source pool')
  n=n+1
 end
end
assert(n==130);print('CURRENT_130_ORDINARY_BINDINGS_PASS')
`);
 const r=runLua('build/lua/current_event_relic_inventory.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/CURRENT_130_ORDINARY_BINDINGS_PASS/);
});
