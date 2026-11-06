import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {analyzeSources} from '../scripts/check-architecture.mjs';

test('pure Power rules have a permanent boundary against lifecycle orchestrators',()=>{
 const policy=JSON.parse(readFileSync('config/architecture.json','utf8'));
 assert.equal(policy.layers.abyss_actor_power_rules,'core');
 const rule=policy.dependencyBoundaries.find(r=>r.id==='actor-power-rules-independence');
 assert(rule,'required rule');
 assert.deepEqual(rule.from,['abyss_actor_power_rules']);
 for(const target of ['abyss_actor','abyss_combat','abyss_relic_hooks']){
  assert(rule.forbiddenTargets.includes(target),target);
  for(const code of [`return require('${target}')`,`return function()return require('${target}')end`]){
   const report=analyzeSources({abyss_actor_power_rules:code,[target]:'return {}'},
    {layers:policy.layers,dependencyBoundaries:[rule]},{});
   assert(report.errors.some(e=>e.message.includes('Dependency boundary actor-power-rules-independence')));
  }
 }
});
