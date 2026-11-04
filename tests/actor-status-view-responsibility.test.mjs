import {createHash} from 'node:crypto';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';
import {originalActorStatusViewSource,actorStatusViewRevision} from './helpers/actor-status-view-source.mjs';
import {runStatic} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';
const path='src/lua/abyss_actor.lua';
const current=()=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
function replay(source,directory,label){
 const actor=join(directory,`${label}.lua`),driver=join(directory,`${label}-driver.lua`);
 writeFileSync(actor,source);
 writeFileSync(driver,`QUERY_DIFFERENTIAL_TRACE=true;package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;package.loaded.abyss_actor=dofile(${luaString(actor.replaceAll('\\','/'))});dofile(${luaString(resolve('tests/lua/actor_status_view_differential.lua').replaceAll('\\','/'))})`);
 const result=runLua(driver,{maxBuffer:4*1024*1024});
 assert.equal(result.status,0,`${label}: ${result.stdout}${result.stderr}`);
 assert.match(result.stdout,/STATUS_VIEW_PASS 252/);
 assert.equal([...result.stdout.matchAll(/^STATUS_BOUNDARY /gm)].length,252,'complete differential trace must be enabled');
 return createHash('sha256').update(result.stdout).digest('hex');
}
test('statusView exact frozen Actor and current Actor agree in independent VMs on full returns, aliases, errors and lazy reads',()=>{
 assert.equal(actorStatusViewRevision,'a308edbfde7792485cbe79b5650c17e1c7de98cc');
 const directory=mkdtempSync(join(tmpdir(),'actor-status-view-'));
 try{assert.equal(replay(current(),directory,'current'),replay(originalActorStatusViewSource(),directory,'original'));}
 finally{rmSync(directory,{recursive:true,force:true});}
});
test('all statusView responsibilities, including callbacks, have complete CC15 measurements',()=>{
 const measured=measureSources(discoverSources(),runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics);
 assert.deepEqual(measured.errors,[]);
 const actor=measured.modules.find(m=>m.file===path);
 const names=['monsterStatusIds','playerStatusIds','statusKind','statusEntry','statusResource','appendRaidenResources','appendOriginalV4Resources','appendTargetV4Resources','M.statusView'];
 for(const name of names){const entries=actor.functions.filter(f=>f.name===name);assert.equal(entries.length,1,name);assert(entries[0].complexity<=15,`${name}: ${entries[0].complexity}`);}
 const start=actor.functions.find(f=>f.name==='monsterStatusIds').line,end=actor.functions.find(f=>f.name==='battleEnding').line;
 for(const f of actor.functions.filter(f=>f.kind==='function'&&f.line>=start&&f.line<end))assert(f.complexity<=15,`${f.name}: nested budget`);
});
test('semantic status selection, metadata, description and V4 mutants disagree with the real frozen implementation',()=>{
 const source=current();
 const mutations=[
  ['monster order','local seen={}\n    for _,id in ipairs(actor.powerOrder or {})do','local seen={}\n    for _,id in ipairs({})do'],
  ['required zero','amount==0 and not zeroPower or seen[id]','amount==0 or seen[id]'],
  ['player zero exception','id == "focus" or id==\'slow\'','id == "nemesis_intangible" or id==\'slow\''],
  ['temporary threshold','(actor[temporaryFields[id]] or 0) > 0','(actor[temporaryFields[id]] or 0) >= 0'],
  ['player sort','table.sort(ids)\n    return ids','-- table.sort(ids)\n    return ids'],
  ['source nil false','sourceVerified=actor.definitionId and facts~=nil','sourceVerified=not not (actor.definitionId and facts~=nil)'],
  ['signed kind','actor.statuses[id] > 0 and "buff"','actor.statuses[id] >= 0 and "buff"'],
  ['negative false','canGoNegative=facts and facts.canGoNegative','canGoNegative=facts and facts.canGoNegative or nil'],
  ['source amount','sourceAmount=facts and facts.sourceAmount','sourceAmount=facts and math.max(0,facts.sourceAmount)'],
  ['silent precedence',"require('abyss_silent_final_cards').powerDescription(actor,id)or require('abyss_colorless_cards').powerDescription(actor,id)","require('abyss_colorless_cards').powerDescription(actor,id)or require('abyss_silent_final_cards').powerDescription(actor,id)"],
  ['healing cap','(v.healCap or 12)-v.healUsed','(v.healCap or 11)-v.healUsed'],
  ['HT boundary',"v.role=='HT' and v.infuse>0","v.role=='HT' and v.infuse>=0"],
  ['RD duration','v.eye.uses>0 and v.eye.ends>0','v.eye.uses>0 and v.eye.ends>=0'],
  ['target suffix','appendOriginalV4Resources(actor,resource)\n    appendTargetV4Resources(actor,resource)','appendTargetV4Resources(actor,resource)\n    appendOriginalV4Resources(actor,resource)'],
 ];
 const directory=mkdtempSync(join(tmpdir(),'actor-status-mutants-'));
 try{
  const expected=replay(originalActorStatusViewSource(),directory,'original');
  for(const [label,before,after]of mutations){assert.equal(source.split(before).length-1,1,`${label}: unique semantic mutation`);assert.notEqual(replay(source.replace(before,after),directory,'mutant'),expected,`${label}: survived`);}
 }finally{rmSync(directory,{recursive:true,force:true});}
});
