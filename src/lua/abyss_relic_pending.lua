-- Permanent relic choices retain the originating room/reward behind this modal.
-- UI reads these offers and sends their owner token back; only Run mutates them.
local M={}
function M.owner(run)
 if not run then return end
 for _,key in ipairs({'pendingBottledRelic','shopRelicChoice','pendingBossRelic','shopRelicRewards','pendingCardRewardSelection'})do
  local owner=run[key]
  if owner and(key~='pendingCardRewardSelection'or run.phase=='reward'and owner.rewardOwner==run.rewards)then return owner,key end
 end
end
local function cardRows(run,owner,key,uids,rows)
 local selected={};for _,uid in ipairs(owner.selectedUids or {})do selected[uid]=true end
 local allowed={};for _,uid in ipairs(uids)do allowed[uid]=true end
 for _,card in ipairs(run.deck)do if allowed[card.uid]and not selected[card.uid]then
  rows[#rows+1]={card=card,token={owner=owner,key=key,kind='select',uid=card.uid}}
 end end
end
local function rewardCards(owner,key,cards,upgrades,rows,group,run)
 for i,id in ipairs(cards)do
  rows[#rows+1]={card={cardId=id,upgraded=upgrades and upgrades[i]==true},group=group,
   token={owner=owner,key=key,kind='card',index=group,choice=i}}
 end
 if run and require('abyss_relic_hooks').owns(run,'singing_bowl')then
  rows[#rows+1]={title=group and '第'..group..'组：增加2点生命上限'or'增加2点生命上限',
   description='放弃本组卡牌，增加2点生命上限并普通回复2点生命。',
   token={owner=owner,key=key,kind='card',index=group,choice='bowl'}}
 end
 rows[#rows+1]={title=group and '跳过第'..group..'组卡牌' or '跳过卡牌',
  description='放弃本组卡牌奖励。',token={owner=owner,key=key,kind='card',index=group,choice=0}}
end
function M.view(run)
 local owner,key=M.owner(run);if not owner then return end
 local rows={};local view={owner=owner,key=key,title='遗物效果',body='请完成遗物带来的选择。',rows=rows}
 if key=='pendingBottledRelic'then
  view.body='选择一张卡牌装入瓶中，每场战斗开始时将其放入手牌。'
  cardRows(run,owner,key,owner.uids,rows)
 elseif key=='shopRelicChoice'then
  view.body='选择一张永久牌组中的卡牌，获得它的复制。'
  cardRows(run,owner,key,owner.uids,rows)
 elseif key=='pendingBossRelic'and owner.kind=='cards'then
  view.body='还需选择'..(owner.total-#owner.selectedUids)..'张卡牌。'
  local uids={};for uid in pairs(owner.selectionUids)do uids[#uids+1]=uid end
  cardRows(run,owner,key,uids,rows)
 elseif key=='pendingBossRelic'then
  for i,item in ipairs(owner.relics or {})do if not item.claimed then
   rows[#rows+1]={relic=item.id or item.sourceId,token={owner=owner,key=key,kind='relic',choice=i}}
  end end
  if owner.gold~=nil and not owner.goldClaimed then rows[#rows+1]={title='领取'..owner.gold..'金币',description='金币加入本局库存。',token={owner=owner,key=key,kind='gold'}}end
  if owner.potion and not owner.potion.claimed then rows[#rows+1]={potion=owner.potion.id,token={owner=owner,key=key,kind='potion'}}end
  if owner.cards and not owner.cardResolved then rewardCards(owner,key,owner.cards,owner.cardUpgrades,rows,nil,run)end
  rows[#rows+1]={title='继续',description='放弃尚未领取的奖励并返回。',token={owner=owner,key=key,kind='done'}}
 elseif key=='shopRelicRewards'then
  for i,item in ipairs(owner.items)do if not item.claimed then
   if item.kind=='card'then rewardCards(owner,key,item.reward.cards,item.reward.cardUpgrades,rows,i,run)
   else
    rows[#rows+1]={potion=item.id,token={owner=owner,key=key,index=i,kind='potion',choice=1}}
    rows[#rows+1]={title='放弃第'..i..'瓶药水',description='不改变现有药水。',token={owner=owner,key=key,index=i,kind='potion',choice=0}}
   end
  end end
  if #rows==0 then rows[1]={title='继续',description='所有奖励已处理。',token={owner=owner,key=key,kind='done'}}end
 elseif key=='pendingCardRewardSelection'then
  view.title,view.body='卡牌奖励','每组奖励可以选择一张卡牌；持有颂钵时也可放弃该组卡牌，增加生命上限。'
  for i,group in ipairs(run.rewards.cardRewardGroups or {})do if not group.resolved then
   for j,id in ipairs(group.cards)do
    rows[#rows+1]={card={cardId=id,upgraded=group.cardUpgrades and group.cardUpgrades[j]==true},group=i,
     description='第'..i..'组卡牌奖励。',token={owner=owner,key=key,kind='card',index=i,choice=j}}
   end
   if require('abyss_relic_hooks').owns(run,'singing_bowl')then
    rows[#rows+1]={title='第'..i..'组：增加2点生命上限',description='放弃本组卡牌，增加2点生命上限并普通回复2点生命。',
     token={owner=owner,key=key,kind='card',index=i,choice='bowl'}}
   end
  end end
  rows[#rows+1]={title='返回奖励列表',description='保留所有尚未领取的卡牌奖励，可以稍后重新查看。',
   token={owner=owner,key=key,kind='close'}}
 end
 for _,row in ipairs(rows)do row.token.screenToken=owner.token end
 return view
end
function M.resolve(run,token)
 if type(token)~='table'or M.owner(run)~=token.owner or run[token.key]~=token.owner then return false,'stale_relic_choice'end
 local Run=require('abyss_run')
 return Run.transaction(run,function(staged)
  local p=staged[token.key]
  if token.key=='pendingBottledRelic'then
   local allowed=false;for _,uid in ipairs(p.uids)do if uid==token.uid then allowed=true end end
   if not allowed then return false,'invalid_bottle_card'end
   local ok,why=require('abyss_uncommon_relics').equipBottle(staged,p.id,token.uid)
   if ok then staged.pendingBottledRelic=nil end;return ok,why
  elseif token.key=='shopRelicChoice'then return require('abyss_relic_choices').chooseMirror(staged,token.uid)
  elseif token.key=='pendingBossRelic'then
   if p.kind=='cards'then return require('abyss_boss_relics').select(staged,token.uid)end
   return require('abyss_boss_relics').claim(staged,token.kind,token.choice)
  elseif token.key=='shopRelicRewards'then
   local Choices=require('abyss_relic_choices')
   if token.kind=='done'then return Choices.finish(staged,token.screenToken)end
   return Choices.claim(staged,token.screenToken,token.index,token.choice)
  elseif token.key=='pendingCardRewardSelection'then
   if p.rewardOwner~=staged.rewards then return false,'stale_card_reward'end
   local Cards=require('abyss_relic_card_rewards')
   if token.kind=='close'then return Cards.close(staged,token.screenToken)end
   if token.kind~='card'then return false,'invalid_card_reward'end
   return Cards.claim(staged,token.index,token.choice)
  end
  return false,'invalid_relic_choice'
 end)
end
return M
