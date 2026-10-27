import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { runLua } from '../scripts/test-lua.mjs';
const source=JSON.parse(readFileSync('tests/fixtures/library-source-contract.json','utf8'));
test('Library locked source contract fixes20, duplicate rarity+identity retry, fresh obtain, float32 cached Sleep and separate Leave',()=>{
 assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');assert.equal(source.sourceTree,'7b344415731748708a75d75c917f75c883f49fd0');
 assert.equal(source.sources.length,16);
 const event=source.sources.find(s=>s.path==='events/city/TheLibrary.java');
 assert.equal(event.gitBlobSha,'185c2916997d5b68539bc8208e5fc47e0d724484');assert.equal(event.sha256,'8cbe97b4a7a7904d3dbcd5f8940d94e31508cc6e3ca1e2299bd7dea5cf379ff6');
 for(const s of source.sources){assert.match(s.gitBlobSha,/^[a-f0-9]{40}$/);assert.match(s.sha256,/^[a-f0-9]{64}$/);assert.ok(s.size>0);assert.ok(s.url.includes(`/blob/${source.sourceCommit}/`));}
 assert.equal(source.behavior.sourceId,'The Library');assert.equal(source.behavior.offerCount,20);
 assert.deepEqual(source.behavior.introChoices,['read','sleep']);assert.deepEqual(source.behavior.duplicateRetry,['rollRarity','getCard']);
 assert.equal(source.behavior.pityMutation,false);assert.equal(source.behavior.upgradeRolls,false);assert.equal(source.behavior.gridOrder,'reverse accepted generation order');
 assert.match(source.behavior.selectedCopy,/fresh base makeCopy/);
 assert.deepEqual(source.behavior.cachedHealFacts,{'1':0,'2':1,'3':1,'49':16,'50':17,'70':23,'72':24,'75':25,'80':26,'100':33});
 assert.deepEqual(source.behavior.selection,{count:1,forUpgrade:false,forTransform:false,canCancel:true,forPurge:false,anyNumber:false});
 assert.deepEqual(source.behavior.completion,['selection or sleep','result','separate Leave','openMap']);
 assert.match(source.implementationBoundary,/original-V4 Read unavailable/);assert.match(source.implementationBoundary,/Forced Molten\/Frozen Egg Read refuses/);assert.match(source.implementationBoundary,/Native acceptance NOT_RUN/);
});
test('independent source-pool/offer/full-RNG oracle regenerates all17 cases exactly',()=>{
 const result=spawnSync('python',['tools/oracles/library-event-oracle.py','--check'],{encoding:'utf8',timeout:15000});
 assert.equal(result.status,0,result.stderr||result.error?.message||result.stdout);assert.match(result.stdout,/LIBRARY_ORACLE_MATCH 4 ordered source pools \/ 17 full RNG continuations/);
 const vectors=JSON.parse(readFileSync('tests/fixtures/library-event-vectors.json','utf8'));
 assert.equal(vectors.cases.length,17);assert.equal(vectors.cases.filter(c=>c.gift).length,4);
 assert.ok(vectors.cases.some(c=>c.attempts.some(a=>!a.accepted)),'vectors must detect freezing rarity on duplicate retry');
 assert.ok(vectors.cases.some(c=>c.attempts.some(a=>a.rarityWords.length>1)),'vectors must retain primitive rejection words');
 for(const c of vectors.cases){assert.equal(c.offers.length,20);assert.equal(new Set(c.offers).size,20);assert.equal(c.final.counter-c.initial.counter,2*c.attempts.length);}
});
for(const [file,marker]of [['library_event.lua','LIBRARY_EVENT 13 passed'],['library_event_rng.lua','LIBRARY_RNG 4 passed'],['library_event_ui.lua','LIBRARY_UI 8 passed'],['library_event_combat.lua','LIBRARY_COMBAT 4 mapped-class actual acquisitions']]){
 test(`Library public commands/source vectors/generated UI: ${file}`,()=>{
  const result=runLua(`tests/lua/${file}`);assert.equal(result.status,0,result.stdout+result.stderr);assert.ok(result.stdout.includes(marker),result.stdout);
 });
}
