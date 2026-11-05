-- 7e40d2d battle.js approved SVG translated to pooled native image primitives.
-- Dashed path is arc-length sampled, fixed-phase, red, 7 px; never 14 stars.
local M={}
function M.geometry(sx,sy,ex,ey)
 local a={sx=sx,sy=sy,ex=ex,ey=ey,cx=sx+.25*(ex-sx),cy=math.max(sy+150,ey+50),color=0xffd84b50,width=7,dash=12,gap=9,segments={}}
 local points={{x=sx,y=sy,d=0}};local distance=0
 for i=1,256 do local t=i/256;local u=1-t;local x=u*u*sx+2*u*t*a.cx+t*t*ex;local y=u*u*sy+2*u*t*a.cy+t*t*ey;local p=points[#points];distance=distance+math.sqrt((x-p.x)^2+(y-p.y)^2);points[#points+1]={x=x,y=y,d=distance} end
 local index=2
 local function at(d)
  while index<#points and points[index].d<d do index=index+1 end
  local p,q=points[index-1],points[index];local k=(d-p.d)/math.max(.0001,q.d-p.d)
  return p.x+(q.x-p.x)*k,p.y+(q.y-p.y)*k
 end
 for d=0,distance,21 do
  local x,y=at(d);local x2,y2=at(math.min(distance,d+12));local dx,dy=x2-x,y2-y
  a.segments[#a.segments+1]={x=(x+x2)/2,y=(y+y2)/2,length=math.sqrt(dx*dx+dy*dy),angle=math.atan(dy,dx)*180/math.pi}
 end
 a.angle=math.atan(ey-a.cy,ex-a.cx)*180/math.pi
 -- marker refX=15 within 20x20, marker5x5 under strokeUnits=7; center is 8.75 behind endpoint.
 a.headX,a.headY=ex-math.cos(a.angle*math.pi/180)*8.75,ey-math.sin(a.angle*math.pi/180)*8.75
 return a
end
function M.render(layer,geometry)
 layer:SetVisible(geometry~=nil);if not geometry then return end
 for i=1,80 do local node=layer:GetChild(i<=40 and 'dashesA' or 'dashesB'):GetChild('dash'..i);local s=geometry.segments[i];node:SetVisible(s~=nil);if s then node:SetAnchoredPosition(s.x,s.y);node:SetSizeDelta(s.length,geometry.width);node.localRotationZ=s.angle end end
 local head=layer:GetChild('head');head:SetAnchoredPosition(geometry.headX,geometry.headY);head.localRotationZ=geometry.angle
end
return M
