package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run=require('abyss_run')
local Shop=require('abyss_shop')
local Potions=require('abyss_potion_rewards')
local Data=require('abyss_data')
local Pool,R,C=require('abyss_relic_pool'),require('abyss_sts_random'),require('abyss_combat')
local function same(a,b)
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b);return end
 for key,value in pairs(a)do same(value,b[key])end
 for key in pairs(b)do assert(a[key]~=nil,'unexpected '..tostring(key))end
end
local function sourceStock(run,stock,before)
 local expected=C.copy(before)
 local bases={common=150,uncommon=250,rare=300,shop=150}
 for slot,offer in ipairs(stock.relics)do
  assert(#offer.sourceTrace>=1 and #offer.sourceRejected==0)
  if slot==3 then assert(offer.sourceTrace[1].tier=='shop')end
  for _,entry in ipairs(offer.sourceTrace)do
   assert(entry['end']==true,'initial shop consumes source queue tails')
   local queue=expected.queues[entry.tier]
   assert(queue[#queue]==entry.id,'offer trace skipped a remaining source identity')
   table.remove(queue)
  end
  assert(offer.sourceTrace[#offer.sourceTrace].id==offer.sourceId)
  local base=assert(bases[offer.rarity])
  assert(offer.price%1==0 and offer.price>=math.floor(base*.95+.5) and offer.price<=math.floor(base*1.05+.5))
 end
 -- Exact whole queues, including unavailable identities, and relic RNG remain
 -- detached on preparation. No support filter or hidden replacement draw.
 same(Pool.snapshot(stock.relicPool),expected)
 same(Pool.snapshot(run.relicPool),before)
 same(R.snapshot(stock.relicPool.rng),R.snapshot(run.relicPool.rng))
end
local part=... or 1
assert(part>=1 and part<=3 and part%1==0,'invalid character shop part')
local count,registered=0,0
local function test(name,fn) registered=registered+1;if (registered<=3)~=(part==1)then return end;fn();count=count+1;print('ok character shop '..registered..' - '..name)end
for _,id in ipairs({'silent','defect','watcher'}) do
 test(id..' merchant uses complete source identities and shared colorless cards',function()
  local available=0
  for seed=1,8 do
   local r=Run.new(Data,tostring(seed),{character=id,experimental=true})
   local before=Pool.snapshot(r.relicPool)
   local stock=Shop.prepare(r)
   assert(stock.contentMode=='source-queues')
   sourceStock(r,stock,before)
   for i,o in ipairs(stock.cards) do
    if i<=5 and not o.unavailable then
     available=available+1
     local found
     for _,c in ipairs(r.data.cards.cards) do if c.id==o.id then found=c end end
     assert(found and found.color==r.characterProfile.color)
     assert(o.id~='strike' and o.id~='defend' and o.id~='bash')
    end
   end
   for slot=6,7 do
    local offer=stock.cards[slot];local found
    for _,c in ipairs(r.data.cards.cards)do if c.id==offer.id then found=c end end
    assert(not offer.unavailable and found and found.colorlessNative,'shared colorless card must be implemented')
    assert(found.rarity==(slot==6 and 'uncommon' or 'rare'))
   end
   for _,p in ipairs(stock.potions) do
    if id~='silent' then assert(p.id~='poison_potion') end
   end
  end
  assert(available>0,'class color must not filter out all supported cards')
 end)
end
test('Poison Potion class eligibility agrees in merchant and reward selection',function()
 local poison
 for _,p in ipairs(Data.potions.potions) do if p.id=='poison_potion' then poison=p end end
 assert(poison)
 for _,id in ipairs(part==2 and {'silent','defect'} or {'watcher','ironclad'}) do
  local shopSeen,rewardSeen=false,false
  for seed=1,16 do
   local r=id=='ironclad' and Run.new(Data,tostring(seed))
    or Run.new(Data,tostring(seed),{character=id,experimental=true})
   -- A single-item fixture isolates eligibility, without claiming full pool parity.
   r.data.potions.potions={poison};r.potionChanceModifier=60
   local stock=Shop.prepare(r)
   for _,p in ipairs(stock.potions) do if p.id=='poison_potion' then shopSeen=true end end
   local reward=Potions.prepare(r,2)
   if reward and reward.id=='poison_potion' then rewardSeen=true end
  end
  assert(shopSeen==(id=='silent'));assert(rewardSeen==(id=='silent'))
 end
end)
print('CHARACTER_SHOP_PASS '..count)
print('CHARACTER_SHOP_PART '..part..' REGISTERED '..registered..' EXECUTED '..count)
