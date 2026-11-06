import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import luaparse from 'luaparse';
import {checkArchitecture} from '../scripts/check-architecture.mjs';
import {frozenRelicQuerySources,runRelicQueryFixture} from './helpers/relic-query-baseline.mjs';

test('relic query oracle pins six complete LF sources at reviewed revision 391306af',()=>{
 const proof=frozenRelicQuerySources();assert.equal(Object.keys(proof.files).length,6);
 const parse=source=>luaparse.parse(Buffer.from(source).toString('latin1'),{luaVersion:'5.3',encodingMode:'pseudo-latin1'});
 const expected=Object.values(proof.files).slice(0,5).map(file=>{
  const declaration=parse(file.source).body.find(node=>['LocalStatement','AssignmentStatement'].includes(node.type)
   &&node.variables.some(value=>value.name==='aliases'||value.type==='MemberExpression'&&value.identifier.name==='aliases'));
  return declaration.init[0].fields.map(field=>field.key.value??field.key.name);
 });
 const fixture=parse(readFileSync('tests/lua/relic_query_contract.lua','utf8'));
 const input=fixture.body.find(node=>node.type==='LocalStatement'&&node.variables[0].name==='aliasInputs').init[0];
 assert.deepEqual(input.fields.map(group=>group.value.fields.map(field=>field.value.value)),expected,
  'all 139 original alias input keys, with namespace and source order; no copied output mapping');
});

for(const [fixture,marker]of [['contract','RELIC_QUERY_CONTRACT_PASS 139 aliases'],['rewards','RELIC_QUERY_REWARDS_PASS 48 cases']]){
 test(`relic query ${fixture} agrees with independent frozen-source VM`,()=>{
  const path=`tests/lua/relic_query_${fixture}.lua`;
  const old=runRelicQueryFixture(path,{frozen:true});
  assert.equal(old.status,0,'pinned old behavior must execute: '+old.stdout+old.stderr);
  assert(old.stdout.includes(marker),'pinned baseline completed all assertions');
  const current=runRelicQueryFixture(path);
  assert.equal(current.status,0,'current behavior must execute: '+current.stdout+current.stderr);
  assert.equal(current.stdout,old.stdout,'complete query/return/RNG trajectory differs from pinned source');
 });
}

test('reward count cold query does not load Actor or mixed relic facades',()=>{
 const result=runRelicQueryFixture('tests/lua/relic_query_cold_load.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/RELIC_QUERY_COLD_PASS/);
});

test('one relic query leaf exists and has no require edge',()=>{
 assert(existsSync('src/lua/abyss_relic_queries.lua'),'[RELIC_QUERY_STRUCTURE] missing single abyss_relic_queries leaf');
 const graph=checkArchitecture();
 assert.deepEqual(graph.errors,[],'query leaf source and policy must parse and classify correctly');
 assert.deepEqual(graph.edges.filter(e=>e.from==='abyss_relic_queries'),[],'[RELIC_QUERY_STRUCTURE] pure query leaf has outbound dependency');
});

test('CardPool query dependency no longer returns through mixed relic facades',()=>{
 const graph=checkArchitecture();
 const oldTargets=['abyss_relic_hooks','abyss_boss_relics','abyss_uncommon_relics','abyss_rare_relics','abyss_shop_relics'];
 assert.deepEqual(graph.edges.filter(e=>e.from==='abyss_card_pool'&&oldTargets.includes(e.to)),[],
  '[RELIC_QUERY_STRUCTURE] CardPool still imports mixed execution facades');
});
