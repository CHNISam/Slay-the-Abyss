-- Normal, non-Daily PC A0 combat gold. Fixed AbstractRoom source and unsupported
-- modifiers/shared chest-stream boundary: docs/reviews/TASK-13.1-combat-gold.md.
local R = require('abyss_sts_random')
local M = {}

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
