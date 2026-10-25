return function(first,last,cardFirst,cardLast)
first,last=first or 1,last or math.huge
cardFirst,cardLast=cardFirst or 1,cardLast or 80
local registered=0
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map,Combat,Data=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_data')
local passed,failed=0,0
local function test(name,fn)
    registered=registered+1
    if registered<first or registered>last then return end

 local ok,reason=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name)
 else failed=failed+1;print('FAIL '..name..': '..tostring(reason)) end
end

local function same(actual,expected)
 assert(type(actual)==type(expected),'state type changed')
 if type(actual)~='table' then assert(actual==expected,'state changed');return end
 for key,value in pairs(expected) do same(actual[key],value) end
 for key in pairs(actual) do assert(expected[key]~=nil,'state gained a field') end
end

local function reward(seed,stolen)
 local run,map=Run.new(Data,seed),Map.generate(Data,seed)
 assert(Nodes.enter(run,map,Nodes.available(run,map)[1].id))
 -- Completed-battle/registered-ledger fixture only. No reward fields are
 -- patched; Run.finishCombat constructs all offers, then real APIs resolve them.
 -- The unmodified full-route test below provides the natural-combat evidence.
 for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
 run.combat.stolenGoldReward=stolen and 30 or 0
 assert(Run.finishCombat(run))
 return run,map
end

