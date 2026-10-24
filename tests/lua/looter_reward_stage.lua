local H=dofile('tests/lua/support/battle_action_fixture.lua')
local Theme=require('abyss_theme')
local test,finish=H.suite('LOOTER_REWARD_STAGE')
local function reward()
 local h,u,p,e,t,d=H.reward();h.run.rewards.stolenGold={type='STOLEN_GOLD',amount=30,claimed=false};h.run.rewards.manualContinue=true;h.run.rewards.cardResolved=false;h:refresh();return h,u,p,e,t,d
end
test('manual reward keeps the single centred stage and nonoverlapping action row',function()
 local h,u,p,e,t=reward();assert(p:GetChild('rewardStage').visible and not p:GetChild('resultPlate').visible)
 for _=1,40 do h:update(.05) end
 local R=Theme.layout.rewardPick
 for i=1,3 do local c=p:GetChild('card'..i);assert(c.y==R.y and c.localScaleX==R.scale) end
 local names={'skip','stolenGold','continue'}
 for _,name in ipairs(names) do local c=p:GetChild(name);assert(c.y==R.skip[2],name..' not below reward cards') end
 for i=1,2 do local a,b=p:GetChild(names[i]),p:GetChild(names[i+1]);assert(b.x-b.sizeDeltaX/2-(a.x+a.sizeDeltaX/2)>=Theme.space.m) end
 t('card1',1);assert(h.run.phase=='reward' and p:GetChild('rewardStage').visible);assert(not p:GetChild('card1').visible and not p:GetChild('skip').visible)
 assert(p:GetChild('stolenGold').visible and p:GetChild('continue').visible);t('stolenGold',2);t('continue',3);assert(h.run.phase=='map' and not p:GetChild('rewardStage').visible)
end)
test('normal entrance and hover updates do not swallow fresh card or action gestures',function()
 for _,name in ipairs({'card1','skip','stolenGold','continue'}) do
  local h,u,p,e,t=reward();local gold,deck=h.run.gold,#h.run.deck
  e(name,'down',7);h:update(.05);if name=='card1' then u:setHover(1);h:update(.05) end;e(name,'up',7);h:update(.05);e(name,'click',7)
  if name=='card1' then assert(#h.run.deck==deck+1) elseif name=='skip' then assert(h.run.rewards.cardResolved) elseif name=='stolenGold' then assert(h.run.gold==gold+30) else assert(h.run.phase=='map') end
 end
end)
finish()
