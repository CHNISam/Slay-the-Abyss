-- Act-one combat potion rewards, independently implemented from the fixed
-- AbstractRoom/AbstractDungeon rule evidence in docs/POTION_REWARDS.md.
-- Content is explicitly restricted; an empty rarity is never rerolled down.
local Random = require('abyss_sts_random')
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
    -- it still draws once and increments the modifier on failure. White Beast
    -- Statue's later override is outside this project's supported relic pool.
    if context and context.allEscaped and run.encounterTier=='normal' then chance=0 end
    -- No reward-count suppression is currently reached by the supported normal,
    -- elite or Act-one Boss bundle; retain the source boundary explicitly.
    if (rewardCount or 0)>=4 then chance=0 end
    local roll=Random.randomInt(rng,99)
    if roll>=chance then return nil,rng,modifier+10 end
    local rarity=P.rarity(Random.randomInt(rng,99))
    local pool={}
    for _,definition in ipairs(run.data.potions.potions) do
        -- Poison Potion is Silent-exclusive, never an Ironclad reward.
        -- Effect-only additions wait for the complete source pool integration.
        -- That integration must remove this temporary exclusion, never reroll it.
        if definition.rarity==rarity and (definition.id~='poison_potion' or run.character=='silent') and not definition.acquisitionPending then
            pool[#pool+1]=definition.id
        end
    end
    table.sort(pool)
    local id=#pool>0 and pool[Random.randomInt(rng,#pool-1)+1] or nil
    return {id=id,rarity=rarity,unavailable=id==nil,contentMode='restricted-supported-pools'},rng,modifier-10
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
