import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {frozenRelicLifecycleSources,frozenPurgeA27Sources,readFrozenRelic391Source,readFrozenPurgeA27Source,relicLifecycleGroups,runRelicLifecycle,relicLifecycleRevision,relicLifecycleArchiveSha256,lifecycleHash} from './helpers/relic-lifecycle-baseline.mjs';
import {frozenRelicQuerySources} from './helpers/relic-query-baseline.mjs';
import {frozenPurgeQuerySources} from './helpers/purge-query-baseline.mjs';

test('relic lifecycle pins all 329 historical handwritten Lua sources with LF SHA256 and Git blob identities',()=>{
 const proof=frozenRelicLifecycleSources();assert.equal(Object.keys(proof.files).length,329);
 for(const name of ['abyss_actor','abyss_combat','abyss_run','abyss_relic_hooks','abyss_writhing_mass'])assert(proof.files[name]);
});
test('complete independent epochs retain original six/two-source query witnesses byte for byte',()=>{
 assert.equal(Object.keys(frozenPurgeA27Sources().files).length,330);
 for(const file of Object.values(frozenRelicQuerySources().files))assert.equal(readFrozenRelic391Source(file.path),file.source,'original six-source 391 witness');
 for(const file of Object.values(frozenPurgeQuerySources().files))assert.equal(readFrozenPurgeA27Source(file.path),file.source,'original two-source a27 witness');
 assert.throws(()=>readFrozenPurgeA27Source('src/lua/nonexistent.lua'),/registered complete/);
});
test('frozen VMs reject live new-source preloads and allow only each complete epoch plus exact generated inputs',()=>{
 for(const a27 of [false,true]){
  const result=runRelicLifecycle('hp',{frozen:true,trace:false,isolation:true,a27});
  assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/RELIC_FROZEN_ISOLATION_PASS 0/);
  for(const [name,origin]of Object.entries(result.manifest.loadedOrigins)){
   const files=a27?frozenPurgeA27Sources().files:frozenRelicLifecycleSources().files;
   assert(origin==='handwritten'&&Object.hasOwn(files,name)||origin==='generated'&&Object.hasOwn(result.manifest.generatedBindings,name));
  }
 }
});
test('bounded dispatch preserves every original fatal/turn/attack fixture byte and fixed source hash',()=>{
 const contract=JSON.parse(readFileSync('tests/helpers/relic-lifecycle-baseline-fixture-contract.json','utf8'));
 assert.equal(contract.schemaVersion,1);assert.equal(contract.normalization,'LF');
 const source=readFileSync('tests/helpers/relic-lifecycle-baseline-fixtures.lua','utf8').replaceAll('\r\n','\n');
 const entries=[...source.matchAll(/(\w+)=\{path='([^']+)',sha256='([a-f0-9]+)',source=\[====\[([\s\S]*?)\]====\]\},/g)];
 assert.deepEqual(entries.map(m=>m[1]),['fatal','turns','attacks','uncommon','shop','parasite']);
 for(const [,key,path,sha,body]of entries){
  const original=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  assert.equal(path,contract.fixtures[key].path);assert.equal(sha,contract.fixtures[key].sha256);
  assert.equal(lifecycleHash(original),sha,'complete fixed original fixture hash');assert.equal(body,original,'all original assertions remain unchanged');
 }
});
for(const group of relicLifecycleGroups)test(`relic lifecycle ${group} full frozen-source VM matches current complete graph`,()=>{
 const before=runRelicLifecycle(group,{frozen:true}),after=runRelicLifecycle(group);
 for(const result of [before,after]){
  assert.equal(result.status,0,`${group}: ${result.stdout}${result.stderr}`);
  assert.match(result.stdout,new RegExp(`RELIC_LIFECYCLE_PASS ${group} checkpoints=`));
  assert(result.manifest.checkpoints>0,'explicit trace must contain actual full checkpoints');
  assert.equal(lifecycleHash(result.graph),result.manifest.traceSha256,'read-back complete graph hash');
  const records=result.graph.trim().split('\n').map(line=>JSON.parse(line));
  assert.equal(records.length,result.manifest.checkpoints,'complete recorded checkpoint count');
  assert(records.some(row=>row.graph.definitions.some(d=>d[0]==='table')),'actual table graph definitions');
 }
 assert.equal(before.manifest.frozenRevision,relicLifecycleRevision);assert.equal(before.manifest.frozenArchiveSha256,relicLifecycleArchiveSha256);
 assert.equal(before.manifest.preloadedSources,329);assert(before.manifest.loadedFrozen.includes('abyss_run'));
 assert.equal(after.manifest.preloadedSources,0,'current VM reads real current source files');
 assert.deepEqual(after.manifest.generatedBindings,before.manifest.generatedBindings,'identical generated source input hashes');
 assert.deepEqual(after.manifest.registeredCases,before.manifest.registeredCases,'same actual loop-generated case registrations');
 assert.deepEqual(after.manifest.executedCases,before.manifest.executedCases,'same complete selected assertion bodies');
 assert.equal(after.manifest.checkpoints,before.manifest.checkpoints,'all method entry/return/throw boundaries');
 assert.deepEqual(after.manifest.coverage,before.manifest.coverage,'same real method invocations');
 assert.equal(after.stdout,before.stdout,'same original assertions and return markers');
 assert(after.graph===before.graph,`${group}: complete graph differs; inspect ${before.directory} and ${after.directory}`);
});
test('bounded fatal and hook case partitions have complete unions and no duplicate execution',()=>{
 for(const variant of ['frozen391','current']){
  const read=group=>JSON.parse(readFileSync(`build/relic-lifecycle/${group}-${variant}/manifest.json`,'utf8'));
  const fatal=['fatal_native','fatal_shared','fatal_orb','fatal_guardian'].map(read);
  for(const row of fatal)assert.deepEqual(row.registeredCases,fatal[0].registeredCases,'entire original registration inventory');
  const executed=fatal.flatMap(row=>row.executedCases);
  assert.equal(new Set(executed).size,executed.length,'each original fatal case executes exactly once');
  assert.deepEqual([...executed].sort(),[...fatal[0].registeredCases].sort(),'all original fatal assertions covered');
  for(const [group,count]of [['hooks_turns',5],['hooks_attacks',6],['hooks_opening',2]]){
   const row=read(group);assert.equal(row.executedCases.length,count);assert.deepEqual(row.executedCases,row.registeredCases);
  }
  for(const groups of [Array.from({length:11},(_,i)=>`uncommon_${String(i+1).padStart(2,'0')}`),['shop_early','shop_late'],Array.from({length:9},(_,i)=>`parasite_${String(i+1).padStart(2,'0')}`)]){
   const rows=groups.map(read),all=rows.flatMap(row=>row.executedCases);
   for(const row of rows)assert.deepEqual(row.registeredCases,rows[0].registeredCases,'entire original case inventory retained');
   assert.equal(new Set(all).size,all.length,'no duplicated original cases');
   assert.deepEqual([...all].sort(),[...rows[0].registeredCases].sort(),'complete original assertion union');
  }
 }
});
test('real lifecycle witnesses exercise all 14 Combat Hooks and every moved family/common method',()=>{
 const expected={
  hooks:'enqueuePostDraw upgradeRandomHand onVictory bindBattle preBattle hpChanged wasHpLost atTurnStart prepareTurnStart onUseCard afterCard battleStart endTurnBlock onPlayerEndTurn',
  boss:'atTurnStart onPlayCard wasHpLost preBattle onSpawnMonster battleStart',
  uncommon:'onVictory atTurnStart onShuffle onUseCard onMonsterDeath wasHpLost strikeBonus vulnerablePercent canPlayCurse',
  rare:'bindBattle battleStart atTurnStart postDraw onPlayCard onUseCard onPlayerEndTurn disableTop onRefreshHand blockPower onVulnerableApplied onAttacked blockAtTurnStart rechargeEnergy modifyHealing randomCardId onExhaust chooseGambling applyEffect onVictory',
  shop:'battleStartActions turnStartActions onBlockBroken onShuffle medicalCard exhaustAfterUse onUseCard execute beginToolbox chooseToolbox',
  common:'gainGold beforeObtainCard onPreviewObtainCard previewCardReward onObtainCard',
 };
 for(const variant of ['frozen391','current']){
  const coverage={};for(const group of relicLifecycleGroups){
   const row=JSON.parse(readFileSync(`build/relic-lifecycle/${group}-${variant}/manifest.json`,'utf8'));
   for(const [name,n]of Object.entries(row.coverage))coverage[name]=(coverage[name]??0)+n;
  }
  for(const [scope,names]of Object.entries(expected))for(const name of names.split(' '))
   assert(coverage[`${scope==='common'?'hooks':scope}.${name}`]>0,`${variant}: missing real ${scope}.${name} invocation`);
  const dynamic=JSON.parse(readFileSync(`build/relic-lifecycle/dynamic-${variant}/manifest.json`,'utf8'));
  assert.equal(dynamic.executedCases.length,114,'all original function fields replace, call, nil and restore');
 }
});
