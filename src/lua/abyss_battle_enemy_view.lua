-- Screen slots are presentation only. Every entry retains its core index/ID.
local Actors=require('abyss_actor')
local Theme=require('abyss_theme')
local M={capacity=5}
local L,S=Theme.layout,Theme.space
local function pendingFeedback(feedback,actor)
 if not feedback then return false end
 local current=feedback.current
 return feedback.escaping[actor.id] or feedback.dying[actor.id]
  or current and current.kind=='death' and current.detail.target==actor.id
  or not actor.escaped and not feedback.deaths[actor.id]
end
function M.slots(battle,feedback)
 local live=0
 for _,actor in ipairs(battle.enemies)do if Actors.isPresent(actor)then live=live+1 end end
 assert(live<=M.capacity,'live enemy presentation capacity exceeded')
 local rows,extras={},M.capacity-live
 for index,actor in ipairs(battle.enemies)do
  local active=Actors.isPresent(actor)
  local pending=pendingFeedback(feedback,actor)
  if active or pending and extras>0 then
   rows[#rows+1]={index=index,id=actor.id,actor=actor}
   if not active then extras=extras-1 end
  end
 end
 return rows
end
function M.find(battle,index,feedback)
 local rows=M.slots(battle,feedback)
 for slot,entry in ipairs(rows)do if entry.index==index then return entry,slot,#rows end end
end
function M.position(count,slot,actor)
 local step=count>1 and (L.enemyRow.xTo-L.enemyRow.xFrom)/(count-1) or 0
 local badge=math.max(L.blockBadge.size,3*Theme.font.body+L.blockBadge.padding*2)
 local full=L.hpBar.size[1]+badge+L.blockBadge.gap
 local x=count==1 and (L.enemyRow.xFrom+L.enemyRow.xTo)/2 or L.enemyRow.xFrom+(slot-1)*step
 local right=Theme.canvas.base[1]/2-Theme.canvas.safe.x
 local playerRight=L.player.position[1]+L.hpBar.size[1]/2
 local width=math.min(full,count>1 and step-S.s or full,2*(right-x)-S.s,2*(x-playerRight-S.s)-S.s)
 local portrait=actor.tier=='boss' and L.enemyRow.bossPortrait or math.min(L.enemyRow.portrait,width)
 return x,width,portrait,step
end
return M
