-- Explicit component snapshots for claim/gesture tests, never natural queue
-- or probability evidence. Every remaining source identity is retained.
local M={}
function M.stageQueue(run,priority,consumed)
 local before=run.relicPool.queues.boss
 assert(#before==22,'fixture expects the complete initial source Boss queue')
 local used,out={},{}
 for _,id in ipairs(consumed or {})do used[id]=true end
 for _,id in ipairs(priority or {})do
  assert(not used[id],'component priority is already consumed')
  local found=false;for _,value in ipairs(before)do if value==id then found=true end end
  assert(found,'unknown component source identity');used[id]=true;out[#out+1]=id
 end
 for _,id in ipairs(before)do if not used[id]then out[#out+1]=id end end
 assert(#out==#before-#(consumed or {}),'component snapshot lost source identities')
 run.relicPool.queues.boss=out
end
function M.supportedChoices(run)
 M.stageQueue(run,{'Black Blood','SlaversCollar','Sozu'})
end
function M.definition(run,id)
 for _,entry in ipairs(run.data.relics.relics)do if entry.id==id then return entry end end
end
return M
