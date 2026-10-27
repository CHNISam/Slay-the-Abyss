-- Independent A0 NeowEvent/NeowReward behavior, fixed aeubanks/sts@319009d5.
-- The host supplies real per-character boss history; this module never unlocks it.
-- Run/Nodes owns the encompassing transaction, including all reward hooks.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local Purge=require('abyss_living_wall')
local Capability=require('abyss_card_capability')
local Context=require('abyss_event_transform_context')
local Transform=require('abyss_transform_card')
local Potions=require('abyss_potion_random')
local Hooks=require('abyss_relic_hooks')
local Copy=require('abyss_combat').copy
local M={}
local category0={'THREE_CARDS','ONE_RANDOM_RARE_CARD','REMOVE_CARD','UPGRADE_CARD','TRANSFORM_CARD','RANDOM_COLORLESS'}
local category1={'THREE_SMALL_POTIONS','RANDOM_COMMON_RELIC','TEN_PERCENT_HP_BONUS','THREE_ENEMY_KILL','HUNDRED_GOLD'}
local drawbacks={'TEN_PERCENT_HP_LOSS','NO_GOLD','CURSE','PERCENT_DAMAGE'}
local labels={THREE_CARDS='从三张随机职业牌中选一张',ONE_RANDOM_RARE_CARD='获得一张随机稀有职业牌',REMOVE_CARD='移除一张卡牌',
 UPGRADE_CARD='升级一张卡牌',TRANSFORM_CARD='变换一张卡牌',RANDOM_COLORLESS='从三张无色牌中选一张',
 THREE_SMALL_POTIONS='获得三瓶随机药水',RANDOM_COMMON_RELIC='获得一件随机普通遗物',TEN_PERCENT_HP_BONUS='增加最大生命',
 THREE_ENEMY_KILL='前三场战斗敌人生命为1',HUNDRED_GOLD='获得100金币',RANDOM_COLORLESS_2='从三张稀有无色牌中选一张',
 REMOVE_TWO='移除两张卡牌',ONE_RARE_RELIC='获得一件随机稀有遗物',THREE_RARE_CARDS='从三张稀有职业牌中选一张',
 TWO_FIFTY_GOLD='获得250金币',TRANSFORM_TWO_CARDS='变换两张卡牌',TWENTY_PERCENT_HP_BONUS='增加最大生命',
 BOSS_RELIC='失去初始遗物，获得一件随机首领遗物'}
local drawbackLabels={NONE='',TEN_PERCENT_HP_LOSS='失去最大生命',NO_GOLD='失去所有金币',CURSE='获得一张随机诅咒',PERCENT_DAMAGE='失去生命'}
local function row(choice,title,description,picker)
 return {choice=choice,title=title,description=description,enabled=true,picker=picker}
end
local function find(list,id,key)
 for _,v in ipairs(list or {})do if v[key or 'id']==id then return v end end