for _,potionState in ipairs({'none','pending','full','claimed','skipped','unavailable'}) do
 for _,goldState in ipairs({'none','pending','claimed'}) do
  for _,choice in ipairs({0,1}) do
   test(potionState..' potion / '..goldState..' stolen gold / card choice '..choice,function()
    local finish=dofile('tools/diagnostics/finish_combat_rewards.lua')
    local seed=potionState=='none' and 0 or (potionState=='unavailable' and 33 or 42)
    local run,map=reward(seed,goldState~='none')
    local rewards=run.rewards
    local quotedGold=rewards.gold
    assert(rewards.goldClaimed==false and run.gold==99,'victory gold must remain an independent offer')
    local offer=run.rewards.potion
    assert((offer~=nil)==(potionState~='none'),'fixture potion precondition')
    if potionState=='full' then
     for _,id in ipairs({'block_potion','energy_potion','fire_potion'}) do assert(Run.obtainPotion(run,id)) end
    elseif potionState=='claimed' then assert(Run.claimPotionReward(run))
    elseif potionState=='skipped' then assert(Run.skipPotionReward(run)) end
    if goldState=='claimed' then assert(Run.claimStolenGoldReward(run)) end
    local beforeCount=Run.potionCount(run)
    local beforePotions,seedBefore=Combat.copy(run.potions),run.seed
    local rngBefore=Combat.copy(run.shopRng.potion)
    assert(Run.claimCardReward(run,choice))
    assert(Run.potionCount(run)==beforeCount,'card choice acquired a potion')
    finish(run,map)
    assert(run.phase=='map' and run.nodeFlow.complete,'reward did not finish the real map node')
    assert(#run.deck==10+choice,'card choice changed')
    assert(rewards.goldClaimed and run.gold==99+quotedGold+(goldState=='none' and 0 or 30),'victory/stolen gold lost or duplicated')
    assert(not Run.claimGoldReward(run),'resolved victory gold must not be paid twice')
    local counts={none=0,pending=1,full=3,claimed=1,skipped=0,unavailable=0}
    assert(Run.potionCount(run)==counts[potionState],'wrong potion inventory')
    if potionState~='pending' then same(run.potions,beforePotions) end
    assert(run.seed==seedBefore,'reward handling changed the battle seed')
    same(run.shopRng.potion,rngBefore)
    if offer then
     local result=(potionState=='pending' or potionState=='claimed') and 'claimed' or 'skipped'
     assert(offer.resolved and offer.result==result,'potion was not explicitly resolved')
     if result=='claimed' then assert(run.potions[offer.slot]==offer.id,'wrong potion acquired') end
    end
    local before,previousMap=Combat.copy(run),Combat.copy(map)
    local ok,reason=pcall(finish,run,map)
    assert(not ok and tostring(reason):find('no_pending_node',1,true),'duplicate completion must report its real error')
    same(run,before);same(map,previousMap)
   end)
  end
 end
end

test('a genuine potion API rejection is not silently skipped or retried',function()
 local run,map=reward(42,false)
 -- Explicit invalid-catalog fixture: leave the generated reward untouched,
 -- but make its definition unavailable to the real obtainPotion API.
 run.data=Combat.copy(run.data)
 for i,potion in ipairs(run.data.potions.potions) do
  if potion.id==run.rewards.potion.id then table.remove(run.data.potions.potions,i);break end
 end
 assert(Run.claimCardReward(run,0))
 local before=Combat.copy(run)
 local ok,reason=pcall(dofile('tools/diagnostics/finish_combat_rewards.lua'),run,map)
 assert(not ok and tostring(reason):find('unknown_potion',1,true),'real potion error was swallowed')
 same(run,before);assert(not run.nodeFlow.complete)
end)

test('Sozu consumes the clicked offer without a bottle or a false diagnostic error',function()
 local run,map=reward(42,false)
 local quotedGold=run.rewards.gold
 run.relics[#run.relics+1]='sozu'
 assert(Run.claimCardReward(run,0))
 local offer=run.rewards.potion
 local potions,seed,rng=Combat.copy(run.potions),run.seed,Combat.copy(run.shopRng.potion)
 dofile('tools/diagnostics/finish_combat_rewards.lua')(run,map)
 assert(offer.resolved and offer.result=='blocked' and offer.slot==nil)
 same(run.potions,potions);same(run.shopRng.potion,rng)
 assert(run.seed==seed and Run.potionCount(run)==0)
 assert(run.phase=='map' and run.nodeFlow.complete and run.gold==99+quotedGold)
 assert(not Run.claimPotionReward(run),'consumed Sozu offer must not be claimable twice')
end)

test('already claimed victory gold is not claimed again by the diagnostic',function()
 local run,map=reward(0,false)
 local quotedGold=run.rewards.gold
 assert(Run.claimGoldReward(run));assert(Run.claimCardReward(run,0))
 local gold=run.gold
 dofile('tools/diagnostics/finish_combat_rewards.lua')(run,map)
 assert(run.gold==gold and gold==99+quotedGold and run.nodeFlow.complete)
 assert(not Run.claimGoldReward(run),'claimed victory gold must stay resolved')
end)

test('a genuine victory-gold API rejection is not silently forfeited',function()
 local run,map=reward(0,false);assert(Run.claimCardReward(run,0))
 run.gold=2147483640 -- Explicit overflow fixture, not a normal route balance.
 local before=Combat.copy(run)
 local ok,reason=pcall(dofile('tools/diagnostics/finish_combat_rewards.lua'),run,map)
 assert(not ok and tostring(reason):find('invalid_gold_reward',1,true),'real victory-gold error was swallowed')
 same(run,before);assert(not run.nodeFlow.complete)
end)

test('a genuine stolen-gold API rejection is not silently forfeited',function()
 local run,map=reward(0,true)
 assert(Run.claimGoldReward(run)) -- Isolate stolen-gold overflow after normal gold resolves.
 assert(Run.claimCardReward(run,0))
 run.gold=2147483640 -- Explicit overflow fixture, not a normal route balance.
 local before=Combat.copy(run)
 local ok,reason=pcall(dofile('tools/diagnostics/finish_combat_rewards.lua'),run,map)
 assert(not ok and tostring(reason):find('invalid_stolen_gold',1,true),'real gold error was swallowed')
 same(run,before);assert(not run.nodeFlow.complete)
end)

test('a sparse belt claims into its vacancy without replacing other bottles',function()
 local run,map=reward(42,false)
 for _,id in ipairs({'block_potion','energy_potion','fire_potion'}) do assert(Run.obtainPotion(run,id)) end
 assert(Run.discardPotion(run,2));assert(Run.claimCardReward(run,0))
 local offer=run.rewards.potion
 dofile('tools/diagnostics/finish_combat_rewards.lua')(run,map)
 assert(offer.result=='claimed' and offer.slot==2)
 assert(run.potions[1]=='block_potion' and run.potions[2]==offer.id and run.potions[3]=='fire_potion')
end)

test('retry after a gold rejection does not claim the already acquired bottle again',function()
 local run,map=reward(42,true);local quotedGold=run.rewards.gold
 assert(Run.claimGoldReward(run));assert(Run.claimCardReward(run,0))
 local offer=run.rewards.potion
 local finish=dofile('tools/diagnostics/finish_combat_rewards.lua')
 run.gold=2147483640 -- Explicit overflow fixture.
 local ok,reason=pcall(finish,run,map)
 assert(not ok and tostring(reason):find('invalid_stolen_gold',1,true))
 assert(offer.result=='claimed' and Run.potionCount(run)==1)
 assert(run.phase=='reward' and not run.rewards.stolenGold.claimed and not run.nodeFlow.complete)
 run.gold=99+quotedGold -- Repair only the injected fixture error before the explicit retry.
 finish(run,map)
 assert(Run.potionCount(run)==1 and run.gold==99+quotedGold+30 and run.nodeFlow.complete)
end)

test('final node rejection is preserved and explicit retry does not duplicate rewards',function()
 local run,map=reward(42,true);local quotedGold=run.rewards.gold
 assert(Run.claimCardReward(run,0))
 local finish=dofile('tools/diagnostics/finish_combat_rewards.lua')
 local ok,reason=pcall(finish,run,Map.generate(Data,43))
 assert(not ok and tostring(reason):find('map_mismatch',1,true))
 assert(run.phase=='map' and not run.nodeFlow.complete and run.gold==99+quotedGold+30 and Run.potionCount(run)==1)
 finish(run,map)
 assert(run.nodeFlow.complete and run.gold==99+quotedGold+30 and Run.potionCount(run)==1)
end)

-- These cases run the actual diagnostic with explicit fixture seeds. The
-- wrappers only choose a seed and observe real Nodes.enter/Run transitions;
-- they do not resolve rooms, choose another route, or manufacture victories.
-- Source seed89's first unknown is f2_l1, previous room combat, bucket14:
-- the unchanged diagnostic policy therefore reaches an actual treasure room.
for _,case in ipairs({{seed=0,kind='event'},{seed=7,kind='combat'},{seed=89,kind='treasure'},{seed=58,kind='shop'}}) do
 test('the actual diagnostic handles an unknown room resolved as '..case.kind,function()
  local run,unknownId
  local completed={}
  local fixtureRun=setmetatable({new=function(data) run=Run.new(data,case.seed);return run end},{__index=Run})
  local fixtureMap=setmetatable({generate=function(data) return Map.generate(data,case.seed) end},{__index=Map})
  local fixtureNodes=setmetatable({enter=function(activeRun,map,id)
   local selected
   for _,node in ipairs(Nodes.available(activeRun,map)) do if node.id==id then selected=node end end
   local ok,reason=Nodes.enter(activeRun,map,id)
   if ok and selected.type=='event' then
    assert(not unknownId,'first unknown room was not completed')
    unknownId=id;assert(run.nodeFlow.type==case.kind,'fixture resolved a different room kind')
   end
   return ok,reason
  end},{__index=Nodes})
  local environment=setmetatable({require=function(name)
   if name=='abyss_run' then return fixtureRun end
   if name=='abyss_nodes' then return fixtureNodes end
   if name=='abyss_map' then return fixtureMap end
   return require(name)
  end,print=function(label)
   if unknownId and label=='COMPLETE '..unknownId then
    assert(run.phase=='map' and run.nodeFlow.complete,'resolved room did not complete')
    error(completed) -- Stop this scoped fixture, only after the real room completes.
   end
  end},{__index=_G})
  local ok,reason=pcall(assert(loadfile('tools/diagnostics/core_route_seed42.lua','t',environment)))
  assert(not ok and reason==completed,'resolved '..case.kind..' route failed: '..tostring(reason))
 end)
end

test('the actual diagnostic rejects an unsupported resolved node type',function()
 local invalidType='unsupported_fixture'
 local fixtureNodes=setmetatable({enter=function(run,map,id)
  local ok,reason=Nodes.enter(run,map,id)
  -- Deliberately invalid future-node fixture; no ordinary route state is changed.
  if ok then run.nodeFlow.type=invalidType;run.phase='node' end
  return ok,reason
 end},{__index=Nodes})
 local completed=false
 local environment=setmetatable({require=function(name)
  if name=='abyss_nodes' then return fixtureNodes end
  return require(name)
 end,print=function(label)
  if tostring(label):match('^COMPLETE ') then completed=true end
 end},{__index=_G})
 local ok,reason=pcall(assert(loadfile('tools/diagnostics/core_route_seed42.lua','t',environment)))
 assert(not ok and tostring(reason):find('unsupported_node_type:'..invalidType,1,true),'unsupported node was not reported')
 assert(not completed,'unsupported node was reported as complete')
end)

test('the actual seed42 diagnostic reaches a real terminal result without hiding a stop',function()
 local first,later,ending,lossGate,fresh=false,false,false,false,false
 local phase,stopped,bossTreasureClaimed,firstNodeId,observedRun
 local observedNodes=setmetatable({enter=function(run,map,id)
  local ok,reason=Nodes.enter(run,map,id)
  if ok then
   observedRun=run
   if not firstNodeId then assert(run.floor==1);firstNodeId=id end
  end
  return ok,reason
 end,claimBossTreasure=function(run,choice)
  assert(run.floor==17 and run.nodeFlow.roomKind=='boss_treasure')
  local selected=run.nodeFlow.reward.relics[choice]
  assert((choice==0 and #run.nodeFlow.reward.relics==0) or (choice>0 and selected),'diagnostic selected no legal Boss relic')
  local ok,reason=Nodes.claimBossTreasure(run,choice)
  assert(ok and run.phase=='victory' and run.nodeFlow.chosenRelic==selected)
  local after=Combat.copy(run);assert(not Nodes.claimBossTreasure(run,choice));same(run,after)
  bossTreasureClaimed=true
  return ok,reason
 end},{__index=Nodes})
 local environment=setmetatable({require=function(name)
  if name=='abyss_nodes' then return observedNodes end
  return require(name)
 end,print=function(label,...)
  if firstNodeId and label=='COMPLETE '..firstNodeId then
   assert(observedRun.phase=='map' and observedRun.nodeFlow.complete,'first source room did not return to the map')
   first=true
  end
  if tostring(label):match('^COMPLETE f[2-9]_') then later=true end
  if tostring(label):match('^END turns=') then
   ending=true
   for _,value in ipairs({...}) do phase=tostring(value):match('^phase=(.+)$') or phase end
  end
  if tostring(label):match('^STOP ') then stopped=label end
  if label=='LOSS_GATE' then lossGate=true end
  if label=='FRESH_RUN' then fresh=true end
 end},{__index=_G})
 local ok,reason=pcall(assert(loadfile('tools/diagnostics/core_route_seed42.lua','t',environment)))
 assert(ok,'the actual diagnostic failed: '..tostring(reason))
 assert(first,'first reward did not return to the map')
 assert(later and ending,'the unchanged natural route did not continue')
 assert(not stopped,'diagnostic stopped early: '..tostring(stopped))
 assert(phase=='defeat' or phase=='victory','diagnostic did not reach a real terminal result')
 -- Its original loss-gate assertions must execute if this strategy loses.
 -- This is not an artificial win or an alternate route policy.
 if phase=='defeat' then assert(lossGate and fresh,'original defeat/restart assertions did not execute') end
 if phase=='victory' then assert(bossTreasureClaimed,'victory must follow the real independent Boss chest claim') end
 print('NATURAL_ROUTE first='..tostring(first)..' later='..tostring(later)..' phase='..phase..' loss_gate='..tostring(lossGate))
end)

print('DIAGNOSTIC_REWARD_PROTOCOL '..passed..' passed '..failed..' failed')
assert(failed==0)

return registered
end
