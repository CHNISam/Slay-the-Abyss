-- TheLibrary at fixed STS319009d5. Nodes owns the enclosing transaction.
-- This is NOT getRewardCards: duplicate attempts reroll rarity AND identity;
-- pity never changes and no random upgrade/card-count/reward relic roll runs.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local CardRandom=require('abyss_card_random')
local Capability=require('abyss_card_capability')
local Hooks=require('abyss_relic_hooks')
local M={}
local colors={ironclad='red',silent='green',defect='blue',watcher='purple'}
local sizes={ironclad={common=20,uncommon=36,rare=16},silent={common=19,uncommon=33,rare=19},
 defect={common=18,uncommon=36,rare=17},watcher={common=19,uncommon=35,rare=17}}
local function definition(run,id)
 for _,d in ipairs(run.data.cards.cards)do if d.id==id then return d end end
end
local function available(run)
 -- The historical prepared and original-V4 components do not declare a full
 -- source class catalogue. This is an implementation boundary, not a source rule.
 return run.data.runCardCatalog==true and sizes[run.data.runCardCharacter]~=nil
end
local function dependencies(run)
 if not available(run)then return false,'library_source_catalog_unavailable'end
 -- These preview/obtain hooks have not been implemented by their shared owner.
 -- Never silently show base cards or insert a manually upgraded preview instead.
 for _,id in ipairs(run.relics or {})do
  if id=='frozen_egg' or id=='Frozen Egg 2' then
   return false,'event_obtain_content_unavailable'
  end
 end
 return true
end
local function row(choice,title,description,enabled)
 return {choice=choice,title=title,description=description,enabled=enabled~=false}
end
function M.prepare(run,event)
 assert(type(run.maxHp)=='number' and run.maxHp%1==0 and run.maxHp>=1 and run.maxHp<=2147483647,'invalid Library health')
 event.startMaxHp=run.maxHp
 -- Positive signed32 HP * .33f stays below MathUtils.round's int-cast limit.
 -- The operand and product are binary32; MathUtils adds its double .5 offset.
 event.healAmount=math.floor(R.float32(R.float32(run.maxHp)*R.float32(.33))+.5)
 event.stage,event.body='intro','书架之间一片寂静。你可以阅读一本书，也可以睡一会儿。'
end
function M.options(run,event)
 if event.stage=='intro'then
  local ready=dependencies(run)
  return {row('read','阅读',ready and '从20张不同的本职业卡牌中选择一张加入牌组。' or
   '当前来源目录或获得预览钩子尚未接齐，阅读暂不可用。',ready),
   row('sleep','睡觉','回复'..event.healAmount..'点生命（受治疗限制）。')}
 elseif event.stage=='result'then return {row('leave','离开','返回路线。')}end
 return {}
end
-- Nodes.view passes only its detached flow copy, never the permanent owner.
function M.view(_,event)
 if event.stage=='choose_offer'then
  -- Source four-argument grid overload, not a purge/reward-skip screen.
  event.selection={count=1,forUpgrade=false,forTransform=false,canCancel=true,forPurge=false,anyNumber=false}
 end