end
local function def(run,id)return find(run.data.cards.cards,id)end
local function bonus(maxHp)return math.floor(R.float32(R.float32(maxHp)*R.float32(.1)))end
local function pick(rng,list)return list[R.randomIntBetween(rng,0,#list-1)+1]end
local function reward(kind,drawback)return {type=kind,drawback=drawback or 'NONE'}end
function M.prepare(_run,event,history)
 if type(history)~='table' or type(history.bossCount)~='number' or history.bossCount<0 or history.bossCount%1~=0 then
  return false,'neow_history_unavailable'
 end
 event.stage,event.body='neow_intro','高塔之下，一位古老的存在向你伸出援手。'
 event.neowBossCount=history.bossCount
 return true
end
local function offers(run,event)
 event.hpBonus,event.damageLabel=bonus(run.maxHp),math.floor(run.hp/10)*3
 if event.neowBossCount==0 then
  event.rewards={reward('THREE_ENEMY_KILL'),reward('TEN_PERCENT_HP_BONUS')}
 else
  local rng=R.fromSeed(run.runSeed)
  local first,second=pick(rng,category0),pick(rng,category1)
  local drawback=pick(rng,drawbacks)
  local third={'RANDOM_COLORLESS_2'}
  if drawback~='CURSE'then third[#third+1]='REMOVE_TWO'end
  third[#third+1]='ONE_RARE_RELIC';third[#third+1]='THREE_RARE_CARDS'
  if drawback~='NO_GOLD'then third[#third+1]='TWO_FIFTY_GOLD'end
  third[#third+1]='TRANSFORM_TWO_CARDS'
  if drawback~='TEN_PERCENT_HP_LOSS'then third[#third+1]='TWENTY_PERCENT_HP_BONUS'end
  event.rewards={reward(first),reward(second),reward(pick(rng,third),drawback),reward(pick(rng,{'BOSS_RELIC'}))}
  event.neowRng=rng
 end
 event.stage,event.body='neow_blessing','选择一份恩赐。'
 return true,'pending'
end
local function description(_run,event,offer)
 local text=labels[offer.type]
 if offer.type=='TEN_PERCENT_HP_BONUS'then text=text..event.hpBonus
 elseif offer.type=='TWENTY_PERCENT_HP_BONUS'then text=text..event.hpBonus*2 end
 if offer.drawback~='NONE'then
  local penalty=drawbackLabels[offer.drawback]
  if offer.drawback=='TEN_PERCENT_HP_LOSS'then penalty=penalty..event.hpBonus
  elseif offer.drawback=='PERCENT_DAMAGE'then penalty=penalty..event.damageLabel end
  text=penalty..'；'..text
 end
 return text..'。'
end
function M.options(run,event)
 if event.stage=='neow_intro'then return {row('continue','继续','听取可获得的恩赐。')}end
 if event.stage=='neow_blessing'then
  local rows={};for i,offer in ipairs(event.rewards)do rows[i]=row('reward_'..i,'恩赐'..i,description(run,event,offer))end
  return rows
 end
 if event.stage=='neow_choose_card'then
  return {row('select','选择卡牌','选择'..(event.selectionTotal-#event.selectedUids)..'张卡牌。','neow_card')}
 end
 if event.stage=='neow_card_reward'then
  local rows={}
  for i,offer in ipairs(event.cardOffers)do
   local definition=def(run,offer.cardId)
   local entry=row('claim_'..i,definition and definition.name or offer.cardId,'将这张牌加入永久牌组。')
   entry.cardId=offer.cardId;rows[#rows+1]=entry
  end
  rows[#rows+1]=row('skip','跳过','不获取卡牌。');return rows
 end
 if event.stage=='neow_potions'then
  local rows={};local full=Run.potionCount(run)>=Run.potionCapacity(run)
  for i,offer in ipairs(event.potionOffers)do
   local definition=find(run.data.potions.potions,offer.id)
   local entry=row('potion_'..i,definition and definition.name or offer.id,offer.claimed and '已经处理。' or full and '药水槽已满，可先处理背包。' or '领取这瓶药水。')
   entry.enabled=not offer.claimed and (not full or Hooks.owns(run,'sozu'));entry.potionId=offer.id;rows[#rows+1]=entry
  end
  rows[#rows+1]=row('skip','继续','放弃尚未领取的药水。');return rows
 end
 if event.stage=='neow_result'then return {row('leave','启程','前往高塔。')}end
 return {}
end
local function upgradeable(run,card)
 local d=def(run,card.cardId)
 if not d or not d.upgrade or next(d.upgrade)==nil or card.upgraded and d.repeatable~=true then return false end
 local upgraded=Copy(d)
 for key,value in pairs(d.upgrade)do upgraded[key]=value end
 return Capability.isImplemented(upgraded)
end
local function candidates(run,kind)
 if kind~='UPGRADE_CARD'then return Purge.purgeCards(run)end
 local result={};for _,card in ipairs(run.deck)do if upgradeable(run,card)then result[#result+1]=card end end
 return result
end
function M.view(run,event)
 if event.stage~='neow_choose_card'then return end
 event.purgeCards={}
 for _,card in ipairs(candidates(run,event.selectedType))do
  if event.selectionUids[card.uid]then
   local selected=false;for _,uid in ipairs(event.selectedUids)do if uid==card.uid then selected=true end end
   if not selected then event.purgeCards[#event.purgeCards+1]=Copy(card) end
  end
 end
 event.selection={count=event.selectionTotal-#event.selectedUids,canCancel=false,anyNumber=false,
  forUpgrade=event.selectedType=='UPGRADE_CARD',forTransform=event.selectedType=='TRANSFORM_CARD',forPurge=event.selectedType=='REMOVE_CARD'}
end
local function result(event)
 event.stage,event.body='neow_result','你已接受恩赐，可以启程。';return true,'pending'
end
local function preparePicks(run,event,kind)
 local list=candidates(run,kind);event.selectionUids={};event.selectedUids={}
 for _,card in ipairs(list)do
  if event.selectionUids[card.uid]then return false,'invalid_card'end
  event.selectionUids[card.uid]=true
 end
 event.selectionTotal=(kind=='REMOVE_TWO' or kind=='TRANSFORM_TWO_CARDS')and 2 or 1
 if #list<event.selectionTotal then return false,'neow_insufficient_selectable_cards'end
 event.stage='neow_choose_card';return true,'choose_card'
end
local function prepareCards(run,event,kind)
 local sources=run.data.cards.sourcePools
 local choices,used={},{}
 local colorless=kind=='RANDOM_COLORLESS' or kind=='RANDOM_COLORLESS_2'
 for _=1,3 do
  -- Rare-only choices still consume rollRarity before overriding its result.
  local rarity=R.randomBooleanChance(event.neowRng,R.float32(.33))and 'uncommon' or 'common'
  if kind=='THREE_RARE_CARDS' or kind=='RANDOM_COLORLESS_2'then rarity='rare'
  elseif colorless and rarity=='common'then rarity='uncommon'end
  local pool=colorless and sources.colorlessShop[rarity] or sources.reward[rarity]
  if type(pool)~='table' or #pool<3 then return false,'neow_card_pool_unavailable'end
  local id
  repeat id=pick(colorless and run.cardRng or event.neowRng,pool)until not used[id]
  used[id]=true
  if not Capability.isImplemented(def(run,id))then return false,'card_content_unavailable'end
  choices[#choices+1]={cardId=id,rarity=rarity}
 end
 event.cardOffers,event.stage=choices,'neow_card_reward';return true,'pending'
end
local function preparePotions(run,event)
 local pool=Potions.pool(Potions.character(run))
 local rng=run.shopRng and R.cloneState(run.shopRng.potion)or R.fromSeed(run.runSeed)
 local choices={}
 for i=1,3 do
  local selected=pick(rng,pool)
  if not find(run.data.potions.potions,selected.id)then return false,'unknown_potion'end
  choices[i]={id=selected.id,claimed=false}
 end
 run.shopRng=run.shopRng or {merchant=R.fromSeed(run.runSeed)};run.shopRng.potion=rng
 event.potionOffers,event.stage=choices,'neow_potions';return true,'pending'
end
local function obtainRelic(run,event,tier)
 if tier=='boss'then
  if not run.relics[1]then return false,'neow_starting_relic_unavailable'end
  event.lostRelicId=table.remove(run.relics,1)
 end
 local offer,pool=Run.prepareRelic(run,{tier=tier,room='neow'})
 if not offer then return false,pool end
 local ok,why=Run.obtainRelic(run,offer.id);if not ok then return false,why end
 run.relicPool=pool;event.obtainedRelicId,event.relicOffer=why,offer
 return result(event)
end
local function activateReward(run,event,kind)
 if kind=='THREE_CARDS' or kind=='THREE_RARE_CARDS' or kind=='RANDOM_COLORLESS' or kind=='RANDOM_COLORLESS_2'then
  return prepareCards(run,event,kind)
 elseif kind=='THREE_SMALL_POTIONS'then return preparePotions(run,event)
 elseif kind=='REMOVE_CARD' or kind=='REMOVE_TWO' or kind=='TRANSFORM_CARD' or kind=='TRANSFORM_TWO_CARDS' or kind=='UPGRADE_CARD'then
  return preparePicks(run,event,kind)
 elseif kind=='RANDOM_COMMON_RELIC'then return obtainRelic(run,event,'common')
 elseif kind=='ONE_RARE_RELIC'then return obtainRelic(run,event,'rare')
 elseif kind=='BOSS_RELIC'then return obtainRelic(run,event,'boss')
 elseif kind=='THREE_ENEMY_KILL'then
  local ok,why=Run.obtainRelic(run,'NeowsBlessing');if not ok then return false,why end
  event.obtainedRelicId=why
 elseif kind=='TEN_PERCENT_HP_BONUS' or kind=='TWENTY_PERCENT_HP_BONUS'then
  local ok,why=Run.increaseMaxHp(run,event.hpBonus*(kind=='TWENTY_PERCENT_HP_BONUS'and 2 or 1))
  if not ok then return false,why end
 elseif kind=='HUNDRED_GOLD' or kind=='TWO_FIFTY_GOLD'then event.goldGained=Run.gainGold(run,kind=='HUNDRED_GOLD'and 100 or 250)
 elseif kind=='ONE_RANDOM_RARE_CARD'then
  local pool=run.data.cards.sourcePools.reward.rare
  if type(pool)~='table' or #pool==0 then return false,'neow_card_pool_unavailable'end
  local ok,why=Run.obtainCard(run,pick(event.neowRng,pool));if not ok then return false,why end
  event.obtainedCardUid=why
 else return false,'invalid_neow_reward'end
 return result(event)
end
local function curse(run,event)
 local context=Context.new(run)
 if not context then return false,'neow_curse_pool_unavailable'end
 -- CardLibrary.getCurse() uses cardRng, after the immediate reward setup.
 local source=pick(run.cardRng,context.pools.curses)
 local id=context.sourceToLocal[source]
 if not id then return false,'card_content_unavailable'end
 local ok,why=Run.obtainCard(run,id);if not ok then return false,why end
 event.curseUid=type(why)=='number' and why or nil;event.curseBlocked=why=='curse_blocked'
 return true
end
local function activate(run,event,index)
 local offer=event.rewards[index]
 if not offer then return false,'invalid_event_choice'end
 if offer.drawback=='NO_GOLD'then run.gold=0
 elseif offer.drawback=='TEN_PERCENT_HP_LOSS'then
  run.maxHp=math.max(1,run.maxHp-event.hpBonus);run.hp=math.min(run.hp,run.maxHp)
 elseif offer.drawback=='PERCENT_DAMAGE'then
  local ok,why=Run.eventDamage(run,math.floor(run.hp/10)*3);if not ok then return false,why end
 elseif offer.drawback~='CURSE' and offer.drawback~='NONE'then return false,'invalid_neow_drawback'end
 event.selectedType,event.selectedDrawback=offer.type,offer.drawback
 local ok,status=activateReward(run,event,offer.type);if not ok then return false,status end
 if offer.drawback=='CURSE'then
  local obtained,why=curse(run,event);if not obtained then return false,why end
 end
 return true,status
end
local function unique(run,uid)
 if type(uid)~='number' or uid%1~=0 then return nil end
 local found
 for _,card in ipairs(run.deck)do if card.uid==uid then if found then return nil end;found=card end end
 return found
end
local function selectCard(run,event,uid)
 if uid==nil or type(uid)~='number' or not event.selectionUids[uid] or not unique(run,uid)then return false,'invalid_card'end
 for _,selected in ipairs(event.selectedUids)do if uid==selected then return false,'invalid_card'end end
 local kind=event.selectedType
 if not find(candidates(run,kind),uid,'uid')then
  return false,kind=='UPGRADE_CARD'and 'card_not_upgradeable' or 'card_not_purgeable'
 end
 event.selectedUids[#event.selectedUids+1]=uid
 if #event.selectedUids<event.selectionTotal then return true,'choose_card'end
 local selected={}
 for _,id in ipairs(event.selectedUids)do
  local card=unique(run,id)
  if not card or not find(candidates(run,kind),id,'uid')then return false,'invalid_card'end
  selected[#selected+1]=card
 end
 if kind=='UPGRADE_CARD'then
  local card=selected[1];card.upgrades=(card.upgrades or(card.upgraded and 1 or 0))+1;card.upgraded=true
  event.upgradedUid=card.uid;return result(event)
 end
 local context
 if kind=='TRANSFORM_CARD' or kind=='TRANSFORM_TWO_CARDS'then
  context=Context.new(run);if not context then return false,'event_content_unavailable'end
 end
 -- Two-card transforms remove BOTH before either obtain effect. The single
 -- form selects its replacement before removal. Keep both source orders.
 local transformed={}
 local function transform(card)
  local original=context.cards[card.cardId]
  if not original then return false,'event_content_unavailable'end
  local selectedCard,rng=Transform.select(original.category,original.sourceId,context.pools,event.neowRng)
  if not selectedCard then return false,rng end
  local id=context.sourceToLocal[selectedCard.cardId]
  if not id or not Capability.isImplemented(def(run,id))then return false,'card_content_unavailable'end
  event.neowRng=rng;transformed[#transformed+1]=id;return true
 end
 if kind=='TRANSFORM_CARD'then local ok,why=transform(selected[1]);if not ok then return false,why end end
 for _,card in ipairs(selected)do local ok,why=Run.removeCard(run,card.uid);if not ok then return false,why end end
 if kind=='TRANSFORM_TWO_CARDS'then
  for _,card in ipairs(selected)do local ok,why=transform(card);if not ok then return false,why end end
 end
 event.obtainedUids={}
 for _,id in ipairs(transformed)do
  local ok,why=Run.obtainCard(run,id);if not ok then return false,why end
  event.obtainedUids[#event.obtainedUids+1]=why
 end
 return result(event)
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if event.stage=='neow_choose_card'then
  if choice~='select' or uid==nil then return false,'invalid_event_choice'end
  return selectCard(run,event,uid)
 end
 if uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='neow_intro' and choice=='continue'then return offers(run,event)end
 if event.stage=='neow_blessing'then
  local index=type(choice)=='string' and choice:match('^reward_([1234])$')
  if not index then return false,'invalid_event_choice'end
  return activate(run,event,tonumber(index))
 end
 if event.stage=='neow_card_reward'then
  if choice=='skip'then return result(event)end
  local index=type(choice)=='string' and choice:match('^claim_([123])$')
  local offer=index and event.cardOffers[tonumber(index)]
  if not offer then return false,'invalid_event_choice'end
  local ok,why=Run.obtainCard(run,offer.cardId);if not ok then return false,why end
  event.obtainedCardUid=why;return result(event)
 end
 if event.stage=='neow_potions'then
  if choice=='skip'then return result(event)end
  local index=type(choice)=='string' and choice:match('^potion_([123])$')
  local offer=index and event.potionOffers[tonumber(index)]
  if not offer or offer.claimed then return false,'invalid_event_choice'end
  if Hooks.owns(run,'sozu')then offer.claimed,offer.blocked=true,true;return true,'pending'end
  local ok,why=Run.obtainPotion(run,offer.id);if not ok then return false,why end
  offer.claimed,offer.slot=true,why;return true,'pending'
 end
 if event.stage=='neow_result' and choice=='leave'then return true,'complete'end
 return false,'invalid_event_choice'
end
return M
