package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local W,C,P,D=require('abyss_watcher_final_cards'),require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data')
local function state()
 local s=C.new(P.prepare(D,'watcher'),{seed=1,cardRandomSeed='1',shuffleSeed='1',enableStances=true,deck={'empty_body'},enemies={'cultist'}})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;s.energy=10
 return s
end
-- Caller supplied queue preserves TOP order and the partial first enqueue on failure.
do
 local s=state();local sentinel={stage='second TOP'};s.sentinel=sentinel;s.trace={}
 local q={pushTop=function(owner,item)
  owner.trace[#owner.trace+1]=item
  if #owner.trace==2 then error(sentinel,0)end
 end}
 local ok,why=pcall(W.execute,C,s,{op='watcherFinalDeusExMachina',uid=s.hand[1].uid,value=2},q)
 assert(not ok and why==sentinel and #s.trace==2,'exact TOP failure identity')
 assert(s.trace[1].effect.op=='makeTempCard' and s.trace[2].effect.op=='exhaustHand','Deus TOP order')
end
-- The legacy non-queue path remains supported and moves the actual held object.
do
 local s=state();local held=s.hand[1]
 assert(W.execute(C,s,{op='watcherFinalDeusExMachina',uid=held.uid,value=2}))
 assert(s.exhaust[1]==held and #s.hand==0,'legacy Deus retains card alias')
end
-- Choice opening deliberately retains its partial state if the event sink fails.
do
 local s=state();s.pendingPlay={uid=99};local sentinel={stage='choice event'};s.sentinel=sentinel
 local Events=require('abyss_events');local emit=Events.emit
 Events.emit=function(owner,kind,payload)emit(owner,kind,payload);if kind=='card_choice'then error(sentinel,0)end end
 local ok,why=pcall(W.execute,C,s,{op='watcherFinalWish',value=1});Events.emit=emit
 assert(not ok and why==sentinel and s.pendingChoice.using==99 and s.choiceSerial==1,'choice late failure state')
 assert(s.pendingChoice.cards[1].upgraded and s.pendingChoice.kind=='wish')
end
-- Public dynamic capabilities and delegate multi-returns cannot be snapshotted.
do
 local s=state();local Actor=require('abyss_actor');local apply=Actor.applyPower
 local marker={};s.marker=marker
 W.availablePowers.test_power=true
 Actor.applyPower=function(owner,actor,status,value,source)
  assert(owner==s and actor==s.player and source==s.player and status=='test_power' and value==7)
  owner.observed=marker
 end
 assert(W.execute(C,s,{op='gainWatcherFinalPower',status='test_power',value=7}))
 Actor.applyPower=apply;W.availablePowers.test_power=nil
 assert(s.observed==marker,'mutable availablePowers and dynamic Actor API')
 local Pile=require('abyss_pile_choice');local begin=Pile.begin
 Pile.begin=function(owner,kind,count,generation,combat)
  assert(owner==s and kind=='omniscience' and count==1 and generation==0 and combat==C)
  return false,'refused',marker
 end
 local a,b,c=W.execute(C,s,{op='watcherFinalOmniscience',value=9});Pile.begin=begin
 assert(a==false and b=='refused' and c==marker,'pile delegate exact multi-return')
end
-- A failure after damage is not relocated before the damage call.
do
 local s=state();s.pendingPlay={targetId=s.enemies[1].id};local sentinel={stage='post damage'};s.sentinel=sentinel
 local damage=C.damage
 C.damage=function(...)damage(...);error(sentinel,0)end
 local ok,why=pcall(W.execute,C,s,{op='watcherFinalLessonLearned',value=10});C.damage=damage
 assert(not ok and why==sentinel and s.enemies[1].hp==990,'partial damage failure identity')
end
-- Omega is also a direct executor operation, independent of power scheduling.
do
 local s=state()
 assert(W.execute(C,s,{op='watcherFinalOmega',value=7}))
 assert(s.enemies[1].hp==993,'Omega retaliation uses the active enemy')
end
-- Actor loading must precede the sole effect-op read, even for a flag effect.
do
 local execute=WATCHER_EXECUTE_UNOBSERVED or W.execute
 local s=state();local events={};local original=require
 require=function(name)if name=='abyss_actor'then events[#events+1]='Actor'end;return original(name)end
 local effect=setmetatable({},{__index=function(_,key)
  assert(key=='op');events[#events+1]='op';return 'watcherFinalEndTurnEarly'
 end})
 assert(execute(C,s,effect));require=original
 assert(#events==2 and events[1]=='Actor' and events[2]=='op' and s.endTurnAfterCard,'require before one op read')
 local Pile=require('abyss_pile_choice');local begin=Pile.begin;local marker={}
 Pile.begin=function()return nil,marker,nil,4 end
 local result=table.pack(execute(C,s,{op='watcherFinalMeditate',value=1}));Pile.begin=begin
 assert(result.n==4 and result[1]==nil and result[2]==marker and result[3]==nil and result[4]==4,'nil-hole delegate multi-return')
 local sentinel={stage='Actor load'}
 require=function(name)if name=='abyss_actor'then error(sentinel,0)end;return original(name)end
 local ok,why=pcall(execute,C,s,effect);require=original
 assert(not ok and why==sentinel and #events==2,'Actor load fails before another op read')
end
print('WATCHER_EXECUTION_BOUNDARIES queue order, partial failures, aliases, dynamic capabilities and delegated multi-return passed')
