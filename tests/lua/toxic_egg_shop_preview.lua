-- StoreRelic purchase hook component; source stock is intact, not a natural-acquisition claim.
local Run,Shop,C,R,Data=require('abyss_run'),require('abyss_shop'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local run=Run.new(Data,'42');local flow=Shop.prepare(run,2)
local before=C.copy({run.cardRng,run.relicPool,flow.shopRng})
local deck=C.copy(run.deck)
assert(Run.obtainRelic(run,'toxic_egg'))
local offer={id='toxic_egg',slot=1}
Shop.afterPurchase(run,flow,'relics',offer)
local skills,others=0,0
for _,card in ipairs(flow.cards)do
 local definition
 for _,d in ipairs(run.data.cards.cards)do if d.id==card.id then definition=d;break end end
 if definition then
  if definition.type=='skill'then assert(card.upgraded==true);skills=skills+1
  else assert(not card.upgraded);others=others+1 end
 end
end
assert(skills>=2 and others>=2 and offer.sold==true)
local function same(a,b)
 if type(a)~='table'then assert(a==b);return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil)end
end
same({run.cardRng,run.relicPool,flow.shopRng},before);same(run.deck,deck)
Shop.afterPurchase(run,flow,'relics',offer)
for _,card in ipairs(flow.cards)do if card.upgraded then assert(card.upgrades==1)end end
same({run.cardRng,run.relicPool,flow.shopRng},before)
print('TOXIC_EGG_SHOP_PREVIEW_PASS')
