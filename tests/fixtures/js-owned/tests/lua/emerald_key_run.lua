local F=dofile('tests/lua/support/emerald_run_fixture.lua')
local Run,Nodes,Map,C=F.Run,F.Nodes,F.Map,F.C
local R=require('abyss_sts_random')
assert(type(Run.freezeMapContext)=='function','missing Run trusted map-birth boundary')
assert(type(Run.claimEmeraldKey)=='function','missing independent Emerald claim')
local count=0
local function test(fn)fn();count=count+1;print('PASS emerald run '..count)end
test(function()
 local run,map=F.fixture();local birth=assert(Run.mapContext(run))
 assert(birth.endingUnlocked and not birth.emeraldOwned)
 birth.emeraldOwned=true;assert(not Run.mapContext(run).emeraldOwned)
 run.keys.emerald=true;assert(not Run.freezeMapContext(run).emeraldOwned)
 F.same(assert(Nodes.restoreMap(run,Map.snapshot(map))),map)
 run.phase,run.pendingAct,run.floor='act_transition',2,17
 run.nodeFlow={floor=17,complete=true,roomKind='boss_treasure',result='boss_treasure_complete'}
 assert(Run.advanceAct(run));assert(run.mapBirthAct==2 and Run.mapContext(run).emeraldOwned)
 assert(not Map.generate(run.data,run.runSeed,2,Run.mapContext(run)).emeraldSelection)
end)
test(function()
 local run,map,id=F.fixture();local before=R.restore(map.mapRng)
 local boost=assert(Map.prepareEmeraldBoost(map,id));local E=require('abyss_emerald_elite')
 local apply=E.apply;local calls=0
 E.apply=function(actors,effect,api)
  calls=calls+1;F.same(effect,boost.effect)
  return apply(actors,effect,api)
 end
 local ok,why=Nodes.enter(run,map,id);E.apply=apply;assert(ok,why)
 assert(calls==1,'real Combat.new must apply source boost exactly once')
 assert(map.emeraldBoost and run.emeraldCombat and run.nodeFlow.emeraldBoost)
 assert(map.mapRng.counter==before.counter+1)
 F.same(map.emeraldBoost,boost)
 F.same(assert(Nodes.restoreMap(run,Map.snapshot(map))),map)
end)
test(function()
 local run,map,id=F.fixture();local before,graph=F.snapshot(run),C.copy(map)
 local new=C.new;C.new=function()error('late battle constructor fault')end
 local ok=Nodes.enter(run,map,id);C.new=new
 assert(not ok);F.same(run,before);F.same(map,graph)
 local commit=Map.commitEmeraldBoost;Map.commitEmeraldBoost=function()return false,'late map commit fault'end
 ok=Nodes.enter(run,map,id);Map.commitEmeraldBoost=commit
 assert(not ok);F.same(run,before);F.same(map,graph)
 assert(Nodes.enter(run,map,id))
end)
test(function()
 local run,map,id=F.fixture(true);assert(Nodes.enter(run,map,id));local rewards=F.victory(run)
 assert(rewards.emeraldKey and #rewards.relics==2 and not rewards.emeraldKey.relicLink)
 local gold,held=run.gold,#run.relics
 assert(Run.claimEmeraldKey(run));assert(run.keys.emerald and run.rewards.emeraldKey.claimed)
 assert(run.gold==gold and #run.relics==held and not run.rewards.goldClaimed)
 assert(not Run.claimEmeraldKey(run))
 assert(Run.claimRelicReward(run,1));assert(Run.claimRelicReward(run,2))
 assert(#run.relics==held+2 and run.rewards.relics[1].claimed and run.rewards.relics[2].claimed)
 assert(Run.claimGoldReward(run));assert(run.gold>gold)
 assert(not Run.mapContext(run).emeraldOwned,'this map keeps its pre-claim birth context')
end)
test(function()
 local run,map,id=F.fixture();assert(Nodes.enter(run,map,id));F.victory(run)
 local offer=run.rewards.emeraldKey
 assert(Run.leaveCombatRewards(run));assert(Nodes.completeCombat(run,map))
 assert(Run.reopenCombatRewards(run));assert(run.rewards.emeraldKey==offer)
 local E=require('abyss_emerald_elite');local claim=E.claim
 E.claim=function(item,context,obtain)assert(obtain());error('late key obtain fault')end
 local before=F.snapshot(run);assert(not Run.claimEmeraldKey(run));E.claim=claim
 F.same(run,before);assert(not run.keys.emerald and not run.rewards.emeraldKey.claimed)
 assert(Run.leaveCombatRewards(run))
 local nextId=assert(Nodes.available(run,map)[1]).id
 assert(Nodes.enter(run,map,nextId));assert(not run.pendingCombatRewards)
 assert(not Run.reopenCombatRewards(run)and not Run.claimEmeraldKey(run))
end)
test(function()
 local run,map,id=F.fixture();run.potions[1]='smoke_bomb';assert(Nodes.enter(run,map,id))
 assert(Run.usePotion(run,1));assert(run.phase=='map'and not run.rewards and not run.keys.emerald)
 assert(not Run.claimEmeraldKey(run))
 run,map,id=F.fixture();assert(Nodes.enter(run,map,id));run.combat.player.hp=0
 assert(Run.finishCombat(run));assert(run.phase=='defeat'and not run.rewards and not run.keys.emerald)
end)
print('EMERALD_KEY_RUN 6 groups; 0 failed; natural/platform NOT_RUN')
