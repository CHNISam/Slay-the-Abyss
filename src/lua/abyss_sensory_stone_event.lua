-- Fixed319009 SensoryStone: all RewardItems precede null-owner HP_LOSS.
-- This room owns its frozen reward list; combat rewards/choices are unrelated.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local Capability=require('abyss_card_capability')
local CardRandom=require('abyss_card_random')
local RelicHooks=require('abyss_relic_hooks')
local M={}
local counts={one=1,two=2,three=3}
local missing={question_card=true,busted_crown=true,singing_bowl=true}
local function definition(run,id)for _,d in ipairs(run.data.cards.cards)do if d.id==id then return d end end end
local function owns(run,id)for _,held in ipairs(run.relics)do if held==id then return true end end;return false end
local function dependencies(run)
 for id in pairs(missing)do if owns(run,id)then return false,'event_reward_content_unavailable'end end
 return true
end
local function row(choice,title,description,card)
 return {choice=choice,title=title,description=description,enabled=true,cardId=card and card.cardId,
  upgraded=card and card.upgraded,rewardCard=card~=nil,rarity=card and card.rarity}
end
local function pools(run)
 local source=assert(run.data.cards.sourcePools,'missing colorless source pool')
 local metadata=assert(source.cardSourceMetadata,'missing source card metadata')
 local out,seen={},{}
 for rarity,size in pairs({uncommon=20,rare=15})do
  local list=assert(source.colorlessShop and source.colorlessShop[rarity],'missing colorless rarity pool')
  assert(#list==size,'incomplete ordinary colorless pool');out[rarity]={}
  for _,id in ipairs(list)do
   local meta=assert(metadata[id],'missing colorless source identity')
   assert(not seen[id]and meta.rarity==rarity and type(meta.sourceId)=='string','invalid colorless source identity')
   seen[id]=true;out[rarity][#out[rarity]+1]=id
  end
  -- CardGroup.getRandomCard(true,rarity) sorts the temporary bucket by cardID.
  table.sort(out[rarity],function(a,b)return metadata[a].sourceId<metadata[b].sourceId end)
 end
 return out,metadata
end
local function rewards(run,num)
 local pool,metadata=pools(run);local owner=CardRandom.clone(run)
 local rng,offset=owner.cardRng,owner.cardRarityOffset;local groups={}
 for group=1,num do
  local cards,used={},{}
  for _=1,3 do
   local rarity=R.randomBooleanChance(rng,R.float32(.3))and'rare'or'uncommon'
   local bucket=pool[rarity];local id
   repeat id=bucket[R.randomInt(rng,#bucket-1)+1]until not used[id]
   if rarity=='rare'then offset=5 end
   local d=definition(run,id)
   if not Capability.isImplemented(d)or d.sourceId~=metadata[id].sourceId or d.rarity~=rarity then return nil,'event_content_unavailable'end
   used[id]=true;cards[#cards+1]={cardId=id,sourceCardId=metadata[id].sourceId,rarity=rarity,upgraded=false}
  end
  local reward={id=group,cards=cards,claimed=false};RelicHooks.previewCardReward(run,reward)
  groups[#groups+1]=reward
 end
 return groups,rng,offset
end
function M.prepare(run,event)
 assert(run.act==3,'Sensory Stone requires act3')
 event.stage,event.body='intro','Sensory Stone之中封存着一段记忆。'
end
function M.options(_,event)
 if event.stage=='intro'then return {row('continue','继续','查看记忆的代价。')}end
 if event.stage=='choice'then return {
  row('one','记忆1','获得1组无色卡牌奖励，不失去生命。'),
  row('two','记忆2','获得2组无色卡牌奖励，然后失去5点生命（HP_LOSS）。'),
  row('three','记忆3','获得3组无色卡牌奖励，然后失去10点生命（HP_LOSS）。')}
 end
 if event.stage=='result'then return {row('leave','离开','返回路线，放弃尚未领取的奖励。')}end
 local out={}
 if event.stage=='rewards'then
  for _,group in ipairs(event.rewards)do if not group.claimed then
   out[#out+1]=row('open_'..group.id,'无色奖励 '..group.id,'从本组选择一张牌；跳过后仍可重新查看。')
  end end
  out[#out+1]=row('proceed','结束奖励','返回事件，尚未领取的奖励将被放弃。')
 elseif event.stage=='cards'then
  local group=event.rewards[event.selectedReward]
  for i,c in ipairs(group.cards)do out[#out+1]=row('take_'..group.id..'_'..i,'领取卡牌','永久加入牌组。',c)end
  out[#out+1]=row('skip_'..group.id,'跳过本组','返回奖励列表，不改变本组候选。')
 end
 return out
end
local function remember(run,event,num)
 local ok,why=dependencies(run);if not ok then return false,why end
 local memories={1,2,3,4};R.shuffle(run.miscRng,memories)
 local groups,nextRng,offset=rewards(run,num);if not groups then return false,nextRng end
 event.memory,event.rewards,event.choiceCount=memories[1],groups,num
 event.stage,event.rewardScreenOpen='rewards',true
 event.body='记忆 '..event.memory..' · 请选择任意一组无色奖励。'
 run.cardRng,run.cardRarityOffset=nextRng,offset
 event.hpLoss=(num-1)*5
 if event.hpLoss>0 then
  local accepted,reason=Run.eventDamage(run,event.hpLoss);if not accepted then return false,reason end
 end
 return true,'pending'
end
local function chooseReward(_,event,choice)
 local index=tonumber(choice:match('^open_(%d+)$'))
 if index then
  local group=event.rewards[index];if not group or group.claimed then return false,'invalid_event_choice'end
  event.selectedReward,event.stage=index,'cards';return true,'pending'
 end
 if choice~='proceed'then return false,'invalid_event_choice'end
 event.stage,event.rewardScreenOpen,event.selectedReward='result',false,nil
 event.body='记忆渐渐散去。你可以继续前行。';return true,'pending'
end
local function chooseCard(run,event,choice)
 local group=event.rewards[event.selectedReward]
 if choice=='skip_'..group.id then event.stage,event.selectedReward='rewards',nil;return true,'pending'end
 local id,index=choice:match('^take_(%d+)_(%d+)$');id,index=tonumber(id),tonumber(index)
 if id~=group.id or not index or not group.cards[index]or group.claimed then return false,'invalid_event_choice'end
 local ready,why=dependencies(run);if not ready then return false,why end
 local card=group.cards[index];local d=definition(run,card.cardId)
 if not d or d.sourceId~=card.sourceCardId or d.rarity~=card.rarity then return false,'stale_event_card'end
 local expected={upgraded=false};RelicHooks.onPreviewObtainCard(run,expected,d)
 if card.upgraded~=expected.upgraded or card.upgrades~=expected.upgrades then return false,'stale_event_card'end
 local ok,uid=Run.obtainCard(run,card.cardId,{upgraded=card.upgraded,upgrades=card.upgrades})
 if not ok then return false,uid end
 group.claimed,group.obtainedUid,group.selectedIndex=true,uid,index
 event.stage,event.selectedReward='rewards',nil;return true,'pending'
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if run.act~=3 or uid~=nil or type(choice)~='string'then return false,'invalid_event_choice'end
 if event.stage=='intro'and choice=='continue'then event.stage='choice';return true,'pending'end
 if event.stage=='choice'and counts[choice]then return remember(run,event,counts[choice])end
 if event.stage=='rewards'then return chooseReward(run,event,choice)end
 if event.stage=='cards'then return chooseCard(run,event,choice)end
 if event.stage=='result'and choice=='leave'then return true,'complete'end
 return false,'invalid_event_choice'
end
return M
