import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';
const read=path=>JSON.parse(readFileSync(path,'utf8'));
const contract=read('tests/fixtures/darkstone-periapt-source-contract.json');

test('Darkstone contract binds exact pinned mirror blobs, original order and honest implementation boundary',()=>{
 assert.equal(contract.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(contract.sourceTree,'7b344415731748708a75d75c917f75c883f49fd0');
 const relic=contract.sources.find(r=>r.path==='relics/DarkstonePeriapt.java');
 assert.equal(relic.gitBlobSha,'7cff88ec76f796024b9b8f7bb567215dd14d1933');assert.equal(relic.size,1434);
 for(const source of contract.sources){assert.match(source.gitBlobSha,/^[0-9a-f]{40}$/);assert.match(source.sha256,/^[0-9a-f]{64}$/);assert.ok(source.size>0);assert.match(source.url,new RegExp(`/blob/${contract.sourceCommit}/`));}
 assert.deepEqual(contract.behavior,{rarity:'UNCOMMON',curseColorOnly:true,maxHpPerActualObtain:6,onEquipRetroactive:false,statusCardBonus:false,sourceMaxHpCap:null,spawnMaxFloor:48,endlessSpawn:true,order:['oldOmamoriBeforeObtainHooks','currentRelicsBeforePermanentDeckInsertion','increaseMaximum','healThroughRelicsThenPowers','clampCurrentToMaximum','insertPermanentCard']});
 assert.match(contract.provenanceBoundary,/decompiled.*not official source.*not.*PC.binary/i);
 assert.match(contract.implementationBoundary,/UNWIRED/);assert.match(contract.implementationBoundary,/NOT_RUN/);
 assert.match(contract.implementationBoundary,/retained combat/);assert.match(contract.implementationBoundary,/not an original rule restriction/);
});

test('Darkstone definition, existing icon alias and launch record remain explicit and source-identified',()=>{
 const relic=read('data/relics.json').relics.find(r=>r.id==='darkstone_periapt');
 assert.deepEqual(relic,{id:'darkstone_periapt',sourceId:'Darkstone Periapt',name:'Darkstone Periapt',description:'每当一张诅咒牌实际加入永久牌组，最大生命增加6，并按治疗规则回复6生命。',rarity:'uncommon',trigger:'hooks',effects:[]});
 const theme=read('data/presentation/ui_theme.json');assert.equal(theme.icon.relic.darkstone_periapt,theme.icon.relic.oddly_smooth_stone);assert.match(theme.note,/Darkstone Periapt.*暂复用/);
 const row=read('data/release/launch-content.json').relics.find(r=>r.id===relic.id);
 const mapped=read('docs/rules/evidence/sts1-relic-pool-catalog.json').relics.find(r=>r.id===relic.sourceId);assert.equal(mapped.projectId,relic.id);assert.equal(mapped.status,'existing-local-effect-not-full-pool-parity');assert.match(mapped.implementationLimitation,/reject atomically/);
 assert.equal(row.sourceId,relic.sourceId);assert.deepEqual(row.channels,['treasure','shop_relic']);assert.match(row.naturalExecutionLimitation,/reject atomically/);
 const catalog=read('data/catalogs/sts1-relic-queues.json');assert.equal(catalog.queues.uncommon.filter(id=>id==='Darkstone Periapt').length,1);assert.deepEqual(catalog.spawnGates['Darkstone Periapt'],{kind:'max-floor',floor:48,endlessBypass:true});
});

test('data gate admits the implemented hook but rejects no-op unknown hook and generic-effect substitution',()=>{
 const data=loadContent('data');assert.deepEqual(validateContent(data),[]);
 for(const mutate of [r=>{r.id='invented_darkstone_hook';},r=>{r.effects=[{op:'heal',value:6}];}]){
  const invalid=structuredClone(data);mutate(invalid.relics.relics.find(r=>r.id==='darkstone_periapt'));
  assert.ok(validateContent(invalid).some(error=>/unsupported relic hook|source hooks require empty/.test(error)));
 }
});

test('Darkstone actual Run commands preserve curse, status, healing, transaction, context and queue boundaries',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/darkstone_periapt.lua');assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/DARKSTONE_PERIAPT 13 passed/);
});

test('newly admitted Darkstone honors source destination-floor gates without retroactive obtain refusal',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/darkstone_spawn_gates.lua');assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/DARKSTONE_SPAWN_GATES 4 passed/);
});
