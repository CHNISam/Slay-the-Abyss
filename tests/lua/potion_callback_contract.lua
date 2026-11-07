package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Hooks=require('abyss_relic_hooks')
local Actor=require('abyss_actor')
local Reactions=require('abyss_combat_reactions')
local function observe(value,label)
 if POTION_GRAPH_WRITE then POTION_GRAPH_WRITE(value,label,true)end
end
local function owner(hp,relics)
 local shared=setmetatable({value=19},{label='shared metadata'})
 local r={hp=hp,maxHp=80,relics=relics or {},phase='map',a=shared,b=shared}
 r.self=r;return r
end
-- Keep the exact live identities, every raw field, table key and metatable.
-- Unlike a structural copy this detects replacement by an equal-looking table.
local function unchanged(root)
 local records={}
 local function visit(value)
  if type(value)~='table'or records[value]then return end
  local record={fields={},meta=getmetatable(value),count=0};records[value]=record
  for key,item in next,value do record.fields[key]=item;record.count=record.count+1;visit(key);visit(item)end
  visit(record.meta)
 end
 visit(root)
 return function()
  for object,record in pairs(records)do
   assert(getmetatable(object)==record.meta,'rollback preserves exact metatables')
   local count=0
   for key,item in next,object do count=count+1;assert(record.fields[key]==item,'rollback preserves every raw field and identity')end
   assert(count==record.count,'rollback preserves complete field inventory')
  end
 end
