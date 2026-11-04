import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {analyzeSources,checkArchitecture} from '../scripts/check-architecture.mjs';
const sources={a:'return {}',b:'return {}'};
const rule={id:'no-reverse',from:['a'],forbiddenTargets:['b'],reason:'Admission cannot depend on dispatch'};
const policy={layers:{a:'core',b:'core'},dependencyBoundaries:[rule]};
test('responsibility boundaries validate policy and reject immediate and deferred imports',()=>{
 for(const code of ['return require("b")','return function() return require("b") end']) {
  const report=analyzeSources({...sources,a:code},{...policy,deferredImports:code.includes('function')?[{from:'a',to:'b'}]:[]},{});
  assert(report.errors.some(e=>/Dependency boundary no-reverse/.test(e.message)),code);
 }
 for(const a of ['-- require("b")\nreturn {}','return "require(\'b\')"','local require=function()end;return require("b")'])
  assert.deepEqual(analyzeSources({...sources,a},policy,{}).errors,[]);
 for(const boundary of [{...rule,id:''},{...rule,from:[]},{...rule,from:['a','a']},
  {...rule,forbiddenTargets:[]},{...rule,forbiddenTargets:['b','b']},{...rule,from:['missing']},
  {...rule,forbiddenTargets:['missing']},{...rule,reason:''}])
  assert(analyzeSources(sources,{...policy,dependencyBoundaries:[boundary]},{}).errors.length,JSON.stringify(boundary));
 assert(analyzeSources(sources,{...policy,dependencyBoundaries:[rule,rule]},{}).errors.length);
});
test('production policy permanently protects Actor and the independently loadable reaction entry',()=>{
 const policy=JSON.parse(readFileSync('config/architecture.json','utf8'));
 const boundaries=policy.dependencyBoundaries??[];
 const required=[['actor-reaction-admission','abyss_actor',['abyss_card_actions']],
  ['combat-reaction-independence','abyss_combat_reactions',['abyss_actor','abyss_card_actions','abyss_combat']]];
 for(const [id,from,targets] of required){
  const row=boundaries.find(row=>row.id===id);assert(row,id);assert(row.from.includes(from));
  for(const target of targets)assert(row.forbiddenTargets.includes(target),target);
 }
 const report=checkArchitecture();assert.deepEqual(report.errors,[]);
 assert(!report.edges.some(edge=>edge.from==='abyss_actor'&&edge.to==='abyss_card_actions'));
});
