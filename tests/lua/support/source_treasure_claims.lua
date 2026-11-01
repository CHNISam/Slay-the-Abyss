-- Public source-chest navigation for transaction/UI fixtures. Skipping an
-- unavailable identity is explicit and never substitutes another relic.
local N,C,P=require('abyss_nodes'),require('abyss_combat'),require('abyss_relic_pool')
local M={}
function M.open(run)
 if not run.nodeFlow.chest.opened then assert(N.openTreasure(run))end
 return run.nodeFlow.reward
end
function M.claim(run)
 M.open(run)
 for _,item in ipairs(C.copy(run.nodeFlow.reward.items))do
  if item.kind~='sapphire' then
   local token=assert(N.treasureRewardSource(run,item.slot))
   if item.kind=='relic' and not item.available then
    local reward=run.nodeFlow.reward;local pool=P.snapshot(run.relicPool)
    local ok,why=N.claimTreasureReward(run,token)
    assert(not ok and why=='relic_content_unavailable' and run.nodeFlow.reward==reward)
    local after=P.snapshot(run.relicPool)
    for tier,queue in pairs(pool.queues)do
     assert(#after.queues[tier]==#queue)
     for index,id in ipairs(queue)do assert(after.queues[tier][index]==id)end
    end
   else assert(N.claimTreasureReward(run,token))end
  end
 end
 if run.phase=='node'then assert(N.leaveTreasure(run))end
 return true
end
function M.depleted(run,remaining)
 -- A consumed-queue checkpoint, not a smaller catalog or capability filter.
 -- Keep the complete pinned catalog (including every missing implementation).
 local snap=P.snapshot(run.relicPool)
 for _,tier in ipairs({'common','uncommon','rare'})do snap.queues[tier]={}end
 if remaining then snap.queues.common={remaining}end
 run.relicPool=P.restore(snap,run.relicPool.catalog)
end
function M.goldOnly(run)
 -- The legacy all-owned shortcut is not a valid acquired-owner checkpoint:
 -- passive blockers and uninitialized on-equip counters change gold/opening.
 -- Recognize only that exact set; ordinary acquired inventories stay intact.
 local definitions=run.data.relics.relics;local allOwned=#run.relics==#definitions;local held={}
 for _,id in ipairs(run.relics)do if held[id]then allOwned=false end;held[id]=true end
 for _,entry in ipairs(definitions)do if not held[entry.id]then allOwned=false end end
 if allOwned then
  assert(held.burning_blood,'the legacy all-owned checkpoint has the default starter')
  run.relics={'burning_blood'};run.relicCounters={}
  M.depleted(run) -- consumed ordinary queues, complete catalog and same RNG
 end
 -- Explicit held-relic component: the real after-hook removes base/key. This
 -- does not claim Nloth's Mask can yet be obtained in a natural campaign.
 run.relics[#run.relics+1]='nloths_mask'
 run.relicCounters=run.relicCounters or {};run.relicCounters.nloths_mask=1
 -- A gold-only checkpoint also exhausts an owned finite extra-relic hook;
 -- all definitions and source queue identities remain present.
 for _,id in ipairs(run.relics)do if id=='matryoshka'or id=='Matryoshka'then run.relicCounters[id]=-2 end end
end
return M