end
local function pools(run)
 local source=assert(run.data.cards.sourcePools,'missing Library source pools')
 local meta=assert(source.cardSourceMetadata,'missing Library source metadata')
 local reward=assert(source.reward,'missing Library reward pools')
 local expected=sizes[run.data.runCardCharacter];local seen={}
 for _,rarity in ipairs({'common','uncommon','rare'})do
  local bucket=assert(reward[rarity],'missing Library rarity pool')
  assert(#bucket==expected[rarity],'incomplete Library source pool')
  for _,id in ipairs(bucket)do
   local fact=assert(meta[id],'missing Library source identity')
   assert(type(fact.sourceId)=='string' and fact.rarity==rarity and not seen[fact.sourceId],'invalid Library source identity')
   seen[fact.sourceId]=true
  end
 end
 return reward,meta
end
local function rarity(run,owner)
 -- AbstractRoom applies every rare modifier before every uncommon modifier.
 -- Nloth'sGift is the source's only A0 ordinary-room rarity-changing relic.
 local rare=3
 for _,id in ipairs(run.relics or {})do if id=='nloths_gift' or id=="Nloth's Gift" or id=='NlothsGift'then rare=rare*3 end end
 if rare==3 then return CardRandom.rollRarity(owner,'normal')end
 local value=R.randomInt(owner.cardRng,99)+owner.cardRarityOffset
 return value<rare and 'rare' or value<rare+37 and 'uncommon' or 'common'
end
local function read(run,event)
 local ok,why=dependencies(run);if not ok then return false,why end
 local reward,meta=pools(run);CardRandom.snapshot(run)
 -- Nodes already staged this complete owner. Preview callbacks see the SAME
 -- stream as the source generator, never an independently forked card RNG.
 local owner=run
 local offers,seen={},{};local epoch=(event.offerEpoch or 0)+1
 while #offers<20 do
  local tier=rarity(run,owner);local bucket=reward[tier]
  local id=bucket[R.randomInt(owner.cardRng,#bucket-1)+1]
  local fact=meta[id]
  if not seen[fact.sourceId]then
   local d=definition(run,id)
   if not Capability.isImplemented(d) or d.sourceId~=fact.sourceId or d.rarity~=tier or d.color~=colors[run.data.runCardCharacter] then return false,'card_content_unavailable'end
   local card={cardId=id,sourceCardId=fact.sourceId,rarity=tier,upgraded=false,
    offerToken='library:'..tostring(run.roomGeneration)..':'..epoch..':'..(#offers+1)}
   Hooks.onPreviewObtainCard(run,card,d)
   seen[fact.sourceId]=true
   -- CardGroup.addToBottom prepends: grid order is reversed generation order.
   table.insert(offers,1,card)
  end
 end
 -- rollRarity never writes the inherited rarity offset.
 event.offers,event.offerEpoch,event.choice=offers,epoch,'read'
 event.stage,event.body='choose_offer','你翻开一本书。请选择一张卡牌加入牌组。'
 -- Source getBook uses global cosmetic MathUtils.random, not a gameplay RNG.
 return true,'choose_offer'
end
local function select(run,event,token)
 local ok,why=dependencies(run);if not ok then return false,why end
 local selected,matches
 matches=0
 for _,card in ipairs(event.offers or {})do if card.offerToken==token then selected=card;matches=matches+1 end end
 if type(token)~='string' or matches~=1 then return false,'invalid_event_card'end
 local reward,meta=pools(run);local member=false
 for _,id in ipairs(reward[selected.rarity] or {})do if id==selected.cardId then member=true end end
 local d=definition(run,selected.cardId);local fact=meta[selected.cardId]
 if not member or not fact or fact.sourceId~=selected.sourceCardId or not Capability.isImplemented(d)
  or d.sourceId~=selected.sourceCardId or d.rarity~=selected.rarity or d.color~=colors[run.data.runCardCharacter] then
  return false,'card_content_unavailable'
 end
 -- makeCopy, NOT makeStatEquivalentCopy. SearingBlow's constructor alone
 -- carries timesUpgraded, while resetting upgraded and baseDamage to 12.
 local options
 if selected.cardId=='searing_blow'then
  local n=selected.upgrades or (selected.upgraded and 1 or 0)
  options={upgrades=n,upgraded=false,searingBlowCopyUpgrades=n}
 end
 local accepted,uid=Run.obtainCard(run,selected.cardId,options)
 if not accepted then return false,uid end
 event.selectedOffer,event.obtainedCardUid,event.stage=token,uid,'result'
 event.body='你合上书本，获得了一张卡牌。'
 return true,'pending'
end
function M.choose(run,flow,choice,token)
 local event=flow.event
 if event.stage=='choose_offer'then
  if choice~='select'then return false,'invalid_event_choice'end
  return select(run,event,token)
 end
 if token~=nil then return false,'invalid_event_choice'end
 if event.stage=='result' and choice=='leave'then return true,'complete'end
 if event.stage~='intro'then return false,'invalid_event_choice'end
 if choice=='read'then return read(run,event)end
 if choice~='sleep'then return false,'invalid_event_choice'end
 local healed=Run.heal(run,event.healAmount)
 if type(healed)~='number' or healed<0 or healed%1~=0 then return false,'event_heal_failed'end
 event.healed,event.choice,event.stage=healed,'sleep','result'
 event.body='你睡了一会儿，实际回复了'..healed..'点生命。'
 return true,'pending'
end
return M
