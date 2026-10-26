local Run=require('abyss_run')
local Shop=require('abyss_shop')
local C=require('abyss_combat')
local R=require('abyss_sts_random')
local Data=require('abyss_data')
local function same(a,b)
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil)end
end
-- Removing one implementation cannot change original selection or any stream.
-- The real shelf must retain that same source identity as unavailable.
local count=0
for _,character in ipairs({'ironclad','silent','defect','watcher','hutao','arlecchino','furina','raiden'})do
 local options=character~='ironclad' and {experimental=true,character=character} or nil
 local original=Run.new(Data,'42',options)
 local stock=Shop.prepare(original)
 local chosen=stock.cards[1]
 local changed=C.copy(original)
 for i=#changed.data.cards.cards,1,-1 do
  if changed.data.cards.cards[i].id==chosen.id then table.remove(changed.data.cards.cards,i)end
 end
 local actual=Shop.prepare(changed)
 assert(actual.cards[1].id==chosen.id,'removing an effect implementation changed source identity')
 assert(actual.cards[1].unavailable,'missing implementation must remain explicitly unavailable')
 for i,offer in ipairs(stock.cards)do
  assert(actual.cards[i].id==offer.id and actual.cards[i].price==offer.price,'missing definition shifted later shelf identities/prices')
 end
 same(R.snapshot(stock.cardRandom.cardRng),R.snapshot(actual.cardRandom.cardRng))
 same(stock.shopRng,actual.shopRng)
 count=count+1
end
print('SHOP_COMPLETE_SOURCE_PASS '..count)
