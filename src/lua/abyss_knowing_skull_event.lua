-- KnowingSkull at STS319009d5. Repeated rewards charge independent costs.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local P=require('abyss_potion_random')
local H=require('abyss_relic_hooks')
local M={}
local function row(choice,title,description)return {choice=choice,title=title,description=description,enabled=true}end
function M.prepare(run,event,_,floor)
 event.potionCost,event.goldCost,event.cardCost,event.leaveCost=6,6,6,6
 event.damageTaken,event.hpLost,event.goldEarned=0,0,0
 event.cards,event.potions={},{}
 -- Like the source room's shuffleRng, one room-seeded owner is reused for
 -- every draw. colorlessCardPool itself persists (and permutes) for the act.
 event.shuffleRng=Run.roomStreams(run,floor or run.floor).shuffleRng
 event.stage,event.body='intro','一颗会说话的头骨向你许诺答案。'
end
function M.options(_,event)
 if event.stage=='intro'then return {row('continue','继续','听听头骨的条件。')}end
 if event.stage=='choice'then return {
  row('potion','成功？','失去'..event.potionCost..'点生命，随机获得一瓶药水；满槽时药水丢失。'),
  row('gold','财富？','失去'..event.goldCost..'点生命，获得90金币。'),
  row('card','力量？','失去'..event.cardCost..'点生命，获得一张随机无色罕见牌。'),
  row('leave','离开','失去'..event.leaveCost..'点生命，然后离开。')}end
 if event.stage=='result'then return {row('leave','继续','返回路线。')}end
 return {}
end
local function damage(run,event,cost)
 local ok,lost=Run.eventDamage(run,cost);if not ok then return false,lost end
 event.damageTaken=event.damageTaken+cost;event.hpLost=event.hpLost+lost
 return true
end
local function potion(run,event)
 -- Sozu prevents generation entirely, whereas full slots still generate and
 -- lose the potion. This is a direct obtain, not a reclaimable reward item.
 if H.owns(run,'sozu')then event.potionBlocked=true;return true end
 local entries=P.pool(P.character(run))
 run.shopRng=run.shopRng or {merchant=R.fromSeed(run.eventSeed)}
 run.shopRng.potion=run.shopRng.potion or R.fromSeed(run.eventSeed)
 local index=R.randomIntBetween(run.shopRng.potion,0,#entries-1)
 local selected=entries[index+1]
 local ok,slot=Run.obtainPotion(run,selected.id)
 if not ok and slot~='potion_slots_full'then return false,slot end
 event.potions[#event.potions+1]={id=selected.id,sourceId=selected.sourceId,sourceIndex=index,
  obtainedSlot=ok and slot or nil,lost=not ok}
 return true
end
local function card(run,event)
 local sampled,why=require('abyss_event_card_sampling').colorless(run,'uncommon',event.shuffleRng)
 if not sampled then return false,why end
 local ok,uid=Run.obtainCard(run,sampled.cardId);if not ok then return false,uid end
 event.cards[#event.cards+1]={cardId=sampled.cardId,sourceCardId=sampled.sourceCardId,obtainedCardUid=uid}
 return true
end
local function reward(run,event,choice)
 local key=choice..'Cost';local cost=event[key]
 if not cost then return false,'invalid_event_choice'end
 local ok,why=damage(run,event,cost);if not ok then return false,why end
 event[key]=cost+1
 if choice=='potion'then ok,why=potion(run,event)
 elseif choice=='card'then ok,why=card(run,event)
 else event.lastGoldGained=Run.gainGold(run,90);event.goldEarned=event.goldEarned+90 end
 if ok==false then return false,why end
 event.choice,event.body=choice,'头骨回答了你，随后又索取更多生命。'
 return true,'pending'
end
function M.choose(run,flow,choice,uid)
 local event=flow.event
 if uid~=nil then return false,'invalid_event_choice'end
 if event.stage=='result'and choice=='leave'then return true,'complete'end
 if event.stage=='intro'and choice=='continue'then event.stage='choice';return true,'pending'end
 if event.stage~='choice'then return false,'invalid_event_choice'end
 if choice=='potion'or choice=='gold'or choice=='card'then return reward(run,event,choice)end
 if choice~='leave'then return false,'invalid_event_choice'end
 local ok,why=damage(run,event,event.leaveCost);if not ok then return false,why end
 event.choice,event.stage,event.body='leave','result','头骨指引你找到了出口。'
 return true,'pending'
end
return M
