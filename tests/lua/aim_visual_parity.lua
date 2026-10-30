local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local T=require('abyss_theme')
local function near(a,b)assert(math.abs(a-b)<0.0001,tostring(a)..' ~= '..tostring(b))end
for _,touch in ipairs({false,true})do
 local h,u,p,e=H.setup({'strike'},nil,{touchScreen=function()return touch end})
 local enemy=p:GetChild('enemy1');local ex,ey=enemy.x+10,enemy.y+8
 e('card1','down',7);e('card1','drag',7,ex,ey)
 local layer=p:GetChild('dragLayer');local card=p:GetChild('card1');local r=layer:GetChild('reticle')
 local sx,sy=card.x,card.y+T.layout.card.size[2]*T.layout.cardDrag.scale/2
 local fy=r.y-r.sizeDeltaY/2
 for i=1,14 do
  local t=i/14;local q=1-t;local dot=layer:GetChild('aim'..i)
  local b=T.layout.cardDrag.aimBend;local cx,cy=sx-(r.x-sx)*b[1],fy+(fy-sy)*b[2]
  near(dot.x,q*q*sx+2*q*t*cx+t*t*r.x);near(dot.y,q*q*sy+2*q*t*cy+t*t*fy)
  near(dot.sizeDeltaX,8+16*t)
  local colour=t>0.6 and T.color.danger or T.color.goldBright
  assert(dot.imageColor.r==colour.r and dot.imageColor.g==colour.g)
 end
 assert(r.visible and r.kind=='image');near(r.x,enemy.x);near(r.y,enemy.y)
 e('dragLayer','drag',7,-285,0)
 assert(r.visible,'previous visual keeps a dim ring at an untargeted pointer')
 near(r.x,-285);near(r.y,0);near(r.sizeDeltaX,T.layout.cardDrag.aimDot[2]*2)
 assert(r.imageColor.r==T.color.textDim.r and r.imageColor.g==T.color.textDim.g)
 e('dragLayer','drag',7,0,T.layout.hand.y)
 assert(not layer.visible and h.run.combat.energy==3,'cancel remains unspent and hides the whole aim layer')
end
local h,u,p,e=H.setup({'strike'})
e('card1','down',7);e('card1','drag',7,0,0);e('dragLayer','drag',7,0,300)
local layer=p:GetChild('dragLayer');local dot=layer:GetChild('aim14')
near(dot.x,0);near(dot.y,300)
-- STS TargetArrow 式流动：update 推进 phase 后点位沿曲线前移，末点仍钉在终点，规则状态不变。
do
 local h2,u2,p2,e2=H.setup({'strike'})
 local en=p2:GetChild('enemy1');e2('card1','down',7);e2('card1','drag',7,en.x,en.y)
 local L2=p2:GetChild('dragLayer');local before=L2:GetChild('aim5').x;local last=L2:GetChild('aim14')
 local lx,ly=last.x,last.y;local energy=h2.run.combat.energy
 h2:update(0.1)
 do assert(L2:GetChild('aim5').x~=before,'dots flow along the arc');near(last.x,lx);near(last.y,ly) end
 assert(h2.run.combat.energy==energy,'aim animation never spends or plays')
end
print('AIM_VISUAL_PARITY_PASS 3')
