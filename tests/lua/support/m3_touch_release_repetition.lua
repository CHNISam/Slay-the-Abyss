return function(duration)
 local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
 local h,u,p,e,tap,drain=H.setup({'defend'},nil,{touchScreen=function()return true end})
 local battle=h.run.combat
 local function idle()
  assert(not u.gesture and not u.carry and not u.selected and not p:GetChild('dragLayer').visible,'invalid release retained selection or aim')
 end
 -- Reuse one real UI and battle: no render/reinitialisation recovery between attempts.
 for i=1,20 do
  e('card1','down',7)
  local x,y=0,-330
  if i%3==0 then x,y=700,0
  elseif i%3==1 then x,y=0,300 end
  e('card1','drag',7,0,0);h:update(duration)
  e('dragLayer','up',7,x,y)
  e('card1','endDrag',7,x,y);e('card1','click',7,x,y)
  idle();assert(battle.energy==3 and #battle.hand==1 and battle.player.block==0,'cancel spent resources')
 end
 -- A real tap retry must remain available after all twenty cancelled drags.
 tap('card1',8);assert(u.selected==battle.hand[1].uid)
 tap('card1',8);assert(not u.selected and battle.energy==3,'same-card double tap must cancel')
 print('M3_TOUCH_RELEASE_REPETITION '..duration..' 20 cancelled; C mode preserved')
end
