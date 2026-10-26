-- BOTTOM damage reactions. Actor owns the action boundary and supplies arithmetic.
local Events=require('abyss_events')
local M={}
local function push(s,action)
 s.act2Bottom=s.act2Bottom or {};s.act2Bottom[#s.act2Bottom+1]=action
end
function M.damaged(s,source,target,lost,fixed)
 if source and not fixed and lost>0 and lost<target.hp and (target.statuses.malleable or 0)>0 then
  push(s,{op='block',target=target,value=target.statuses.malleable})
  target.statuses.malleable=target.statuses.malleable+1
 end
 if source and not fixed and lost>0 and (source.statuses.painful_stabs or 0)>0 then
  push(s,{op='card',card='wound'})
 end
end
function M.flush(api,s)
 local queue=s.act2Bottom;s.act2Bottom=nil
 if not queue or s.player.hp<=0 then return end
 local live=false;for _,e in ipairs(s.enemies)do if api.isActive(e)then live=true end end
 for _,entry in ipairs(queue)do
  if entry.op=='block' and api.isActive(entry.target) then api.block(s,entry.target,entry.value,true)
  elseif entry.op=='card' and live then
   assert(s.catalog.cards[entry.card],'unknown enemy-generated card')
   local c={cardId=entry.card,uid=s.nextUid,upgraded=false}
   s.nextUid=s.nextUid+1.0;s.discard[#s.discard+1]=c
   Events.emit(s,'cards_created',{cardId=entry.card,amount=1,pile='discard'})
  end
 end
end
return M
