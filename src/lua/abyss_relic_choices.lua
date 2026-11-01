-- Same-run shop relic reward screens; Run wraps public commands in transactions.
local M={}
local function runApi()return require('abyss_run')end
function M.createCardReward(run)
 local owner={};for key,value in pairs(run)do owner[key]=value end
 owner.encounterTier='normal' -- ShopRoom inherits AbstractRoom's base rarity.
 local cards,rng,offset,upgrades=require('abyss_card_pool').prepareRewards(owner)
 run.cardRng,run.cardRarityOffset=rng,offset
 local reward={cards=cards,cardUpgrades=upgrades,cardResolved=false}
 require('abyss_relic_hooks').previewCardReward(run,reward,true)
 return reward
end
function M.openRewards(run,id,items)
 assert(not run.shopRelicRewards,'unresolved shop relic rewards')
 run.shopRelicRewardSerial=(run.shopRelicRewardSerial or 0)+1
 run.shopRelicRewards={token=run.shopRelicRewardSerial,relic=id,items=items}
end
function M.adapter()
 return {createCardReward=M.createCardReward,openRewards=M.openRewards,
  obtainCardCopy=function(run,uid)return runApi().obtainCardCopy(run,uid)end}
end
local function screen(run,token)
 local p=run.shopRelicRewards
 if not p or p.token~=token then return nil,'stale_shop_relic_rewards'end
 return p
end
function M.claim(run,token,index,choice)
 local p,why=screen(run,token);if not p then return false,why end
 if type(index)~='number'or index%1~=0 or not p.items[index]then return false,'invalid_reward_choice'end
 local item=p.items[index];if item.claimed then return false,'reward_already_claimed'end
 local api=runApi();local ok,detail
 if item.kind=='card'then
  local reward=item.reward
  if choice~='bowl'and (type(choice)~='number'or choice%1~=0 or choice<0 or choice>#reward.cards)then return false,'invalid_reward_choice'end
  if choice=='bowl' then
   if not require('abyss_relic_hooks').owns(run,'singing_bowl')then return false,'missing_singing_bowl'end
   ok,detail=api.increaseMaxHp(run,2)
  elseif choice==0 then ok,detail=true,'skipped'
  else ok,detail=api.obtainCard(run,reward.cards[choice],{upgraded=reward.cardUpgrades and reward.cardUpgrades[choice]==true})end
 elseif item.kind=='potion'then
  if choice==0 then ok,detail=true,'skipped'
  elseif choice==1 then
   ok,detail=api.obtainPotion(run,item.id)
   if not ok and detail=='potion_blocked_by_sozu'then ok=true end
  else return false,'invalid_reward_choice'end
 else return false,'invalid_shop_relic_reward'end
 if not ok then return false,detail end
 -- Nested permanent commands can replace the reward graph. Find the committed
 -- private owner again rather than marking the obsolete pre-command item.
 p=assert(screen(run,token));p.items[index].claimed=true;p.items[index].result=detail
 return true,detail
end
function M.finish(run,token)
 local p,why=screen(run,token);if not p then return false,why end
 for _,item in ipairs(p.items)do if not item.claimed then return false,'shop_relic_rewards_pending'end end
 run.shopRelicRewards=nil;return true
end
function M.chooseMirror(run,uid)
 return require('abyss_shop_relics').chooseMirror(run,uid,M.adapter())
end
function M.pending(run)return run.shopRelicRewards~=nil or run.shopRelicChoice~=nil end
return M
