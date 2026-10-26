-- Controlled continuous source streams and real acquisition commands; these
-- fixtures do not claim natural-floor progression or platform acceptance.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run=require('abyss_run');local C=require('abyss_combat');local Pool=require('abyss_card_pool');local Shop=require('abyss_shop');local Nodes=require('abyss_nodes')
local data=require('abyss_data');local Capability=require('abyss_card_capability')
local run=Run.new(data,42,{character='silent',experimental=true});local expected={};local total=0
for _,rarity in ipairs({'common','uncommon','rare'})do for _,id in ipairs(run.data.cards.sourcePools.reward[rarity])do
 expected[id]=true;total=total+1;local definition
 for _,d in ipairs(run.data.cards.cards)do if d.id==id then definition=d end end
 assert(definition and Capability.isImplemented(definition),'incomplete source '..id)
end end
assert(total==71)
local seen,count={},0
for _=1,3000 do
 local ids,rng,offset,upgrades=Pool.prepareRewards(run);run.cardRng,run.cardRarityOffset=rng,offset
 for i,id in ipairs(ids)do if not seen[id]then
  run.phase='reward';run.rewards={cards=ids,cardUpgrades=upgrades};local before=#run.deck
  assert(Run.claimCardReward(run,i));assert(#run.deck==before+1 and run.deck[#run.deck].cardId==id)
  seen[id]=true;count=count+1;break
 end end
 if count==71 then break end
end
assert(count==71,'reward closure '..count)
print('ok all71 complete source identities sampled then really claimed')
seen,count={},0
for _=1,1500 do
 local flow=Shop.prepare(run);run.cardRng,run.cardRarityOffset=flow.cardRandom.cardRng,flow.cardRandom.cardRarityOffset;run.shopRng=flow.shopRng
 for slot=1,5 do local offer=flow.cards[slot];assert(not offer.unavailable,offer.id)
  if not seen[offer.id]then
   run.phase='node';flow.type='shop';run.nodeFlow=flow;run.gold=100000
   local before=#run.deck;assert(Nodes.buyCardSlot(run,slot));assert(#run.deck==before+1 and run.deck[#run.deck].cardId==offer.id)
   seen[offer.id]=true;count=count+1
  end
 end
 if count==71 then break end
end
assert(count==71,'shop closure '..count)
print('ok all71 source identities sampled then really purchased')
for _,spec in ipairs({{0,1,'cunning_potion'},{10,3,'ghost_in_a_jar'}})do
 local r=Run.new(data,spec[1],{character='silent',experimental=true});local flow=Shop.prepare(r)
 assert(flow.potions[spec[2]].id==spec[3]and not flow.potions[spec[2]].unavailable)
 r.phase='node';r.nodeFlow=flow;flow.type='shop';r.gold=100000;r.shopRng=flow.shopRng
 assert(Nodes.buyPotion(r,spec[2]));assert(r.potions[1]==spec[3])
 print('ok normal initial Silent shop purchases '..spec[3])
end
