-- Diagnostic policy after the caller's independent card choice: keep existing
-- bottles, decline a full-belt/unavailable offer explicitly, then finish the node.
local Run,Nodes=require('abyss_run'),require('abyss_nodes')
return function(run,map)
 if run.phase=='reward' and run.rewards.manualContinue then
  local potion=run.rewards.potion
  if potion and not potion.resolved then
   if potion.unavailable or Run.potionCount(run)>=run.data.rules.player.potionSlots then
    assert(Run.skipPotionReward(run))
    print('POTION skip',potion.id or potion.rarity,potion.unavailable and 'content_unavailable' or 'slots_full')
   else
    assert(Run.claimPotionReward(run))
    print('POTION claim',potion.id,'slot='..potion.slot)
   end
  end
  local stolen=run.rewards.stolenGold
  if stolen and not stolen.claimed then
   assert(Run.claimStolenGoldReward(run))
   print('STOLEN_GOLD claim',stolen.amount)
  end
  assert(Run.leaveCombatRewards(run))
 end
 assert(Nodes.completeCombat(run,map))
end
