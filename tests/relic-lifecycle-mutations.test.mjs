import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve,dirname,basename} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import luaparse from 'luaparse';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';

const hash=value=>createHash('sha256').update(value).digest('hex');
const puzzle="require('abyss_combat_reactions').enqueueReaction(state,{op='draw',value=3},true)";
const cardSetup=`
local C,A,H,Q,D=require('abyss_combat'),require('abyss_actor'),require('abyss_relic_hooks'),require('abyss_card_actions'),require('abyss_data')
local function battle(shared)
 local s=C.new(D,{seed=42,deck={},enemies={'cultist'},enableStances=shared})
 H.bindBattle(s,{'centennial_puzzle'})
 local card=Q.fresh(C,s,'bloodletting');s.hand={card};s.draw={};s.discard={}
 for _=1,6 do s.draw[#s.draw+1]=Q.fresh(C,s,'defend')end
 return s,card
end
`;
const specs=[
 {id:'shared_queue_owner',module:'abyss_relic_combat_hooks',before:puzzle,
  after:"require('abyss_combat_reactions').enqueue(state,{op='draw',value=3},nil,nil,nil,true)",
  probe:cardSetup+`
local s,card=battle(true);local observed=false;local old=H.hpChanged
H.hpChanged=function(state,actor,before,...)
 local result=old(state,actor,before,...)
 if state==s and actor==s.player and before>actor.hp then
  check(type(state.actionQueue)=='table','real shared action owner remains active')
  check(state.cardActions==nil,'HP callback cannot create a second native action owner')
  local action=state.actionQueue.actions[1]
  check(action and action.effect.op=='draw','Puzzle joins existing owner at TOP');observed=true
 end
 return result
end
assert(C.play(s,card.uid,1));H.hpChanged=old
check(observed and #s.hand==3,'real HP callback and queued draw executed')
`},
 {id:'puzzle_top_order',module:'abyss_relic_combat_hooks',before:puzzle,
  after:"require('abyss_combat_reactions').enqueueReaction(state,{op='draw',value=3},false)",
  probe:cardSetup+`
local s,card=battle(false);A.applyPower(s,s.player,'rupture',2,s.player)
local old=C.draw;local observed=false
C.draw=function(state,n)
 if state==s and n==3 then
  check((state.player.statuses.strength or 0)==0,'Puzzle TOP draw executes before Rupture Strength')
  observed=true
 end
 return old(state,n)
end
assert(C.play(s,card.uid,1));C.draw=old
check(observed and s.player.statuses.strength==2,'both reactions resolved in real native owner')
`},
 {id:'persistent_counter_alias',module:'abyss_relic_combat_hooks',
  before:'state.relicCounters={};for k,v in pairs(persistentCounters or {})do state.relicCounters[k]=v end',
  after:'state.relicCounters=persistentCounters or {}',
  probe:`
local R,C,H,D=require('abyss_run'),require('abyss_combat'),require('abyss_relic_hooks'),require('abyss_data')
local r=R.new(D,42);assert(R.obtainRelic(r,'happy_flower'))
local original=r.relicCounters;local before=original.happy_flower
local s=C.new(D,{seed=42,deck={'defend'},enemies={'cultist'}})
H.bindBattle(s,r.relics,original);H.atTurnStart(s)
check(not rawequal(s.relicCounters,original),'Combat counter projection is a separate table')
check(r.relicCounters==original and original.happy_flower==before,'Combat turn cannot mutate persistent owner counters')
check(s.relicCounters.happy_flower==1,'real Happy Flower turn advanced combat counter')
`},
 {id:'dynamic_boss_spawn',module:'abyss_relic_family_combat',
  before:"function M.battleStart(state,id)\n id=M.localId(id)\n if id=='philosophers_stone'then for _,enemy in ipairs(state.enemies)do M.onSpawnMonster(state,enemy)end",
  after:"local capturedOnSpawnMonster=M.onSpawnMonster\nfunction M.battleStart(state,id)\n id=M.localId(id)\n if id=='philosophers_stone'then for _,enemy in ipairs(state.enemies)do capturedOnSpawnMonster(state,enemy)end",
  probe:`
local C,H,B,D=require('abyss_combat'),require('abyss_relic_hooks'),require('abyss_boss_relics'),require('abyss_data')
local s=C.new(D,{seed=42,deck={'defend'},enemies={'cultist'}})
H.bindBattle(s,{'philosophers_stone'})
local original=B.onSpawnMonster;local calls=0
B.onSpawnMonster=function(state,enemy)check(state==s,'actual battle owner');calls=calls+1;return original(state,enemy)end
B.battleStart(s,'philosophers_stone');B.onSpawnMonster=original
check(calls==#s.enemies,'battleStart dynamically reads the public onSpawnMonster slot')
`},
 {id:'wish_bloom_owner',module:'abyss_relic_family_combat',
  before:"if require('abyss_potion_health').blocked(run.relics)then return end",
  after:"if require('abyss_potion_health').blocked(run.relics)and false then return end",
  probe:`
local C,H,P,D=require('abyss_combat'),require('abyss_relic_hooks'),require('abyss_character_profiles'),require('abyss_data')
local s=C.new(P.prepare(D,'watcher'),{seed=1,cardRandomSeed='1',shuffleSeed='1',enableStances=true,deck={'wish'},enemies={'cultist'}})
H.bindBattle(s,{'bloody_idol','mark_of_bloom'});s.energy=20
local card=s.hand[1];assert(C.play(s,card.uid,1));local choice=assert(s.pendingChoice);local gold=s.player.gold
local ok,accepted=pcall(C.chooseCard,s,choice.token,2)
check(ok and accepted==true,'Bloom prevents health access on the real Wish temporary owner')
check(s.player.gold==gold+25 and s.pendingChoice==nil,'Wish commits gold and choice exactly once')
`},
 {id:'omamori_before_publication',module:'abyss_relic_family_combat',
  before:"if remaining>0 then c.omamori=remaining-1;return false,'curse_prevented' end",
  after:'if remaining>0 then c.omamori=remaining-1;return true end',
  probe:`
local C,H,W,S,D=require('abyss_combat'),require('abyss_relic_hooks'),require('abyss_writhing_mass'),require('abyss_sts_random'),require('abyss_data')
local streams={};for _,key in ipairs({'monsterHpRng','aiRng','cardRandomRng','shuffleRng'})do streams[key]=S.fromSeed('42')end
local s=C.new(D,{enemies={'writhing_mass'},deck={},roomSeed='42',roomStreams=streams,
 masterDeck={{uid=9,cardId='strike',upgraded=false}},nextMasterDeckUid=31,
 beforeFirstTurn=function(state)H.bindBattle(state,{'omamori','ceramic_fish','darkstone_periapt'},{omamori=2});return true end})
local uid,count,gold,hp,maximum=s.nextMasterDeckUid,#s.masterDeck,s.player.gold,s.player.hp,s.player.maxHp
W.obtainParasite(s,s.enemies[1])
check(s.relicCounters.omamori==1,'one Omamori charge consumed')
check(s.nextMasterDeckUid==uid and #s.masterDeck==count and s.masterDeckObtains==nil,'blocked Parasite cannot allocate or publish permanent UID')
check(s.player.gold==gold and s.player.hp==hp and s.player.maxHp==maximum,'blocked Parasite cannot run Ceramic Fish or Darkstone health hooks')
`},
];

