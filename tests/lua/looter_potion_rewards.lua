package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Data,P,R=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_potion_rewards'),require('abyss_sts_random')
local passed,failed=0,0
local function test(name,fn) local ok,e=pcall(fn);if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(e)) end end
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table' then assert(a==b);return end
 for k,v in pairs(a) do same(v,b[k]) end;for k in pairs(b) do assert(a[k]~=nil) end
end
local function reward(stolen)
 local run=Run.new(Data,42);assert(Run.startCombat(run,'cultist_solo'))
 -- Completed-battle/registered-ledger fixture isolates reward transactions.
 for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
 run.combat.stolenGoldReward=stolen or 0;assert(Run.finishCombat(run));assert(run.rewards.potion)
 return run
end
local function rejectUnchanged(run,fn,reason)
 local before=C.copy(run);local ok,why=fn();assert(ok==false and why==reason,tostring(ok)..' '..tostring(why));same(run,before)
end
test('ordinary no-loss card keeps the independent bottle pending',function()
 local run=reward();local id=run.rewards.potion.id;assert(Run.claimCardReward(run,1));assert(run.phase=='reward' and Run.potionCount(run)==0)
 assert(Run.claimPotionReward(run));assert(run.potions[1]==id);assert(Run.leaveCombatRewards(run))
end)
test('manual card does not auto-claim its independent bottle',function()
 local run=reward(30);local bottle=run.rewards.potion;assert(Run.claimCardReward(run,1))
 assert(run.phase=='reward' and run.rewards.cardResolved and not bottle.resolved and Run.potionCount(run)==0,'card consumed potion')
 assert(Run.claimPotionReward(run));assert(Run.claimStolenGoldReward(run));assert(Run.leaveCombatRewards(run));assert(run.phase=='map')
end)
test('manual leave refuses a pending bottle before any state changes',function()
 local run=reward(30);rejectUnchanged(run,function() return Run.leaveCombatRewards(run) end,'pending_potion_reward')
 assert(Run.skipPotionReward(run));assert(Run.leaveCombatRewards(run));assert(run.phase=='map' and #run.deck==10 and run.gold==114)
end)
test('full belt blocks only bottle claim in manual flow and retains card/gold decisions',function()
 local run=reward(30);for _,id in ipairs({'block_potion','energy_potion','fire_potion'}) do assert(Run.obtainPotion(run,id)) end
 assert(Run.claimCardReward(run,1),'full belt blocked independent card');assert(Run.claimStolenGoldReward(run))
 rejectUnchanged(run,function() return Run.claimPotionReward(run) end,'potion_slots_full')
 rejectUnchanged(run,function() return Run.leaveCombatRewards(run) end,'pending_potion_reward')
 assert(Run.skipPotionReward(run));assert(Run.leaveCombatRewards(run));assert(#run.deck==11 and run.gold==144)
end)
test('Sozu blocks bottle acquisition but not independent card or stolen gold',function()
 local run=reward(30);run.relics[#run.relics+1]='sozu'
 assert(Run.claimCardReward(run,0),'Sozu blocked independent card');assert(Run.claimStolenGoldReward(run))
 rejectUnchanged(run,function() return Run.claimPotionReward(run) end,'potion_blocked_by_sozu')
 assert(Run.skipPotionReward(run));assert(Run.leaveCombatRewards(run));assert(Run.potionCount(run)==0)
end)
test('normal all-escaped provider consumes only drop roll and increases modifier',function()
 local run=Run.new(Data,42);run.encounterTier='normal'
 local item,rng,modifier=P.prepare(run,2,{allEscaped=true})
 assert(item==nil,'escaped encounter generated bottle');assert(rng.counter==1 and modifier==10)
 local ordinary,ordinaryRng=P.prepare(run,2);assert(ordinary and ordinaryRng.counter==3)
end)
test('real unmodified Looter escape wires provider without extra battle RNG',function()
 local run=Run.new(Data,42);run.floor=4;assert(Run.startCombat(run,'looter_solo'))
 for _=1,5 do if run.phase=='combat' then assert(Run.endTurn(run)) end end
 assert(run.phase=='reward' and run.lastResult.allEnemiesEscaped)
 assert(not run.rewards.potion,'real escape generated bottle')
 assert(run.shopRng.potion.counter==1 and run.potionChanceModifier==10)
 assert(run.rewards.gold==0 and #run.rewards.cards==3 and run.victories==1)
end)
test('new run resets provider history after an escape',function()
 local run=Run.new(Data,42);assert(run.shopRng==nil and run.potionChanceModifier==nil)
end)
test('terminal potion failure restores preexisting shared potion RNG by identity',function()
 local run=reward();assert(Run.claimCardReward(run,0));assert(Run.skipPotionReward(run));assert(Run.leaveCombatRewards(run));assert(Run.startCombat(run,'cultist_solo'))
 assert(Run.obtainPotion(run,'fire_potion'));local slot
 for i=1,3 do if run.potions[i]=='fire_potion' then slot=i end end
 -- One-HP terminal fixture and injected commit failure test existing transaction scope.
 run.combat.enemies[1].hp=1;local before=C.copy(run);local streams,stream=run.shopRng,run.shopRng.potion
 local commit=P.commit;P.commit=function(...) commit(...);error('injected reward commit') end
 local ok,reason=Run.usePotion(run,slot,1);P.commit=commit
 assert(not ok and reason=='potion_effect_failed');same(run,before)
 assert(run.shopRng==streams and run.shopRng.potion==stream)
end)
test('manual leave retains the earned Boss16 to separate chest17 route',function()
 local Nodes,Map=require('abyss_nodes'),require('abyss_map')
 for choice=0,1 do
  local run,map=Run.new(Data,42),Map.generate(Data,42)
  -- Explicit navigation/terminal/ledger fixture: current Boss does not steal.
  -- This exercises composition only, not a normal seventeen-floor clear.
  while Map.available(map)[1].floor<16 do assert(Map.choose(map,Map.available(map)[1].id)) end
  assert(Nodes.enter(run,map,Map.available(map)[1].id));assert(run.floor==16)
  for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
  run.combat.stolenGoldReward=30;assert(Run.finishCombat(run));assert(run.rewards.potion)
  assert(Run.claimCardReward(run,1));assert(Run.claimStolenGoldReward(run))
  rejectUnchanged(run,function() return Run.leaveCombatRewards(run) end,'pending_potion_reward')
  assert(Run.skipPotionReward(run));assert(Run.leaveCombatRewards(run))
  assert(run.phase=='map' and not run.nodeFlow.complete and run.floor==16)
  assert(Nodes.completeCombat(run,map));assert(run.nodeFlow.result=='boss_victory' and run.phase=='map')
  local restored=assert(Map.restore(Data,Map.snapshot(map)));local node=Nodes.available(run,restored)[1]
  assert(node.roomKind=='boss_treasure' and node.floor==17);assert(Nodes.enter(run,restored,node.id))
  assert(run.phase=='node');assert(Nodes.claimBossTreasure(run,choice));assert(run.phase=='victory')
  assert(not Nodes.claimBossTreasure(run,choice) and not Run.leaveCombatRewards(run))
 end
end)
print('LOOTER_POTION_REWARDS '..passed..' passed '..failed..' failed');assert(failed==0)
