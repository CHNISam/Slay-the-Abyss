-- Independent CARD RewardItems; normal-room Prayer Wheel and Singing Bowl.
-- Generation consumes the shared card RNG in source order, never a rarity reroll.
local M={}
local function owns(run,id)return require('abyss_relic_hooks').owns(run,id)end
function M.managed(run)
 return run.rewards and run.rewards.cardRewardGroups~=nil or owns(run,'singing_bowl')or owns(run,'prayer_wheel')
end
function M.ensure(run)
 local rewards=run.rewards
 if not rewards.cardRewardGroups then
  rewards.cardRewardGroups={{cards=rewards.cards,cardUpgrades=rewards.cardUpgrades,resolved=rewards.cardResolved==true}}
 end
 return rewards.cardRewardGroups
end
function M.nextGroup(run)
 for i,group in ipairs(run.rewards.cardRewardGroups or {})do if not group.resolved then return group,i end end
end
function M.sync(run)
 local next=M.nextGroup(run)
 run.rewards.cardResolved=next==nil
 if next then run.rewards.cards,run.rewards.cardUpgrades=next.cards,next.cardUpgrades end
end
function M.prepareExtra(run)
 local extra=require('abyss_rare_relics').extraCardRewards(run,run.encounterTier=='normal')
 if extra==0 and not owns(run,'singing_bowl')then return end
 local groups=M.ensure(run)
 for _=1,extra do
  local cards,rng,offset,upgrades=require('abyss_card_pool').prepareRewards(run)
  run.cardRng,run.cardRarityOffset=rng,offset
  local group={cards=cards,cardUpgrades=upgrades,resolved=false}
  require('abyss_relic_hooks').previewCardReward(run,group,true)
  groups[#groups+1]=group
 end
 M.sync(run)
end
function M.open(run,source)
 if run.phase~='reward'or run.rewards~=source or source.cardResolved or not M.managed(run)then
  return false,'stale_card_reward'
 end
 if run.pendingBottledRelic or run.shopRelicChoice or run.pendingBossRelic or run.shopRelicRewards or run.pendingCardRewardSelection then
  return false,'relic_choice_pending'
 end
 return require('abyss_run').transaction(run,function(staged)
  M.ensure(staged)
  staged.cardRewardSelectionSerial=(staged.cardRewardSelectionSerial or 0)+1
  staged.pendingCardRewardSelection={token=staged.cardRewardSelectionSerial,rewardOwner=staged.rewards}
  return true
 end)
end
-- choice=0 is explicit API abandonment of one group; modal Skip instead uses close.
function M.claim(run,index,choice)
 return require('abyss_run').transaction(run,function(staged)
  if staged.phase~='reward'or not staged.rewards then return false,'no_pending_reward'end
  M.ensure(staged)
  if index==nil then local _,i=M.nextGroup(staged);index=i end
  if type(index)~='number'or index%1~=0 then return false,'invalid_reward_group'end
  local group=staged.rewards.cardRewardGroups[index]
  if not group or group.resolved then return false,'no_pending_reward'end
  local Run=require('abyss_run');local ok,why
  if choice=='bowl'then
   if not owns(staged,'singing_bowl')then return false,'missing_singing_bowl'end
   ok,why=Run.increaseMaxHp(staged,2)
  elseif type(choice)=='number'and choice%1==0 and choice>=0 and choice<=#group.cards then
   if choice==0 then ok=true
   else ok,why=Run.obtainCard(staged,group.cards[choice],{upgraded=group.cardUpgrades and group.cardUpgrades[choice]==true})end
  else return false,'invalid_reward_choice'end
  if not ok then return false,why end
  staged.rewards.cardRewardGroups[index].resolved=true
  M.sync(staged)
  if staged.rewards.cardResolved then staged.pendingCardRewardSelection=nil end
  return true,why
 end)
end
function M.close(run,token)
 local p=run.pendingCardRewardSelection
 if not p or p.token~=token or p.rewardOwner~=run.rewards then return false,'stale_card_reward'end
 run.pendingCardRewardSelection=nil;return true
end
return M
