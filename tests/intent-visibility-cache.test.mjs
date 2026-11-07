import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,unlinkSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {randomUUID} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';
test('intent visibility retains native owner, lifecycle, failure and reentry semantics',()=>{
 const r=runLua('tests/lua/intent_visibility_cache.lua');assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/INTENT_VISIBILITY_CACHE_PASS/);
});
for(const [name,anchor,replacement,marker] of [
 ['owner','saved.binding==binding and ','','visibility owner ignored'],
 ['alive','saved.value==value and control.alive~=false','saved.value==value','dead visibility guard bypassed'],
 ['rejected write','accepted~=false and ownsWrite then intentVisibilities','ownsWrite then intentVisibilities','rejected visibility write cached'],
 ['overlap','accepted~=false and ownsWrite then intentVisibilities','accepted~=false then intentVisibilities','overlapping visibility cached'],
 ['escape post-clear','local ok,why=pcall(control.SetVisible,control,false)\n            intentVisibilities[control]=nil','local ok,why=pcall(control.SetVisible,control,false)','escape writer retained nested visibility promise'],
 ['no cache','saved and saved.binding','false and saved and saved.binding','unchanged visibility resubmitted'],
])for(const [format,newline] of [['LF','\n'],['CRLF','\r\n']])test(`visibility negative control (${format}): ${name}`,()=>{
 const path='src/lua/abyss_battle_render_actors.lua',original=readFileSync(path,'utf8');
 const source=original.replace(/\r?\n/g,newline),formattedAnchor=anchor.replaceAll('\n',newline);
 assert.equal(source.split(formattedAnchor).length,2,'exactly one mutation boundary in either checkout format');
 const entry=join(tmpdir(),'visibility-'+randomUUID()+'.lua');
 writeFileSync(entry,`package.preload.abyss_battle_render_actors=assert(load(${luaString(source.replace(formattedAnchor,replacement.replaceAll('\n',newline)))},'@visibility-mutant'))\ndofile('tests/lua/intent_visibility_cache.lua')`);
 try{const r=runLua(entry);assert.notEqual(r.status,0);assert.match(r.stdout+r.stderr,new RegExp(marker));}finally{unlinkSync(entry);}
 assert.equal(readFileSync(path,'utf8'),original,'negative control changed production source');
});
test('complete Host route retains final run/native graph while idle intent writes fall',async()=>{
 const {spawnSync}=await import('node:child_process');
 const {createHash}=await import('node:crypto');
 const {mkdirSync}=await import('node:fs');
 const samples=['before','after'].map(side=>{
  const r=spawnSync(process.execPath,['tests/helpers/intent-visibility-vm.mjs',side],{encoding:'utf8',timeout:30000,maxBuffer:32*1024*1024});
  assert.ifError(r.error);assert.equal(r.status,0,r.stderr+'\n'+r.stdout.slice(-2000));
  assert.match(r.stdout,/RUNTIME_BASELINE_PASS seed=1 idleFrames=300/);
  const graphs=r.stdout.split('\n').filter(line=>line.startsWith('VISIBILITY_GRAPH '));assert.equal(graphs.length,1);
  const counts=r.stdout.split('\n').filter(line=>line.startsWith('VISIBILITY_COUNTS '));assert.equal(counts.length,1);
  return {side,graph:graphs[0],counts:JSON.parse(counts[0].slice('VISIBILITY_COUNTS '.length))};
 });
 assert.equal(samples[1].graph,samples[0].graph,'complete final Host/run/native graph changed');
 const idle=samples.map(s=>s.counts.find(row=>row.phase==='idle-300'));
 assert.deepEqual(idle.map(row=>row.counts),[[900,0,3600,7200,0],[900,0,1800,5400,0]]);
 for(let i=0;i<samples[0].counts.length;i++)for(const index of [0,1,4])assert.equal(samples[0].counts[i].counts[index],samples[1].counts[i].counts[index],'require/load/snapshot workload changed');
 mkdirSync('build/intent-visibility',{recursive:true});
 writeFileSync('build/intent-visibility/equivalence.json',JSON.stringify({
  beforeSource:createHash('sha256').update(readFileSync('tests/fixtures/intent-visibility/before.lua')).digest('hex'),
  afterSource:createHash('sha256').update(readFileSync('src/lua/abyss_battle_render_actors.lua')).digest('hex'),
  graphBytes:Buffer.byteLength(samples[0].graph),graphSha256:createHash('sha256').update(samples[0].graph).digest('hex'),
  equal:true,samples:samples.map(({side,counts})=>({side,counts})),
  scope:'Full final Host/run/native reachable fields and alias/metatable graph after the fixed route, not per-frame output or official device evidence.'},null,2)+'\n');
});
