import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdirSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {analyzeSources} from '../scripts/check-architecture.mjs';
import {discoverSources,measureSources,dependencyCycles} from '../scripts/lua-quality-metrics.mjs';
import luaparse from 'luaparse';
import {runStatic,reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {watcherExecutionPath as path,watcherExecutionBefore,preWatcherExecutionSource,watcherExecutionReader} from './helpers/watcher-final-execution-source-inverse.mjs';
import {watcherExecutionVm,comparableWatcherError} from './helpers/watcher-final-execution-vm.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const seenEffects=new Set();
const fixtures=['watcher_final_damage_generation','watcher_final_wish_lesson','watcher_final_foreign',
 'watcher_final_draw_powers','watcher_final_pile_choices','watcher_final_turn',
 'watcher_final_block_retention','watcher_early_turn_queue_order','watcher_final_execution_boundaries','watcher_final_first','watcher_early_turn_autoplay',
 'watcher_master_reality_generation','watcher_omniscience_energy_snapshot','watcher-final-execution-edges'];
test('the complete Watcher source epoch authenticates a fresh owner and never accepts source drift',()=>{
 const current=read(path);assert.equal(preWatcherExecutionSource(path,current),watcherExecutionBefore);
 assert.equal(preWatcherExecutionSource(path,current.replaceAll('\n','\r\n')),watcherExecutionBefore);
 let source=current,reads=0;const raw=p=>{assert.equal(p,path);reads++;return source;};
 const reader=watcherExecutionReader(watcherExecutionReader(raw));
 assert.equal(preWatcherExecutionSource(path,current,{readSource:reader}),watcherExecutionBefore);assert.equal(reads,1);
 for(source of [current+'\n',watcherExecutionBefore,null,undefined])assert.throws(()=>preWatcherExecutionSource(path,current,{readSource:reader}),/linked owner/);
 source=current;assert.equal(reader(path),watcherExecutionBefore);
 assert.throws(()=>preWatcherExecutionSource(path,current,{readSource(){throw Error('sentinel');}}),/linked owner missing/);
 assert.throws(()=>preWatcherExecutionSource(path,current,{readSource:null}),/linked reader/);
 reads=0;for(const unknown of [null,undefined,'',current+'\n',watcherExecutionBefore])assert.equal(preWatcherExecutionSource(path,unknown,{readSource:raw}),unknown);
 assert.equal(preWatcherExecutionSource('foreign/'+path,current,{readSource:raw}),current);assert.equal(reads,0);
});
test('each effect executor, dispatcher and nested callback remains under the same CC15 gate',()=>{
 const source=read(path),names=[...source.matchAll(/^function (effectHandlers\.[^(]+|M\.execute)\(/gm)].map(m=>m[1]);
 assert.equal(names.length,17);
 for(const name of names){
  const code=`function ${name}()return function()end end`;
  const row=(column,subject,value)=>({file:path,line:1,column,code:'W561',message:`cyclomatic complexity of ${subject} is too high (${value} > 0)`});
  const errors=reviewResponsibilityComplexity([row(1,'main chunk',1),row(1,`function '${name}'`,16),row(code.indexOf('function()')+1,'function',16)],{[path]:code}).errors;
  assert(errors.some(e=>e.file===path&&e.message===`Responsibility complexity 16 exceeds 15: function '${name}'`),name);
  assert(errors.some(e=>e.file===path&&e.message==='Responsibility complexity 16 exceeds 15: function'),name+' nested');
 }
 const unknown=reviewResponsibilityComplexity([],{[path]:'function M.execute()end'}).errors;
 assert(unknown.some(e=>e.message==="Required responsibility entry missing or duplicated: function 'M.execute'"));
});
for(const fixture of fixtures)test(`${fixture}: independent old/current VMs preserve complete state, aliases, RNG, events and returns`,()=>{
 const file=(fixture==='watcher-final-execution-edges'?'tests/helpers/':'tests/lua/')+fixture+'.lua',before=watcherExecutionVm('before',file),after=watcherExecutionVm('after',file);
 assert.equal(before.status,0,before.error);assert.equal(after.status,0,after.error);
 assert(before.checkpoints.length>0);assert.deepEqual(after.logs,before.logs);
 assert.deepEqual(after.checkpoints,before.checkpoints);assert.equal(after.bytes,before.bytes);
 for(const checkpoint of after.checkpoints)if(checkpoint.label.startsWith('effect:'))seenEffects.add(checkpoint.label.slice(7));
 mkdirSync('build/watcher-execution',{recursive:true});
 writeFileSync('build/watcher-execution/'+fixture+'.json',JSON.stringify({fixture,checkpoints:after.checkpoints,bytesPerSide:after.bytes,logs:after.logs},null,2)+'\n');
});
test('the complete old/new graph cases actually execute every supported Watcher operation',()=>{
 const ast=luaparse.parse(read(path),{luaVersion:'5.3'});
 const declaration=ast.body.find(n=>n.type==='AssignmentStatement'&&n.variables[0]?.base?.name==='M'&&n.variables[0]?.identifier?.name==='ops');
 const operations=declaration.init[0].fields.map(field=>field.key.name).sort();
 assert.equal(operations.length,18);assert.deepEqual([...seenEffects].sort(),[...operations,'unsupported'].sort());
});
for(const [label,from,to,fixture,expected]of [
 ['legacy normal upgrade eligibility','not enemy.minion','enemy.minion','watcher_final_wish_lesson','false ~= true'],
 ['legacy residual energy','state.energy=0','state.energy=1','watcher_final_damage_generation','1 ~= 0'],
 ['minion reward','and not enemy.minion','and true','watcher_final_wish_lesson','true ~= false'],
 ['X payment','if not context.freeToPlayOnce then state.energy=0 end','if false then state.energy=0 end','watcher_final_damage_generation','2 ~= 0'],
 ['damage continuation','remaining=effect.remaining-1','remaining=0','watcher_final_damage_generation','982 ~= 973'],
 ['drawn-card exhaust',"top(state,queue,{op='exhaustHand',uid=effect.uid})","do end",'watcher_final_draw_powers','0 ~= 1'],
])test(`real parsed ${label} regression is caught by existing behavior assertions`,()=>{
 const source=read(path);assert.equal(source.split(from).length,2,'one real mutation site');
 const mutation=source.replace(from,to);luaparse.parse(mutation,{luaVersion:'5.3'});
 const result=watcherExecutionVm('after','tests/lua/'+fixture+'.lua',{mutation});
 assert.equal(result.status,2,'semantic mutant must fail at the behavior assertion');
 assert.equal(result.error,`tests/lua/${fixture}.lua:3: ${expected}`);
});
test('current raw source composes into the unchanged 391 proof and rejects every linked owner drift',async()=>{
 const {preRelicQuerySource,relicQuerySourceProof}=await import('./helpers/relic-query-source-inverse.mjs');
 const current=read(path),expected=relicQuerySourceProof.files[path].beforeSource;
 assert.equal(preRelicQuerySource(path,current),expected);
 for(const linked of Object.keys(relicQuerySourceProof.files)){
  const seen=[];let mode='good';const readSource=p=>{seen.push(p);return read(p)+(mode==='drift'&&p===linked?'\n':'');};
  assert.equal(preRelicQuerySource(path,current,{readSource}),expected);
  assert(Object.keys(relicQuerySourceProof.files).every(p=>seen.includes(p)),'every original linked owner is freshly authenticated');
  mode='drift';assert.throws(()=>preRelicQuerySource(path,current,{readSource}),/linked owner/);
  mode='good';assert.equal(preRelicQuerySource(path,current,{readSource}),expected);
 }
 let reads=0;
 assert.throws(()=>preRelicQuerySource(path,current,{readSource:p=>read(p)+(p===path&&++reads>1?'\n':'')}),/linked owner/,'later same-call reads cannot reuse the initial matching Watcher bytes');
});

test('actual require edges and SCC membership are unchanged by card-local responsibility extraction',()=>{
 const sources=Object.fromEntries(Object.entries(discoverSources()).map(([p,s])=>[p.slice(8,-4).replaceAll('/','.'),s]));
 const policy=JSON.parse(readFileSync('config/architecture.json','utf8'));
 const before=analyzeSources({...sources,abyss_watcher_final_cards:watcherExecutionBefore},policy),after=analyzeSources(sources,policy);
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
  writeFileSync(join(directory,'watcher-final-execution-before.lua'),watcherExecutionBefore.replaceAll('\n','\r\n'));
  const crlf=await import(pathToFileURL(join(directory,helper)).href);
  assert.equal(crlf.watcherExecutionBefore,watcherExecutionBefore);
  const current=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  assert.equal(crlf.preWatcherExecutionSource(path,current,{readSource:()=>current}),watcherExecutionBefore);
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('real full-source measurements cover all extracted Watcher effect responsibilities under CC15',()=>{
 const sources=discoverSources(),run=runStatic(['--max-cyclomatic-complexity','0','--only','561']);
 const measured=measureSources(sources,run.diagnostics);assert.deepEqual(measured.errors,[]);
 const functions=measured.modules.find(m=>m.file===path).functions;
 const selected=functions.filter(f=>f.name==='M.execute'||f.name.startsWith('effectHandlers.'));
 assert.equal(selected.length,17,'all effect responsibilities are measured');
 assert(selected.every(f=>f.complexity<=15),JSON.stringify(selected.filter(f=>f.complexity>15)));
 const gate=reviewResponsibilityComplexity(run.diagnostics,sources);
 assert.deepEqual(gate.errors,[]);
});
test('error comparison recognizes only verified exact locations and unchanged bodies',()=>{
 const prefix='src/lua/abyss_watcher_final_cards.lua:';
 assert.equal(comparableWatcherError(prefix+'376: unsupported Watcher final effect: unsupported'),prefix+'340: unsupported Watcher final effect: unsupported');
 for(const value of [prefix+'377: unsupported Watcher final effect: unsupported',prefix+'376: changed body','foreign.lua:376: unsupported Watcher final effect: unsupported'])assert.equal(comparableWatcherError(value),value);
 const sentinel={kind:'failure'};assert.equal(comparableWatcherError(sentinel),sentinel);
});
