local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
do
  local h,u,p,e,tap,drain=H.setup({'defend','defend'})
  e('card1','down',7);e('card1','drag',7,0,0);e('dragLayer','up',7,0,0)
  drain()
  assert(h.run.combat.energy==2 and h.run.combat.player.block==5 and u.suppressClick)
  p:GetChild('endTurn').click()
  print('MIXED_HOST_AFTER_REAL_DRAG','turn='..h.run.combat.turn,'suppress='..tostring(u.suppressClick))
  assert(h.run.combat.turn==1,'expected current-source click-only action lock')
  assert(h:openExit() and h:closeExit())
  p:GetChild('endTurn').click()
  assert(h.run.combat.turn==2)
  print('MIXED_HOST_ENDTURN_RECOVERS_AFTER_EXIT')
end
do
  local h,u,p,e,tap,drain=H.setup({'bludgeon'},{'acid_slime_s'})
  local enemy=p:GetChild('enemy1')
  e('card1','down',7);e('card1','drag',7,enemy.x,enemy.y);e('dragLayer','up',7,enemy.x,enemy.y)
  drain()
  assert(h.run.phase=='reward' and u.rewardScreen=='list' and u.suppressClick)
  for i=1,3 do p:GetChild('cardReward').click();assert(u.rewardScreen=='list')end
  print('MIXED_HOST_REWARD_LOCK','screen='..u.rewardScreen,'suppress='..tostring(u.suppressClick))
  assert(h:openExit() and h:closeExit())
  p:GetChild('cardReward').click();assert(u.rewardScreen=='cards')
  p:GetChild('skip').click();assert(u.rewardScreen=='list')
  print('MIXED_HOST_REWARD_RECOVERS_AFTER_EXIT')
end
