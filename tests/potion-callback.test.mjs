import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import luaparse from 'luaparse';
import {discoverSources,dependencyCycles} from '../scripts/lua-quality-metrics.mjs';
import {analyzeSources} from '../scripts/check-architecture.mjs';
import {reviewResponsibilityComplexity,reviewModuleSize} from '../scripts/check-lua-static.mjs';
import {runPotion} from './helpers/potion-callback-vm.mjs';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const fixture='tests/lua/potion_callback_contract.lua';
const leaf='src/lua/abyss_relic_potion_hooks.lua';
test('potion callback and Candidate cannot transitively import Session responsibilities, including deferred imports',()=>{
 const sources=Object.fromEntries(Object.entries(discoverSources()).map(([path,source])=>[path.slice(8,-4),source]));
 const policy=JSON.parse(read('config/architecture.json'));
 const boundary=policy.dependencyBoundaries.find(row=>row.id==='potion-callback-session-independence');
 assert(boundary&&boundary.forbiddenTargets.length>0,'actual complete callback dependency boundary');
 const graph=analyzeSources(sources,policy);assert.deepEqual(graph.errors,[]);
 const closure=(graph,root)=>{
  const seen=new Set(),pending=[root];
  while(pending.length){const node=pending.pop();if(seen.has(node))continue;seen.add(node);for(const edge of graph.edges)if(edge.from===node)pending.push(edge.to);}
  return seen;
 };
 for(const root of ['abyss_relic_potion_hooks','abyss_run_potion_candidate']){
  const reachable=closure(graph,root);
  for(const forbidden of boundary.forbiddenTargets)assert(!reachable.has(forbidden),`${root} cannot reach ${forbidden}`);
  assert(!dependencyCycles(graph.nodes,graph.edges).some(cycle=>cycle.members.includes(root)));
  for(const imported of ['abyss_relic_hooks','abyss_run'])for(const prefix of [`local bad=require('${imported}')\n`,`local function bad()return require('${imported}')end\n`]){
   const source=prefix+sources[root];luaparse.parse(source,{luaVersion:'5.3'});
   const mutant=analyzeSources({...sources,[root]:source},policy);
   assert(closure(mutant,root).has(imported));
   assert(mutant.errors.some(row=>row.message.includes('potion-callback-session-independence')),'parsed direct/deferred Session edge violates actual architecture rule');
  }
 }
});
test('the frozen handwritten VM refuses a current-only module instead of falling back through package.path',()=>{
 const result=runPotion('before',null,{prelude:"require('abyss_relic_potion_hooks')"});
 assert.notEqual(result.status,0);assert.match(result.error,/POTION_CORPUS_UNKNOWN abyss_relic_potion_hooks/);
});
test('potion callbacks preserve complete frozen/current graph streams, errors, RNGs, queues, identities and transaction ownership',{concurrency:false},()=>{
 const before=runPotion('before',fixture),after=runPotion('after',fixture);
 assert.equal(before.status,0,before.error);assert.equal(after.status,0,after.error);
 assert(before.graphs.length>0&&after.graphs.length>0);
 assert.deepEqual(after.logs,before.logs);assert.deepEqual(after.generated,before.generated);
 assert.deepEqual(after.graphs,before.graphs);assert.equal(after.bytes,before.bytes);
 mkdirSync('build/potion-callback',{recursive:true});
 writeFileSync('build/potion-callback/equivalence.json',JSON.stringify({fixture,baseline:'2ad07111e3d5b5cb52b4229860b3b780941e29a9',handwrittenBefore:before.handwritten,handwrittenAfter:after.handwritten,generated:after.generated,checkpoints:after.graphs,bytesPerSide:after.bytes,definitions:after.definitionCount,beforeStream:before.traceFile,afterStream:after.traceFile,stableFullFieldGraphStream:true,diagnosticLocationMappings:[]},null,2)+'\n');
});
for(const root of ['abyss_relic_potion_hooks','abyss_run_potion_candidate','abyss_relic_hooks'])test(`${root}: cold loading and the fixed callback slot preserve both replacement directions`,{concurrency:false},()=>{
 const prelude=`
 require('${root}')
 local P=require('abyss_relic_potion_hooks')
 ${root==='abyss_relic_hooks'?'':"assert(not package.loaded.abyss_relic_hooks and not package.loaded.abyss_run and not package.loaded.abyss_run_settlement,'cold callback and Candidate exclude Session/Run')"}
 local original=P.onUsePotion
 local cold={hp=20,maxHp=80,relics={'toy_ornithopter','magic_flower'}}
 P.onUsePotion(cold);assert(cold.hp==25)
 ${root==='abyss_relic_hooks'?'':"assert(not package.loaded.abyss_relic_hooks and not package.loaded.abyss_run,'cold real callback does not load Session/Run')"}
 local early=function(...)return 'early',table.pack(...)end
 P.onUsePotion=early
 local H=require('abyss_relic_hooks');assert(H.onUsePotion==early,'replacement before Session load is retained')
 assert(rawget(H,'onUsePotion')==nil,'Session has no shadow callback value')
 local marker={};local callable=setmetatable({marker=marker},{__call=function(self,...)return self.marker,nil,table.pack(...)end})
 H.onUsePotion=callable;assert(P.onUsePotion==callable and H.onUsePotion==callable)
 local result=table.pack(P.onUsePotion(cold,false));assert(result.n==3 and result[1]==marker and result[2]==nil and result[3].n==2 and result[3][1]==cold and result[3][2]==false)
 P.onUsePotion=false;assert(H.onUsePotion==false)
 assert(not pcall(function()H.onUsePotion(cold)end),'false callback slot stays noncallable')
 H.onUsePotion=nil;assert(P.onUsePotion==nil and H.onUsePotion==nil)
 assert(not pcall(function()P.onUsePotion(cold)end),'nil callback slot stays absent')
 P.onUsePotion=early;assert(H.onUsePotion==early)
 H.onUsePotion=false;assert(P.onUsePotion==false)
 P.onUsePotion=nil;assert(H.onUsePotion==nil)
 H.onUsePotion=original;assert(P.onUsePotion==original and rawget(H,'onUsePotion')==nil)
 H.potionUnrelated=marker;assert(rawget(H,'potionUnrelated')==marker and P.potionUnrelated==nil);H.potionUnrelated=nil
 local saved=H.onUsePotion;P.onUsePotion=callable;saved(cold);assert(cold.hp==30,'saved callback remains callable after replacement');H.onUsePotion=original
 POTION_GRAPH_WRITE({cold=cold,returned=result,marker=marker,callable=callable,leaf=P,session=H,saved=saved},'cold live callback slots and complete owners',true)
 print('POTION_CALLBACK_COLD_PASS')
 `;
 const result=runPotion('after',null,{prelude});assert.equal(result.status,0,result.error);
 assert.match(result.logs.join('\n'),/POTION_CALLBACK_COLD_PASS/);
});
for(const [label,from,to,marker]of [
 ['queued Toy amount','value=5,','value=4,',/Toy queues raw five/],
 ['cached ownership predicate',"Queries.owns(run,'toy_ornithopter')","cachedOwns(run,'toy_ornithopter')",/saved callback reads dynamic Hooks\.owns/],
 ['cached Actor predicate','A.isActive(combat.player)','cachedActive(combat.player)',/saved callback reads dynamic Actor predicate/],
])test(`parsed ${label} semantic regression fails its actual Lua contract assertion`,{concurrency:false},()=>{
 let source=read(leaf);assert.equal(source.split(from).length,2,'one exact semantic mutation target');source=source.replace(from,to);
 if(label==='cached ownership predicate')source=source.replace('local M={}','local cachedOwns=Queries.owns\nlocal M={}');
 if(label==='cached Actor predicate')source=source.replace('local M={}','local cachedActive=A.isActive\nlocal M={}');
 luaparse.parse(source,{luaVersion:'5.3'});
 const result=runPotion('after',fixture,{mutation:{name:'abyss_relic_potion_hooks',source}});
 assert.notEqual(result.status,0);assert.match(result.error,marker);
});
test('complete potion callback responsibility rejects new nested CC16 functions and files over 1000 lines',()=>{
 const source='local function later() return function(value)\n'+Array.from({length:15},(_,i)=>`if value==${i} then value=value+1 end`).join('\n')+'\nend end\n';
 luaparse.parse(source,{luaVersion:'5.3'});
 const nestedColumn=source.indexOf('function(value)')+1;
 const diagnostic={file:leaf,line:1,column:nestedColumn,code:'W561',message:'cyclomatic complexity of function is too high (16 > 0)'};
 const row=(column,subject)=>({file:leaf,line:1,column,code:'W561',message:`cyclomatic complexity of ${subject} is too high (1 > 0)`});
 const complexity=reviewResponsibilityComplexity([row(1,'main chunk'),row(7,"function 'later'"),diagnostic],{[leaf]:source});
 assert.deepEqual(complexity.errors.filter(row=>row.file===leaf).map(row=>row.message),['Responsibility complexity 16 exceeds 15: function']);
 assert.deepEqual(reviewModuleSize({[leaf]:read(leaf)}).errors.filter(row=>row.file===leaf),[]);
 const oversized=read(leaf)+'\n'.repeat(1001);luaparse.parse(oversized,{luaVersion:'5.3'});
 const size=reviewModuleSize({[leaf]:oversized});
 assert(size.errors.some(row=>row.file===leaf&&/1000/.test(row.message)));
});
