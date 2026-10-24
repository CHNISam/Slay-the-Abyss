-- Independent merchant implementation. Source/known content and RNG gaps:
-- docs/SHOP_PARITY.md. Missing buckets remain unavailable, never rerolled.
local R = require('abyss_sts_random')
local Price = require('abyss_shop_price')
local C = require('abyss_combat')
local Effects = require('abyss_effects')
local CardRandom = require('abyss_card_random')
local S = {}
local f32, floor = R.float32, math.floor
local bases = { common=150, uncommon=250, rare=300, shop=150 }
local potionBases = { common=50, uncommon=75, rare=100 }
local function owns(run,id)
    for _,v in ipairs(run.relics) do if v==id then return true end end
    return false
end
S.owns=owns
function S.cardRarity(roll,offset)
    roll=roll+(offset or 5)
    return roll<9 and 'rare' or roll<46 and 'uncommon' or 'common'
end
function S.relicRarity(roll) return roll<48 and 'common' or roll<82 and 'uncommon' or 'rare' end
function S.potionRarity(roll) return roll<65 and 'common' or roll<90 and 'uncommon' or 'rare' end
local function discount(run,price)
    if owns(run,'courier') then price=floor(f32(price*f32(.8))+.5) end
    if owns(run,'membership_card') then price=floor(f32(price*f32(.5))+.5) end
    return price
end
function S.removePrice(run)
    if owns(run,'smiling_mask') then return 50 end
    local base=run.data.rules.shop.removeCard+(run.shopRemoveCount or 0)*run.data.rules.shop.removeCardIncrement
    -- Each applyDiscount recomputes the service from its base; Membership is last.
    local multiplier=owns(run,'membership_card') and .5 or owns(run,'courier') and .8 or 1
    return floor(f32(base*f32(multiplier))+.5)
end
local function streams(run)
    if run.shopRng then return C.copy(run.shopRng) end
    local seed=run.eventSeed or string.format('%.0f',run.seed)
    return { merchant=R.fromSeed(seed),potion=R.fromSeed(seed) }
