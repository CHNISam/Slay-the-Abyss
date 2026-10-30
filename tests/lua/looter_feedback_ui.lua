local Native=dofile('tests/lua/support/current_monster_controls.lua')
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local test,finish=H.suite('LOOTER_FEEDBACK_UI')
test('gold HUD follows each displayed event frame, not committed final balance',function()
 local h,u,p,e,t,d=H.setup(nil,{'looter'});t('endTurn',1)
 assert(h.run.gold==84);assert(u.busy);assert(p:GetChild('piles').text=='99','HUD jumped before theft frame')
 local saw=false
 for i=1,100 do h:update(.05);if u.feedback.current and u.feedback.current.kind=='gold_stolen' then saw=true;assert(p:GetChild('piles').text=='84');break end end
 assert(saw);d()
end)
test('escape has a half-second action gate and independent three-second presentation, never death or target',function()
 local h,u,p,e,t,d=H.setup(nil,{'looter'});local escaped=false
 for turn=1,5 do
  if h.run.phase~='combat' then break end;t('endTurn',turn)
  for i=1,400 do
   if not u.busy then break end
   if u.feedback.current and u.feedback.current.kind=='enemy_escape' then
    local actor=h.run.combat.enemies[1];local id=actor.id;local box=Native.actor(p,actor)
    assert(not u.feedback.deaths[id] and box.visible)
    local state=assert(u.feedback.escaping[id]);local portrait=box:GetChild('portrait');local x=portrait.x
    h:update(.49);assert(u.feedback.current.kind=='enemy_escape' and box.alive and box.visible)
    h:update(.02);assert(u.feedback.current.kind~='victory','last escaping actor delays victory until the independent three-second animation ends')
    assert(u.feedback.escaping[id]==state and state.timer>2 and box.alive and portrait.x>x,'original escape continues moving after its action gate')
    h:update(2.38);assert(u.feedback.escaping[id]==state and box.alive,'escape remains before the three-second threshold')
    h:update(.12);assert(not u.feedback.escaping[id] and u.feedback.escaped[id] and box.alive==false,'escape retires its own native actor after the source clock')
    assert(not u.feedback.deaths[id]);escaped=true;break
   end
   h:update(.05)
  end
  d()
 end
 assert(escaped);assert(h.run.phase=='reward');assert(not p:GetChild('result').text:find('全灭'))
end)
finish()
