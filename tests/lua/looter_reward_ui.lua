local H=dofile('tests/lua/support/battle_action_fixture.lua')
local test,finish=H.suite('LOOTER_REWARD_UI')
local function reward()
 local h,u,p,e,t,d,deck=H.reward()
 -- Reward-controller contract fixture: real victory with independent staged reward.
 h.run.rewards.stolenGold={type='STOLEN_GOLD',amount=30,claimed=false}
 h.run.rewards.manualContinue=true;h.run.rewards.cardResolved=false;h:refresh()
 return h,u,p,e,t,d,deck
end
test('stolen button and explicit leave coexist with card choices',function()
 local h,u,p,e,t=reward();local g=h.run.gold
 assert(p:GetChild('stolenGold').visible,'missing stolen button')
 assert(p:GetChild('continue').visible,'missing explicit leave')
 t('card1',1);assert(h.run.phase=='reward');assert(not p:GetChild('card1').visible)
 t('stolenGold',2);assert(h.run.gold==g+30);t('stolenGold',3);assert(h.run.gold==g+30)
 t('continue',4);assert(h.run.phase=='map')
end)
test('skip preserves stolen reward and leave forfeits',function()
 local h,u,p,e,t=reward();local g=h.run.gold;t('skip',1);assert(h.run.phase=='reward');t('continue',2);assert(h.run.phase=='map' and h.run.gold==g)
end)
test('old stolen and leave gestures cannot survive card claim, modal, redraw or new reward',function()
 for _,action in ipairs({'stolenGold','continue'}) do for _,change in ipairs({'card','modal','redraw','replace'}) do
  local h,u,p,e,t,d,deck=reward();local g=h.run.gold;e(action,'down',1);e(action,'up',1)
  if change=='card' then t('card1',2) elseif change=='modal' then deck() elseif change=='redraw' then h:refresh() else h.run.rewards=H.F.Combat.copy(h.run.rewards);h:refresh() end
  e(action,'click',1);assert(h.run.gold==g and h.run.phase=='reward',action..' '..change)
 end end
end)
finish()