end
local original=Hooks.onUsePotion
local absent=owner(20);local emptyCombat={}
local emptyReturned=table.pack(original(absent,emptyCombat))
assert(emptyReturned.n==0 and next(emptyCombat)==nil,'unowned Toy exits without reading missing combat.player')
observe({owner=absent,state=emptyCombat,returned=emptyReturned},'unowned absent combat player')
local results={}
for _,relics in ipairs({{}, {'toy_ornithopter'}, {'Toy Ornithopter'},
 {'toy_ornithopter','magic_flower'}, {'toy_ornithopter','mark_of_bloom'},
 {'Toy Ornithopter','Mark of the Bloom'}, {'magic_flower','toy_ornithopter','mark_of_bloom'}})do
 for _,phase in ipairs({'map','combat'})do
  for _,hp in ipairs({0,20,79,80})do
   local r=owner(hp,relics);r.phase=phase
   local returned=table.pack(Hooks.onUsePotion(r))
   local toy=Hooks.owns(r,'toy_ornithopter')
   local blocked=require('abyss_potion_health').blocked(relics)
   assert(r.hp==(toy and not blocked and math.min(80,hp+5)or hp),'outside Toy heals five without Flower and honors Bloom/clamp')
   assert(returned.n==0 and r.a==r.b and r.self==r,'outside callback return count and aliases')
   results[#results+1]={state=r,returned=returned}
  end
 end
end
observe(results,'outside Toy matrix complete owners')
-- Both predicate tables are looked up at invocation time, including a retained
-- callback value. Exceptions retain their actual objects, fields and aliases.
local owns,active=Hooks.owns,Actor.isActive
local r=owner(20);local calls={}
Hooks.owns=function(o,id)assert(o==r and id=='toy_ornithopter');calls[#calls+1]={o,id};return true end
local returned=table.pack(original(r))
assert(r.hp==25 and #calls==1 and returned.n==0,'saved callback reads dynamic Hooks.owns')
observe({state=r,calls=calls,returned=returned},'dynamic owns true')
Hooks.owns=function()return false end
local state={player={hp=20,maxHp=80},relics={'toy_ornithopter'}}
Actor.isActive=function()error('ownership guard must precede Actor predicate')end
returned=table.pack(original(r,state))
assert(not state.cardActions and returned.n==0,'ownership false exits before Actor predicate')
observe({state=state,owner=r,returned=returned},'dynamic owns false')
local failure=setmetatable({kind='predicate failure',owner=r},{tag='error metadata'})
failure.self=failure
Hooks.owns=function()error(failure,0)end
returned=table.pack(pcall(original,r,state))
assert(not returned[1]and returned[2]==failure and not state.cardActions,'owns error object identity')
observe({state=state,owner=r,returned=returned,error=failure},'owns error object')
Hooks.owns=owns;Actor.isActive=active
r=owner(20,{'toy_ornithopter'})
for _,spec in ipairs({{hp=0},{hp=20,escaped=true},{hp=20,halfDead=true},{hp=20,isDying=true}})do
 local s={player=spec,relics=r.relics};local check=unchanged(s)
 local tuple=table.pack(original(r,s));check()
 assert(tuple.n==0 and not s.cardActions,'inactive player never receives queued Toy healing')
 observe({state=s,owner=r,returned=tuple},'inactive player guard')
end
state={player={hp=20,maxHp=80},relics=r.relics}
Actor.isActive=function(a)assert(a==state.player);calls[#calls+1]=a;return false end
returned=table.pack(original(r,state))
assert(not state.cardActions and returned.n==0,'saved callback reads dynamic Actor predicate')
observe({state=state,owner=r,calls=calls,returned=returned},'dynamic Actor false')
Actor.isActive=function()error(failure,0)end
returned=table.pack(pcall(original,r,state))
assert(not returned[1]and returned[2]==failure and not state.cardActions,'Actor error object identity')
observe({state=state,owner=r,returned=returned,error=failure},'Actor error object')
Actor.isActive=active
local enqueue=Reactions.enqueue
local reactionCalls={}
Reactions.enqueue=function(s,e,source,...)
 reactionCalls[#reactionCalls+1]=table.pack(s,e,source,...)
 return enqueue(s,e,source,...)
end
returned=table.pack(original(r,state));Reactions.enqueue=enqueue
assert(#reactionCalls==1 and reactionCalls[1].n==3,'live Reactions callback receives original arity')
assert(state.player.hp==20 and #state.cardActions==1 and returned.n==0,'Toy callback queues instead of healing immediately')
local action=state.cardActions[1]
assert(action.effect.op=='heal'and action.effect.value==5 and action.effect.relic=='toy_ornithopter','Toy queues raw five')
assert(action.source==state.player and action.target==nil and action.instance==nil,'queued action keeps player source identity')
observe({state=state,owner=r,returned=returned,calls=reactionCalls},'queued Toy complete action and aliases')
-- Outside legacy arithmetic also keeps its original field access/write order.
local backing=owner(20,{'toy_ornithopter','magic_flower'});local accesses={}
local proxy=setmetatable({}, {__index=function(_,key)accesses[#accesses+1]={'read',key};return backing[key]end,
 __newindex=function(_,key,value)accesses[#accesses+1]={'write',key,value};backing[key]=value end})
returned=table.pack(original(proxy));assert(backing.hp==25 and returned.n==0)
observe({proxy=proxy,backing=backing,accesses=accesses,returned=returned},'outside complete proxy accesses')
local blocked=require('abyss_potion_health').blocked
require('abyss_potion_health').blocked=function()error(failure,0)end
returned=table.pack(pcall(original,r));require('abyss_potion_health').blocked=blocked
assert(not returned[1]and returned[2]==failure and r.hp==20,'outside block error retains object without HP mutation')
observe({state=r,error=failure,returned=returned},'outside error object')

local Run,Combat,Data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local Inventory,Actions=require('abyss_inventory'),require('abyss_card_actions')
local base=Run.new(Data,42);base.hp=20
assert(Run.obtainRelic(base,'Toy Ornithopter'))
assert(Run.obtainPotion(base,'blood_potion'))
assert(Run.startCombat(base,'cultist_solo'))
-- Complete roots include every RNG, catalog, event, queue and persistent field.
observe(base,'live base before potion')
for _,relic in ipairs({'none','magic_flower','mark_of_bloom'})do
 local live=Combat.copy(base)
 if relic~='none'then live.relics[#live.relics+1]=relic;live.combat.relics[#live.combat.relics+1]=relic end
 local trace={};local apply,drain=Inventory.apply,Actions.drain
 Inventory.apply=function(...)
  trace[#trace+1]='effect';return apply(...)
 end
 Hooks.onUsePotion=function(o,candidate)
  trace[#trace+1]='hook';assert(o==live and candidate.potionInventory[1]=='blood_potion','callback precedes physical slot release')
  return original(o,candidate)
 end
 Actions.drain=function(c,candidate)
  trace[#trace+1]='drain';assert(candidate.potionInventory[1]==nil,'drain observes released slot')
  return drain(c,candidate)
 end
 local savedRoot=live.combat
 local tuple=table.pack(pcall(Run.usePotion,live,1,nil,function(candidate)
  trace[#trace+1]='caller'
  assert(candidate.potionInventory[1]==nil and candidate.player.hp==20,'slot release precedes caller; queued healing waits for drain')
  assert(#candidate.cardActions==2 and candidate.cardActions[1].effect.value==16 and candidate.cardActions[2].effect.value==5,'Blood then Toy preserve queue order and raw values')
  observe({live=live,candidate=candidate,trace=trace},'candidate before drain '..relic)
 end))
 Inventory.apply,Actions.drain,Hooks.onUsePotion=apply,drain,original
 assert(tuple.n==2 and tuple[1]and tuple[2],'ordinary potion use returns true')
 assert(table.concat(trace,',')=='effect,hook,caller,drain','effect hook release caller drain order')
 local expected=({none=41,magic_flower=52,mark_of_bloom=20})[relic]
 assert(live.hp==expected and live.combat.player.hp==expected and live.potions[1]==nil,'drain applies combat Flower/Bloom exactly once')
 assert(live.combat==savedRoot,'successful potion retains live battle root')
 observe({state=live,returned=tuple,trace=trace},'committed potion '..relic)
end
-- Failure after the complete drain must leave the complete live graph intact,
-- including physical-slot ownership and all random streams, not selected fields.
for _,where in ipairs({'hook','caller','drain'})do
 local live=Combat.copy(base);local check=unchanged(live);local drain=Actions.drain
 local staged;local fault=setmetatable({kind='late potion failure',where=where},{tag='late failure metadata'});fault.self=fault
 Hooks.onUsePotion=function(o,candidate)
  staged=candidate;original(o,candidate)
  if where=='hook'then error(fault,0)end
 end
 Actions.drain=function(c,candidate)
  drain(c,candidate)
  if where=='drain'then assert(candidate.player.hp==41,'late failure occurs after actual healing');error(fault,0)end
 end
 observe(live,'rollback live before '..where)
 local tuple=table.pack(Run.usePotion(live,1,nil,function(candidate)
  assert(candidate.potionInventory[1]==nil)
  if where=='caller'then error(fault,0)end
 end))
 Hooks.onUsePotion,Actions.drain=original,drain
 assert(tuple.n==2 and tuple[1]==false and tuple[2]=='potion_effect_failed','staged callback failure retains public refusal tuple')
 check();observe({live=live,staged=staged,returned=tuple,error=fault},'complete rollback '..where)
end
-- Outside errors escape with the exact object; combat errors become the ordinary
-- refusal tuple. Both paths retain live aliases and all fields.
local outside=Run.new(Data,42);outside.hp=20;outside.relics={'toy_ornithopter'}
assert(Run.obtainPotion(outside,'blood_potion'))
local check=unchanged(outside)
Hooks.onUsePotion=function(candidate)candidate.hp=77;error(failure,0)end
returned=table.pack(pcall(Run.usePotion,outside,1));Hooks.onUsePotion=original
assert(returned.n==2 and not returned[1]and returned[2]==failure,'outside callback preserves exact escaping error object')
check();observe({state=outside,returned=returned,error=failure},'outside callback rollback')
for _,kind in ipairs({'nil','false'})do
 local battle,room=Combat.copy(base),Combat.copy(outside)
 local battleCheck,roomCheck=unchanged(battle),unchanged(room)
 if kind=='nil'then Hooks.onUsePotion=nil else Hooks.onUsePotion=false end
 local combatResult=table.pack(pcall(Run.usePotion,battle,1))
 local outsideResult=table.pack(pcall(Run.usePotion,room,1))
 Hooks.onUsePotion=original
 assert(combatResult.n==3 and combatResult[1]and combatResult[2]==false and combatResult[3]=='potion_effect_failed','noncallable combat slot becomes ordinary refusal')
 assert(outsideResult.n==2 and not outsideResult[1]and type(outsideResult[2])=='string'and outsideResult[2]:find('attempt to call a '..(kind=='nil'and'nil'or'boolean')..' value',1,true),'noncallable outside slot error escapes unchanged')
 battleCheck();roomCheck()
 observe({battle=battle,room=room,combatResult=combatResult,outsideResult=outsideResult},'noncallable slot '..kind)
end
local callable=setmetatable({calls={}},{__call=function(self,o,candidate)
 self.calls[#self.calls+1]=table.pack(o,candidate)
 return nil,'callable return',false,o
end})
Hooks.onUsePotion=callable
local direct=owner(20,{'toy_ornithopter'})
local directResult=table.pack(Hooks.onUsePotion(direct))
assert(directResult.n==4 and directResult[1]==nil and directResult[2]=='callable return'and directResult[3]==false and directResult[4]==direct,'callable slot preserves exact return tuple')
assert(original(direct)==nil and direct.hp==25,'saved original remains callable after public replacement')
local battle,room=Combat.copy(base),Combat.copy(outside)
local combatResult=table.pack(Run.usePotion(battle,1));local outsideResult=table.pack(Run.usePotion(room,1))
Hooks.onUsePotion=original
assert(combatResult.n==1 and combatResult[1]and outsideResult.n==1 and outsideResult[1]and #callable.calls==3,'both Candidate paths read current callable slot')
assert(battle.hp==36 and room.hp==36,'replacement callback suppresses original Toy healing')
observe({callable=callable,direct=direct,returned=directResult,battle=battle,room=room,combatResult=combatResult,outsideResult=outsideResult},'callable and saved callbacks')
assert(Hooks.onUsePotion==original and Hooks.owns==owns and Actor.isActive==active and Reactions.enqueue==enqueue)
print('POTION_CALLBACK_CONTRACT_PASS')
