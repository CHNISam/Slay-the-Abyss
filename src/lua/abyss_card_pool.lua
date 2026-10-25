-- Source-ordered, all-unlocked Ironclad pools; shared run.cardRng ownership.
-- This module never filters a rarity bucket by implemented effects or rerolls
-- an unsupported result. Canonical pool evidence lives in data/reference.
local R=require('abyss_sts_random')
local M={}
function M.rarity(roll,offset,tier)
    local adjusted=roll+offset
    if tier=='boss' then return 'rare' end
    local rare=tier=='elite' and 10 or tier=='shop' and 9 or 3
    local uncommon=tier=='elite' and 50 or tier=='shop' and 46 or 40
    return adjusted<rare and 'rare' or adjusted<uncommon and 'uncommon' or 'common'
end
function M.prepareRewards(run)
    local rng=R.cloneState(run.cardRng)
    local offset,choices,used=run.cardRarityOffset or 5,{},{}
    local pools=assert(run.data.cards.sourcePools,'missing source pools').reward
    for _=1,run.data.rules.rewards.cardChoices do
        local rarity=M.rarity(R.randomInt(rng,99),offset,run.encounterTier)
        if rarity=='common' then offset=math.max(-40,offset-1)
        elseif rarity=='rare' then offset=5 end
        local pool=assert(pools[rarity]);assert(#pool>=3,'incomplete original rarity pool')
        local id
        repeat id=pool[R.randomInt(rng,#pool-1)+1] until not used[id]
        used[id]=true;choices[#choices+1]={cardId=id,rarity=rarity}
    end
    -- A0 Act1 probability is zero, but every nonrare still consumes a float.
    for _,c in ipairs(choices) do if c.rarity~='rare' then R.randomBooleanChance(rng,0) end end
    local ids={};for i,c in ipairs(choices) do ids[i]=c.cardId end
    return ids,rng,offset
end
return M
