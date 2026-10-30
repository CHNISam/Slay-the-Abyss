local actorControl=dofile('tests/lua/support/game_ui_fixture.lua').actorControl
local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local T=require('abyss_theme')
local function near(a,b,eps)assert(math.abs(a-b)<(eps or 0.0001),tostring(a)..' ~= '..tostring(b))end
-- STS TargetArrow: control point behind the start, overshooting past the end.
local function curve(sx,sy,ex,fy,t)
 local cx,cy=sx-(ex-sx)/4,fy+(fy-sy)/2;local q=1-t
 return q*q*sx+2*q*t*cx+t*t*ex,q*q*sy+2*q*t*cy+t*t*fy,cx,cy
end
for _,touch in ipairs({false,true})do
 local h,u,p,e=H.setup({'strike'},nil,{touchScreen=function()return touch end})
 local enemy=actorControl(p,"enemy1");local ex,ey=enemy.x+10,enemy.y+8
 e('card1','down',7);e('card1','drag',7,ex,ey)
 local layer=p:GetChild('dragLayer');local card=p:GetChild('card1');local r=layer:GetChild('reticle')
 local sx,sy=card.x,card.y+T.layout.card.size[2]*T.layout.cardDrag.scale/2
 local fy=r.y-r.sizeDeltaY/2
 local n=T.layout.cardDrag.aimDots-2
 -- Continuous shaft: each segment is centred between consecutive curve points, rotated
 -- along the chord and long enough to overlap its neighbour (no gaps, no star beads).
 local px,py=sx,sy
 local span=math.sqrt((r.x-sx)^2+(fy-sy)^2);local stop=math.max(0.5,1-15/span)
 for i=1,n do
  local x,y=curve(sx,sy,r.x,fy,stop*i/n);local seg=layer:GetChild('aim'..i)
  assert(seg.visible)
  near(seg.x,(x+px)/2);near(seg.y,(y+py)/2)
  local len=math.sqrt((x-px)^2+(y-py)^2)
  assert(seg.sizeDeltaX>=len,'segments overlap into one continuous line')
  assert(seg.sizeDeltaY<=11,'shaft is a thin stroke, not a bead')
  near(seg.localRotationZ,math.deg(math.atan(y-py,x-px)),1e-6)
  assert(seg.imageColor.r==T.color.danger.r and seg.imageColor.g==T.color.danger.g,'locked arrow is red end to end')
  px,py=x,y
 end
 -- V head: both barbs meet at the tip and point back along the tangent, mirrored.
 local _,_,cx,cy=curve(sx,sy,r.x,fy,1);local heading=math.deg(math.atan(fy-cy,r.x-cx))
 local a,b=layer:GetChild('aim'..(n+1)),layer:GetChild('aim'..(n+2))
 assert(a.visible and b.visible)
 near(a.localRotationZ+b.localRotationZ,2*(heading+180),1e-6)
 for _,barb in ipairs({a,b})do
  local rad=math.rad(barb.localRotationZ)
  near(barb.x-math.cos(rad)*barb.sizeDeltaX/2,r.x,1e-6);near(barb.y-math.sin(rad)*barb.sizeDeltaX/2,fy,1e-6)
 end
 near(cy,fy+(fy-sy)/2) -- Source curve direction follows start/target height; it is not always downward.
 assert(r.visible and r.kind=='image');near(r.x,enemy.x);near(r.y,enemy.y)
 e('dragLayer','drag',7,-285,0)
 assert(r.visible,'previous visual keeps a dim ring at an untargeted pointer')
 near(r.x,-285);near(r.y,0);near(r.sizeDeltaX,T.layout.cardDrag.aimDot[2]*2)
 assert(r.imageColor.r==T.color.textDim.r and r.imageColor.g==T.color.textDim.g)
 assert(layer:GetChild('aim1').imageColor.r==T.color.goldBright.r,'unlocked arrow stays gold')
 e('dragLayer','drag',7,0,T.layout.hand.y)
 assert(not layer.visible and h.run.combat.energy==3,'cancel remains unspent and hides the whole aim layer')
end
local h,u,p,e=H.setup({'strike'})
e('card1','down',7);e('card1','drag',7,0,0);e('dragLayer','drag',7,0,300)
local layer=p:GetChild('dragLayer');local a,b=layer:GetChild('aim13'),layer:GetChild('aim14')
-- Pointer-only aim: arrow tip sits on the pointer.
local ra,rb=math.rad(a.localRotationZ),math.rad(b.localRotationZ)
near(a.x-math.cos(ra)*a.sizeDeltaX/2,0,1e-6);near(a.y-math.sin(ra)*a.sizeDeltaX/2,300,1e-6)
near(b.x-math.cos(rb)*b.sizeDeltaX/2,0,1e-6);near(b.y-math.sin(rb)*b.sizeDeltaX/2,300,1e-6)
print('AIM_VISUAL_PARITY_PASS 3')
