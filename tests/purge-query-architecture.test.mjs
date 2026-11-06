import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {analyzeSources,checkArchitecture} from '../scripts/check-architecture.mjs';
import {reviewResponsibilityComplexity,reviewModuleSize} from '../scripts/check-lua-static.mjs';

const leaf='abyss_purge_candidates';
const execution=['abyss_living_wall','abyss_boss_relics','abyss_run','abyss_actor','abyss_combat',
 'abyss_transform_card','abyss_card_capability','abyss_event_transform_context'];

test('permanent purge candidates only depend on Copy and Boss cannot return through LivingWall',()=>{
 const policy=JSON.parse(readFileSync('config/architecture.json','utf8'));
 assert.equal(policy.layers[leaf],'core','permanent candidate query requires explicit core ownership');
 const expected=[{id:'purge-candidate-independence',from:[leaf],forbiddenTargets:execution},
  {id:'boss-purge-query',from:['abyss_boss_relics'],forbiddenTargets:['abyss_living_wall']}];
 for(const wanted of expected){
  const rule=policy.dependencyBoundaries.find(row=>row.id===wanted.id);
  assert(rule,'missing query boundary '+wanted.id);
  assert.deepEqual(rule.from,wanted.from);assert.deepEqual(rule.forbiddenTargets,wanted.forbiddenTargets);
  const sources=Object.fromEntries([...new Set([...rule.from,...rule.forbiddenTargets])].map(name=>[name,'return {}']));
  for(const from of rule.from)for(const to of rule.forbiddenTargets)for(const deferred of [false,true]){
   const call=`require('${to}')`,code=deferred?`return function()return ${call}end`:`return ${call}`;
   const report=analyzeSources({...sources,[from]:code},{layers:policy.layers,dependencyBoundaries:[rule],
    deferredImports:deferred?[{from,to}]:[]},{});
   assert(report.errors.some(e=>e.message===`Dependency boundary ${wanted.id}: ${from} cannot depend on ${to}`),
    `${deferred?'deferred':'eager'} ${from}->${to}`);
  }
 }
 const graph=checkArchitecture();assert.deepEqual(graph.errors,[]);
 assert.deepEqual(graph.edges.filter(e=>e.from===leaf).map(e=>e.to),['abyss_copy'],'candidate query has one Foundation dependency');
});

test('every permanent candidate helper and facade accessor retains CC15',()=>{
 for(const [file,names]of [[`src/lua/${leaf}.lua`,['purgeCards']],
  ['src/lua/abyss_living_wall.lua',['queryIndex','queryNewIndex']]])for(const name of names){
  const source=`local function ${name}()return function()end end`;
  const row=(column,subject)=>({file,line:1,column,code:'W561',
   message:`cyclomatic complexity of ${subject} is too high (16 > 0)`});
  const errors=reviewResponsibilityComplexity([row(1,'main chunk'),row(7,`function '${name}'`),
   row(source.indexOf('function()')+1,'function')],{[file]:source}).errors;
  assert(errors.some(e=>e.file===file&&e.message===`Responsibility complexity 16 exceeds 15: function '${name}'`));
  assert(errors.some(e=>e.file===file&&e.message==='Responsibility complexity 16 exceeds 15: function'));
 }
 const file=`src/lua/${leaf}.lua`;
 assert(reviewModuleSize({[file]:Array(1001).fill('-- line').join('\n')}).errors.some(e=>e.file===file));
 assert(reviewModuleSize({}).errors.some(e=>e.file===file));
});
