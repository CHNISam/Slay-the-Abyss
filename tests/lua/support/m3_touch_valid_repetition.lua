return function(duration)
 local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
 local deck={};for i=1,25 do deck[i]='defend' end
 local h,u,p,e,_,drain=H.setup(deck,nil,{touchScreen=function()return true end})
 local b=h.run.combat;b.energy=25
 -- The fixture already started a battle. Configure its existing playback port;
 -- gesture duration remains independent of animation speed.
 h.fastMode,u.fastMode=true,true;u.feedback:setFastMode(true)
 for i=1,20 do
  local energy,block,hand=b.energy,b.player.block,#b.hand
  e('card1','down',7);e('card1','drag',7,0,0);h:update(duration)
  e('dragLayer','up',7,0,0)
  e('card1','endDrag',7,0,0);e('card1','click',7,0,0)
  assert(b.energy==energy-1 and b.player.block==block+5 and #b.hand==hand-1,'release failed or committed twice at '..i)
  drain();assert(not u.gesture and not u.selected and not u.carry)
  H.F.Combat.draw(b,1);h:refresh()
 end
 assert(b.energy==5 and b.player.block==100)
 print('M3_TOUCH_VALID_REPETITION '..duration..' 20 submitted once')
end
