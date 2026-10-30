-- Persistent cardRng/cardBlizzRandomizer state. Fixed STS source 319009d5:
-- AbstractDungeon.rollRarity/getRewardCards and the four room rarity methods.
-- Base room rules only; this is not a complete reward identity/pool adapter.
local R = require('abyss_sts_random')
local M = {}
local contexts = {normal=true,elite=true,boss=true,shop=true}
local rarities = {common=true,uncommon=true,rare=true}
local function offset(value)
    assert(type(value)=='number' and value%1==0 and value>=-40 and value<=5,
        'Invalid card rarity offset')
    return value
end
local function validate(owner)
    assert(type(owner)=='table','Expected card RNG owner')
    offset(owner.cardRarityOffset)
    R.snapshot(owner.cardRng)
end
function M.new(seed)
    return {cardRng=R.fromSeed(seed),cardRarityOffset=5}
end
function M.snapshot(owner)
    validate(owner)
    return {version=1,cardRng=R.snapshot(owner.cardRng),cardRarityOffset=owner.cardRarityOffset}
end
function M.restore(snapshot)
    assert(type(snapshot)=='table' and getmetatable(snapshot)==nil,'Expected plain card snapshot')
    for key in pairs(snapshot)do
        assert(key=='version' or key=='cardRng' or key=='cardRarityOffset','Unexpected card snapshot field')
    end
    assert(snapshot.version==1,'Invalid card snapshot version')
    local value=offset(snapshot.cardRarityOffset)
    return {cardRng=R.restore(snapshot.cardRng),cardRarityOffset=value}
end
function M.clone(owner) return M.restore(M.snapshot(owner)) end
function M.commit(owner,prepared)
    validate(prepared)
    owner.cardRng,owner.cardRarityOffset=prepared.cardRng,prepared.cardRarityOffset
end
function M.rollRarity(owner,context,relics)
    assert(contexts[context],'Invalid card rarity context')
    validate(owner)
    -- BossRoom ignores the adjusted value but AbstractDungeon still rolled it.
    local roll=R.randomInt(owner.cardRng,99)+owner.cardRarityOffset
    if context=='boss' then return 'rare' end
    local rare,uncommon=require('abyss_relic_rarity').thresholds(context,relics or owner.relics)
    return roll<rare and 'rare' or roll<uncommon and 'uncommon' or 'common'
end
function M.rewardRarity(owner,context)
    assert(context=='normal' or context=='elite' or context=='boss','Invalid reward rarity context')
    local rarity=M.rollRarity(owner,context)
    if rarity=='common' then owner.cardRarityOffset=math.max(-40,owner.cardRarityOffset-1)
    elseif rarity=='rare' then owner.cardRarityOffset=5 end
    return rarity
end
function M.upgrade(owner,rarity,chance)
    assert(rarities[rarity],'Invalid reward upgrade rarity')
    validate(owner)
    if rarity=='rare' then return false end
    -- This must run after ALL reward identities are selected. Even chance=0
    -- consumes a nextFloat; callers must not optimize the A0 branch away.
    return R.randomBooleanChance(owner.cardRng,chance or 0)
end
return M
