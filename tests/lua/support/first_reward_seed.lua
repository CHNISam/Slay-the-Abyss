-- Select a seed before exercising the real victory transaction. This does not
-- award a card, edit stock, change rarity, or substitute for a real kill.
local Pool,R=require('abyss_card_pool'),require('abyss_sts_random')
return function(data,id,tier)
    for seed=1,4096 do
        local options=Pool.prepareRewards({data=data,cardRng=R.fromSeed(tostring(seed)),cardRarityOffset=5,encounterTier=tier or 'normal'})
        for _,cardId in ipairs(options) do if cardId==id then return seed end end
    end
    error('no source-pool reward seed for '..id)
end
