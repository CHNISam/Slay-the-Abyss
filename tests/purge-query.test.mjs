import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync} from 'node:fs';
import {checkArchitecture} from '../scripts/check-architecture.mjs';
import {frozenPurgeQuerySources,runPurgeQueryFixture,purgeQueryBehaviorTrace} from './helpers/purge-query-baseline.mjs';

test('purge oracle pins full LivingWall and Boss sources at a27b86a5',()=>{
 assert.equal(Object.keys(frozenPurgeQuerySources().files).length,2);
});
for(const [fixture,marker]of [['contract','PURGE_QUERY_CONTRACT_PASS'],['dynamic','PURGE_QUERY_DYNAMIC_PASS']]){
 test(`purge ${fixture} preserves independently executed full-source baseline`,()=>{
  const path=`tests/lua/purge_query_${fixture}.lua`;
  const old=runPurgeQueryFixture(path,{frozen:true});assert.equal(old.status,0,old.stdout+old.stderr);assert(old.stdout.includes(marker));
  const current=runPurgeQueryFixture(path);assert.equal(current.status,0,current.stdout+current.stderr);
  assert.equal(purgeQueryBehaviorTrace(current.stdout),purgeQueryBehaviorTrace(old.stdout),'complete existing graph and purge API trajectory differs');
 });
}
test('pure candidate query loads only Copy in a cold VM',()=>{
 const result=runPurgeQueryFixture('tests/lua/purge_query_cold_load.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/PURGE_QUERY_COLD_PASS/);
});
test('pure purge candidate leaf exists with exactly the Copy dependency',()=>{
 assert(existsSync('src/lua/abyss_purge_candidates.lua'),'[PURGE_QUERY_STRUCTURE] missing abyss_purge_candidates leaf');
 const graph=checkArchitecture();assert.deepEqual(graph.errors,[]);
 const edges=graph.edges.filter(e=>e.from==='abyss_purge_candidates');
 assert.deepEqual(edges.map(e=>e.to),['abyss_copy'],'[PURGE_QUERY_STRUCTURE] candidate leaf must only import Copy');
});
test('Boss candidate selection no longer loads the LivingWall event module',()=>{
 const graph=checkArchitecture();
 assert.deepEqual(graph.edges.filter(e=>e.from==='abyss_boss_relics'&&e.to==='abyss_living_wall'),[],
  '[PURGE_QUERY_STRUCTURE] Boss still imports mixed LivingWall for purgeCards');
});
