package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local W,A=require('abyss_watcher_final_cards'),require('abyss_actor')
local function state()
 local c={uid=1,cardId='strike_p',retain=true}
 return {player={statuses={}},enemies={},hand={c},draw={},masterDeck={c},nextUid=2,
  pendingPlay={uid=1,targetId=1,energyOnUse=2},cardInUse=c,energy=3,events={}}
end
local function attempt(combat,s,e,q)
 local returned=table.pack(pcall(W.execute,combat,s,e,q))
 WATCHER_GRAPH_WRITE({state=s,effect=e,returned=returned[1],value=type(returned[2])=='table' and returned[2] or nil},'edge-complete')
 return table.unpack(returned,1,returned.n)
end
local sentinel={kind='injected failure'}
do
 local s=state();local ok,why=attempt({},s,{op='unsupported'})
 assert(not ok and why:find('unsupported Watcher final effect: unsupported',1,true))
 ok,why=attempt({},s,{op='gainWatcherFinalPower',status='invalid',value=1})
 assert(not ok and why:find('unsupported Watcher final Power',1,true))
 s.player.statuses.deva_form=2;s.devaEnergyGain=3
 local previous=A.applyPower;A.applyPower=function()error(sentinel,0)end
 ok,why=attempt({},s,{op='gainWatcherFinalPower',status='deva_form',value=1})
 A.applyPower=previous;assert(not ok and why==sentinel and s.devaEnergyGain==4)
end
do
 local s=state();s.pendingChoice={token=7};local pending=s.pendingChoice
 local ok=attempt({},s,{op='watcherFinalWish',value=1})
 assert(not ok and s.pendingChoice==pending and not s.choiceSerial)
 s.pendingChoice=nil;s.pendingPlay=nil;ok=attempt({},s,{op='watcherFinalWish',value=1})
 assert(not ok and s.choiceSerial==1 and not s.pendingChoice)
end
do
 local s=state();local effects={};local queue={pushTop=function(current,entry)
  assert(current==s);table.insert(effects,1,entry);current.effects=effects
 end}
 assert(W.execute({},s,{op='watcherFinalDeusExMachina',uid=1,value=2},queue))
 assert(effects[1].effect.op=='exhaustHand' and effects[2].effect.op=='makeTempCard')
 local ok=attempt({},s,{op='watcherFinalDamageHit',remaining=2,targetId=1,value=3})
 assert(not ok)
end
do
 local s=state();local actions=require('abyss_card_actions')
 local enqueue,exhaust=actions.enqueue,actions.exhaust
 actions.enqueue=function(current,e)current.enqueued=e end
 actions.exhaust=function(_,current,c)current.exhausted=c;error(sentinel,0)end
 local ok,why=attempt({},s,{op='watcherFinalDeusExMachina',uid=1,value=2})
 assert(not ok and why==sentinel and #s.hand==0 and s.exhausted==s.masterDeck[1] and s.enqueued.card=='miracle')
 s=state();assert(W.execute({},s,{op='watcherFinalDeusExMachina',uid=999,value=1}))
 assert(#s.hand==1 and not s.exhausted and s.enqueued)
 actions.enqueue,actions.exhaust=enqueue,exhaust
end
do
 local pile=require('abyss_pile_choice');local begin=pile.begin
 for _,mode in ipairs({'watcherFinalMeditate','watcherFinalOmniscience'})do
  for _,value in ipairs({false,'pause'})do
   pile.begin=function(s,kind,n,g,c) s.observed={kind=kind,n=n,generation=g,combat=c};return value,nil,s end
   local s=state();local combat={};local result=table.pack(W.execute(combat,s,{op=mode,value=2}))
   assert(result.n==3 and result[1]==value and result[2]==nil and result[3]==s)
  end
 end
 pile.begin=function()return nil end
 local result=table.pack(W.execute({},state(),{op='watcherFinalMeditate',value=2}));assert(result.n==1 and result[1]==nil)
 pile.begin=begin
end
do
 local s=state();local def={selfRetain=true,cost=2}
 local combat={cardDefinition=function()return def end,combatBaseCost=function()return 2 end}
 s.hand[1].turnCost=0;assert(W.execute(combat,s,{op='watcherFinalEstablishment',value=1}));assert(s.hand[1].combatCost==1 and s.hand[1].turnCost==0)
 s.hand[1].turnCost=2;assert(W.execute(combat,s,{op='watcherFinalEstablishment',value=3}));assert(s.hand[1].combatCost==0 and s.hand[1].turnCost==0)
 def.costMode='X';s.hand[1].combatCost=7;assert(W.execute(combat,s,{op='watcherFinalEstablishment',value=3}));assert(s.hand[1].combatCost==7)
end
do
 local s=state();local enemy={id=1,hp=3,statuses={},maxHp=3};s.enemies={enemy};s.miscRng=require('abyss_sts_random').fromSeed('2')
 local combat={damage=function(_,_,e)e.hp=0 end,canUpgrade=function()return true end,
  upgrade=function(_,c)c.upgraded=true;error(sentinel,0)end,copy=function()error('copy must not run')end}
 local ok,why=attempt(combat,s,{op='watcherFinalLessonLearned',value=3})
 assert(not ok and why==sentinel and s.masterDeck[1].upgraded and not s.masterDeckChanges)
 enemy.hp=3;enemy.halfDead=true;assert(W.execute(combat,s,{op='watcherFinalLessonLearned',value=3}))
 enemy.halfDead=nil;enemy.hp=3;enemy.statuses.minion=1;assert(W.execute(combat,s,{op='watcherFinalLessonLearned',value=3}))
 enemy.statuses.minion=nil;enemy.hp=3;combat.canUpgrade=function()return false end
 assert(W.execute(combat,s,{op='watcherFinalLessonLearned',value=3}))
end
do
 local s=state();s.enemies={{id=1,hp=1,statuses={}},{id=2,hp=0,statuses={}}}
 local combat={retaliate=function(current,from,enemy,value)
  assert(from==nil and enemy==current.enemies[1]);current.omega={enemy=enemy,value=value}
 end}
 assert(W.execute(combat,s,{op='watcherFinalOmega',value=50}));assert(s.omega.value==50)
end
print('WATCHER_EXECUTION_EDGES partial writes, aliases, owner replacement, queue order and exact return arity passed')
