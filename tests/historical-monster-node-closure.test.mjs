import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {verifiedHistoricalMonsterNodeClosure,historicalMonsterNodeInputs} from './helpers/historical-monster-node-closure.mjs';
const read=path=>readFileSync(path,'utf8');
test('historical before/after Node replay restores matching helpers and original compressed documents',()=>{
 const sources=verifiedHistoricalMonsterNodeClosure(read),map=new Map(sources);
 assert.equal(sources.length,26);assert.equal(map.size,26);
 assert.ok(map.get('tests/helpers/native-monster-art-source-inverse.mjs'));
 assert(!map.get('tests/helpers/pr323-accepted-source-inverse.mjs').includes('preIntegrationSource'));
 assert.equal(map.get('docs/reviews/mobile-qa-source-migration-20261028.json.gz').subarray(0,2).toString('hex'),'1f8b');
 assert.equal(verifiedHistoricalMonsterNodeClosure(path=>read(path).replaceAll('\r\n','\n').replaceAll('\n','\r\n')).length,26);
});
test('every current helper and archive is reread and rejects missing or edited bytes after warm success',()=>{
 verifiedHistoricalMonsterNodeClosure(read);
 for(const changed of historicalMonsterNodeInputs){
  assert.throws(()=>verifiedHistoricalMonsterNodeClosure(path=>read(path)+(path===changed?'\n// unreviewed\n':'')),/unreviewed historical Node/);
  assert.throws(()=>verifiedHistoricalMonsterNodeClosure(path=>path===changed?'':read(path)),/unreviewed historical Node/);
 }
});

test('current selector, constructor and entry dependency witnesses are covered by fresh closure guards',()=>{
 const names=['selector-current-source','fixture-construction-source','current-entry-source',
  'phase-four-runner-source','deck-visibility-source','death-audio-source','raw-binding-source',
  'phase-three-memory-source','entry-recognition-lengths','runtime-recognition-lengths',
  'source-recognition-lengths','p0-deck-recognition-lengths','final-ui-source','title-menu-source'];
 const inputs=names.flatMap(name=>['tests/helpers/'+name+'.mjs','tests/fixtures/'+name+'.json']);
 verifiedHistoricalMonsterNodeClosure(read);
 for(const input of inputs){
  assert.ok(historicalMonsterNodeInputs.includes(input),'missing current closure dependency: '+input);
  let reads=0;
  verifiedHistoricalMonsterNodeClosure(path=>{if(path===input)reads++;return read(path);});
  assert.equal(reads,1,'fresh dependency read: '+input);
  for(const replacement of ['',read(input)+'\n// drift\n']){
   assert.throws(()=>verifiedHistoricalMonsterNodeClosure(path=>path===input?replacement:read(path)),/unreviewed historical Node/);
  }
 }
});
