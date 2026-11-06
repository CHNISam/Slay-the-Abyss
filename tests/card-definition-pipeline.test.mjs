import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

const file='src/lua/abyss_combat.lua',fixture='tests/lua/card_definition_pipeline.lua';
const normalize=s=>s.replaceAll('\r\n','\n'),hash=s=>createHash('sha256').update(s).digest('hex');
const frozen=JSON.parse(readFileSync('tests/fixtures/card-definition-before.json','utf8'));
const baseline=gunzipSync(Buffer.from(frozen.gzipBase64,'base64')).toString('utf8');
assert.equal(frozen.revision,'b4ac63145689b9dd632db100eee49087f6182b39');
assert.equal(frozen.path,file);assert.equal(frozen.sha256,'2e6a406674d95f0037892120301b684857414dc75b9b225fec2052ff8ed6b55a');
assert.equal(hash(baseline),frozen.sha256);
function execute(source,group,trace=false){
 const dir=mkdtempSync(join(tmpdir(),'card-definition-'));
 try{
  const module=join(dir,'combat.lua'),driver=join(dir,'driver.lua');writeFileSync(module,source);
  writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;package.loaded.abyss_combat=dofile(${luaString(module.replaceAll('\\','/'))});DEFINITION_GROUP=${luaString(group)};DEFINITION_TRACE=${trace?'true':'false'};dofile(${luaString(resolve(fixture).replaceAll('\\','/'))})`);
  return runLua(driver,{maxBuffer:64*1024*1024});
 }finally{rmSync(dir,{recursive:true,force:true});}
}
for(const group of ['native','adapters','costs','copies-errors'])test(`complete card definition/input/RNG differential: ${group}`,t=>{
 const before=execute(baseline,group,true),after=execute(normalize(readFileSync(file,'utf8')),group,true);
 for(const r of [before,after]){assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/CARD_DEFINITION_PIPELINE_PASS 1/);}
 assert.ok(before.stdout===after.stdout,`${group}: full outputs and input graph differ in independent VMs`);
 t.diagnostic(`${group}: ${Buffer.byteLength(after.stdout)} bytes, SHA256 ${hash(after.stdout)}`);
});
test('definition pipeline real semantic mutations fail behavior and input immutability assertions',()=>{
 const source=normalize(readFileSync(file,'utf8'));
 const changes=[
  ['native Perfected Strike cannot be counted twice','native',
   "if not (native and card.id=='perfected_strike') then","if true then"],
  ['captured native flag remains stable after adapter replacement','native',
   "if not (native and card.id=='perfected_strike') then","if not (nativeDefinition(state,card) and card.id=='perfected_strike') then"],
  ['returned adapter object must be adopted','adapters',
   'card=require("abyss_silent_discard_cards").costAdapter(state,instance,card)',
   'require("abyss_silent_discard_cards").costAdapter(state,instance,card)'],
  ['zero override remains present','costs',
   'if instance.costForTurn~=nil then card.cost=instance.costForTurn end',
   'if instance.costForTurn and instance.costForTurn>0 then card.cost=instance.costForTurn end'],
  ['persistent Blood costs do not double-reduce','costs',
   "if card.id=='blood_for_blood' and instance.combatCost==nil and instance.turnCost==nil and instance.costReduction~=nil then",
   "if card.id=='blood_for_blood' and instance.costReduction~=nil then"],
  ['native Corruption must win skill cost','costs',
   "if native and state.player and not state.experimentalMechanics and card.type=='skill' and (state.player.statuses.corruption or 0)>0 then card.cost=0 end",
   'if false then card.cost=0 end'],
  ['Necronomicon snapshots before free Attack','costs',
   "if RelicHooksQueries.owns(state,'necronomicon')then card.necronomiconCostForTurn=card.cost end\n    if state.player and not card.costMode and require('abyss_watcher_final_cards').freeAttack(state,card) then card.cost=0 end",
   "if state.player and not card.costMode and require('abyss_watcher_final_cards').freeAttack(state,card) then card.cost=0 end\n    if RelicHooksQueries.owns(state,'necronomicon')then card.necronomiconCostForTurn=card.cost end"],
  ['X mode is not an ordinary free Attack','costs',
   "if state.player and not card.costMode and require('abyss_watcher_final_cards').freeAttack(state,card) then card.cost=0 end",
   "if state.player and require('abyss_watcher_final_cards').freeAttack(state,card) then card.cost=0 end"],
  ['Medical Kit replacement object must be retained','costs',
   'card=ShopRelics.medicalCard(state,card)','ShopRelics.medicalCard(state,card)'],
  ['definitions cannot mutate the catalog','copies-errors',
   'local card = copy(assert(state.catalog.cards[instance.cardId], "unknown card"))',
   'local card = assert(state.catalog.cards[instance.cardId], "unknown card")'],
  ['Searing validation precedes unknown-card lookup','copies-errors',
   'assert(M.validSearingBlowCopy(instance),"invalid Searing Blow constructor copy")\n    local card = copy(assert(state.catalog.cards[instance.cardId], "unknown card"))',
   'local card = copy(assert(state.catalog.cards[instance.cardId], "unknown card"))\n    assert(M.validSearingBlowCopy(instance),"invalid Searing Blow constructor copy")'],
 ];
 for(const [label,group,before,after]of changes){
  assert.equal(source.split(before).length-1,1,`${label}: unique live source mutation`);
  const r=execute(source.replace(before,after),group);assert.notEqual(r.status,0,`${label}: mutant survived`);
  assert.match(r.stdout+r.stderr,/\[DEFINITION_PIPELINE\]/,`${label}: behavioral assertion, not parse/runner failure`);
 }
 // A genuine reorder, rather than an omitted bonus: Shiv's base overwrite
 // must happen before the per-instance bonus, not after it.
 const begin=source.indexOf('local function damageCardDefinition('),end=source.indexOf('local function costCardDefinition(');
 assert(begin>=0&&end>begin);const block=source.slice(begin,end);
 const shiv='    if instance.cardId=="shiv" and state.player then\n        card=require("abyss_shivs").adaptDefinition(state,instance,card)\n    end\n';
 assert.equal(block.split(shiv).length-1,1);const removed=block.replace(shiv,'');
 const mutant=source.slice(0,begin)+removed.replace('    return card\nend',''+shiv+'    return card\nend')+source.slice(end);
 const r=execute(mutant,'adapters');assert.notEqual(r.status,0,'Shiv-after-bonus mutant survived');
 assert.match(r.stdout+r.stderr,/\[DEFINITION_PIPELINE\]/,'Shiv ordering: genuine assertion');
});
