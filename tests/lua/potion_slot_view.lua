local Run,Data=require('abyss_run'),require('abyss_data')
local Candidate=require('abyss_run_potion_candidate')
assert(type(Run.potionSlotView)=='function','fresh single-slot potion API missing')
local function same(a,b)
 assert(type(a)==type(b),'view type mismatch')
 if type(a)~='table'then assert(a==b,'view value mismatch');return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'extra view key')end
end
local function preserveGraph(root)
 local saved={};local function remember(v)
  if type(v)~='table' or saved[v]then return end
  local copy={};saved[v]=copy;for k,item in pairs(v)do copy[k]=item;remember(k);remember(item)end
 end;remember(root)
 return function()
  for original,copy in pairs(saved)do
   for k,v in pairs(original)do assert(copy[k]==v,'live run/RNG value changed')end
   for k,v in pairs(copy)do assert(original[k]==v,'live run/RNG value removed')end
  end
 end
end
local run=Run.new(Data,42);assert(Run.startCombat(run,'cultist_solo'))
-- Every registered potion uses the exact complete original row, including sparse slots.
local count=0
for _,potion in ipairs(Data.potions.potions)do
 run.potions={[2]=potion.id};local unchanged=preserveGraph(run)
 local whole=Run.potionView(run);local row=Run.potionSlotView(run,2)
 same(row,whole[2]);assert(whole[1]==nil and whole[3]==nil and row.slot==2)
 unchanged();count=count+1
end
print('POTION_SLOT_VIEW parity all registered potions='..count)
local prepare=Candidate.prepare;local calls={}
Candidate.prepare=function(r,slot,...)
 calls[#calls+1]=slot;return prepare(r,slot,...)
end
run.potions={'block_potion','energy_potion','fire_potion'}
local row=Run.potionSlotView(run,2)
assert(row.id=='energy_potion' and #calls==1 and calls[1]==2,'single-slot query simulated other inventory slots')
calls={};local full=Run.potionView(run)
assert(#calls==3 and calls[1]==1 and calls[2]==2 and calls[3]==3,'full view traversal changed')
for slot=1,3 do same(Run.potionSlotView(run,slot),full[slot])end
calls={}
for _,case in ipairs({{nil},{false},{'1'},{0},{-1},{1.5},{4},{math.huge},{-math.huge},{0/0},{{}}})do
 assert(Run.potionSlotView(run,case[1])==nil,'invalid slot accepted')
end
assert(#calls==0,'invalid slot simulated a potion')
run.potions={[3]='fire_potion'};assert(Run.potionSlotView(run,2)==nil and #calls==0)
Candidate.prepare=prepare
-- Rows remain detached, and in-place model changes must be observed immediately.
run.potions={'block_potion','energy_potion','not_a_potion'}
local first=Run.potionSlotView(run,1);assert(first.canUse)
local potency=first.effects[1].value;first.effects[1].value=-999
assert(Run.potionSlotView(run,1).effects[1].value==potency,'returned effects alias definition or cached row')
run.combat.player.block=2147483647
local changed=Run.potionSlotView(run,1);assert(not changed.canUse and changed.reason=='effect_overflow')
run.combat.player.block=0;assert(Run.potionSlotView(run,1).canUse)
run.combat.energy=2147483647;assert(not Run.potionSlotView(run,2).canUse)
run.combat.energy=3;run.combat.pendingChoice={}
assert(Run.potionSlotView(run,1).reason=='card_choice_pending');run.combat.pendingChoice=nil
same(Run.potionSlotView(run,3),Run.potionView(run)[3]);assert(not Run.potionSlotView(run,3).canUse)
run.potions[1]='fairy_in_a_bottle';assert(Run.potionSlotView(run,1).reason=='automatic_potion')
run.nodeFlow={event={id='WeMeetAgain'}}
assert(Run.potionSlotView(run,2).reason=='potion_event_restricted')
print('POTION_SLOT_VIEW_PASS full/slot parity; sparse/invalid; detached; fresh states')

-- Capacity and outside-combat effects retain full-view behavior.
run.nodeFlow=nil;run.phase='map';run.potionSlots=5;run.potions={[5]='fruit_juice'}
local unchanged=preserveGraph(run)
same(Run.potionSlotView(run,5),Run.potionView(run)[5]);assert(Run.potionSlotView(run,5).canUse)
assert(Run.potionSlotView(run,6)==nil);unchanged()
-- Do not replace full target search with the first active enemy.
run.phase='combat';run.potions={[2]='poison_potion'}
local Combat=require('abyss_combat');local firstEnemy=run.combat.enemies[1]
local second=Combat.copy(firstEnemy);second.id='second_target';run.combat.enemies[2]=second
firstEnemy.statusDefinitions=Combat.copy(firstEnemy.statusDefinitions);firstEnemy.statusDefinitions.poison=nil
local targets={};Candidate.prepare=function(r,slot,index,...)
 targets[#targets+1]=index;return prepare(r,slot,index,...)
end
local targetView=Run.potionSlotView(run,2)
Candidate.prepare=prepare
assert(targetView.canUse and #targets==2 and targets[1]==1 and targets[2]==2,'later legal enemy was not searched')
print('POTION_SLOT_VIEW_PASS expanded capacity/outside/later legal target')