end
local function pick(rng,list)
    if #list==0 then return nil end
    return list[R.randomInt(rng,#list-1)+1]
end
local function candidates(run,category,rarity,kind,color,stock)
    local pool={}
    for _,def in ipairs(run.data[category][category]) do
        local allowed=def.rarity==rarity
        if category=='cards' then
            allowed=allowed and (not kind or def.type==kind) and (def.color or 'colored')==color
                and (def.type=='attack' or def.type=='skill' or def.type=='power')
                and not def.condition and not def.costMode and Effects.supported(def.effects)
        elseif category=='relics' then
            -- Both relics' canSpawn reject ShopRoom, even on the initial shelf.
            allowed=allowed and not owns(run,def.id) and def.id~='courier' and def.id~='smiling_mask'
            for _,o in ipairs(stock or {}) do if o.id==def.id then allowed=false end end
        elseif category=='potions' then
            -- Ironclad's potion pool excludes Silent's class-specific Poison Potion.
            -- Temporary effect-only isolation; complete 33-item source selection
            -- must remove this exclusion rather than skip or reroll pending items.
            allowed=allowed and def.id~='poison_potion' and not def.acquisitionPending
        end
        if allowed then pool[#pool+1]=def end
    end
    table.sort(pool,function(a,b) return a.id<b.id end)
    return pool
end
local function cardOffer(run,rng,cardOwner,slot,kind,color,rarity,previous,restock)
    local def
    -- The original rerolls both rarity and card for duplicate attack/skill.
    -- Bounded only to prevent an incomplete supported pool hanging the game.
    for _=1,256 do
        if color=='colored' then
            rarity=CardRandom.rollRarity(cardOwner,'shop')
            if kind=='power' and rarity=='common' then rarity='uncommon' end
        end
        def=pick(cardOwner.cardRng,candidates(run,'cards',rarity,kind,color))
        if not def or def.id~=previous then break end
    end
    if def and def.id==previous then def=nil end
    local multiplier=R.randomFloatBetween(rng.merchant,f32(.9),f32(1.1))
    return { slot=slot, id=def and def.id or '__missing_card_'..slot, type=def and def.type or kind or 'skill',color=color,
        rarity=rarity, unavailable=not def, sold=false,
        price=Price.quoteCard({rarity=rarity,multiplier=multiplier,color=color,
            phase=restock and 'restock' or 'initial',courier=restock and owns(run,'courier') or false,
            membership=restock and owns(run,'membership_card') or false}) }
end
local function itemOffer(run,rng,category,slot,stock,restock)
    local rarity
    if category=='potions' then rarity=S.potionRarity(R.randomInt(rng.potion,99))
    else rarity=slot==3 and not restock and 'shop' or S.relicRarity(R.randomInt(rng.merchant,99)) end
    local pool=candidates(run,category,rarity,nil,nil,stock)
    if restock and category=='relics' then
        local filtered={}
        for _,d in ipairs(pool) do
            if d.id~='smiling_mask' and d.id~='courier' and d.id~='old_coin' and d.id~='maw_bank' then filtered[#filtered+1]=d end
        end
        pool=filtered
    end
    local def=pick(category=='potions' and rng.potion or rng.merchant,pool)
    local base=(category=='potions' and potionBases or bases)[rarity]
    local price=floor(f32(base*R.randomFloatBetween(rng.merchant,f32(.95),f32(1.05)))+.5)
    return { slot=slot,id=def and def.id or '__missing_'..category..'_'..slot,rarity=rarity,
        unavailable=not def,sold=false,price=discount(run,price) }
end
function S.prepare(run)
    local rng=streams(run)
    local cardOwner=CardRandom.clone(run)
    local stock={cards={},relics={},potions={},shopRng=rng,cardRandom=cardOwner,contentMode='restricted-supported-pools'}
    for i,kind in ipairs({'attack','attack','skill','skill','power'}) do
        stock.cards[i]=cardOffer(run,rng,cardOwner,i,kind,'colored',nil,(i==2 or i==4) and stock.cards[i-1].id)
    end
    -- Colorless type varies; collect by rarity independently of type.
    for i,rarity in ipairs({'uncommon','rare'}) do
        stock.cards[i+5]=cardOffer(run,rng,cardOwner,i+5,nil,'colorless',rarity)
    end
    local sale=R.randomInt(rng.merchant,4)+1
    local o=stock.cards[sale];o.sale=true
    o.price=floor(o.price/2)
    for _,offer in ipairs(stock.cards) do offer.price=discount(run,offer.price) end
    for i=1,3 do stock.relics[i]=itemOffer(run,rng,'relics',i,stock.relics) end
    for i=1,3 do stock.potions[i]=itemOffer(run,rng,'potions',i) end
    return stock
end
function S.afterPurchase(run,flow,category,offer)
    if category=='relics' and offer.id=='membership_card' then
        for _,name in ipairs({'cards','relics','potions'}) do
            for _,o in ipairs(flow[name]) do o.price=floor(f32(o.price*f32(.5))+.5) end
        end
    end
    if not owns(run,'courier') then offer.sold=true;return end
    local cardOwner=category=='cards' and CardRandom.clone(run) or nil
    local fresh
    if category=='cards' then
        local rarity=offer.rarity
        if offer.color=='colorless' then rarity=R.randomFloat(flow.shopRng.merchant)<f32(.3) and 'rare' or 'uncommon' end
        fresh=cardOffer(run,flow.shopRng,cardOwner,offer.slot,offer.color=='colored' and offer.type or nil,offer.color,rarity,nil,true)
    else fresh=itemOffer(run,flow.shopRng,category,offer.slot,flow.relics,true) end
    flow[category][offer.slot]=fresh
    run.shopRng=flow.shopRng
    if cardOwner then CardRandom.commit(run,cardOwner) end
end
return S
