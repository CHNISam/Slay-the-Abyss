local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local test,finish=H.suite('LOOTER_FEEDBACK_UI')
test('gold HUD follows each displayed event frame, not committed final balance',function()
 local h,u,p,e,t,d=H.setup(nil,{'looter'});t('endTurn',1)
 assert(h.run.gold==84);assert(u.busy);assert(p:GetChild('piles').text=='99','HUD jumped before theft frame')
 local saw=false
 for i=1,100 do h:update(.05);if u.feedback.current and u.feedback.current.kind=='gold_stolen' then saw=true;assert(p:GetChild('piles').text=='84');break end end
 assert(saw);d()
end)
test('escape is a separate three-second presentation, never death or target',function()
 local h,u,p,e,t,d=H.setup(nil,{'looter'});local escaped=false
 for turn=1,5 do
  if h.run.phase~='combat' then break end;t('endTurn',turn)
  for i=1,400 do
   if not u.busy then break end
   if u.feedback.current and u.feedback.current.kind=='enemy_escape' then
    local id=h.run.combat.enemies[1].id;assert(not u.feedback.deaths[id]);assert(monsterControl(p,'enemy1').visible)
    h:update(2.9);assert(u.feedback.current.kind=='enemy_escape');assert(monsterControl(p,'enemy1').visible)
    h:update(.11);assert(u.feedback.current.kind~='enemy_escape');assert(not monsterControl(p,'enemy1'));escaped=true;break
   end
   h:update(.05)
  end
  d()
 end
 assert(escaped);assert(h.run.phase=='reward');assert(not p:GetChild('result').text:find('全灭'))
end)
finish()
