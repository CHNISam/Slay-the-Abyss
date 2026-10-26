-- Act-one combat potion rewards, independently implemented from the fixed
-- AbstractRoom/AbstractDungeon rule evidence in docs/POTION_REWARDS.md.
-- Select from the source-ordered full pool; rarity rejection spends every draw.
local Random = require('abyss_sts_random')
local Pool=require('abyss_potion_random')
local P = {}

function P.rarity(roll)
    assert(type(roll)=='number' and roll%1==0 and roll>=0 and roll<=99,'invalid potion rarity roll')
    return roll<65 and 'common' or roll<90 and 'uncommon' or 'rare'
end

function P.prepare(run, rewardCount, context)
    local streams=run.shopRng
    local rng=streams and Random.cloneState(streams.potion)
        or Random.fromSeed(run.eventSeed or string.format('%.0f',run.seed))
    local modifier=run.potionChanceModifier or 0
    local chance=40+modifier
    -- AbstractRoom keeps chance zero when all monsters escape a normal room;
    -- it still draws once and increments the modifier on failure.
    if context and context.allEscaped and (run.encounterTier=='normal' or run.encounterTier=='boss') then chance=0 end
    if require('abyss_relic_hooks').owns(run,'white_beast_statue') then chance=100 end
    -- No reward-count suppression is currently reached by the supported normal,
    -- elite or Act-one Boss bundle; retain the source boundary explicitly.
    if (rewardCount or 0)>=4 then chance=0 end
    local roll=Random.randomInt(rng,99)
    if roll>=chance then return nil,rng,modifier+10 end
    local selected=Pool.sample({potionRng=rng})
    local present=false
    for _,definition in ipairs(run.data.potions.potions)do if definition.id==selected.id then present=true;break end end
    return {id=selected.id,sourceId=selected.sourceId,rarity=selected.rarity,unavailable=not present,
        contentMode='source-full33'},rng,modifier-10
end

function P.commit(run,rng,modifier)
    if not run.shopRng then
        local seed=run.eventSeed or string.format('%.0f',run.seed)
        run.shopRng={merchant=Random.fromSeed(seed)}
    end
    run.shopRng.potion=rng
    run.potionChanceModifier=modifier
end

return P
