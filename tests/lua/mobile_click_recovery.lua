local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
do
  local h,u,p,e,_,drain=H.setup({'defend','defend'})
  e('card1','down',7);e('card1','drag',7,0,0);e('dragLayer','up',7,0,0)
  drain()
  assert(h.run.combat.energy==2 and h.run.combat.player.block==5 and u.suppressClick)
  -- A trailing touch Click is not an intentional anonymous button command.
  p:GetChild('endTurn').click({touchId=7})
  assert(h.run.combat.turn==1)
  p:GetChild('endTurn').click()
  assert(h.run.combat.turn==2,'click-only action must recover after real drag')
end
do
  local h,u,p,e,_,drain=H.setup({'bludgeon'},{'acid_slime_s'})
  local enemy=p:GetChild('enemy1')
  e('card1','down',7);e('card1','drag',7,enemy.x,enemy.y);e('dragLayer','up',7,enemy.x,enemy.y)
  drain()
  assert(h.run.phase=='reward' and u.rewardScreen=='list' and u.suppressClick)
  p:GetChild('cardReward').click();assert(u.rewardScreen=='cards')
  p:GetChild('skip').click();assert(u.rewardScreen=='list')
end
print('LUA_MOBILE_CLICK_RECOVERY 2 passed')
