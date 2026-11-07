import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runStatic,reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';
const file='src/lua/abyss_defect_engine_cards.lua';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
test('Defect pure-plan dispatcher and extracted responsibilities retain CC15',()=>{
 const sources=discoverSources(),rows=runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics;
 const measured=measureSources(sources,rows);assert.deepEqual(measured.errors,[]);
 const functions=measured.modules.find(m=>m.file===file).functions;
 assert(functions.find(f=>f.name==='M.planEffect').complexity<=15,'planEffect CC15');
 assert.deepEqual(reviewResponsibilityComplexity(rows,sources).errors,[]);
});

import {mkdtempSync,mkdirSync,rmSync,writeFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {defectPlanBefore as before,preDefectPlanSource,defectPlanReader,defectPlanErrorSites,verifyDefectPlanErrorSites,comparableDefectPlanError} from './helpers/defect-plan-source-inverse.mjs';
function replay(source,fixture,{group,mode='runtime'}={}){
 mkdirSync('build/defect-plan',{recursive:true});const dir=mkdtempSync('build/defect-plan/vm-');
 try{
  const output=join(dir,'graph.jsonl'),result=spawnSync(process.execPath,['--max-old-space-size=768','tests/helpers/defect-plan-vm.mjs'],{
   input:JSON.stringify({source,fixture,mode,group,output}),encoding:'utf8',timeout:30000,maxBuffer:1024**2,
  });
  assert.equal(result.error,undefined,result.error?.message);assert.equal(result.status,0,result.stderr);
  return {...JSON.parse(result.stdout),graph:readFileSync(output)};
 }finally{rmSync(dir,{recursive:true,force:true});}
}
const boundaryProofs=[];
function compare(fixture,options={},t){
 const old=replay(before,fixture,options),current=replay(read(file),fixture,options);
 assert.equal(old.status,0,old.error);assert.equal(current.status,0,current.error);
 assert(current.checkpoints>0);assert.equal(current.checkpoints,old.checkpoints);assert.deepEqual(current.logs,old.logs);
 if(!current.graph.equals(old.graph)){
  const a=old.graph.toString().split('\n'),b=current.graph.toString().split('\n'),i=a.findIndex((x,i)=>x!==b[i]);
  writeFileSync('build/defect-plan/mismatch-'+(options.group??'runtime')+'.json',JSON.stringify({checkpoint:i,before:JSON.parse(a[i]),after:JSON.parse(b[i])}));
 }
 assert(current.graph.equals(old.graph),'complete graphs differ');
 const proof={fixture,...options,checkpoints:current.checkpoints,bytesPerSide:current.graph.length,sha256:createHash('sha256').update(current.graph).digest('hex'),labels:current.labels,logs:current.logs};
 writeFileSync('build/defect-plan/'+(options.group??'runtime')+'.json',JSON.stringify(proof,null,2)+'\n');t.diagnostic(JSON.stringify({...proof,labels:undefined}));
 if(options.mode==='plans')boundaryProofs.push(proof);
 return proof;
}
test('existing complete Defect engine gameplay fixture preserves complete state, aliases, RNG and returns',t=>compare('tests/lua/defect_engine_build.lua',{},t));

import {analyzeSources} from '../scripts/check-architecture.mjs';
import {dependencyCycles} from '../scripts/lua-quality-metrics.mjs';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
const roots=['M.planEffect','change',...['growClaws','loseSteamBlock','reduceStreamlineCost','aggregateEnergy','autoShields','blizzardDamage','chaosOrbs','chillOrbs','randomEngineAttack','engineRandomRounds','sunderDamage','engineSunderRefund','tempestOrbs','engineChannelRounds','engineEvokeRounds'].map(n=>'planHandlers.'+n)];
test('every pure planner and nested callback retains the same CC15 hard limit',()=>{
 for(const name of roots){
  const source=`function ${name}()return function()end end`;
  const row=(column,subject)=>({file,line:1,column,code:'W561',message:`cyclomatic complexity of ${subject} is too high (16 > 0)`});
  const errors=reviewResponsibilityComplexity([row(1,'main chunk'),row(1,`function '${name}'`),row(source.indexOf('function()')+1,'function')],{[file]:source}).errors;
  assert(errors.some(e=>e.message===`Responsibility complexity 16 exceeds 15: function '${name}'`));
  assert(errors.some(e=>e.message==='Responsibility complexity 16 exceeds 15: function'));
 }
 assert(reviewResponsibilityComplexity([],{[file]:'function M.planEffect()end'}).errors.some(e=>e.message.includes('missing or duplicated')));
});
test('pure planner extraction preserves every require edge and SCC member',()=>{
 const sources=Object.fromEntries(Object.entries(discoverSources()).map(([p,s])=>[p.slice(8,-4).replaceAll('/','.'),s]));
 const policy=JSON.parse(read('config/architecture.json'));
 const old=analyzeSources({...sources,abyss_defect_engine_cards:before},policy),current=analyzeSources(sources,policy);
 assert.deepEqual(old.errors,[]);assert.deepEqual(current.errors,[]);
 const edges=g=>g.edges.map(({from,to,reviewedDeferred})=>JSON.stringify({from,to,reviewedDeferred})).sort();
 assert.deepEqual(edges(current),edges(old));assert.deepEqual(dependencyCycles(current.nodes,current.edges).map(c=>c.members),dependencyCycles(old.nodes,old.edges).map(c=>c.members));
});
test('Defect source proof authenticates fresh owners, original Git identity and CRLF',async()=>{
 const current=read(file);let live=current,reads=0;const raw=p=>{assert.equal(p,file);reads++;return live;};
 const reader=defectPlanReader(raw);assert.equal(defectPlanReader(reader),reader);
 assert.equal(preDefectPlanSource(file,current,{readSource:reader}),before);assert.equal(reads,1);
 assert.equal(preDefectPlanSource(file,current.replaceAll('\n','\r\n'),{readSource:raw}),before);
 for(live of [current+'\n',before,null,undefined])assert.throws(()=>preDefectPlanSource(file,current,{readSource:reader}),/linked owner/);
 assert.throws(()=>preDefectPlanSource(file,current,{readSource(){throw Error('missing');}}),/linked owner missing/);
 assert.throws(()=>preDefectPlanSource(file,current,{readSource:null}),/linked reader/);
 reads=0;for(const unknown of [null,undefined,'',current+'\n',before])assert.equal(preDefectPlanSource(file,unknown,{readSource:raw}),unknown);
 assert.equal(preDefectPlanSource('foreign/'+file,current,{readSource:raw}),current);assert.equal(reads,0);
 const dir=mkdtempSync(join(tmpdir(),'defect-plan-crlf-'));
 try{
  for(const name of ['defect-plan-source-inverse.mjs','defect-plan-before.lua'])writeFileSync(join(dir,name),read('tests/helpers/'+name).replaceAll('\n','\r\n'));
  const module=await import(pathToFileURL(join(dir,'defect-plan-source-inverse.mjs')).href);assert.equal(module.defectPlanBefore,before);
  assert.equal(module.preDefectPlanSource(file,current.replaceAll('\n','\r\n')),before);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
test('Defect current owner composes into the unchanged full historical lifecycle source',async()=>{
 const {preRelicQuerySource,relicQuerySourceProof}=await import('./helpers/relic-query-source-inverse.mjs');
 const current=read(file),expected=relicQuerySourceProof.files[file].beforeSource;
 assert.equal(preRelicQuerySource(file,current),expected);
 let changed=false;assert.throws(()=>preRelicQuerySource(file,current,{readSource:p=>{const value=read(p);if(p===file){if(changed)return value+'\n';changed=true;}return value;}}),/linked owner/);
});
test('moved assert observations keep exact bodies, foreign locations and thrown object identity',()=>{
 verifyDefectPlanErrorSites(read(file));assert.equal(defectPlanErrorSites.length,15);
 for(const [old,current,,body]of defectPlanErrorSites){
  assert.equal(comparableDefectPlanError(`${file}:${current}: ${body}`),`${file}:${old}: ${body}`);
  for(const input of [`${file}:9999: ${body}`,`${file}:${current}: changed body`,`foreign.lua:${current}: ${body}`])assert.equal(comparableDefectPlanError(input),input);
 }
 for(const value of [null,{},new Error('sentinel')])assert.equal(comparableDefectPlanError(value),value);
 assert.throws(()=>verifyDefectPlanErrorSites(read(file).replace('unsupported Steam decrement','changed Steam decrement')));
});

for(const group of [1,2,3,4])test(`Defect planner boundaries ${group}/4 preserve pure inputs, graphs, aliases and failure values`,t=>compare('tests/helpers/defect-plan-boundaries.lua',{mode:'plans',group},t));


test('the boundary partitions execute every actual planner and every registered case exactly once',()=>{
 assert.equal(boundaryProofs.length,4);
 const source=read(file),names=[...source.matchAll(/^function planHandlers\.([^ (]+)\(/gm)].map(m=>m[1]);
 const aliases=[...source.matchAll(/^planHandlers\.([^ =]+)=planHandlers\./gm)].map(m=>m[1]);
 assert.equal(names.length,15);assert.equal(aliases.length,2);
 const executed=new Set(boundaryProofs.flatMap(p=>p.labels).filter(x=>x.startsWith('plan:')).map(x=>x.slice(5)));
 for(const op of [...names,...aliases])assert(executed.has(op),'unexecuted planner '+op);
 const cases=boundaryProofs.flatMap(p=>p.logs.flatMap(line=>{const m=/^PASS defect boundaries (\d+) /.exec(line);return m?[Number(m[1])]:[]})).sort((a,b)=>a-b);
 assert.deepEqual(cases,Array.from({length:13},(_,i)=>i+1));
});

import luaparse from 'luaparse';
for(const [name,from,to,group,expected]of [
 ['Claw exhaust exclusion','ipairs({state.hand,state.draw,state.discard})','ipairs({state.hand,state.draw,state.discard,state.exhaust})',1,'4 ~= 3'],
 ['random input RNG purity',"Random.cloneState(assert(state.cardRandomRng,'random attack requires cardRandomRng'))","assert(state.cardRandomRng,'random attack requires cardRandomRng')",4,'1 ~= 0'],
 ['X free payment','p.consumeAllEnergy=context.freeToPlayOnce~=true','p.consumeAllEnergy=context.freeToPlayOnce==true',2,'false ~= true'],
 ['final evoke continuation','p.top[2]=nextRound(op,1,effect.remaining-1)end','p.top[2]=nextRound(op,1,effect.remaining)end',3,'2 ~= 1'],
])test(`real boundary assertions reject ${name} semantic mutation`,t=>{
 const source=read(file);assert.equal(source.split(from).length,2,'one real mutation site');
 const mutant=source.replace(from,to);luaparse.parse(mutant,{luaVersion:'5.3'});
 const result=replay(mutant,'tests/helpers/defect-plan-boundaries.lua',{mode:'plans',group});
 assert.equal(result.status,2,'actual Lua assertion rather than harness failure');
 assert.equal(result.error,'tests/helpers/defect-plan-boundaries.lua:10: '+expected);
 t.diagnostic(JSON.stringify({name,error:result.error}));
});
