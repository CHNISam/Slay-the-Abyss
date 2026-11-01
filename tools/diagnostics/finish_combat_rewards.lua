-- Diagnostic policy after the caller's independent card choice: keep existing
-- bottles, decline a full-belt/unavailable offer explicitly, claim independent
-- victory/stolen gold, then finish the node. Sozu consumes the clicked offer.
local Run,Nodes=require('abyss_run'),require('abyss_nodes')
return function(run,map)
 if run.phase=='reward' and run.rewards.manualContinue then
  local potion=run.rewards.potion
  if potion and not potion.resolved then
   if potion.unavailable or Run.potionCount(run)>=run.data.rules.player.potionSlots then
    assert(Run.skipPotionReward(run))
    print('POTION skip',potion.id or potion.rarity,potion.unavailable and 'content_unavailable' or 'slots_full')
   else
    local ok,reason=Run.claimPotionReward(run)
    assert(ok,reason)
    if reason=='potion_blocked_by_sozu' then print('POTION blocked',potion.id,reason)
    else print('POTION claim',potion.id,'slot='..potion.slot) end
   end
  end
  if run.rewards.goldClaimed==false then
   local amount=run.rewards.gold
   assert(Run.claimGoldReward(run))
   print('GOLD claim',amount)
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
