import test from 'node:test';
import {historicalTest} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {cachePureSourceProjection,deepFreezeSourceProof} from './helpers/pure-source-projection-cache.mjs';
import {relicRound3Composition} from './helpers/relic-round3-composition.mjs';
import {relicArtComposition} from './helpers/relic-art-composition.mjs';
import {relicRound2Composition} from './helpers/relic-round2-composition.mjs';
import {preRound3CatalogSource} from './helpers/round3-catalog-source-inverse.mjs';
import {preRound2UiSource} from './helpers/round2-ui-source-inverse.mjs';
const targets=deepFreezeSourceProof({one:{files:{a:{},b:{}}},two:{files:{a:{}}}});

test('cache keys retain complete raw source, path and target and include unknown-source results',()=>{
 let calls=0;
 const project=cachePureSourceProjection(targets,(path,source,target)=>{calls++;return source.startsWith('unknown')?source:[path,target,source].join('|');});
 const large='x'.repeat(5000);
 const cases=[['a',large,'one'],['a',large+'!','one'],['a',large,'two'],['b',large,'one'],
  ['a','unknown\n','one'],['a','unknown\r\n','one']];
 for(const args of cases){const previous=project(...args);assert.equal(project(...args),previous);}
 assert.equal(calls,cases.length);
 assert.equal(project('a','unknown\r\n','one'),'unknown\r\n');
 assert.equal(calls,cases.length);
});

test('exceptions retry instead of becoming cache entries and unregistered pairs never grow the cache',()=>{
 let calls=0;
 const project=cachePureSourceProjection(targets,(_path,source)=>{
  calls++;if(calls<=2)throw new Error('validation failed');return source;
 });
 for(let i=0;i<2;i++)assert.throws(()=>project('a','known','one'),/validation failed/);
 assert.equal(project('a','known','one'),'known');assert.equal(project('a','known','one'),'known');
 assert.equal(calls,3);
 for(const args of [['foreign','known','one'],['a','known','foreign'],['a',null,'one']]){
  project(...args);project(...args);
 }
 assert.equal(calls,9);
});

test('each proof path/target independently retains at most the configured number of complete inputs',()=>{
 const calls=new Map();
 const project=cachePureSourceProjection(targets,(path,source,target)=>{
  const key=[path,target,source].join('|');calls.set(key,(calls.get(key)??0)+1);return source;
 });
 project('a','independent','two');
 for(let i=0;i<64;i++)project('a','source'+i,'one');
 project('a','source0','one');assert.equal(calls.get('a|one|source0'),1);
 project('a','source64','one');project('a','source0','one');
 assert.equal(calls.get('a|one|source0'),2,'oldest input is recomputed after bounded eviction');
 project('a','independent','two');assert.equal(calls.get('a|two|independent'),1);
 let smallCalls=0;
 const small=cachePureSourceProjection(targets,(_path,source)=>{smallCalls++;return source;},{maxEntriesPerPair:1});
 for(const source of ['one','two','one'])small('a',source,'one');assert.equal(smallCalls,3);
 for(const maxEntriesPerPair of [0,-1,Infinity,1.5])assert.throws(()=>cachePureSourceProjection(targets,()=>{}, {maxEntriesPerPair}),/cache bound/);
});

test('all exported composition proofs are deeply immutable, including hunk line arrays',()=>{
 const frozen=value=>{
  if(value===null||typeof value!=='object')return;
  assert.ok(Object.isFrozen(value));for(const child of Object.values(value))frozen(child);
 };
 for(const proof of [relicRound3Composition,relicArtComposition,relicRound2Composition]){
  frozen(proof);
  assert.throws(()=>{proof.currentCommit='unreviewed';},TypeError);
  const target=Object.values(proof.targets)[0],binding=Object.values(target.files)[0];
  assert.throws(()=>{binding.afterSha256='unreviewed';},TypeError);
  assert.throws(()=>binding.hunks[0].after.push('unreviewed'),TypeError);
 }
});

historicalTest('warm pure projections never cache catalog or extracted UI linked-file validation',()=>{
 const path='config/architecture.json',source=readFileSync(path,'utf8');
 for(const project of [preRound3CatalogSource,preRound2UiSource]){
  project(path,source);
  let reads=0;
  for(let i=0;i<2;i++)assert.throws(()=>project(path,source,{readSource:()=>{reads++;throw Error('missing');}}),/linked.*missing/);
  assert.equal(reads,2,'each dynamic guard rereads the actual dependency after pure cache hits');
 }
});
