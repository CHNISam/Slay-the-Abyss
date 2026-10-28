import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
test('fixed-source Lizard Tail callback owns a single persistent use without claiming full integration',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/lizard_tail_component.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/LIZARD_TAIL_COMPONENT_PASS 11 groups; callback-only/);
});
test('Lizard Tail source lock retains fixed Java identities and the reviewed dependency-free component',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/lizard-tail-source.json','utf8'));
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.archive.sha256,'3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458');
 assert.equal(lock.files['relics/LizardTail.java'].sha256,'9ee5bd6aad4aa34a4d79cdd69f97160913b71d0f9e727f9ae8d7b26e2f281b90');
 assert.equal(lock.files['characters/AbstractPlayer.java'].sha256,'2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95');
 assert.equal(lock.files['relics/AbstractRelic.java'].sha256,'e4b5a8e6dda41cb9b25f75c5777f03e84da245247d1dac5d3070727fc8d24167');
 assert.equal(Object.keys(lock.files).length,9);
 assert.deepEqual(lock.contracts,{internalId:'lizard_tail',sourceId:'Lizard Tail',rarity:'rare',freshCounter:-1,
  spentCounter:-2,baseHeal:'max(1, maxHealth integer division by 2)',normalReturningHealConsumes:true,
  markBlocksWithoutConsuming:true,fairySelection:'caller must run Fairy first',integratedFatal:false,
  integratedAcquisition:false,integratedPersistence:false,integratedUI:false});
 for(const [path,hash]of Object.entries(lock.authoredInputs)){
  const source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  assert.equal(createHash('sha256').update(source).digest('hex'),hash,path);
  assert.doesNotMatch(source,/\brequire\s*\(/,'component must not depend on Actor, Fairy, healing or RNG');
 }
});
