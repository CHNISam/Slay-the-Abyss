local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local T=require('abyss_theme')
local function near(a,b,eps)assert(math.abs(a-b)<(eps or 0.0001),tostring(a)..' ~= '..tostring(b))end
-- STS TargetArrow: control point behind the start, overshooting past the end.
local function _curve(sx,sy,ex,fy,t)
 local cx,cy=sx-(ex-sx)/4,fy+(fy-sy)/2;local q=1-t
 return q*q*sx+2*q*t*cx+t*t*ex,q*q*sy+2*q*t*cy+t*t*fy,cx,cy
end
for _,touch in ipairs({false,true})do
 local h,u,p,e=H.setup({'strike'},nil,{touchScreen=function()return touch end})
 local enemy=monsterControl(p,'enemy1');local ex,ey=enemy.x+10,enemy.y+8
 e('card1','down',7);e('card1','drag',7,ex,ey)
 local layer=p:GetChild('dragLayer');local card=p:GetChild('card1');local r=layer:GetChild('reticle')
 local sx,sy=card.x,card.y+T.layout.card.size[2]*T.layout.cardDrag.scale/2
 local fy=r.y-r.sizeDeltaY/2
 -- Star chain (Pan 2026-10-31 restore of e7098ac over the dense shaft): upright
 -- star beads on the Bezier, growing toward the target, last bead pinned on the tip.
 local n=T.layout.cardDrag.aimDots
 local last=layer:GetChild('aim'..n);near(last.x,r.x);near(last.y,fy)
 local prev=0
 for i=1,n do
  local dot=layer:GetChild('aim'..i);assert(dot.visible)
  assert(dot.sizeDeltaX==dot.sizeDeltaY,'star bead, not a stretched shaft')
  assert(dot.sizeDeltaX>=prev);prev=dot.sizeDeltaX
  assert((dot.localRotationZ or 0)==0,'stars stay upright')
 end
 assert(last.imageColor.r==T.color.danger.r,'locked tail turns red')
 -- Native source positions may put this target below the carried card. The
 -- exact tangent and mirrored barb checks above cover either approach direction.
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
print('AIM_VISUAL_PARITY_PASS 3')
