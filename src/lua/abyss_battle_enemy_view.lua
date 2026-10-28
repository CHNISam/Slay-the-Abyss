-- Screen slots are presentation only. Every entry retains its core index/ID.
local Actors=require('abyss_actor')
local UnitView=require('abyss_battle_unit_view')
local Theme=require('abyss_theme')
local M={capacity=5}
local L=Theme.layout
local function pendingFeedback(feedback,actor)
 if not feedback then return false end
 local current=feedback.current
 return feedback.escaping[actor.id] or feedback.dying[actor.id]
  or current and current.kind=='death' and current.detail.target==actor.id
  or not actor.escaped and not feedback.deaths[actor.id]
end
local function centerBoss(rows)
 if #rows%2==0 then return rows end
 local boss
 for slot,entry in ipairs(rows)do if entry.actor.tier=='boss' then
  if boss then return rows end
  boss=slot
 end end
 if boss then table.insert(rows,(#rows+1)/2,table.remove(rows,boss)) end
 return rows
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
 return centerBoss(rows)
end
function M.find(battle,index,feedback)
 local rows=M.slots(battle,feedback)
 for slot,entry in ipairs(rows)do if entry.index==index then return entry,slot,#rows end end
end
local function portraitSize(count,slot,actor)
 local row=L.enemyRow
 if actor and actor.tier=='boss' then return row.bossPortrait end
 local source=math.min(row.frontSourceSize,math.floor((row.zoneRight-row.zoneLeft)*row.sourceScale/count*1.1+.5))
 if slot%2==0 then source=math.floor(source*row.backScale+.5) end
 return source/row.sourceScale
end
function M.rowY(count,slot,actor)
 local row=L.enemyRow
 local portrait=portraitSize(count,slot,actor)
 local top=slot%2==1 and row.frontTop or row.backTop
 local y=top-L.intent.size-L.intent.portraitGap-portrait/2
 return y+(actor and UnitView.noticeLift(actor,portrait,y,false) or 0)
end
function M.position(count,slot,actor)
 local row=L.enemyRow
 local step=(row.zoneRight-row.zoneLeft)/count
 local x=row.zoneLeft+step*(slot-.5)
 return x,L.battleUnit.nameWidth,portraitSize(count,slot,actor),step,M.rowY(count,slot,actor)
end
return M