for(const spec of specs)test(`D5 semantic mutation ${spec.id} is killed by its named real behavior assertion`,()=>{
 const path=`src/lua/${spec.module}.lua`,source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
 assert.equal(source.split(spec.before).length,2,`${spec.id}: unique real mutation site`);
 const mutant=source.replace(spec.before,spec.after);
 const parse=text=>luaparse.parse(Buffer.from(text).toString('latin1'),{luaVersion:'5.3',encodingMode:'pseudo-latin1'});
 assert.doesNotThrow(()=>parse(source));assert.doesNotThrow(()=>parse(mutant),'actual mutant must parse');
 const marker=`[RELIC_D5_MUTATION_ASSERT/${spec.id}]`;
 const driver=text=>`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path\nassert(package.loaded[${luaString(spec.module)}]==nil,'fresh mutation VM')\npackage.preload[${luaString(spec.module)}]=function()return assert(load(${luaString(text)},${luaString('@relic-d5-probe/'+spec.module+'.lua')},'t'))()end\nlocal function check(value,why)assert(value,${luaString(marker+' ')}..why)end\n${spec.probe}\nprint(${luaString('RELIC_D5_PROBE_PASS '+spec.id)})\n`;
 const directory=mkdtempSync(join(tmpdir(),'abyss-relic-d5-mutation-'));
 const evidence=`build/relic-lifecycle/mutations/${spec.id}`;mkdirSync(evidence,{recursive:true});
 try{
  const controlPath=join(directory,'control.lua'),mutantPath=join(directory,'mutant.lua');
  const controlSource=driver(source),mutantSource=driver(mutant);
  writeFileSync(controlPath,controlSource);writeFileSync(mutantPath,mutantSource);
  writeFileSync(`${evidence}/control.lua`,controlSource);writeFileSync(`${evidence}/mutant.lua`,mutantSource);
  const started=Date.now(),control=runLua(controlPath),controlMs=Date.now()-started;
  writeFileSync(`${evidence}/control.stdout.log`,control.stdout);writeFileSync(`${evidence}/control.stderr.log`,control.stderr);
  assert.equal(control.status,0,`${spec.id}: control must execute successfully\n${control.stdout}${control.stderr}`);
  assert(control.stdout.includes(`RELIC_D5_PROBE_PASS ${spec.id}`),'control completed all real behavior assertions');
  const mutantStarted=Date.now(),result=runLua(mutantPath),mutantMs=Date.now()-mutantStarted;
  writeFileSync(`${evidence}/mutant.stdout.log`,result.stdout);writeFileSync(`${evidence}/mutant.stderr.log`,result.stderr);
  const receipt={id:spec.id,module:spec.module,parsed:true,sourceSha256:hash(source),mutantSha256:hash(mutant),
   control:{status:control.status,milliseconds:controlMs,completed:true},mutant:{status:result.status,milliseconds:mutantMs},
   requiredBehaviorAssertion:marker,killed:result.status!==0&&(result.stdout+result.stderr).includes(marker)};
  writeFileSync(`${evidence}/result.json`,JSON.stringify(receipt,null,2)+'\n');
  assert.notEqual(result.status,0,`${spec.id}: semantic mutant survived`);
  assert((result.stdout+result.stderr).includes(marker),`${spec.id}: kill must come from the specified real behavior assertion, not syntax/source identity/infrastructure`);
  assert.equal(hash(readFileSync(path,'utf8').replaceAll('\r\n','\n')),receipt.sourceSha256,'real product source remains unchanged');
 }finally{
  assert.equal(dirname(resolve(directory)),resolve(tmpdir()));assert(basename(directory).startsWith('abyss-relic-d5-mutation-'));
  rmSync(directory,{recursive:true,force:true});
 }
});
