-- Normal, non-Daily PC A0 base combat gold: AbstractRoom source.
-- Frozen Golden Idol bonus: docs/rules/GOLDEN_IDOL.md; chest stream stays separate.
local R = require('abyss_sts_random')
local M = {}
-- RewardItem.GOLD freezes this bonus when the non-TreasureRoom offer is made.
-- Source adds round(base*.25f), rather than truncating/rounding the total.
function M.offerAmount(base,owner)
    assert(type(base)=='number' and base%1==0 and base>=0 and base<=2147483647,'invalid gold offer')
    local bonus=0
    for _,id in ipairs(owner and owner.relics or {})do
        if id=='golden_idol'then bonus=math.floor(R.float32(R.float32(base)*R.float32(.25))+.5);break end
    end
    assert(base+0.0+bonus<=2147483647,'gold offer overflow')
    return base+0.0+bonus,bonus
end

-- Prepare privately; the reward transaction publishes the selected stream only
-- after every reward is ready. Claiming the offered gold draws no randomness.
function M.prepare(tier, streams, context)
    assert(tier == 'normal' or tier == 'elite' or tier == 'boss', 'unknown encounter reward tier')
    if tier == 'normal' and context and context.allEscaped then return 0 end
    local key = tier == 'boss' and 'miscRng' or 'treasureRng'
    local rng = R.cloneState(streams[key])
    local gold
    if tier == 'boss' then gold = 100 + R.randomIntBetween(rng, -5, 5)
    elseif tier == 'elite' then gold = R.randomIntBetween(rng, 25, 35)
    else gold = R.randomIntBetween(rng, 10, 20) end
    return gold, key, rng
end

return M
