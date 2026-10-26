package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local count=0
for _,combat in ipairs({false,true}) do
 for _,spec in ipairs({{'blood_potion',80,20,36,80},{'fruit_juice',80,20,25,85}}) do
  local run=Run.new(Data,42);run.maxHp,run.hp=spec[2],spec[3]
  assert(Run.obtainPotion(run,spec[1]));if combat then assert(Run.startCombat(run,'cultist_solo')) end
  local old=run.potions;local preview=Run.potionView(run)[1];assert(preview.canUse and run.potions==old)
  assert(Run.usePotion(run,1));eq(run.hp,spec[4]);eq(run.maxHp,spec[5]);eq(run.potions[1],nil)
  if combat then eq(run.combat.player.hp,run.hp);eq(run.combat.player.maxHp,run.maxHp) end
  count=count+1
 end
end
for _,id in ipairs({'blood_potion','fruit_juice'}) do
 local run=Run.new(Data,42);run.hp=20;run.relics[#run.relics+1]='mark_of_bloom'
 assert(Run.obtainPotion(run,id));assert(Run.usePotion(run,1));eq(run.hp,20);eq(run.maxHp,id=='fruit_juice' and 85 or 80)
 count=count+1
end
local blocked=Run.new(Data,42);assert(Run.obtainPotion(blocked,'blood_potion'))
blocked.phase='node';blocked.node={eventId='WeMeetAgain'}
local ok,reason=Run.usePotion(blocked,1);eq(ok,false);eq(reason,'potion_event_restricted');eq(blocked.potions[1],'blood_potion')
local boundary=Run.new(Data,42);boundary.maxHp=16777219;boundary.hp=1
assert(Run.obtainPotion(boundary,'blood_potion'));assert(Run.usePotion(boundary,1));eq(boundary.hp,3355445)
-- Magic Flower's natural relic acquisition is still outside this slice. Supply
-- its passive definition so the ordinary pre-combat relic snapshot owns it.
local flowerData=C.copy(Data)
flowerData.relics.relics[#flowerData.relics.relics+1]={id='magic_flower',name='Magic Flower',rarity='rare',trigger='passive',effects={}}
local flower=Run.new(flowerData,42);flower.hp=10
flower.relics[#flower.relics+1]='magic_flower'
assert(Run.obtainPotion(flower,'blood_potion'));assert(Run.startCombat(flower,'cultist_solo'))
assert(Run.usePotion(flower,1));eq(flower.hp,34)
local flowerHooks=Run.new(flowerData,42);flowerHooks.hp=10
assert(Run.obtainRelic(flowerHooks,'Toy Ornithopter'));flowerHooks.relics[#flowerHooks.relics+1]='magic_flower'
assert(Run.obtainPotion(flowerHooks,'blood_potion'));assert(Run.startCombat(flowerHooks,'cultist_solo'))
assert(Run.usePotion(flowerHooks,1,nil,function(candidate)
 eq(candidate.player.hp,10);eq(candidate.cardActions[1].effect.value,16)
 eq(candidate.cardActions[2].effect.value,5)
end));eq(flowerHooks.hp,42)
-- Fixed 319009d5 BloodPotion.use queues its HealAction; FruitJuice.use
-- immediately calls increaseMaxHp(5), which heals before onUsePotion hooks.
-- AbstractCreature.heal dispatches onNotBloodied; RedSkull removes its +3.
for _,slot in ipairs({4,5})do
 for _,id in ipairs({'blood_potion','fruit_juice'})do
  local run=Run.new(Data,42)
  assert(Run.obtainRelic(run,'Potion Belt'));assert(Run.obtainRelic(run,'Toy Ornithopter'));assert(Run.obtainRelic(run,'Red Skull'))
  run.hp=id=='blood_potion' and 30 or 39
  for i=1,slot-1 do assert(Run.obtainPotion(run,'block_potion'))end
  local obtained,at=Run.obtainPotion(run,id);assert(obtained);eq(at,slot)
  assert(Run.startCombat(run,'cultist_solo'));local s=run.combat
  eq(s.player.statuses.strength,3);s.events={};local hookCalls=0;local observed
  assert(Run.usePotion(run,slot,nil,function(candidate)
   hookCalls=hookCalls+1
   observed={hp=candidate.player.hp,maxHp=candidate.player.maxHp,strength=candidate.player.statuses.strength or 0,actions=C.copy(candidate.cardActions)}
  end))
  if id=='blood_potion'then
   eq(observed.hp,30);eq(observed.maxHp,80)
   eq(#observed.actions,2);eq(observed.actions[1].effect.op,'heal');eq(observed.actions[1].effect.value,16)
   eq(observed.actions[2].effect.op,'heal');eq(observed.actions[2].effect.value,5)
  else
   eq(observed.hp,44);eq(observed.maxHp,85);eq(observed.strength,0)
   eq(#observed.actions,1);eq(observed.actions[1].effect.op,'heal');eq(observed.actions[1].effect.value,5)
  end
  eq(hookCalls,1);eq(run.potions[slot],nil)
  for i=1,slot-1 do eq(run.potions[i],'block_potion')end
  eq(s.player.hp,id=='blood_potion' and 51 or 49);eq(run.hp,s.player.hp)
  eq(s.player.maxHp,id=='blood_potion' and 80 or 85);eq(run.maxHp,s.player.maxHp)
  eq(s.player.statuses.strength or 0,0);eq(s.relicCombat.redSkullActive,false)
  local trace={}
  for _,e in ipairs(s.events)do
   if e.kind=='heal'then trace[#trace+1]='heal:'..tostring(math.floor(e.detail.amount))
   elseif e.kind=='status' and e.detail.status=='strength'then trace[#trace+1]='strength:'..tostring(math.floor(e.detail.amount))end
  end
  eq(table.concat(trace,','),id=='blood_potion' and 'heal:16,strength:-3,heal:5' or 'heal:5,strength:-3,heal:5')
  count=count+1
 end
end
for _,id in ipairs({'blood_potion','fruit_juice'})do
 local run=Run.new(Data,42);assert(Run.obtainRelic(run,'Red Skull'));run.hp=id=='blood_potion' and 30 or 39
 assert(Run.obtainPotion(run,id));assert(Run.startCombat(run,'cultist_solo'));assert(Run.usePotion(run,1))
 eq(run.combat.player.statuses.strength or 0,0);eq(run.combat.relicCombat.redSkullActive,false)
 count=count+1
end
for _,id in ipairs({'blood_potion','fruit_juice'})do
 for _,event in ipairs({{id='WeMeetAgain'},{id='mapped_event',originalId='WeMeetAgain'}})do
  local run=Run.new(Data,42);run.hp=20;run.phase='node';run.nodeFlow={type='event',event=event}
  assert(Run.obtainPotion(run,id));local potions=run.potions;local before=C.copy(run)
  eq(Run.potionView(run)[1].canUse,false)
  local ok,why=Run.usePotion(run,1);eq(ok,false);eq(why,'potion_event_restricted');eq(run.hp,before.hp);eq(run.maxHp,before.maxHp);eq(run.potions,potions);eq(run.potions[1],id)
  count=count+1
 end
end
local current=Run.new(Data,42);current.hp=20;current.phase='node'
current.node={eventId='WeMeetAgain'};current.nodeFlow={type='event',event={id='cleric'}}
assert(Run.obtainPotion(current,'blood_potion'));assert(Run.usePotion(current,1));eq(current.hp,36);count=count+1
local capped=Run.new(Data,42);capped.hp=79;assert(Run.obtainPotion(capped,'blood_potion'));assert(Run.startCombat(capped,'cultist_solo'))
assert(Run.usePotion(capped,1,nil,function(staged)eq(staged.player.hp,79);eq(staged.cardActions[1].effect.value,16)end));eq(capped.hp,80);count=count+1
print('LUA_POTION_HEALTH_PASS '..(count+4))
