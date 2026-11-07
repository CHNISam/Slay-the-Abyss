import test from 'node:test';
import assert from 'node:assert/strict';
import {checkArchitecture,analyzeSources} from '../scripts/check-architecture.mjs';
import {dependencyCycles} from '../scripts/lua-quality-metrics.mjs';
import {readFileSync} from 'node:fs';
const consumers=['abyss_event_combat','abyss_event_combat_routes','abyss_potion_rewards'];
const facades=['abyss_relic_hooks','abyss_boss_relics','abyss_uncommon_relics','abyss_shop_relics','abyss_run'];
test('reward preparation consumes capabilities without returning to permanent Session owners',()=>{
 const graph=checkArchitecture();assert.deepEqual(graph.errors,[]);
 assert.deepEqual(graph.edges.filter(e=>consumers.includes(e.from)&&facades.includes(e.to)),[],
  '[SESSION_REWARD_BOUNDARY] reward preparation imports a mixed Session command facade');
 for(const cycle of dependencyCycles(graph.nodes,graph.edges))for(const member of consumers)
  assert(!cycle.members.includes(member),'reward preparation remains in an SCC: '+member);
});
test('reward capability policy rejects eager and deferred Session facade regressions',()=>{
 const policy=JSON.parse(readFileSync('config/architecture.json','utf8'));
 const rule=policy.dependencyBoundaries.find(x=>x.id==='session-reward-capabilities');assert(rule,'missing Session reward capability boundary');
 assert.deepEqual(rule.from,consumers);assert.deepEqual(rule.forbiddenTargets,facades);
 const sources=Object.fromEntries([...consumers,...facades].map(n=>[n,'return {}']));
 for(const from of consumers)for(const to of facades)for(const deferred of [false,true]){
  const report=analyzeSources({...sources,[from]:deferred?`return function()return require('${to}')end`:`return require('${to}')`},
   {layers:policy.layers,dependencyBoundaries:[rule],deferredImports:deferred?[{from,to}]:[]},{});
  assert(report.errors.some(e=>e.message.includes('Dependency boundary session-reward-capabilities:')));
 }
});
import {spawnSync} from 'node:child_process';
for(const group of ['potion','events','dynamic'])test(`Session reward ${group} complete graph matches independent three-source baseline VM`,()=>{
 const receipts=[];
 for(const variant of ['old','current']){
  const directory=`build/scc-owner/${group}-${variant}`;
  const result=spawnSync(process.execPath,['tests/helpers/session-reward-vm.mjs',variant,group,directory],{encoding:'utf8',timeout:30000,maxBuffer:1024*1024,windowsHide:true});
  assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);
  const receipt=JSON.parse(result.stdout);assert(receipt.checkpoints>0);receipts.push({receipt,graph:readFileSync(directory+'/graph.jsonl','utf8')});
 }
 assert.equal(receipts[0].receipt.checkpoints,receipts[1].receipt.checkpoints);
 assert.equal(receipts[1].graph,receipts[0].graph,'full state/RNG/alias/return/error graph differs');
});
