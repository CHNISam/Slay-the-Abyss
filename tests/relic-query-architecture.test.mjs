import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {analyzeSources} from '../scripts/check-architecture.mjs';
import {reviewResponsibilityComplexity,reviewModuleSize} from '../scripts/check-lua-static.mjs';

const leaf='abyss_relic_queries',pool='abyss_card_pool';
const facades=['abyss_relic_hooks','abyss_uncommon_relics','abyss_rare_relics','abyss_boss_relics','abyss_shop_relics'];
const owners=['abyss_actor','abyss_combat','abyss_run','abyss_card_actions'];
const expected=[
 {id:'relic-query-independence',from:[leaf],forbiddenTargets:[...facades,...owners]},
 {id:'card-pool-read-queries',from:[pool],forbiddenTargets:facades},
];

test('relic query policy prevents eager and deferred return to execution owners',()=>{
 const policy=JSON.parse(readFileSync('config/architecture.json','utf8'));
 assert.equal(policy.layers[leaf],'core','single query leaf must be explicitly classified');
 for(const wanted of expected){
  const rule=policy.dependencyBoundaries.find(row=>row.id===wanted.id);
  assert(rule,'missing dependency boundary '+wanted.id);
  assert.deepEqual(rule.from,wanted.from);assert.deepEqual(rule.forbiddenTargets,wanted.forbiddenTargets);
  const names=[...new Set([...rule.from,...rule.forbiddenTargets,leaf])];
  const sources=Object.fromEntries(names.map(name=>[name,'return {}']));
  const scoped={layers:policy.layers,dependencyBoundaries:[rule]};
  assert.deepEqual(analyzeSources(sources,scoped,{}).errors,[]);
  for(const from of rule.from)for(const to of rule.forbiddenTargets)for(const deferred of [false,true]){
   const call=`require('${to}')`;
   const code=deferred?`return function()return ${call}end`:`return ${call}`;
   const report=analyzeSources({...sources,[from]:code},{...scoped,
    deferredImports:deferred?[{from,to}]:[]},{});
   assert(report.errors.some(error=>error.message.includes(`Dependency boundary ${rule.id}: ${from} cannot depend on ${to}`)),
    `restored ${deferred?'deferred':'eager'} dependency ${from}->${to} must fail`);
  }
 }
});

test('every query leaf helper and callback retains CC15 and module size limits',()=>{
 const file=`src/lua/${leaf}.lua`;
 const source='local function owns() return function() end end';
 const row=(column,subject,value)=>({file,line:1,column,code:'W561',
  message:`cyclomatic complexity of ${subject} is too high (${value} > 0)`});
 const rows=[row(1,'main chunk',1),row(7,"function 'owns'",16),
  row(source.indexOf('function()')+1,'function',16)];
 const errors=reviewResponsibilityComplexity(rows,{[file]:source}).errors;
 assert(errors.some(e=>e.file===file&&e.message==="Responsibility complexity 16 exceeds 15: function 'owns'"));
 assert(errors.some(e=>e.file===file&&e.message==='Responsibility complexity 16 exceeds 15: function'));
 assert(reviewModuleSize({[file]:Array(1001).fill('-- line').join('\n')}).errors.some(e=>e.file===file));
 assert(reviewModuleSize({}).errors.some(e=>e.file===file));
});

test('query facade accessors retain complete CC15 measurements',()=>{
 for(const name of facades)for(const accessor of ['queryIndex','queryNewIndex']){
  const file=`src/lua/${name}.lua`,source=`local function ${accessor}() end`;
  const row=(column,subject,value)=>({file,line:1,column,code:'W561',
   message:`cyclomatic complexity of ${subject} is too high (${value} > 0)`});
  const rows=[row(1,'main chunk',1),row(7,`function '${accessor}'`,16)];
  assert(reviewResponsibilityComplexity(rows,{[file]:source}).errors.some(e=>e.file===file
   &&e.message===`Responsibility complexity 16 exceeds 15: function '${accessor}'`));
  assert(reviewResponsibilityComplexity([],{[file]:source}).errors.some(e=>e.file===file
   &&e.message===`Required responsibility entry missing or duplicated: function '${accessor}'`));
 }
});
