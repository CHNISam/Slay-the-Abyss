-- Component-only stream/checkpoint fixtures, not naturally earned campaigns.
-- Every catalog identity remains; snapshots merely reorder or exhaust existing
-- queues. No implementation filtering, redraw or legacy nil-pool fallback.
local C,R,P=require('abyss_combat'),require('abyss_sts_random'),require('abyss_relic_pool')
local M={}
local sourceIds={strawberry='Strawberry',whetstone='Whetstone',anchor='Anchor'}
local function front(queue,id)
 for index,candidate in ipairs(queue)do
  if candidate==id then table.remove(queue,index);table.insert(queue,1,id);return end
 end
 error('fixture source identity missing: '..id)
end
function M.stage(run,options)
 options=options or {}
 local snap=P.snapshot(run.relicPool)
 if options.exhausted then
  for _,tier in ipairs({'common','uncommon','rare'})do snap.queues[tier]={}end
  run.relics[#run.relics+1]='nloths_mask';run.relicCounters=run.relicCounters or {};run.relicCounters.nloths_mask=1
 else
  front(snap.queues.common,sourceIds[options.relic or 'strawberry'])
 end
 if options.extra then
  front(snap.queues.common,'Anchor')
  run.relics[#run.relics+1]='matryoshka';run.relicCounters=run.relicCounters or {};run.relicCounters.matryoshka=2
 end
 if options.boss then
  for _,id in ipairs({'Sozu','SlaversCollar','Black Blood'})do front(snap.queues.boss,id)end
 end
 run.relicPool=P.restore(snap,run.relicPool.catalog)
 -- Independent RandomXS128 source values: seed39 => 45,69 (Small/Common,
 -- no gold); seed42 => 24,41 then float23.2982025... => 23 gold.
 run.treasureRng=R.fromSeed(options.gold or options.exhausted and '42' or '39')
end
function M.claimDisplayed(run,map)
 local Nodes=require('abyss_nodes')
 if not run.nodeFlow.chest.opened then assert(Nodes.openTreasure(run))end
 for _,item in ipairs(C.copy(run.nodeFlow.reward.items))do
  if item.kind~='sapphire' then
   local token=assert(Nodes.treasureRewardSource(run,item.slot))
   if item.kind=='relic' and not item.available then
    local before=C.copy(run);local ok,why=Nodes.claimTreasureReward(run,token)
    assert(not ok and why=='relic_content_unavailable');assert(run.nodeFlow.reward.relicId==before.nodeFlow.reward.relicId)
   else assert(Nodes.claimTreasureReward(run,token))end
  end
 end
 if run.phase=='node' then assert(Nodes.leaveTreasure(run))end
 return true
end
return M
