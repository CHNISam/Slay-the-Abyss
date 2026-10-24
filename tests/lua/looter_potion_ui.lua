local F=dofile('tests/lua/support/looter_potion_ui_fixture.lua')
local Run,C,Theme,reward=F.Run,F.C,F.Theme,F.reward
local passed,failed=0,0
local function test(name,fn) local ok,e=pcall(fn);if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(e)) end end
local function resolvedAction(h,name)
 if name=='card1' or name=='skip' then
  return h.run.phase=='reward' and h.run.rewards.cardResolved and not h.run.rewards.potion.resolved and Run.potionCount(h.run)==0
 end
 return h.run.phase=='reward' and h.run.rewards.potion.resolved
end
test('manual five-action row uses existing tokens without overlap',function()
 local h,u,p=reward(true);local names={'claimPotion','stolenGold','skip','continue','skipPotion'}
 for i,name in ipairs(names) do local a=p:GetChild(name);assert(a.visible,name)
  assert(a.y==Theme.layout.rewardPick.skip[2]);assert(math.abs(a.x)+a.sizeDeltaX/2<=Theme.canvas.base[1]/2-Theme.canvas.safe.x,'safe area '..name)
  if i>1 then local b=p:GetChild(names[i-1]);assert(a.x-a.sizeDeltaX/2-(b.x+b.sizeDeltaX/2)>=Theme.space.m,'overlap '..name) end
 end
 assert(not p:GetChild('potionReward').text:find('选牌时自动领取',1,true),'manual copy promises auto-claim')
end)
test('card and gold resolve without hiding bottle; leave explains pending bottle',function()
 local h,u,p,e,t=reward(true);t('card1',1);t('stolenGold',2)
 assert(h.run.phase=='reward' and p:GetChild('claimPotion').visible and not h.run.rewards.potion.resolved)
 t('continue',3);assert(h.run.phase=='reward');assert(p:GetChild('notice').text:find('药水',1,true))
 t('skipPotion',4);t('continue',5);assert(h.run.phase=='map')
end)
test('old bottle input cannot consume a replacement offer on the same reward owner',function()
 for _,manual in ipairs({false,true}) do for _,name in ipairs({'claimPotion','skipPotion'}) do
  local h,u,p,e,t=reward(manual);e(name,'down',1);e(name,'up',1)
  h.run.rewards.potion=C.copy(h.run.rewards.potion);e(name,'click',1)
  assert(not h.run.rewards.potion.resolved and Run.potionCount(h.run)==0,'stale '..name)
  t(name,2);assert(h.run.rewards.potion.resolved)
 end end
end)
test('old card and gold input cannot cross external potion resolution',function()
 for _,name in ipairs({'card1','skip','stolenGold','continue'}) do
  local h,u,p,e,t=reward(true);local gold,uid=h.run.gold,h.run.nextDeckUid
  e(name,'down',1);e(name,'up',1);assert(Run.skipPotionReward(h.run));e(name,'click',1)
  assert(h.run.phase=='reward' and h.run.gold==gold and h.run.nextDeckUid==uid and not h.run.rewards.cardResolved,'stale '..name)
 end
end)
test('old potion input cannot cross external gold resolution',function()
 local h,u,p,e,t=reward(true);e('claimPotion','down',1);e('claimPotion','up',1)
 assert(Run.claimStolenGoldReward(h.run));e('claimPotion','click',1)
 assert(not h.run.rewards.potion.resolved and Run.potionCount(h.run)==0)
end)
test('visual animation preserves a fresh bottle gesture',function()
 local h,u,p,e=reward(true);e('claimPotion','down',1);h:update(.05);u:setHover(1);h:update(.05);e('claimPotion','up',1);h:update(.05);e('claimPotion','click',1)
 assert(h.run.rewards.potion.result=='claimed' and Run.potionCount(h.run)==1)
end)
test('no-loss pure redraw retains the unchanged 170 reward owner gesture',function()
 for _,name in ipairs({'card1','skip','claimPotion','skipPotion'}) do for _,released in ipairs({false,true}) do
  local h,u,p,e=reward(false)
  e(name,'down',1);if released then e(name,'up',1) end;u:render()
  if not released then e(name,'up',1) end;e(name,'click',1)
  assert(resolvedAction(h,name),'unchanged reward gesture lost '..name)
 end end
end)
test('no-loss visual animation retains valid card and bottle gestures',function()
 for _,name in ipairs({'card1','skip','claimPotion','skipPotion'}) do
  local h,u,p,e=reward(false);e(name,'down',1);h:update(.05);u:setHover(1);h:update(.05);e(name,'up',1);h:update(.05);e(name,'click',1)
  assert(resolvedAction(h,name),'animation swallowed '..name)
 end
end)
print('LOOTER_POTION_UI '..passed..' passed '..failed..' failed');assert(failed==0)
