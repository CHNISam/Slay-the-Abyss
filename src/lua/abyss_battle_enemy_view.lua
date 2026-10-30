-- Screen slots are presentation only. Every entry retains its core index/ID.
local Actors=require('abyss_actor')
local SourceGeometry=require('abyss_monster_source_geometry')
local Theme=require('abyss_theme')
local M={}
local L=Theme.layout
local function pendingFeedback(feedback,actor)
 if not feedback then return false end
 local current=feedback.current
 return feedback.escaping[actor.id] or feedback.dying[actor.id]
  or current and current.kind=='death' and current.detail.target==actor.id and not feedback.deaths[actor.id]
  or feedback.busy and not actor.escaped and not feedback.deaths[actor.id]
end
function M.slots(battle,feedback)
 local rows={}
 for index,actor in ipairs(battle.enemies)do
  if Actors.isPresent(actor)or pendingFeedback(feedback,actor)then
   rows[#rows+1]={index=index,id=actor.id,actor=actor}
  end
 end
 return rows
end
function M.find(battle,index,feedback)
 local rows=M.slots(battle,feedback)
 for slot,entry in ipairs(rows)do if entry.index==index then return entry,slot,#rows end end
end
-- AbstractMonster: drawX=WIDTH*.75+offsetX*xScale, drawY=340*yScale+offsetY*yScale.
-- Native anchored coordinates are centered and Y-up. Control slots never enter this transform.
function M.geometry(actor)
 local source=SourceGeometry.resolve(actor)
 local sx,sy=Theme.canvas.base[1]/1920,Theme.canvas.base[2]/1080
 local x=(1440+source.x)*sx-Theme.canvas.base[1]/2
 local bottom=(340+source.y)*sy-Theme.canvas.base[2]/2
 local portrait=math.max(source.width*sx,source.height*sy)
 local hitX,hitBottom=x+source.hbX*sx,bottom+source.hbY*sy
 local rootY=bottom+portrait/2
 return {x=x,y=rootY,portrait=portrait,
  hitX=hitX,hitY=hitBottom+source.height*sy/2,hitWidth=source.width*sx,hitHeight=source.height*sy,
  nameX=hitX-x,nameY=hitBottom-36*sy-rootY,sourceScale=sy,
  healthX=hitX-x,healthY=hitBottom-18*sy-rootY,healthTextY=hitBottom-17*sy-rootY,healthHeight=20*sy,
  blockX=hitX-source.width*sx/2-14*sx-x,blockY=hitBottom-14*sy-rootY,blockTextY=hitBottom-16*sy-rootY,
  blockWidth=64*sx,blockHeight=64*sy,
  intentX=hitX-x+(actor.definitionId=='gremlin_nob' and -30*sx or 0),
  intentY=hitBottom+source.height*sy+32*sy-rootY,intentWidth=128*sx,intentHeight=128*sy,
  intentHitWidth=64*sx,intentHitHeight=64*sy}

end
function M.rowY(_,_,actor)return M.geometry(actor).y end
function M.position(_,_,actor)
 local g=M.geometry(actor)
 return g.x,L.battleUnit.nameWidth,g.portrait,g.hitWidth,g.y
end
local function fade(value,dt,speed)
 if value~=0 then value=value+(0-value)*dt*speed;if math.abs(value)<.01 then value=0 end end
 return value
end
function M.exp10Out(a)return 1-(2^(-10*a)-2^-10)/(1-2^-10)end
-- blocked: dying OR dragging a non-ENEMY hovered card.
-- hbAlpha multiplication occurs after geometry, exactly as original renderName.
function M.nameStep(timer,alpha,dt,bodyHovered,blocked,hbAlpha)
 timer=bodyHovered and timer+dt or fade(timer,dt,12)
 if blocked then return timer,alpha,nil end
 alpha=timer~=0 and math.min(timer*2,1)or fade(alpha,dt,3)
 local yOffset=-8*M.exp10Out(alpha)
 return timer,alpha*(hbAlpha or 1),yOffset
end
return M
