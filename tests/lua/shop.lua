package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Nodes, Run, Map, C = require('abyss_nodes'), require('abyss_run'), require('abyss_map'), require('abyss_combat')
local data = require('abyss_data')
local function shop(seed, source, relics)
    local run=Run.new(source or data,seed or 42)
    local map=Map.generate(source or data,seed or 42)
    if relics then run.relics=relics end
    while true do
        local choices=Map.available(map)
        for _,n in ipairs(choices) do if n.type=='shop' then assert(Nodes.enter(run,map,n.id));return run,map end end
        assert(#choices>0);assert(Map.choose(map,choices[1].id))
    end
end
local function same(a,b)
    assert(type(a)==type(b),'type mismatch')
    if type(a)~='table' then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil) end
end
local r,m=shop();local f=Nodes.view(r,m).node
assert(#f.cards==7,'normal shop must have seven card slots, not the playable catalogue')
assert(#f.relics==3 and #f.potions==3,'three relic and potion slots')
local kinds={'attack','attack','skill','skill','power'};local sales=0
for i,o in ipairs(f.cards) do
    if i<=5 then assert(o.type==kinds[i] and o.color=='colored') else assert(o.color=='colorless' and o.rarity==(i==6 and 'uncommon' or 'rare')) end
    if o.sale then assert(i<=5);sales=sales+1 end
end
assert(sales==1 and f.relics[3].rarity=='shop')
local ids={'searing_blow','clothesline','warcry','bloodletting','rupture','__missing_card_6','__missing_card_7'}
local prices={70,53,46,34,81,89,173}
for i,o in ipairs(f.cards) do assert(o.id==ids[i] and o.price==prices[i],'project seed42 inventory regression') end
for _,o in ipairs(f.relics) do assert(o.id~='courier' and o.id~='smiling_mask') end
same(f,Nodes.view(r,m).node)
local r2,m2=shop();same(f,Nodes.view(r2,m2).node)
local r3,m3=shop(43);assert(r3.shopRng.merchant.counter>0)
local differs=false
for i,o in ipairs(r3.nodeFlow.cards) do if o.id~=f.cards[i].id or o.price~=f.cards[i].price then differs=true end end
assert(differs)
-- Snapshot/re-render/reopen must preserve stock and all streams.
local before=C.copy(r);Nodes.view(r,m);same(r,before)
local loaded=C.copy(r);same(Nodes.view(loaded,m).node,f)
r.gold=10000
local offer
for _,o in ipairs(f.cards) do if not o.unavailable then offer=o;break end end
assert(offer)
local n=#r.deck;assert(Nodes.buyCard(r,offer.id));assert(#r.deck==n+1 and r.gold==10000-offer.price)
before=C.copy(r);assert(not Nodes.buyCard(r,offer.id));same(r,before)
for _,o in ipairs(f.cards) do if o.unavailable then before=C.copy(r);assert(not Nodes.buyCard(r,o.id));same(r,before) end end
local potion
for _,o in ipairs(f.potions) do if not o.unavailable then potion=o;break end end
assert(potion)
r.potions={'fire_potion','block_potion','regen_potion'}
before=C.copy(r);local ok,why=Nodes.buyPotion(r,potion.slot);assert(not ok and why=='potion_slots_full');same(r,before)
r.potions[2]=nil;local gold=r.gold;assert(Nodes.buyPotion(r,potion.slot));assert(r.potions[2]==potion.id and r.gold==gold-potion.price)
before=C.copy(r);assert(not Nodes.buyPotion(r,potion.slot));same(r,before)
assert(Nodes.leaveShop(r));before=C.copy(r);assert(not Nodes.enter(r,m,f.id));same(r,before)
assert(not Nodes.buyCard(r,offer.id));same(r,before)
print('SHOP_PASS fixed seed, slots, categories, unavailable content, payment, full slots, sold out, reentry')
local S=require('abyss_shop')
local counts={common=0,uncommon=0,rare=0}
for roll=0,99 do local rarity=S.cardRarity(roll,5);counts[rarity]=counts[rarity]+1 end
assert(counts.rare==4 and counts.uncommon==37 and counts.common==59)
counts={common=0,uncommon=0,rare=0}
for roll=0,99 do local rarity=S.relicRarity(roll);counts[rarity]=counts[rarity]+1 end
assert(counts.common==48 and counts.uncommon==34 and counts.rare==18)
counts={common=0,uncommon=0,rare=0}
for roll=0,99 do local rarity=S.potionRarity(roll);counts[rarity]=counts[rarity]+1 end
assert(counts.common==65 and counts.uncommon==25 and counts.rare==10)
-- Same seed lets us independently check sequential integer discounts including sale.
local plain=shop(42);local both=shop(42,nil,{'courier','membership_card'})
for i,o in ipairs(plain.nodeFlow.cards) do
    assert(both.nodeFlow.cards[i].id==o.id)
    assert(both.nodeFlow.cards[i].price==math.floor(math.floor(o.price*.8+.5)*.5+.5))
end
assert(S.removePrice(both)==38)
both.relics[#both.relics+1]='smiling_mask';assert(S.removePrice(both)==50)
local member,memberMap=shop(42);member.gold=10000
local membership=member.nodeFlow.relics[3]
assert(membership.id=='membership_card' and not membership.unavailable,'supported shop-exclusive relic must be obtainable')
local initial=C.copy(member.nodeFlow);local state=C.copy(member.shopRng)
assert(Nodes.buyRelic(member,'membership_card'))
for i,o in ipairs(initial.cards) do assert(member.nodeFlow.cards[i].price==math.floor(o.price*.5+.5)) end
assert(Nodes.view(member,memberMap).node.removePrice==38);same(state,member.shopRng)
local courier=shop(42,nil,{'courier'});courier.gold=10000
local o=courier.nodeFlow.cards[1];local counter=courier.shopRng.merchant.counter
assert(Nodes.buyCard(courier,o.id));assert(not courier.nodeFlow.cards[1].sold and not courier.nodeFlow.cards[1].sale)
assert(courier.shopRng.merchant.counter>counter and #courier.deck==11)
local bottle=courier.nodeFlow.potions[1]
assert(not bottle.unavailable)
counter=courier.shopRng.merchant.counter
assert(Nodes.buyPotion(courier,1));assert(not courier.nodeFlow.potions[1].sold and courier.shopRng.merchant.counter>counter)
-- Purchasing Membership with Courier discounts the existing shelf, then restocks
-- the former shop-exclusive relic slot from the regular tier sampler.
local price=courier.nodeFlow.relics[3].price;local gold=courier.gold
assert(Nodes.buyRelic(courier,'membership_card'));assert(courier.gold==gold-price)
assert(courier.nodeFlow.relics[3].rarity~='shop' and not courier.nodeFlow.relics[3].sold)
assert(courier.nodeFlow.relics[3].id~='courier' and courier.nodeFlow.relics[3].id~='smiling_mask')
local blocked=shop(42,nil,{'sozu'});blocked.gold=10000
before=C.copy(blocked);local accepted,reason=Nodes.buyPotion(blocked,1)
assert(not accepted and reason=='potions_blocked');same(blocked,before)
local mask=shop(42,nil,{'smiling_mask','membership_card'});mask.gold=10000
assert(Nodes.removeCard(mask,mask.deck[1].uid));assert(mask.gold==9950)
before=C.copy(mask);assert(not Nodes.removeCard(mask,mask.deck[1].uid));same(mask,before)
print('SHOP_INTERACTIONS_PASS thresholds, sequential discounts, membership purchase, mask override, courier restock')
local broken=shop(42,nil,{'courier'});broken.gold=10000
broken.cardRng={} -- corrupt the single authoritative card stream for restock
before=C.copy(broken)
local called,ok,why=pcall(Nodes.buyCard,broken,broken.nodeFlow.cards[1].id)
assert(called and not ok and why=='shop_content_unavailable','restock failure must refuse the whole purchase')
same(broken,before)
print('SHOP_ATOMIC_RESTOCK_PASS')
-- Inject only the documented float endpoints; keep real selection and quoting.
-- In binary32, 50 * 1.05F is just below 52.5, so the upper quote is 52, not 53.
local R=require('abyss_sts_random');local original=R.randomFloatBetween
local expectedRelics={common={143,158},uncommon={238,263},rare={285,315},shop={143,158}}
local expectedPotions={common={48,52},uncommon={71,79},rare={95,105}}
local observed={}
local called,err=pcall(function()
    for endpoint=1,2 do
        R.randomFloatBetween=function(_,low,high) return endpoint==1 and low or high end
        for seed=1,20 do
            local stock=S.prepare(Run.new(data,seed))
            for _,o in ipairs(stock.relics) do
                assert(o.price==expectedRelics[o.rarity][endpoint],'relic price endpoint')
                observed[o.rarity]=true
            end
            for _,o in ipairs(stock.potions) do assert(o.price==expectedPotions[o.rarity][endpoint],'potion price endpoint') end
        end
    end
end)
R.randomFloatBetween=original
assert(called,err);assert(observed.common and observed.uncommon and observed.rare and observed.shop)
print('SHOP_PRICE_ENDPOINTS_PASS')
