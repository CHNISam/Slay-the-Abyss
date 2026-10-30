import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {rosterMutationEntries,rosterMutationCases,selectRosterMutationEntries} from './helpers/competition-roster-mutation-partition.mjs';
import {jsShard,discoverJs} from '../scripts/ci-shards.mjs';
const read=url=>readFileSync(new URL(url,import.meta.url),'utf8').replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=read('./fixtures/roster-mutation-partitions.json');
assert.equal(hash(bytes),'74ad05395932342ab01cd865b069925ac47a4ea23ad8e38e8c666931ad1a1e84');
const proof=JSON.parse(bytes);
const wrappers=[1,2,3,4].map(i=>`tests/competition-roster-mutations-${i}.test.mjs`);
function requireCover(groups){
 assert.equal(groups.length,4);
 const flat=groups.flat();
 assert.equal(flat.length,1032);
 assert.equal(new Set(flat).size,1032);
 assert.deepEqual([...flat].sort(),rosterMutationCases.map(c=>c.id).sort());
}
test('all 258 ordered registrations and 1032 unique mutation identities partition exactly once',()=>{
 assert.deepEqual(rosterMutationEntries,proof.registryEntries);
 assert.equal(hash(JSON.stringify(rosterMutationEntries)),proof.registrySha256);
 assert.equal(hash(JSON.stringify(rosterMutationCases.map(c=>c.id))),proof.caseIdsSha256);
 assert.equal(rosterMutationEntries.length,258);assert.equal(rosterMutationCases.length,1032);
 const groups=[1,2,3,4].map(i=>rosterMutationCases.filter(c=>c.index%4===i-1).map(c=>c.id));
 assert.deepEqual(groups.map(g=>g.length),[260,260,256,256]);requireCover(groups);
 for(const i of [1,2,3,4])assert.deepEqual(selectRosterMutationEntries(i),proof.registryEntries.filter((_,index)=>index%4===i-1));
 assert.deepEqual([1,2,3,4].map(i=>selectRosterMutationEntries(i).filter(([n])=>n==='abyss_run_admission').length),[1,0,0,0]);
 for(const i of [0,5,1.5,null,undefined,'1'])assert.throws(()=>selectRosterMutationEntries(i),/exact roster partition/);
 for(const bad of [groups.slice(1),[...groups.slice(0,3),groups[0]],groups.map((g,i)=>i?g:g.slice(1)),groups.map((g,i)=>i?g:[...g.slice(1),g[1]])])assert.throws(()=>requireCover(bad));
});
test('partition loop preserves the original complete mutation body and all 2-target/3-guard assertions',()=>{
 const helper=read('./helpers/competition-roster-mutation-partition.mjs');
 const actual=helper.split(' // BEGIN EXACT ORIGINAL MUTATION BODY\n')[1].split(' // END EXACT ORIGINAL MUTATION BODY')[0];
 const expected=proof.originalMutationBody
  .replace('for(const [name,layer]of Object.entries(layers)){','for(const [name,layer]of selectedEntries){')
  .replace('assert.equal(mutations,Object.keys(layers).length*4);','assert.equal(mutations,selectedEntries.length*4);')
  .replace("assert.equal(accepted,1,'only removing the sole admission insertion recovers a complete old config');","assert.equal(accepted,expectedAccepted,'only removing the sole admission insertion recovers a complete old config');");
 assert.equal(actual,expected);
 const positives=read('./competition-roster-config-composition.test.mjs');
 const marker="test('config reordering";const offset=positives.indexOf(marker);assert.ok(offset>0);
 const restored=positives.slice(0,offset)+"test('all actual registration mutations reject unknown identities while retaining the exact complete prior config witness',()=>{"+proof.originalMutationBody+'});\n'+positives.slice(offset);
 assert.equal(hash(restored),proof.originalTestSha256,'all original four tests are byte-for-byte reconstructible');
 assert.notEqual(actual.replace('assert.throws','assert.doesNotThrow'),expected);
});
test('all four automatic-discovery wrappers execute distinct partitions and existing four-shard scheduler retains them',()=>{
 const localNames=readdirSync(new URL('.',import.meta.url));
 for(const [index,path]of wrappers.entries()){
  assert.ok(localNames.includes(path.slice(6)));
  assert.equal(read('./'+path.slice(6)),`import test from 'node:test';\nimport{runRosterMutationPartition}from'./helpers/competition-roster-mutation-partition.mjs';\ntest('all original roster mutation assertions partition ${index+1}/4 (${[260,260,256,256][index]} cases)',()=>runRosterMutationPartition(${index+1}));\n`);
 }
 const files=[...new Set([...discoverJs(),...wrappers,'tests/competition-roster-mutation-partitions.test.mjs'])];
 for(const platform of ['linux','win32']){
  const plans=[1,2,3,4].map(i=>jsShard(files,i+'/4',platform).files);
  assert.deepEqual(plans.flat().sort(),[...files].sort());
  const assigned=plans.map(p=>p.filter(f=>wrappers.includes(f)));
  assert.deepEqual(assigned.flat().sort(),wrappers);
  assert.deepEqual(assigned.map(p=>p.length),[1,1,1,1]);
  assert.throws(()=>jsShard([...files,wrappers[0]],'1/4',platform),/unique/);
 }
});
