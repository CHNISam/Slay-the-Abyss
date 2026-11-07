import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdirSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import luaparse from 'luaparse';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {preWatcherExecutionSource,watcherExecutionReader} from './helpers/watcher-final-execution-source-inverse.mjs';
import {watcherBefore,watcherVm} from './helpers/watcher-final-execution-vm.mjs';
import {runStatic,reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {analyzeSources} from '../scripts/check-architecture.mjs';
import {discoverSources,measureSources,dependencyCycles} from '../scripts/lua-quality-metrics.mjs';
const file='src/lua/abyss_watcher_final_cards.lua';
const fixtures=['watcher_final_first','watcher_final_turn','watcher_final_damage_generation',
 'watcher_final_draw_powers','watcher_final_wish_lesson','watcher_final_foreign',
 'watcher_final_pile_choices','watcher_early_turn_autoplay','watcher_master_reality_generation',
 'watcher_omniscience_energy_snapshot','watcher-final-execution-edges'];
const operations=new Set();
for(const fixture of fixtures)test(`${fixture}: complete old/current state, aliases, returns, events and RNG agree`,()=>{
 const path=(fixture==='watcher-final-execution-edges'?'tests/helpers/':'tests/lua/')+fixture+'.lua',before=watcherVm('before',path),after=watcherVm('after',path);
 assert.equal(before.status,0,before.error);assert.equal(after.status,0,after.error);
 assert(before.checkpoints.length>0);assert.deepEqual(after,before);
 after.operations.forEach(op=>operations.add(op));
 mkdirSync('build/watcher-final-execution',{recursive:true});
 writeFileSync('build/watcher-final-execution/'+fixture+'.json',JSON.stringify(after,null,2)+'\n');
});
test('all 18 dispatch operations are exercised against the complete original module',()=>{
 assert.deepEqual([...operations].sort(),['gainWatcherFinalPower',...['EndTurnEarly','SkipEnemiesTurn','Establishment','Omega',
 'Generate','Wish','ForeignInfluence','LessonLearned','Meditate','Omniscience','DeusExMachina','SpiritShield',
 'ConjureBlade','Judgment','ExpungerHits','Ragnarok','DamageHit'].map(n=>'watcherFinal'+n),'unsupported'].sort());
});
test('the dispatcher and every extracted responsibility have a fixed CC15 limit',()=>{
 const sources=discoverSources(),run=runStatic(['--max-cyclomatic-complexity','0','--only','561']);
 const measured=measureSources(sources,run.diagnostics);assert.deepEqual(measured.errors,[]);
 const functions=measured.modules.find(m=>m.file===file).functions;
 const selected=functions.filter(f=>f.name==='M.execute'||f.name.startsWith('executeHandlers.')||f.name==='upgradeLessonCard');
 assert(selected.length>=18,'all effect responsibilities must be measured');
 assert(selected.every(f=>f.complexity<=15),JSON.stringify(selected.filter(f=>f.complexity>15)));
 for(const fn of selected){
  const value=`local function ${fn.name.replaceAll('.','_')}()return function()end end`;
  // The real named root and a nested callback must both remain hard-gated.
  const syntax=fn.name==='M.execute'||fn.name.startsWith('executeHandlers.')?`function ${fn.name}()return function()end end`:value;
  const at=syntax.indexOf('function')+1,nested=syntax.lastIndexOf('function')+1;
  const rows=[{file,line:1,column:at,code:'W561',message:`cyclomatic complexity of function '${fn.name}' is too high (16 > 0)`},
   {file,line:1,column:nested,code:'W561',message:'cyclomatic complexity of function is too high (16 > 0)'}];
  const errors=reviewResponsibilityComplexity(rows,{[file]:syntax}).errors;
  assert(errors.some(e=>e.message===`Responsibility complexity 16 exceeds 15: function '${fn.name}'`),fn.name);
  assert(errors.some(e=>e.message==='Responsibility complexity 16 exceeds 15: function'),fn.name+' callback');
 }
});
for(const [name,from,to,fixture,expected] of [
 ['queued hit count','remaining=effect.remaining-1','remaining=0','watcher_final_damage_generation','982 ~= 973'],
 ['permanent upgrade eligibility','not enemy.minion','enemy.minion','watcher_final_wish_lesson','false ~= true'],
 ['energy commit','state.energy=0','state.energy=1','watcher_final_damage_generation','1 ~= 0'],
])test(`${name}: parsed real behavioral mutations fail`,()=>{
 const source=readFileSync(file,'utf8');assert.equal(source.split(from).length,2);
 const mutation=source.replace(from,to);luaparse.parse(mutation,{luaVersion:'5.3'});
 const result=watcherVm('after','tests/lua/'+fixture+'.lua',{mutation});
 assert.equal(result.status,2);assert.equal(result.error,`tests/lua/${fixture}.lua:3: ${expected}`);
});

test('the exact source epoch freshly binds the complete current owner and leaves foreign inputs alone',()=>{
 const current=readFileSync(file,'utf8').replaceAll('\r\n','\n');assert.equal(preWatcherExecutionSource(file,current),watcherBefore);
 assert.equal(preWatcherExecutionSource(file,current.replaceAll('\n','\r\n')),watcherBefore);
 let value=current,reads=0;const raw=p=>{assert.equal(p,file);reads++;if(value instanceof Error)throw value;return value;};
 const reader=watcherExecutionReader(watcherExecutionReader(raw));
 for(const bad of [current+'\n',watcherBefore,undefined,null,new Error('reader sentinel')]){
  value=current;assert.equal(preWatcherExecutionSource(file,current,{readSource:reader}),watcherBefore);
  value=bad;assert.throws(()=>preWatcherExecutionSource(file,current,{readSource:reader}),/linked owner/);
 }
 reads=0;
 for(const input of [watcherBefore,current+'\n',null,'',undefined])
  assert.equal(preWatcherExecutionSource(file,input,{readSource:raw}),input);
 assert.equal(reads,0);
});

test('actual require edges and SCC membership are unchanged by card-local responsibility extraction',()=>{
 const sources=Object.fromEntries(Object.entries(discoverSources()).map(([p,s])=>[p.slice(8,-4).replaceAll('/','.'),s]));
 const policy=JSON.parse(readFileSync('config/architecture.json','utf8'));
 const before=analyzeSources({...sources,abyss_watcher_final_cards:watcherBefore},policy),after=analyzeSources(sources,policy);
 assert.deepEqual(before.errors,[]);assert.deepEqual(after.errors,[]);
 const edges=graph=>graph.edges.map(({from,to,reviewedDeferred})=>JSON.stringify({from,to,reviewedDeferred})).sort();
 assert.deepEqual(edges(after),edges(before));
 const cycles=graph=>dependencyCycles(graph.nodes,graph.edges).map(c=>c.members);
 assert.deepEqual(cycles(after),cycles(before));
});

test('the frozen Git source keeps its LF identity when checked out with CRLF',async()=>{
 const directory=mkdtempSync(join(tmpdir(),'watcher-crlf-'));
 try{
  const helper='watcher-final-execution-source-inverse.mjs';
  writeFileSync(join(directory,helper),readFileSync('tests/helpers/'+helper,'utf8').replaceAll('\r\n','\n').replaceAll('\n','\r\n'));
  writeFileSync(join(directory,'watcher-final-execution-before.lua'),watcherBefore.replaceAll('\n','\r\n'));
  const crlf=await import(pathToFileURL(join(directory,helper)).href);
  assert.equal(crlf.watcherBefore,watcherBefore);
  const current=readFileSync(file,'utf8').replaceAll('\r\n','\n');
  assert.equal(crlf.preWatcherExecutionSource(file,current,{readSource:()=>current}),watcherBefore);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
