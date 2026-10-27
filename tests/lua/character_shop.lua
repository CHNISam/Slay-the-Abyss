package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run=require('abyss_run')
local Shop=require('abyss_shop')
local Potions=require('abyss_potion_rewards')
local Data=require('abyss_data')
local count=0
local function test(name,fn) fn();count=count+1;print('ok character shop '..count..' - '..name) end
for _,id in ipairs({'silent','defect','watcher'}) do
 test(id..' merchant uses complete source identities and shared colorless cards',function()
  local available=0
  for seed=1,8 do
   local r=Run.new(Data,tostring(seed),{character=id,experimental=true})
   local stock=Shop.prepare(r)
   assert(stock.contentMode=='restricted-supported-pools')
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
 for _,id in ipairs({'silent','defect','watcher','ironclad'}) do
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
