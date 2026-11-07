package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local A=require('abyss_actor')
local Moves=require('abyss_act2_ai_moves')
local Summons=require('abyss_act2_summons')
local Discard=require('abyss_silent_discard_cards')
local function graph(label,value)if PRESENCE_GRAPH_WRITE then PRESENCE_GRAPH_WRITE(value,label)end end
local active,present=A.isActive,A.isPresent
assert(active(nil)==false and present(nil)==false,'nil actor is absent')
assert(active({hp=1})==true and active({hp=0})==false,'positive HP targetability')
for _,key in ipairs({'escaped','halfDead','isDying'})do
 local actor={hp=1,[key]=true};assert(active(actor)==false,'inactive flag '..key)
end
local token={rebirth='same object'}
assert(present({hp=0,halfDead=token})==token,'half-dead presence retains truthy value')
assert(present({hp=0,awakenedRebirthPending=token})==token,'rebirth presence retains truthy value')
assert(present({hp=0})==false and present({hp=1,escaped=true})==false and present({hp=1,isDying=true})==false,'absent encounters')
local rows={}
for _,hp in ipairs({-1,0,1})do for _,escaped in ipairs({false,true})do for _,dead in ipairs({false,true})do
 for _,dying in ipairs({false,true})do for _,rebirth in ipairs({false,token})do
  local actor={hp=hp,escaped=escaped,halfDead=dead,isDying=dying,awakenedRebirthPending=rebirth}
  rows[#rows+1]={actor=actor,active=active(actor),present=present(actor)}
 end end
end end end
graph('predicate domain',{rows=rows,token=token})
local reads={};local failure={fault='hp access'}
local proxy=setmetatable({}, {__index=function(_,key)reads[#reads+1]=key;if key=='hp'then error(failure,0)end end})
local ok,err=pcall(active,proxy);assert(not ok and err==failure,'predicate exception identity')
assert(table.concat(reads,',')=='hp','active lookup order')
reads={};ok,err=pcall(present,proxy);assert(not ok and err==failure,'presence exception identity')
assert(table.concat(reads,',')=='escaped,isDying,hp','presence lookup order')
graph('read order and failure',{reads=reads,result=table.pack(ok,err),sentinel=failure})
-- All consumers use the same ordinary slot, including replacement mid-loop.
local first,second={id='first',hp=10,maxHp=20},{id='second',hp=1,maxHp=30}
local state={enemies={first,second}};local calls={}
A.isActive=function(actor)
 calls[#calls+1]=actor.id
 A.isActive=function(nextActor)calls[#calls+1]='new '..nextActor.id;return false end
 return true
end
assert(Moves.mystic({state=state,enemy={act2Last='buff'},roll=0})=='buff','decision reads replacement within loop')
assert(table.concat(calls,',')=='first,new second','query not captured per invocation')
assert(active(first)==true,'saved original predicate retains body')
graph('dynamic AI traversal',{state=state,calls=calls})
A.isActive=setmetatable({}, {__call=function(_,actor)return actor==first end})
assert(Moves.centurion({state=state,enemy={},roll=99})=='fury','callable query table is supported')
A.isActive=false;assert(A.isActive==false and not pcall(Moves.centurion,{state=state,enemy={},roll=99}),'false query is not a fallback')
A.isActive=nil;assert(A.isActive==nil and not pcall(Moves.centurion,{state=state,enemy={},roll=99}),'nil query is not a fallback')
A.isActive=active
A.presenceUnrelated=token;assert(rawget(A,'presenceUnrelated')==token,'unrelated Actor fields remain ordinary');A.presenceUnrelated=nil
local leader={act2GremlinSlots={'first','second'}}
local summonState={enemies={first,second},seed=7};local captured,created
A.isActive=function(actor)return actor==second end
local api={random=function(s,n)s.draws=(s.draws or 0)+1;assert(n==8);return 1 end,
 summonEnemies=function(_,descriptors)captured=descriptors;created={{id='new1'},{id='new3'}};return created end}
Summons.rally(api,summonState,leader)
assert(summonState.draws==2 and #captured==2 and captured[1].slot==1 and captured[2].slot==3,'summon vacant slots and RNG order')
assert(leader.act2GremlinSlots[1]=='new1' and leader.act2GremlinSlots[2]=='second' and leader.act2GremlinSlots[3]=='new3','summon publishes returned slots')
graph('summon planning',{state=summonState,leader=leader,descriptors=captured,created=created})
local originalSlots={'first','second'};leader.act2GremlinSlots=originalSlots
local thrown={fault='summon failure'};api.summonEnemies=function(s,descriptors)s.descriptors=descriptors;error(thrown,0)end
ok,err=pcall(Summons.rally,api,summonState,leader)
assert(not ok and err==thrown and leader.act2GremlinSlots==originalSlots and #originalSlots==2,'summon failure does not commit slots')
graph('summon failure',{state=summonState,leader=leader,returned=table.pack(ok,err),sentinel=thrown})
A.isActive=active
local C=require('abyss_combat');local Data=require('abyss_data')
local s=C.new(Data,{enemies={'jaw_worm'},deck={},seed=42});s.discardedThisTurn=1
local oldEnergy=s.energy;s.player.hp=0;assert(Discard.gainEnergyIfDiscard(s,2)==false and s.energy==oldEnergy,'dead player receives no refund')
s.player.hp=10;s.enemies[1].hp=0;s.enemies[1].halfDead=token
assert(Discard.gainEnergyIfDiscard(s,2)==true and s.energy==oldEnergy+2,'present half-dead enemy keeps refund')
local callsPresent={};A.isPresent=function(actor)callsPresent[#callsPresent+1]=actor;return false end
assert(Discard.gainEnergyIfDiscard(s,2)==false,'discard uses replaced presence predicate')
graph('discard presence',{state=s,calls=callsPresent})
A.isPresent=function()error(thrown,0)end
local previous=s.energy;ok,err=pcall(Discard.gainEnergyIfDiscard,s,2)
assert(not ok and err==thrown and s.energy==previous,'refund query failure precedes energy mutation')
graph('discard failure',{state=s,returned=table.pack(ok,err),sentinel=thrown})
A.isPresent=present
local b={misc={integer=function(lo,hi)assert(lo==0 and hi==7);return 0 end}}
local live=C.new(Data,{deck={},seed=42,hp=500,maxHp=500,sourceEncounter='Gremlin Leader',encounterBoundary=b})
local realLeader=live.enemies[3];live.enemies[1].hp=0;live.enemies[2].hp=0
require('abyss_enemy_ai').advance(live,realLeader,function(_,maximum)assert(maximum==100);return 1 end)
assert(realLeader.intents[realLeader.intentIndex].id=='rally','real Leader chooses rally from liveness')
assert(C.endTurn(live));local count=0;for _,enemy in ipairs(live.enemies)do if enemy~=realLeader and A.isActive(enemy)then count=count+1 end end
assert(count==2,'real rally restores two minions')
graph('real summon transaction',{state=live,leader=realLeader})
print('ok Actor presence predicates, dynamic slots, AI/summon/refund boundaries')
