import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {javaShuffle,tiers} from '../tools/oracles/sts1_relic_queues.mjs';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const lock=JSON.parse(readFileSync('tests/fixtures/class-common-relics-source-lock.json','utf8'));
test('class common definitions retain pinned original identities, tiers and hooks',()=>{
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.files.length,15);
 for(const file of lock.files)assert.match(file.sha256,/^[a-f0-9]{64}$/);
 const relics=JSON.parse(readFileSync('data/relics.json','utf8')).relics;
 for(const [id,fact]of Object.entries(lock.facts)){
  const found=relics.filter(relic=>relic.id===id);assert.equal(found.length,1,id);
  assert.equal(found[0].sourceId,fact.sourceId);assert.equal(found[0].rarity,fact.rarity);
 }
 const inventory=JSON.parse(readFileSync('data/release/launch-content.json','utf8'));
 for(const [id,character]of [['snake_skull','silent'],['data_disk','defect'],['damaru','watcher']]){
  const row=inventory.relics.find(entry=>entry.id===id);assert.equal(row?.sourcePoolClass,character);assert.equal(row.profile,'classCommonRelics');
  assert.equal(inventory.profiles[row.profile].live.status,'pending-natural-acquisition-and-execution');
 }
 for(const id of Object.keys(lock.facts)){
  assert.equal(relics.find(relic=>relic.id===id).trigger,'hooks');
  assert.deepEqual(relics.find(relic=>relic.id===id).effects,[]);
 }
});
for(const [fixture,marker,count]of [
 ['class_common_relic_effects','EFFECTS',9],
 ['class_common_relic_lifecycle','LIFECYCLE',11],
 ['class_common_relic_constructor','CONSTRUCTOR',4],
])test(`class common relic ${marker.toLowerCase()} follows source expectations`,()=>{
 buildLuaData();const result=runLua(`tests/fixtures/js-owned/tests/lua/${fixture}.lua`);
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,new RegExp(`CLASS_COMMON_RELIC_${marker}_PASS ${count}`));
});

const vectors=JSON.parse(readFileSync('tests/fixtures/class-common-relic-queue-vectors.json','utf8'));
test('class-common natural source inputs match the independent RNG and Java shuffle oracle',()=>{
 const sha=path=>createHash('sha256').update(readFileSync(path,'utf8').replaceAll('\r\n','\n')).digest('hex');
 assert.equal(sha(vectors.generator),vectors.generatorSha256);
 assert.equal(sha(vectors.luaFixture),vectors.luaSha256);
 for(const [path,hash]of Object.entries(vectors.inputs))assert.equal(sha(path),hash);
 const catalogs=JSON.parse(readFileSync('data/catalogs/sts1-class-relic-queues.json','utf8'));
 for(const sample of vectors.cases)for(const [i,tier]of tiers.entries())assert.deepEqual(sample.queues[tier],javaShuffle(catalogs[sample.character].queues[tier],sample.rawLongHex[i]));
});
test('formal class-common source channels preserve original full queues, entropy and unavailable guards',()=>{
 buildLuaData();const result=runLua('tests/fixtures/js-owned/tests/lua/class_common_relic_channels.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/CLASS_COMMON_RELIC_CHANNELS_PASS 5/);
});
