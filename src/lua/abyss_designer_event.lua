-- Designer at STS319009d5, A0. Nodes owns each command transaction.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local Copy=require('abyss_combat')
local Purge=require('abyss_living_wall')
local Context=require('abyss_event_transform_context')
local Transform=require('abyss_transform_card')
local M={}
local function row(choice,title,description,enabled,picker)
 return {choice=choice,title=title,description=description,enabled=enabled~=false,picker=picker}
end
local function unique(run,uid)
 local selected,count=nil,0
 for _,card in ipairs(run.deck)do if card.uid==uid then selected,count=card,count+1 end end
 if type(uid)=='number'and uid%1==0 and uid>0 and count==1 then return selected end
end
local function upgradable(run)
 local cards={}
 for _,card in ipairs(run.deck)do
  local ok,why=Run.canUpgradeCard(run,card.uid)
  if ok then cards[#cards+1]=card
  elseif why~='card_not_upgradeable'then error(why)end
 end
 return cards
end
local function unbottledCount(run)
 local count=0
 for _,c in ipairs(run.deck)do if not c.inBottleFlame and not c.inBottleLightning and not c.inBottleTornado then count=count+1 end end
 return count
end
local function purgeable(run,uid)
 for _,card in ipairs(Purge.purgeCards(run))do if card.uid==uid then return true end end
 return false
end
local function result(event)
 event.stage,event.body='result','设计师完成了服务。';return true,'pending'
end
function M.prepare(run,event,rng)
 -- These two independent constructor draws precede the harmless first screen.
 event.adjustmentUpgradesOne=R.randomBoolean(rng or run.miscRng)
 event.cleanUpRemovesCards=R.randomBoolean(rng or run.miscRng)
 event.adjustCost,event.cleanUpCost,event.fullServiceCost,event.hpLoss=40,60,90,3
 event.stage,event.body='intro','一位设计师打量着你的牌组。'
end
local function serviceOptions(run,event)
 local count=unbottledCount(run);local selectable=#Purge.purgeCards(run)
 return {row('adjust','调整','支付40金币，'..(event.adjustmentUpgradesOne and '选择升级1张牌。'or'随机升级最多2张牌。'),run.gold>=40 and #upgradable(run)>0),
   row('cleanup','清理','支付60金币，'..(event.cleanUpRemovesCards and '移除1张牌。'or'变换2张牌。'),run.gold>=60 and count>=(event.cleanUpRemovesCards and 1 or 2) and selectable>=(event.cleanUpRemovesCards and 1 or 2)),
   row('full','全套服务','支付90金币，移除1张牌，然后随机升级1张剩余牌。',run.gold>=90 and count>0 and selectable>0),
   row('punch','殴打','失去3点生命。')}
end
local function selectionOptions(event)
 local upgrade=event.choice=='upgrade'
 return {row(event.choice,upgrade and '升级卡牌'or event.choice=='transform'and'变换卡牌'or'移除卡牌',
   event.choice=='transform'and'依次选择两张不同的卡牌。'or'选择一张卡牌。',true,
   upgrade and'designer_upgrade'or event.choice=='transform'and'designer_transform'or'designer_remove')}
end
function M.options(run,event)
 if event.stage=='intro'then return {row('continue','继续','查看设计师的服务。')}end
 if event.stage=='choice'then return serviceOptions(run,event)end
 if event.stage=='choose_card'then return selectionOptions(event)end
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 return {}
end
function M.view(run,event)
 if event.stage~='choose_card'then return end
 local upgrade=event.choice=='upgrade'
 event.purgeCards=upgrade and Copy.copy(upgradable(run))or Purge.purgeCards(run)
 event.selectionCards=event.purgeCards
 event.selection={count=event.choice=='transform'and 2 or 1,forUpgrade=upgrade,forTransform=false,
  canCancel=false,forPurge=event.choice=='remove'or event.choice=='full_remove',anyNumber=false,action=event.choice}
 if #event.selectionCards<event.selection.count then event.pendingBoundary='source_undersized_mandatory_grid'end
end
local function randomUpgrade(run,event,count)
 local cards=upgradable(run);R.shuffle(run.miscRng,cards)
 event.upgradedUids={}
 for i=1,math.min(count,#cards)do
  local ok,why=Run.upgradeCard(run,cards[i].uid);if not ok then return false,why end
  event.upgradedUids[#event.upgradedUids+1]=cards[i].uid
 end
 return result(event)
end
local function transform(run,event,uids)
 local context=run.transformContext or Context.new(run)
 if not context or not context.cards or not context.sourceToLocal then return false,'event_content_unavailable'end
 local offers={};event.removedUids,event.obtainedCardUids,event.obtainedSourceIds={},{},{}
 for _,uid in ipairs(uids)do
  local original=unique(run,uid);if not original or not purgeable(run,uid)then return false,'card_not_purgeable'end
  local fact=context.cards[original.cardId];if not fact then return false,'event_content_unavailable'end
  -- Source removes and transforms each selected card in click order. Both
  -- ShowCardAndObtain constructors (curse protection) precede either obtain.
  local ok,why=Run.removeCard(run,uid);if not ok then return false,why end
  local card,rng=Transform.select(fact.category,fact.sourceId,context.pools,run.miscRng)
  if not card then return false,rng end
  local id=context.sourceToLocal[card.cardId];if not id then return false,'event_content_unavailable'end
  run.miscRng=rng
  local offer,reason=Run.prepareCard(run,id);if not offer then return false,reason end
  offers[#offers+1]=offer;event.removedUids[#event.removedUids+1]=uid
  event.obtainedSourceIds[#event.obtainedSourceIds+1]=card.cardId
 end
 for _,offer in ipairs(offers)do
  local ok,uid=Run.commitCard(run,offer);if not ok then return false,uid end
  event.obtainedCardUids[#event.obtainedCardUids+1]=uid
 end
 event.selectedUids=nil;return result(event)
end
local function pair(run,uids)
 if type(uids)~='table'or getmetatable(uids)~=nil or #uids~=2 then return false end
 for k in pairs(uids)do if k~=1 and k~=2 then return false end end
 return uids[1]~=uids[2]and unique(run,uids[1])~=nil and unique(run,uids[2])~=nil
end
local function select(run,event,choice,uid)
 if choice~=event.choice then return false,'invalid_event_choice'end
 if choice=='transform'then
  if not pair(run,uid)then return false,'invalid_card'end
  return transform(run,event,uid)
 end
 local card=unique(run,uid);if not card then return false,'invalid_card'end
 if choice=='upgrade'then
  local ok,why=Run.upgradeCard(run,uid);if not ok then return false,why end
  event.upgradedUids={uid};return result(event)
 end
 if not purgeable(run,uid)then return false,'card_not_purgeable'end
 local ok,why=Run.removeCard(run,uid);if not ok then return false,why end
 event.removedUid=uid
 if choice=='full_remove'then return randomUpgrade(run,event,1)end
 return result(event)
end
local costs={adjust=40,cleanup=60,full=90}
local function action(event,choice)
 if choice=='adjust'then return 'upgrade'end
 if choice=='full'then return 'full_remove'end
 return event.cleanUpRemovesCards and 'remove'or'transform'
end
local function purchase(run,event,choice)
 local cost=costs[choice]
 if not cost then return false,'invalid_event_choice'end
 if run.gold<cost then return false,'insufficient_gold'end
 if choice=='adjust'and #upgradable(run)==0 then return false,'card_not_upgradeable'end
 local required=choice=='cleanup'and not event.cleanUpRemovesCards and 2 or 1
 if choice~='adjust'and unbottledCount(run)<required then return false,'event_condition_unmet'end
 -- Approved original-defect adaptation, before payment/state advancement.
 -- Original Punch still costs3HP; this adds no free Leave or reward/refund.
 if choice~='adjust'and #Purge.purgeCards(run)<required then return false,'event_selection_infeasible'end
 run.gold=run.gold-cost;event.goldPaid=cost
 if choice=='adjust'and not event.adjustmentUpgradesOne then return randomUpgrade(run,event,2)end
 event.choice=action(event,choice)
 event.stage,event.body='choose_card','已支付金币。请选择卡牌完成服务。'
 return true,'choose_card'
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if event.stage=='choose_card'then return select(run,event,choice,uid)end
 if uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='result'and choice=='leave'then return true,'complete'end
 if event.stage=='intro'and choice=='continue'then event.stage='choice';return true,'pending'end
 if event.stage~='choice'then return false,'invalid_event_choice'end
 if choice~='punch'then return purchase(run,event,choice)end
 local ok,lost=Run.eventDamage(run,event.hpLoss);if not ok then return false,lost end
 event.hpLost=lost;return result(event)
end
return M
