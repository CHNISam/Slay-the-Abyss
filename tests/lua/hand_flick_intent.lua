local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Intent=require('abyss_battle_card_gestures').Intent
local T=require('abyss_theme')
local hy=T.layout.hand.y
local function gesture(touch,path,dt)
 local h,u,p,e=H.setup({'defend','defend'},nil,{touchScreen=function()return touch end})
 local x0=p:GetChild('card1').x
 e('card1','down',7,x0,hy)
 for _,pt in ipairs(path)do h:update(dt);e('dragLayer','drag',7,x0+pt[1],hy+pt[2])end
 local last=path[#path];local g=u.gesture
 e('dragLayer','up',7,x0+last[1],hy+last[2])
 return h.run.combat,g
end
for _,touch in ipairs({true,false})do
 -- Fast upward throw that stops short of the drop line still plays (no snap-back).
 local b,g=gesture(touch,{{2,20},{4,45},{5,75}},1/60)
 assert(g.playIntent,'vertical-dominant motion locks play intent')
 assert(b.energy==2 and #b.hand==1,'upward flick plays the card')
 -- Same distance, slow and deliberate: honour the drop line, card returns.
 b=gesture(touch,{{2,20},{4,45},{5,75}},0.4)
 assert(b.energy==3 and #b.hand==2,'slow short lift is not a throw')
 -- Fast lateral swipe through the hand never plays.
 b,g=gesture(touch,{{40,6},{90,12},{140,18}},1/60)
 assert(not g.playIntent and b.energy==3 and #b.hand==2,'lateral swipe stays a swipe')
end
-- Diagonal throw: up-dominant wins even with sideways drift.
local g={sx=0,sy=0,elapsed=0}
for i=1,4 do g.elapsed=i/60;g.x,g.y=i*12,i*25;Intent.sample(g,g.x,g.y)end
assert(g.playIntent and Intent.flick(g),'up-right throw counts as play')
-- Aiming / cancelled gestures are never upgraded by a flick.
g.aiming=true;assert(not Intent.flick(g));g.aiming=nil;g.cancelled=true;assert(not Intent.flick(g))
print('HAND_FLICK_INTENT_PASS 4')
