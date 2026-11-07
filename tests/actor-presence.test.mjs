import test from 'node:test';import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';import luaparse from 'luaparse';
import {discoverSources,dependencyCycles} from '../scripts/lua-quality-metrics.mjs';
import {analyzeSources} from '../scripts/check-architecture.mjs';
import {reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {runActorPresence} from './helpers/actor-presence-vm.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const roots=['abyss_actor_presence','abyss_act2_ai_moves','abyss_act2_summons','abyss_silent_discard_cards'];
function closure(g,n){const seen=new Set(),pending=[n];while(pending.length){const next=pending.pop();if(seen.has(next))continue;seen.add(next);for(const e of g.edges)if(e.from===next)pending.push(e.to);}return [...seen].sort();}
test('presence query consumers have no transitive Actor or combat execution dependency including deferred imports',()=>{
 const sources=Object.fromEntries(Object.entries(discoverSources()).map(([p,s])=>[p.slice(8,-4),s])),policy=JSON.parse(read('config/architecture.json'));
 const g=analyzeSources(sources,policy);assert.deepEqual(g.errors,[]);
 const forbidden=['abyss_actor','abyss_combat','abyss_card_actions','abyss_relic_combat_hooks','abyss_relic_family_combat'];
 for(const root of roots){assert(!closure(g,root).some(n=>forbidden.includes(n)));assert(!dependencyCycles(g.nodes,g.edges).some(c=>c.members.includes(root)));}
 assert.deepEqual(closure(g,'abyss_actor_presence'),['abyss_actor_presence']);
 for(const root of roots)for(const prefix of ["local bad=require('abyss_actor')\n","local function bad()return require('abyss_actor')end\n"]){
  const negative=analyzeSources({...sources,[root]:prefix+sources[root]},policy);
  assert(negative.errors.some(e=>e.message.includes('actor-presence-independence')));assert(closure(negative,root).includes('abyss_actor'));
 }
});
test('entire presence leaf and both dynamic bridges including nested functions enforce CC15',()=>{
 for(const [file,names]of [['src/lua/abyss_actor_presence.lua',['outer']],['src/lua/abyss_actor.lua',['presenceIndex','presenceNewIndex']]])for(const name of names){
  const source=`local function ${name}() return function()end end`,row=(column,subject)=>({file,line:1,column,code:'W561',message:`cyclomatic complexity of ${subject} is too high (16 > 0)`});
  const errors=reviewResponsibilityComplexity([row(1,'main chunk'),row(7,`function '${name}'`),row(source.indexOf('function()')+1,'function')],{[file]:source}).errors;
  assert(errors.some(e=>e.file===file&&e.message===`Responsibility complexity 16 exceeds 15: function '${name}'`));
  assert(errors.some(e=>e.file===file&&e.message==='Responsibility complexity 16 exceeds 15: function'));
  if(file.includes('_presence'))assert(errors.some(e=>e.file===file&&e.message==='Responsibility complexity 16 exceeds 15: main chunk'));
 }
});
for(const fixture of ['actor_presence_contract','act2_party_snapshot','silent_discard_build'])test(`${fixture}: complete independent before/current graphs preserve states, aliases, RNG, returns and errors`,()=>{
 const path='tests/lua/'+fixture+'.lua',options={trace:fixture!=='actor_presence_contract'};
 const before=runActorPresence('before',path,options),after=runActorPresence('after',path,options);
 assert.equal(before.status,0,before.error);assert.equal(after.status,0,after.error);assert(before.graphs.length>0);
 assert.deepEqual(after.logs,before.logs);assert.deepEqual(after.generated,before.generated);assert.deepEqual(after.graphs,before.graphs);assert.equal(after.bytes,before.bytes);
 mkdirSync('build/actor-presence',{recursive:true});writeFileSync(`build/actor-presence/${fixture}-equivalence.json`,JSON.stringify({fixture,checkpoints:after.graphs,bytesPerSide:after.bytes,generated:after.generated},null,2)+'\n');
});
for(const root of roots)test(`${root}: cold query loading does not initialize Actor and early overrides stay visible after facade load`,()=>{
 const prelude=`require('${root}');local P=require('abyss_actor_presence');assert(not package.loaded.abyss_actor and not package.loaded.abyss_combat and not package.loaded.abyss_card_actions)
 local old=P.isActive;local special=function()return 'early' end;P.isActive=special;local A=require('abyss_actor');assert(A.isActive==special);A.isActive=old
 for _,key in ipairs({'isActive','isPresent'})do local original=A[key];P[key]=false;assert(A[key]==false);A[key]=nil;assert(P[key]==nil);P[key]=original;assert(A[key]==original)end`;
 const result=runActorPresence('after','tests/lua/actor_presence_contract.lua',{prelude});assert.equal(result.status,0,result.error);
});
for(const [label,module,from,to,marker]of [
 ['half-dead targetability','abyss_actor_presence',' and not actor.halfDead','',/inactive flag halfDead/],
 ['rebirth encounter presence','abyss_actor_presence',' or actor.awakenedRebirthPending','',/rebirth presence retains truthy value/],
 ['dead refund','abyss_silent_discard_cards','if not Actors.isActive(state.player) then return false end','if false then return false end',/dead player receives no refund/],
])test(`a parsed ${label} regression fails its behavior assertion`,()=>{
 const s=read('src/lua/'+module+'.lua');assert.equal(s.split(from).length,2);const changed=s.replace(from,to);luaparse.parse(changed,{luaVersion:'5.3'});
 const result=runActorPresence('after','tests/lua/actor_presence_contract.lua',{mutation:{name:module,source:changed}});assert.notEqual(result.status,0);assert.match(result.error,marker);
});
