-- Explicit full-queue component checkpoints, not natural acquisition evidence.
local P,R=require('abyss_relic_pool'),require('abyss_sts_random')
local M={}
function M.queue(run,fromTail)
 local source=P.snapshot(run.relicPool)
 local before=source.queues.uncommon
 local queue,found={},{}
 for _,id in ipairs(before)do
  assert(not found[id],'duplicate source identity');found[id]=true
  if id~='Darkstone Periapt' and id~='InkBottle'then queue[#queue+1]=id end
 end
 assert(found['Darkstone Periapt'] and found.InkBottle and #queue==#before-2)
 queue[#queue+1]='InkBottle' -- Always-eligible implemented fallback.
 if fromTail then queue[#queue+1]='Darkstone Periapt'
 else table.insert(queue,1,'Darkstone Periapt')end
 assert(#queue==#before,'fixture changed source pool size')
 source.queues.uncommon=queue
 run.relicPool=P.restore(source,run.relicPool.catalog)
end
function M.chest(run)
 M.queue(run,false)
 -- Independent RandomXS128 interpretation: seed0 -> 72,60, a Medium/
 -- Uncommon chest without gold. Run seed42/owners remain unchanged.
 run.treasureRng=R.fromSeed('0')
end
function M.base(flow)
 for _,item in ipairs(flow.reward.items)do if item.origin=='base'then return item end end
 error('missing actual source base reward')
end
return M
