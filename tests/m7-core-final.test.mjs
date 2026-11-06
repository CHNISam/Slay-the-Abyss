import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import luaparse from 'luaparse';
import {analyzeSources} from '../scripts/check-architecture.mjs';
import {discoverSources,dependencyCycles} from '../scripts/lua-quality-metrics.mjs';
import {reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {m7FinalBefore,preM7FinalSource} from './helpers/m7-core-final-source-inverse.mjs';
import {finalCoreVm} from './helpers/m7-core-final-vm.mjs';
const source=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const v4='src/lua/abyss_original_v4.lua',combat='src/lua/abyss_combat.lua';
test('the final source epoch freshly authenticates all three complete Git sources and rejects partial owners',()=>{
 for(const name of Object.keys(m7FinalBefore.files)){
  const path='src/lua/'+name+'.lua',current=source(path);
  assert.equal(preM7FinalSource(path,current),m7FinalBefore.files[name].source);
  for(const missing of Object.keys(m7FinalBefore.files))for(const drift of ['foreign','missing','null','throw'])assert.throws(()=>preM7FinalSource(path,current,{readSource:p=>{
   if(p!=='src/lua/'+missing+'.lua')return source(p);
   if(drift==='throw')throw Error('reader sentinel');
   return drift==='foreign'?source(p)+'\n':drift==='null'?null:undefined;
  }}),/linked owner/);
  let reads=0;const readSource=()=>{reads++;throw Error('unexpected read');};
  for(const value of [m7FinalBefore.files[name].source,current+'\n',null,''])assert.equal(preM7FinalSource(path,value,{readSource}),value);
  assert.equal(reads,0);
 }
});
test('Codex offer planning cannot import the Combat executor even with a deferred edge',()=>{
 const sources=Object.fromEntries(Object.entries(discoverSources()).map(([path,s])=>[path.slice('src/lua/'.length,-4).replaceAll('/','.'),s]));
 const policy=JSON.parse(source('config/architecture.json'));
 const graph=analyzeSources(sources,policy);
 assert.deepEqual(graph.errors,[]);
 const checkBoundary=g=>assert.deepEqual([...new Set(g.edges.filter(e=>e.from==='abyss_codex_relic').map(e=>e.to))],['abyss_events']);
 checkBoundary(graph);
 assert(!dependencyCycles(graph.nodes,graph.edges).some(c=>c.members.includes('abyss_codex_relic')));
 for(const injected of ["local X=require('abyss_card_actions')\n","local function X()return require('abyss_card_actions')end\n"]){
  const changed={...sources,abyss_codex_relic:injected+sources.abyss_codex_relic};
  const negative=analyzeSources(changed,policy);
  assert.throws(()=>checkBoundary(negative),/abyss_card_actions/);
 }
});
test('V4 entry/helper/nested functions and Codex commit enforce the same CC15 budget',()=>{
 for(const [file,names]of [[v4,['validateEffects','denseEffects','validAmount','validTargetFields','apply','applyDamage','applyBasic','applyNext','applyHT','applyGuard','applyAR','applyFR','applyRD','executeRoot','infuseRoot','rootBonus','settleRaiden']],[combat,['chooseCodex']]]){
  for(const name of names){
   const value=`local function ${name}()return function()end end`;
   const rows=[{file,line:1,column:1,code:'W561',message:'cyclomatic complexity of main chunk is too high (1 > 0)'},
    {file,line:1,column:7,code:'W561',message:`cyclomatic complexity of function '${name}' is too high (16 > 0)`},
    {file,line:1,column:value.indexOf('function()')+1,code:'W561',message:'cyclomatic complexity of function is too high (16 > 0)'}];
   const errors=reviewResponsibilityComplexity(rows,{[file]:value}).errors;
   assert(errors.some(e=>e.file===file&&e.message===`Responsibility complexity 16 exceeds 15: function '${name}'`),name);
   assert(errors.some(e=>e.file===file&&e.message==='Responsibility complexity 16 exceeds 15: function'),name+' nested');
  }
 }
});
for(const fixture of ['original_v4_contract','act2_event_relic_codex'])test(`${fixture}: independent old/current VMs preserve full command state, aliases, RNG, events and failure returns`,()=>{
 const path='tests/lua/'+fixture+'.lua',before=finalCoreVm('before',path),after=finalCoreVm('after',path);
 assert.equal(before.status,0,before.error);assert.equal(after.status,0,after.error);
 assert(before.checkpoints.length>0);assert.deepEqual(after.logs,before.logs);
 assert.deepEqual(after.checkpoints,before.checkpoints);assert.equal(after.bytes,before.bytes);
 mkdirSync('build/m7-core-final',{recursive:true});
 writeFileSync('build/m7-core-final/'+fixture+'-equivalence.json',JSON.stringify({fixture,checkpoints:after.checkpoints,bytesPerSide:after.bytes,logs:after.logs},null,2)+'\n');
});
for(const [label,name,from,to,fixture]of [
 ['payment','abyss_original_v4','pay(combat,state,paid)','pay(combat,state,0)','original_v4_contract'],
 ['snapshot','abyss_original_v4','snapshot=M.snapshot(state,item.target)','snapshot={}','original_v4_contract'],
 ['Codex insertion RNG','abyss_combat','M.cardRandom(state,#state.draw)','1','act2_event_relic_codex'],
])test(`a real parsed ${label} regression is caught by the original behavior assertions`,()=>{
 const original=source('src/lua/'+name+'.lua');assert.equal(original.split(from).length,2);
 const changed=original.replace(from,to);luaparse.parse(changed,{luaVersion:'5.3'});
 const result=finalCoreVm('after','tests/lua/'+fixture+'.lua',{mutation:{name,source:changed}});
 assert.notEqual(result.status,0,'semantic mutation must fail a behavior assertion');
 assert(result.error);
});
