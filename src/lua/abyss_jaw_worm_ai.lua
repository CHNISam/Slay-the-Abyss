-- Act 1 Jaw Worm decision only. Source: TASK-15-jaw-worm-ai.md.
-- Rolls are explicit inputs: the runtime adapter uses the project RNG, not STS1 aiRng.
local M = {}

local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown Jaw Worm intent: " .. tostring(id))
end

function M.choose(ai, last, previous, roll, unit)
    if roll < ai.chompCutoff then
        if last ~= ai.chompIntent then return ai.chompIntent end
        return unit() < ai.bellowAfterChomp and ai.bellowIntent or ai.thrashIntent
    elseif roll < ai.thrashCutoff then
        if last ~= ai.thrashIntent or previous ~= ai.thrashIntent then return ai.thrashIntent end
        return unit() < ai.chompAfterTwoThrashes and ai.chompIntent or ai.bellowIntent
    end
    if last ~= ai.bellowIntent then return ai.bellowIntent end
    return unit() < ai.chompAfterBellow and ai.chompIntent or ai.thrashIntent
end

function M.initialize(state, enemy, random)
    enemy.jawLast, enemy.jawPrevious = nil, nil
    random(state, enemy.ai.rollRange) -- rollMove consumes a primary draw even on forced Chomp
    select(enemy, enemy.ai.chompIntent)
end

function M.advance(state, enemy, random)
    local executed = enemy.intents[enemy.intentIndex].id
    enemy.jawPrevious, enemy.jawLast = enemy.jawLast, executed
    local roll = random(state, enemy.ai.rollRange) - 1
    local next = M.choose(enemy.ai, enemy.jawLast, enemy.jawPrevious, roll, function()
        -- Current 16-bit LCG domain; not RandomXS128's 24-bit nextFloat stream.
        return (random(state, 65536) - 1) / 65536
    end)
    select(enemy, next)
end

return M
