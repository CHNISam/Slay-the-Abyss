import test from 'node:test';
import assert from 'node:assert/strict';
import {checkArchitecture,analyzeSources} from '../scripts/check-architecture.mjs';
import {reviewResponsibilityComplexity,reviewModuleSize} from '../scripts/check-lua-static.mjs';
import {existsSync,mkdtempSync,writeFileSync,readFileSync,rmSync,realpathSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {luaString,toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

// Use the production AST graph, including deferred imports. A direct-only ban
// could leave the same Session command reachable through another relic family.
const graph=checkArchitecture();
const session=new Set(['abyss_run','abyss_nodes','abyss_relic_hooks','abyss_boss_relics',
 'abyss_uncommon_relics','abyss_rare_relics','abyss_shop_relics',
 'abyss_relic_choices','abyss_relic_pending','abyss_relic_card_rewards']);

test('all functions and nested callbacks in both Combat capabilities retain CC15 and size1000',()=>{
 for(const name of ['abyss_relic_combat_hooks','abyss_relic_family_combat']){
  const file=`src/lua/${name}.lua`,source='local function callback() return function() end end';
  const row=(column,subject,value)=>({file,line:1,column,code:'W561',
   message:`cyclomatic complexity of ${subject} is too high (${value} > 0)`});
  const rows=[row(1,'main chunk',1),row(7,"function 'callback'",16),
   row(source.indexOf('function()')+1,'function',16)];
  const errors=reviewResponsibilityComplexity(rows,{[file]:source}).errors;
  for(const subject of ["function 'callback'",'function'])
   assert(errors.some(e=>e.file===file&&e.message===`Responsibility complexity 16 exceeds 15: ${subject}`));
  assert(reviewModuleSize({[file]:Array(1001).fill('-- line').join('\n')}).errors.some(e=>e.file===file));
  assert(reviewModuleSize({}).errors.some(e=>e.file===file));
 }
});

test('persisted Combat lifecycle boundaries reject eager and deferred Session imports',()=>{
 const policy=JSON.parse(readFileSync('config/architecture.json','utf8'));
 for(const from of ['abyss_actor','abyss_hp_loss','abyss_card_actions','abyss_combat',
  'abyss_relic_combat_hooks','abyss_relic_family_combat']){
  const rules=policy.dependencyBoundaries.filter(rule=>rule.from.includes(from));
  for(const to of session){
   const rule=rules.find(row=>row.forbiddenTargets.includes(to));
   assert(rule,`missing persisted Session boundary ${from}->${to}`);
   const names=[...new Set([...rule.from,...rule.forbiddenTargets])];
   const sources=Object.fromEntries(names.map(name=>[name,'return {}']));
   for(const deferred of [false,true]){
    const call=`require('${to}')`,code=deferred?`return function()return ${call}end`:`return ${call}`;
    const report=analyzeSources({...sources,[from]:code},{layers:policy.layers,
     dependencyBoundaries:[rule],deferredImports:deferred?[{from,to}]:[]},{});
    assert(report.errors.some(error=>error.message.includes(`Dependency boundary ${rule.id}: ${from} cannot depend on ${to}`)));
   }
  }
 }
});
function sessionPath(start){
 const pending=[[start]],visited=new Set([start]);
 for(let index=0;index<pending.length;index++){
  const path=pending[index];
  for(const edge of graph.edges.filter(edge=>edge.from===path.at(-1))){
   const next=[...path,edge.to];
   if(session.has(edge.to))return next;
   if(!visited.has(edge.to)){visited.add(edge.to);pending.push(next);}
  }
 }
}

for(const owner of ['abyss_actor','abyss_hp_loss','abyss_card_actions','abyss_combat'])
test(`${owner} cannot load Session relic facades or permanent command owners`,()=>{
 assert.deepEqual(graph.errors,[],'production dependency graph must remain valid');
 const path=sessionPath(owner);
 assert.equal(path,undefined,'[RELIC_LIFECYCLE] runtime reaches Session: '+path?.join(' -> '));
});

for(const first of ['actor','capabilities'])test(`cold ${first}-first relic capabilities never initialize Session facades`,()=>{
 for(const name of ['abyss_relic_combat_hooks','abyss_relic_family_combat'])
  assert(existsSync(`src/lua/${name}.lua`),'[RELIC_LIFECYCLE] missing explicit capability '+name);
 const directory=mkdtempSync(join(tmpdir(),'relic-lifecycle-cold-'));
 try{
  const file=join(directory,'cold.lua');
  writeFileSync(file,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local forbidden=${toLua([...session])}
for _,name in ipairs(forbidden)do
 assert(package.loaded[name]==nil,'fresh cold Session target')
 package.preload[name]=function()error('[RELIC_LIFECYCLE_COLD] Session load '..name,0)end
end
local actor,hooks,family
if ${luaString(first)}=='actor'then actor=require('abyss_actor')end
hooks=require('abyss_relic_combat_hooks');family=require('abyss_relic_family_combat')
actor=actor or require('abyss_actor')
assert(type(actor.damage)=='function'and type(hooks.hpChanged)=='function'and type(hooks.bindBattle)=='function')
for _,name in ipairs({'boss','uncommon','rare','shop','common'})do assert(type(family[name])=='table','fixed family capability')end
for _,name in ipairs(forbidden)do assert(package.loaded[name]==nil,'Session facade initialized '..name)end
local loaded={};for name in pairs(package.loaded)do if name:match('^abyss_')then loaded[#loaded+1]=name end end
table.sort(loaded);print('RELIC_LIFECYCLE_COLD_PASS ${first} '..table.concat(loaded,','))
`);
  const result=runLua(file);assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,new RegExp(`RELIC_LIFECYCLE_COLD_PASS ${first} `));
 }finally{
  assert.equal(realpathSync(dirname(directory)),realpathSync(tmpdir()),'owned temporary probe directory');
  rmSync(directory,{recursive:true,force:true});
 }
});

test('all delegated ordinary public fields share their planned canonical slot in both directions',()=>{
 const slots=JSON.parse(readFileSync('tests/fixtures/relic-lifecycle-slots.json','utf8'));
 assert.equal(slots.baselineRevision,'5762bdd07234b1b25d2541604af773d31e7d05f7');
 assert.equal(slots.forwardedFields,89);
 for(const name of ['abyss_relic_combat_hooks','abyss_relic_family_combat'])
  assert(existsSync(`src/lua/${name}.lua`),'[RELIC_LIFECYCLE] missing canonical slot producer '+name);
 const directory=mkdtempSync(join(tmpdir(),'relic-lifecycle-slots-'));
 try{
  const file=join(directory,'slots.lua');
  writeFileSync(file,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local groups=${toLua(slots.groups.map(group=>Object.fromEntries(Object.entries(group).filter(([,value])=>value!==null))))}
local first,second=function()end,function()end
local count=0
for _,group in ipairs(groups)do
 local facade=require(group.facade);local target=require(group.module)
 if group.namespace then target=target[group.namespace]end
 for _,field in ipairs(group.fields)do
  local original=facade[field]
  assert(type(original)==(field=='aliases'and'table'or'function')and target[field]==original,'initial canonical slot '..group.facade..'.'..field)
  facade[field]=first;assert(target[field]==first,'facade write '..field)
  target[field]=second;assert(facade[field]==second,'canonical write '..field)
  facade[field]=nil;assert(facade[field]==nil and target[field]==nil,'ordinary nil '..field)
  target[field]=original;assert(facade[field]==original,'restore original function/table identity '..field)
  count=count+1
 end
 local value={};facade.lifecycleUserProbe=value
 assert(rawget(facade,'lifecycleUserProbe')==value,'unrelated public fields remain ordinary')
 facade.lifecycleUserProbe=nil
end
local boss,rare=require('abyss_boss_relics'),require('abyss_rare_relics')
assert(boss.owns==nil and boss.privateOwns==nil and rare.privateOwns==nil,'private predicates are not new facade API')
assert(count==89);print('RELIC_LIFECYCLE_SLOTS_PASS '..count)
`);
  const result=runLua(file);assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/RELIC_LIFECYCLE_SLOTS_PASS 89/);
 }finally{
  assert.equal(realpathSync(dirname(directory)),realpathSync(tmpdir()),'owned temporary slot probe directory');
  rmSync(directory,{recursive:true,force:true});
 }
});
