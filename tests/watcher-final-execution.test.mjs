import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import luaparse from 'luaparse';
import {reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {watcherExecutionPath as path,watcherExecutionBefore,preWatcherExecutionSource,watcherExecutionReader} from './helpers/watcher-final-execution-source-inverse.mjs';
import {watcherExecutionVm} from './helpers/watcher-final-execution-vm.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const seenEffects=new Set();
const fixtures=['watcher_final_damage_generation','watcher_final_wish_lesson','watcher_final_foreign',
 'watcher_final_draw_powers','watcher_final_pile_choices','watcher_final_turn',
 'watcher_final_block_retention','watcher_early_turn_queue_order','watcher_final_execution_boundaries'];
test('the complete Watcher source epoch authenticates a fresh owner and never accepts source drift',()=>{
 const current=read(path);assert.equal(preWatcherExecutionSource(path,current),watcherExecutionBefore);
 assert.equal(preWatcherExecutionSource(path,current.replaceAll('\n','\r\n')),watcherExecutionBefore);
 let source=current,reads=0;const raw=()=>{reads++;return source;};
 const reader=watcherExecutionReader(watcherExecutionReader(raw));
 assert.equal(preWatcherExecutionSource(path,current,{readSource:reader}),watcherExecutionBefore);assert.equal(reads,1);
 for(source of [current+'\n',watcherExecutionBefore,null,undefined])assert.throws(()=>preWatcherExecutionSource(path,current,{readSource:reader}),/linked owner/);
 source=current;assert.equal(reader(path),watcherExecutionBefore);
 assert.throws(()=>preWatcherExecutionSource(path,current,{readSource(){throw Error('sentinel');}}),/linked owner missing/);
 assert.throws(()=>preWatcherExecutionSource(path,current,{readSource:null}),/linked reader/);
 reads=0;for(const unknown of [null,'',current+'\n',watcherExecutionBefore])assert.equal(preWatcherExecutionSource(path,unknown,{readSource:raw}),unknown);
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
 const file='tests/lua/'+fixture+'.lua',before=watcherExecutionVm('before',file),after=watcherExecutionVm('after',file);
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
 assert.equal(operations.length,18);assert.deepEqual([...seenEffects].sort(),operations);
});
for(const [label,from,to,fixture,marker]of [
 ['minion reward','and not enemy.minion','and true','watcher_final_wish_lesson','false'],
 ['X payment','if not context.freeToPlayOnce then state.energy=0 end','if false then state.energy=0 end','watcher_final_damage_generation','~='],
 ['damage continuation','remaining=effect.remaining-1','remaining=0','watcher_final_damage_generation','~='],
 ['drawn-card exhaust',"top(state,queue,{op='exhaustHand',uid=effect.uid})","do end",'watcher_final_draw_powers','~='],
])test(`real parsed ${label} regression is caught by existing behavior assertions`,()=>{
 const source=read(path);assert.equal(source.split(from).length,2,'one real mutation site');
 const mutation=source.replace(from,to);luaparse.parse(mutation,{luaVersion:'5.3'});
 const result=watcherExecutionVm('after','tests/lua/'+fixture+'.lua',{mutation});
 assert.notEqual(result.status,0,'semantic mutant must fail');assert.match(result.error,new RegExp(marker));
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
