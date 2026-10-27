import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {javaShuffle,tiers} from '../tools/oracles/sts1_relic_queues.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
import {createHash} from 'node:crypto';
const read=path=>JSON.parse(readFileSync(path,'utf8'));
// Independent exact-integer seed -> RandomXS128 words. No production imports.
function shuffleLongs(seed){
 const mask=(1n<<64n)-1n;
 const mix=input=>{
  let value=input&mask;
  value=((value^(value>>33n))*0xff51afd7ed558ccdn)&mask;
  value=((value^(value>>33n))*0xc4ceb9fe1a85ec53n)&mask;
  return value^(value>>33n);
 };
 let a=mix(BigInt(seed)||-(1n<<63n)),b=mix(a);
 return Array.from({length:5},()=>{
  const previous=b;let value=a;value^=(value<<23n)&mask;
  a=previous;b=(value^previous^(value>>17n)^(previous>>26n))&mask;
  return ((b+previous)&mask).toString(16).padStart(16,'0');
 });
}
test('economy effect fixtures use complete pinned queues and independently seeded shuffle words',()=>{
 const fixture=read('tests/fixtures/economy-relic-seeds.json');
 const catalog=read('data/catalogs/sts1-relic-queues.json');
 assert.equal(fixture.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 for(const sample of [fixture.membership,fixture.stone]){
  assert.deepEqual(sample.shuffleLongHex,shuffleLongs(sample.seed));
  for(const [index,tier]of tiers.entries()){
   assert.deepEqual(sample.queues[tier],javaShuffle(catalog.queues[tier],sample.shuffleLongHex[index]));
   assert.equal(sample.queues[tier].length,catalog.queues[tier].length);
  }
  assert.equal(sample.queues[sample.tier].at(-1),sample.target);
 }
 assert.equal(readFileSync('tests/fixtures/economy_relic_seeds.lua','utf8').replaceAll('\r\n','\n'),
  '-- Frozen independent source stream fixtures; see economy-relic-seeds.json.\nreturn '+toLua(fixture)+'\n');
});
test('restore partition keeps the entire migrated body and executes all five original groups once',()=>{
 const lock=read('tests/fixtures/economy-regression-partitions.json');
 assert.equal(lock.base,'2425ad622eed31ad6a965b90086a6838a1db96f4');
 assert.equal(lock.timeoutMilliseconds,30000);assert.equal(lock.total,5);
 const lf=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
 let body=lf(lock.entry);
 assert(body.startsWith(lock.prefix));assert(body.endsWith(lock.footer));
 body=body.slice(lock.prefix.length,-lock.footer.length);
 assert.equal(body.split(lock.after).length,2);body=body.replace(lock.after,lock.before);
 assert.equal(createHash('sha256').update(body).digest('hex'),lock.migratedFullBodySha256LF);
 const groups=[];
 for(const [index,slice]of lock.slices.entries()){
  if(index)assert.equal(lf(slice.path),`assert(loadfile('${lock.entry}'))(${slice.first},${slice.last})\n`);
  else{assert.equal(slice.path,lock.entry);assert(lock.prefix.includes(`sliceFirst or ${slice.first},sliceLast or ${slice.last}`));}
  for(let group=slice.first;group<=slice.last;group++)groups.push(group);
 }
 assert.deepEqual(groups,[1,2,3,4,5]);
});
