local sliceFirst,sliceLast=...
sliceFirst,sliceLast=sliceFirst or 1,sliceLast or 6
assert(sliceFirst>=1 and sliceLast<=8 and sliceFirst<=sliceLast,'invalid looter UI slice')
local sliceRegistered,sliceExecuted=0,0
local F=dofile('tests/lua/support/looter_potion_ui_fixture.lua')
local Run,C,Theme,reward=F.Run,F.C,F.Theme,F.reward
local passed,failed=0,0
local function test(name,fn)
 sliceRegistered=sliceRegistered+1
 if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end
 sliceExecuted=sliceExecuted+1
 print('LOOTER_POTION_UI_CASE '..sliceRegistered..' '..name)
 local ok,e=pcall(fn);if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(e)) end end
local function resolvedAction(h,name)
 if name=='skip' then return h.run.phase=='reward' and h.battleUI.rewardScreen=='list' and not h.run.rewards.cardResolved end
 if name=='card1' then
  return h.run.phase=='reward' and h.run.rewards.cardResolved and not h.run.rewards.potion.resolved and Run.potionCount(h.run)==0
 end
 if name=='goldReward' then return h.run.rewards.goldClaimed==true end
 return h.run.phase=='reward' and h.run.rewards.potion.resolved
end
test('reward list rows use existing tokens without overlap and hide picker actions',function()
 local h,u,p=reward(true);local names={'goldReward','stolenGold','claimPotion','cardReward'}
 for i,name in ipairs(names) do local a=p:GetChild(name);assert(a.visible,name)
  assert(math.abs(a.x)+a.sizeDeltaX/2<=Theme.canvas.base[1]/2-Theme.canvas.safe.x,'safe area '..name)
  if i>1 then local b=p:GetChild(names[i-1]);assert(b.y-b.sizeDeltaY/2-(a.y+a.sizeDeltaY/2)>=Theme.space.m,'overlap '..name) end
 end
 assert(not p:GetChild('potionHelp'):GetChild('potionReward').text:find('选牌时自动领取',1,true),'manual copy promises auto-claim')
 assert(not p:GetChild('skip').visible and p:GetChild('skipPotion')==nil)
end)
test('card and gold resolve without hiding bottle; Proceed leaves it pending',function()
 local h,u,p,e,t=reward(true);t('cardReward',0);t('card1',1);t('stolenGold',2)
 assert(h.run.phase=='reward' and p:GetChild('claimPotion').visible and not h.run.rewards.potion.resolved)
 local rewards=h.run.rewards;t('continue',3);assert(h.run.phase=='map' and h.run.pendingCombatRewards.rewards==rewards and not rewards.potion.resolved)
end)
test('old bottle input cannot consume a replacement offer on the same reward owner',function()
 for _,manual in ipairs({false,true}) do for _,name in ipairs({'claimPotion'}) do
  local h,u,p,e,t=reward(manual);e(name,'down',1);e(name,'up',1)
  h.run.rewards.potion=C.copy(h.run.rewards.potion);e(name,'click',1)
  assert(not h.run.rewards.potion.resolved and Run.potionCount(h.run)==0,'stale '..name)
  t(name,2);assert(h.run.rewards.potion.resolved)
 end end
end)
test('old card and gold input cannot cross external potion resolution',function()
 for _,name in ipairs({'card1','skip','stolenGold','continue'}) do
  local h,u,p,e,t=reward(true);local gold,uid=h.run.gold,h.run.nextDeckUid
  if name=='card1' or name=='skip' then t('cardReward',0) end
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
 for _,name in ipairs({'card1','skip','claimPotion','goldReward'}) do for _,released in ipairs({false,true}) do
  local h,u,p,e,t=reward(false)
  if name=='card1' or name=='skip' then t('cardReward',0) end
  e(name,'down',1);if released then e(name,'up',1) end;u:render()
  if not released then e(name,'up',1) end;e(name,'click',1)
  assert(resolvedAction(h,name),'unchanged reward gesture lost '..name)
 end end
end)
test('no-loss visual animation retains valid card and bottle gestures',function()
 for _,name in ipairs({'card1','skip','claimPotion','goldReward'}) do
  local h,u,p,e,t=reward(false);if name=='card1' or name=='skip' then t('cardReward',0) end
  e(name,'down',1);h:update(.05);u:setHover(1);h:update(.05);e(name,'up',1);h:update(.05);e(name,'click',1)
  assert(resolvedAction(h,name),'animation swallowed '..name)
 end
end)
print('LOOTER_POTION_UI '..passed..' passed '..failed..' failed');assert(failed==0)
assert(sliceRegistered==8,'all original looter UI groups must register')
assert(sliceExecuted==sliceLast-sliceFirst+1,'all selected looter UI groups must execute')
print('LOOTER_POTION_UI_PART '..sliceFirst..' '..sliceLast..' '..sliceExecuted)
