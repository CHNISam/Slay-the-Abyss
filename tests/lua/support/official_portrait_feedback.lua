package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Feedback=require('abyss_feedback')
local Theme=require('abyss_theme')
local _,root=F.fixture()
local panel=root:GetChild('battlePanel')
local nativeFigure=F.control({kind='container',name='nativeFigure'})
local portraits={battlePose=function(_,x,y,sx,sy)
 nativeFigure:SetAnchoredPosition(x,y);nativeFigure:SetLocalScale(sx,sy,1)
end}
local feedback=Feedback.new(panel,{imageSource='static',portraits=portraits,
 color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end},function()end,function()end)
local battle=F.Combat.new(F.Data,{deck={'strike','defend'},enemies={'cultist'},seed=11})
local hero=panel:GetChild('hero'):GetChild('portrait')
hero:SetImage('static',105292)
feedback:bindIdle(battle)
local hit=panel:GetChild('hero'):GetChild('hit');local hx,hy=hit.x,hit.y
local events,hp,energy=#battle.events,battle.player.hp,battle.energy
for _=1,10 do feedback:update(.02)end
local function neutralPortrait(context)
 local c,w=hero.imageColor,Theme.color.buttonPressedText
 assert(c and c.r==w.r and c.g==w.g and c.b==w.b and c.a==w.a,
  context..': feedback replaced the traveler image tone with an element colour')
 assert(hero.imageId==105292,context..': feedback replaced the traveler image identity')
end
neutralPortrait('idle')
assert(nativeFigure.x==hero.x and nativeFigure.y==hero.y,'native figure did not inherit hero motion')
assert(nativeFigure.localScaleX==hero.localScaleX and nativeFigure.localScaleY==hero.localScaleY)
assert(nativeFigure.y~=0 or nativeFigure.localScaleY~=1,'must actually animate')
feedback.poses.player={age=0,keys={{0,40,1.2},{1,20,1.1}}};feedback:update(.02)
assert(nativeFigure.x==hero.x and nativeFigure.localScaleX==hero.localScaleX,'attack motion must propagate')
neutralPortrait('attack pose')
feedback:cancel()
neutralPortrait('cancel/reset')
assert(nativeFigure.x==0 and nativeFigure.y==0 and nativeFigure.localScaleX==1 and nativeFigure.localScaleY==1,'cancel must reset native pose')
feedback:bindIdle(battle);feedback:update(.02)
feedback:bindIdle(nil)
neutralPortrait('battle retirement')
feedback:update(1)
neutralPortrait('hidden battle')
local nextBattle=F.Combat.new(F.Data,{deck={'strike','defend'},enemies={'cultist'},seed=12})
feedback:bindIdle(nextBattle);feedback:update(.02)
neutralPortrait('next battle')
assert(hit.x==hx and hit.y==hy,'portrait motion must not move HUD clicks')
assert(#battle.events==events and battle.player.hp==hp and battle.energy==energy,'art must not change gameplay')
print('OFFICIAL_PORTRAIT_FEEDBACK_PASS')
