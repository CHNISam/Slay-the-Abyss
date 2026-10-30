import test from 'node:test';
import {historicalTest} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {nodesDepletedFixtureRepair as binding,preNodesDepletedFixtureSource as before} from './helpers/nodes-depleted-fixture-inverse.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const hash=source=>createHash('sha256').update(source).digest('hex');
historicalTest('nodes depleted-owner repair restores every original byte and rejects unrelated or partial edits',()=>{
 const current=readFileSync(binding.path,'utf8').replaceAll('\r\n','\n'),previous=before(binding.path,current);
 assert.equal(hash(current),binding.afterSha256);assert.equal(hash(previous),binding.beforeSha256);
 assert.equal(before(binding.path,current.replaceAll('\n','\r\n')),previous);
 assert.equal(before(binding.path,previous),previous);
 assert.equal(previous.replace(binding.before,binding.after),current);
 for(const mutant of [current+'\n',current.replace(binding.after,binding.after+binding.after),
  current.replace("equal(run.nodeFlow.reward.gold,23)","equal(run.nodeFlow.reward.gold,24)"),
  current.replace("equal(run.relicCounters.circlet,2)","equal(run.relicCounters.circlet,1)")]){
  assert.notEqual(mutant,current);assert.throws(()=>before(binding.path,mutant),/unreviewed nodes depleted-fixture source drift/);
 }
});
test('real acquired Omamori preserves exhausted-queue chest execution while invalid injected ownership refuses atomically',()=>{
 const result=runLua('tests/lua/nodes_depleted_ownership.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NODES_DEPLETED_OWNERSHIP_PASS 2/);
});
