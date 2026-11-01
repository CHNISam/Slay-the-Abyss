-- Controlled inventory component inputs, not naturally acquired potion drops.
-- All damage, kills, rewards and map exits use public production commands.
local F=dofile('tests/lua/support/event_combat_route_fixture.lua')
local Run,N=F.Run,F.N
local function winWithPotions(run)
 for _=1,12 do
  if run.phase~='combat'then break end
  local ok,slot=Run.obtainPotion(run,'explosive_potion');assert(ok,slot)
  assert(Run.usePotion(run,slot))
 end
 assert(run.lastResult.outcome=='victory','public potion damage must produce real victory')
end
local function finish(run,map,gold,ids)
 assert(run.phase=='reward'and run.rewards.gold==gold)
 assert(#run.rewards.relics==#ids)
 local before=run.gold
 assert(Run.claimGoldReward(run));assert(run.gold==before+gold)
 assert(not Run.claimGoldReward(run),'gold is once only')
 for i,id in ipairs(ids)do
  assert(run.rewards.relics[i].id==id)
  assert(Run.claimRelicReward(run,i));assert(not Run.claimRelicReward(run,i),'relic is once only')
 end
 assert(Run.claimCardReward(run,0));assert(Run.leaveCombatRewards(run))
 assert(N.completeCombat(run,map));assert(run.phase=='map'and run.nodeFlow.complete)
 assert(not N.completeCombat(run,map),'terminal event must not complete twice')
 assert(#N.available(run,map)>0,'terminal event must retain a usable map exit')
end
for _,held in ipairs({false,true})do
 local run,map=F.event('42','masked_bandits')
 if held then assert(Run.obtainRelic(run,'red_mask'))end
 assert(N.chooseEvent(run,'fight'))
 local gold=run.eventCombat.gold
 winWithPotions(run)
 finish(run,map,gold,{held and'circlet'or'red_mask'})
end
do
 local run,map=F.event('42','colosseum')
 assert(N.chooseEvent(run,'continue'));assert(N.chooseEvent(run,'fight'))
 winWithPotions(run)
 assert(run.phase=='node'and run.nodeFlow.event.stage=='post_combat'and not run.rewards)
 assert(N.chooseEvent(run,'fight'));assert(run.eventCombat.round==2)
 local ids={run.eventCombat.relics[1].id,run.eventCombat.relics[2].id}
 winWithPotions(run)
 finish(run,map,100,ids)
end
print('EVENT_COMBAT_ROUTE_TERMINAL_PASS public damage victories, exact once-only rewards and usable map exits')
