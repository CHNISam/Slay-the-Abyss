import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {eventSnapshotComposition as proof,projectEventSnapshotSource as project} from './helpers/event-snapshot-composition.mjs';
import {requireEventProductionSource} from './helpers/event-production-source-inverse.mjs';
import {preNestedSnapshotOwnerSource} from './helpers/nested-command-snapshot-owner-inverse.mjs';
import {preBattleLifeOuterSource} from './helpers/battle-life-source-inverse.mjs';

test('complete event and nested-owner composition retains both prior immutable sources',()=>{
 assert.deepEqual(Object.keys(proof.files),['src/lua/abyss_combat.lua','src/lua/abyss_run.lua']);
 for(const [path,binding]of Object.entries(proof.files)){
  const current=preBattleLifeOuterSource(path,readFileSync(path,'utf8').replaceAll('\r\n','\n'));
  assert.equal(current,binding.current);
  for(const target of ['event','snapshot']){
   assert.equal(project(path,current,target),binding[target]);
   assert.equal(project(path,current.replaceAll('\n','\r\n'),target),binding[target]);
   for(const mutant of [current.slice(1),current+'\n-- unrelated drift\n',binding.event.slice(1)]){
    assert.equal(project(path,mutant,target),mutant);
    assert.throws(()=>requireEventProductionSource(path,mutant),/unreviewed integrated/);
    assert.equal(preNestedSnapshotOwnerSource(path,mutant),mutant);
   }
  }
  const other=Object.keys(proof.files).find(other=>other!==path);
  assert.equal(project(other,current,'event'),current,'wrong path cannot project');
 }
});
