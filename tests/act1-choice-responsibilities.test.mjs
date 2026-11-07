import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runStatic,reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';
const file='src/lua/abyss_act1_events.lua';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const handlers=['sssserpent','big_fish','accursed_blacksmith','scrap_ooze','transmogrifier','bonfire'];
test('Act1 local choices have a CC15 dispatcher and event-owned handlers',()=>{
 const sources=discoverSources();const rows=runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics;
 const measured=measureSources(sources,rows);assert.deepEqual(measured.errors,[]);
 const functions=measured.modules.find(m=>m.file===file).functions;
 assert.equal(functions.find(f=>f.name==='M.choose').complexity<=15,true,'M.choose must remain at CC15 or less');
 for(const name of handlers)assert(functions.some(f=>f.name==='choiceHandlers.'+name),'event-owned handler '+name);
 const report=reviewResponsibilityComplexity(rows,sources);assert.deepEqual(report.errors,[]);
});

import {mkdtempSync,rmSync,mkdirSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {act1ChoiceBefore as before,preAct1ChoiceSource,act1ChoiceReader} from './helpers/act1-choice-source-inverse.mjs';
function replay(source,fixture,group){
 mkdirSync('build/act1-choice',{recursive:true});
 const dir=mkdtempSync('build/act1-choice/vm-');
 try{
  const output=join(dir,'graph.jsonl');
  const result=spawnSync(process.execPath,['--max-old-space-size=768','tests/helpers/act1-choice-vm.mjs'],{
   input:JSON.stringify({source,fixture,output,group}),encoding:'utf8',timeout:30000,maxBuffer:1024**2,
  });
  assert.equal(result.error,undefined,result.error?.message);assert.equal(result.status,0,result.stderr);
  return {...JSON.parse(result.stdout),graph:readFileSync(output)};
 }finally{rmSync(dir,{recursive:true,force:true});}
}
for(const fixture of ['tests/lua/act1_event_content.lua','tests/lua/scrap_ooze.lua','tests/lua/transmogrifier.lua'])test(`${fixture}: old/current VMs retain complete graphs, aliases, RNG, returns and assertions`,t=>{
 const old=replay(before,fixture),current=replay(read(file),fixture);
 assert.equal(old.status,0,old.error);assert.equal(current.status,0,current.error);
 assert(current.checkpoints>0);assert.equal(current.checkpoints,old.checkpoints);
 assert.deepEqual(current.logs,old.logs);assert(current.graph.equals(old.graph),'complete graph bytes differ');
 const proof={fixture,checkpoints:current.checkpoints,bytesPerSide:current.graph.length,sha256:createHash('sha256').update(current.graph).digest('hex'),logs:current.logs};
 writeFileSync('build/act1-choice/'+fixture.split('/').at(-1)+'.json',JSON.stringify(proof,null,2)+'\n');t.diagnostic(JSON.stringify(proof));
});
test('Act1 source inverse authenticates fresh current bytes with exact LF and Git identity',()=>{
 const current=read(file);let live=current,reads=0;const raw=p=>{assert.equal(p,file);reads++;return live;};
 const reader=act1ChoiceReader(raw);assert.equal(act1ChoiceReader(reader),reader);
 assert.equal(preAct1ChoiceSource(file,current,{readSource:reader}),before);assert.equal(reads,1);
 assert.equal(preAct1ChoiceSource(file,current.replaceAll('\n','\r\n'),{readSource:raw}),before);
 for(live of [current+'\n',before,null,undefined])assert.throws(()=>preAct1ChoiceSource(file,current,{readSource:reader}),/linked owner/);
 assert.throws(()=>preAct1ChoiceSource(file,current,{readSource(){throw Error('missing');}}),/linked owner missing/);
 assert.throws(()=>preAct1ChoiceSource(file,current,{readSource:null}),/linked reader/);
 reads=0;for(const unknown of [null,undefined,'',current+'\n',before])assert.equal(preAct1ChoiceSource(file,unknown,{readSource:raw}),unknown);
 assert.equal(preAct1ChoiceSource('foreign/'+file,current,{readSource:raw}),current);assert.equal(reads,0);
});

import {analyzeSources} from '../scripts/check-architecture.mjs';
import {dependencyCycles} from '../scripts/lua-quality-metrics.mjs';
import {pathToFileURL} from 'node:url';
import {tmpdir} from 'node:os';
import luaparse from 'luaparse';
test('Act1 responsibilities preserve every require edge and SCC member',()=>{
 const sources=Object.fromEntries(Object.entries(discoverSources()).map(([p,s])=>[p.slice(8,-4).replaceAll('/','.'),s]));
 const policy=JSON.parse(read('config/architecture.json'));
 const old=analyzeSources({...sources,abyss_act1_events:before},policy),current=analyzeSources(sources,policy);
 assert.deepEqual(old.errors,[]);assert.deepEqual(current.errors,[]);
 const edges=g=>g.edges.map(({from,to,reviewedDeferred})=>JSON.stringify({from,to,reviewedDeferred})).sort();
 assert.deepEqual(edges(current),edges(old));
 assert.deepEqual(dependencyCycles(current.nodes,current.edges).map(c=>c.members),dependencyCycles(old.nodes,old.edges).map(c=>c.members));
});
test('every extracted Act1 root and nested callback keeps the existing CC15 hard gate',()=>{
 for(const name of ['M.choose','bonfireReward','bonfireCurseReward',...handlers.map(n=>'choiceHandlers.'+n)]){
  const source=`function ${name}() return function() end end`;
  const row=(column,subject)=>({file,line:1,column,code:'W561',message:`cyclomatic complexity of ${subject} is too high (16 > 0)`});
  const errors=reviewResponsibilityComplexity([row(1,'main chunk'),row(1,`function '${name}'`),row(source.indexOf('function()')+1,'function')],{[file]:source}).errors;
  assert(errors.some(e=>e.message===`Responsibility complexity 16 exceeds 15: function '${name}'`));
  assert(errors.some(e=>e.message==='Responsibility complexity 16 exceeds 15: function'));
 }
 assert(reviewResponsibilityComplexity([],{[file]:'function M.choose()end'}).errors.some(e=>e.message.includes('missing or duplicated')));
});
test('actual CRLF source and helper checkout retain the frozen LF Git identity',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'act1-crlf-'));
 try{
  for(const name of ['act1-choice-source-inverse.mjs','act1-choice-before.lua'])writeFileSync(join(dir,name),read('tests/helpers/'+name).replaceAll('\n','\r\n'));
  const module=await import(pathToFileURL(join(dir,'act1-choice-source-inverse.mjs')).href);
  assert.equal(module.act1ChoiceBefore,before);
  assert.equal(module.preAct1ChoiceSource(file,read(file).replaceAll('\n','\r\n')),before);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
test('Act1 current source enters the unchanged historical chain and rereads a mutable owner',async()=>{
 const {preRelicQuerySource}=await import('./helpers/relic-query-source-inverse.mjs');
 const source=read(file);assert.equal(preRelicQuerySource(file,source),before);
 const reader=act1ChoiceReader(p=>read(p));assert.equal(preRelicQuerySource(file,source,{readSource:reader}),before);
 assert.throws(()=>preRelicQuerySource(file,source,{readSource:p=>read(p)+(p===file?'\n':'')}),/linked owner/);
});
for(const [name,from,to,fixture,expected] of [
 ['serpent gold',"Run.gainGold(staged,175)","Run.gainGold(staged,176)",'tests/lua/act1_event_content.lua','275.0 ~= 274'],
 ['blacksmith upgrade count',"(instance.upgraded and 1 or 0))+1","(instance.upgraded and 1 or 0))+2",'tests/helpers/act1-choice-boundaries.lua','2 ~= 1'],
 ['inclusive ooze threshold',"if roll>=99-event.chance then","if roll>99-event.chance then",'tests/lua/scrap_ooze.lua','nil ~= result'],
])test(`existing behavior assertions reject parsed ${name} semantic mutation`,()=>{
 const source=read(file);assert.equal(source.split(from).length,2,'one actual mutation site');
 const mutant=source.replace(from,to);luaparse.parse(mutant,{luaVersion:'5.3'});
 const result=replay(mutant,fixture,fixture.includes('boundaries')?1:undefined);assert.equal(result.status,2,'actual assertion failure');
 assert.match(result.error,new RegExp('^'+fixture.replaceAll('.','\\.')+':'+(fixture.includes('boundaries')?'13':'4')+': '));
 // Exact failures are recorded rather than accepting a harness timeout as evidence.
 assert(result.error.endsWith(expected),result.error);
});

for(const group of [1,2,3,4])test(`Act1 failure boundaries ${group}/4 preserve all original values and aliases`,t=>{
 const fixture='tests/helpers/act1-choice-boundaries.lua',old=replay(before,fixture,group),current=replay(read(file),fixture,group);
 assert.equal(old.status,0,old.error);assert.equal(current.status,0,current.error);
 assert(current.checkpoints>0);assert.equal(current.checkpoints,old.checkpoints);assert.deepEqual(current.logs,old.logs);
 if(!current.graph.equals(old.graph)){
  const a=old.graph.toString().split('\n'),b=current.graph.toString().split('\n');const i=a.findIndex((x,i)=>x!==b[i]);
  writeFileSync('build/act1-choice/mismatch-'+group+'.json',JSON.stringify({checkpoint:i,before:JSON.parse(a[i]),after:JSON.parse(b[i])}));
 }
 assert(current.graph.equals(old.graph),'complete graph bytes differ');
 const proof={group,checkpoints:current.checkpoints,bytesPerSide:current.graph.length,sha256:createHash('sha256').update(current.graph).digest('hex'),logs:current.logs};
 writeFileSync('build/act1-choice/boundary-'+group+'.json',JSON.stringify(proof,null,2)+'\n');t.diagnostic(JSON.stringify(proof));
});


test('error observation maps only the verified moved damage site and preserves foreign errors',async()=>{
 const {comparableAct1ChoiceError:compare,verifyAct1ChoiceErrorSite:verify}=await import('./helpers/act1-choice-source-inverse.mjs');
 verify(read(file));
 const body="attempt to call a nil value (field 'eventDamage')";
 assert.equal(compare(`${file}:174: ${body}`),`${file}:177: ${body}`);
 for(const value of [null,{},new Error('sentinel'),`${file}:175: ${body}`,`${file}:174: changed body`,`foreign.lua:174: ${body}`])assert.equal(compare(value),value);
 assert.throws(()=>verify(read(file).replace('local damaged,damageReason=Run.eventDamage(run,event.damage)','local damaged,damageReason=false')),/moved unguarded damage site/);
});
