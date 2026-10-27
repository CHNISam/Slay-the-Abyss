-- Source-identity adapters for the existing shared Run relic queues.
-- STS1 319009d5 ShopScreen/StoreRelic and MonsterRoomElite.dropReward.
local Pool=require('abyss_relic_pool')
local R=require('abyss_sts_random')
local M={}
local legacy={burning_blood='Burning Blood',anchor='Anchor',vajra='Vajra',
 bag_of_preparation='Bag of Preparation',lantern='Lantern',oddly_smooth_stone='Oddly Smooth Stone',
 bronze_scales='Bronze Scales',membership_card='Membership Card',courier='The Courier',
 smiling_mask='Smiling Mask',black_blood='Black Blood',slavers_collar='SlaversCollar',sozu='Sozu',
 black_star='Black Star',circlet='Circlet'}
local restockRejected={['Old Coin']=true,['Smiling Mask']=true,MawBank=true,['The Courier']=true}
function M.definition(run,id)
 for _,entry in ipairs(run.data.relics.relics)do
  if entry.id==id or entry.sourceId==id or legacy[entry.id]==id then return entry end
 end
end
function M.sourceId(run,id)
 local entry=M.definition(run,id)
 return entry and (entry.sourceId or legacy[entry.id] or entry.id) or legacy[id] or id
end
function M.context(run,options)
 options=options or {};local owned,deck={},{}
 for _,id in ipairs(run.relics)do owned[#owned+1]=M.sourceId(run,id)end
 for _,card in ipairs(run.deck)do
  for _,entry in ipairs(run.data.cards.cards)do
   if entry.id==card.cardId then deck[#deck+1]={type=entry.type:upper(),rarity=entry.rarity:upper()};break end
  end
 end
 return {act=run.act or 1,floor=options.floor or run.floor,room=options.room or 'monster',
  owned=owned,deck=deck,endless=false}
end
local function rarity(pool,id,entry)
 if entry and entry.rarity then return entry.rarity end
 if id=='Circlet' then return 'special' end
 for tier,ids in pairs(pool.catalog.queues)do for _,candidate in ipairs(ids)do if candidate==id then return tier end end end
 error('unknown relic rarity')
end
-- Caller supplies a private/staged pool. Missing implementation is information
-- on the original selected identity, never a predicate passed to canSpawn.
function M.draw(run,pool,tier,options)
 options=options or {}
 local draw=options.noncamp and Pool.noncamp or options.screenless and Pool.screenless or Pool.draw
 local id,trace,requested=draw(pool,tier,M.context(run,options),options.fromTail)
 local entry=M.definition(run,id)
 return {id=entry and entry.id or id,sourceId=id,requestedId=requested,requestedTier=tier,
  rarity=rarity(pool,id,entry),unavailable=entry==nil,trace=trace}
end
-- ShopScreen uses merchantRng only for tier/price. Initial stock and Courier
-- both consume the *tail* of these same queues. Each forbidden Courier result
-- is spent before the next tier roll, including when the next tier differs.
function M.shop(run,pool,merchant,slot,options)
 options=options or {};local offer;local rejected={}
 repeat
  local tier
  if slot==3 and not options.restock then tier='shop'
  else tier=Pool.rarity('shop',R.randomInt(merchant,99))end
  offer=M.draw(run,pool,tier,{room='shop',floor=options.floor,fromTail=true})
  if options.restock and restockRejected[offer.sourceId]then
   rejected[#rejected+1]={sourceId=offer.sourceId,tier=tier,trace=offer.trace}
  else break end
 until false
 offer.rejected=rejected;return offer
end
function M.elite(run)
 if run.encounterTier~='elite' then return {items={}} end
 if not run.relicPool then return nil,'relic_pool_unavailable' end
 local pool=Pool.restore(Pool.snapshot(run.relicPool),run.relicPool.catalog)
 local tier=Pool.rollTier(pool,'elite')
 local result={items={M.draw(run,pool,tier,{room='elite'})},relicPool=pool}
 for _,held in ipairs(run.relics)do
  if M.sourceId(run,held)=='Black Star' then
   tier=Pool.rollTier(pool,'elite')
   result.items[#result.items+1]=M.draw(run,pool,tier,{room='elite',noncamp=true});break
  end
 end
 return result
end
return M
