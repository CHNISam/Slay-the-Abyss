-- Source-ordered, all-unlocked Ironclad pools; shared run.cardRng ownership.
-- This module never filters a rarity bucket by implemented effects or rerolls
-- an unsupported result. Canonical pool evidence lives in data/reference.
local R=require('abyss_sts_random')
local Acts=require('abyss_acts')
local M={}
function M.rewardCount(run,base)
    local n=(base or run.data.rules.rewards.cardChoices)
    if require('abyss_relic_hooks').owns(run,'question_card')then n=n+1 end
    return require('abyss_boss_relics').cardRewardCount(run,n)
end
function M.prismaticPools(run)
    local pools={common={},uncommon={},rare={}}
    local metadata=run.data.cards.sourcePools.cardSourceMetadata or {}
    local seen={}
    for _,card in ipairs(run.data.cards.cards)do
        local fact=metadata[card.id]or card
        local rarity=fact.rarity or card.rarity
        local color=card.color
        if pools[rarity]and card.type~='status'and card.type~='curse'
            and (color=='red'or color=='green'or color=='blue'or color=='purple'or color=='colorless')then
            local source=fact.sourceId or card.sourceId or card.sts_name or card.id
            assert(not seen[source],'duplicate Prismatic source identity')
            seen[source]=true;pools[rarity][#pools[rarity]+1]={id=card.id,source=source}
        end
    end
    -- Fixed CardLibrary registration has 76/160/84 cards, including colorless.
    -- Refuse an incomplete catalogue instead of silently reducing the draw pool.
    local expected={common=76,uncommon=160,rare=84}
    for rarity,pool in pairs(pools)do
        assert(#pool==expected[rarity],'incomplete Prismatic '..rarity..' pool: '..#pool)
        table.sort(pool,function(a,b)return a.source<b.source end)
        for i,entry in ipairs(pool)do pool[i]=entry.id end
    end
    return pools
end
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
    local prismatic=require('abyss_relic_hooks').owns(run,'prismatic_shard')
    local pools=prismatic and M.prismaticPools(run)or assert(run.data.cards.sourcePools,'missing source pools').reward
    for _=1,M.rewardCount(run) do
        local rarity=M.rarity(R.randomInt(rng,99),offset,run.encounterTier)
        if rarity=='common' then offset=math.max(-40,offset-1)
        elseif rarity=='rare' then offset=5 end
        local pool=assert(pools[rarity]);assert(#pool>=3,'incomplete original rarity pool')
        local id
        repeat
            -- CardLibrary.getAnyColorCard shuffles with one randomLong, then
            -- getRandomCard sorts by source cardID before its integer draw.
            if prismatic then R.randomLongHex(rng)end
            id=pool[R.randomInt(rng,#pool-1)+1]
        until not used[id]
        used[id]=true;choices[#choices+1]={cardId=id,rarity=rarity}
    end
    -- AbstractDungeon selects every identity before upgrade rolls. Even the
    -- first act's zero chance spends a float; rares never spend one.
    local chance=Acts.get(run.act or 1).upgradeChance
    local upgrades={}
    for i,c in ipairs(choices) do
        upgrades[i]=c.rarity~='rare' and R.randomBooleanChance(rng,chance) or false
    end
    local ids={};for i,c in ipairs(choices) do ids[i]=c.cardId end
    return ids,rng,offset,upgrades
end
return M
