-- Act 1 / A0 only; source and remaining RNG limits: TASK-15-blue-slaver-ai.md.
local M = {}

local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown Blue Slaver intent: " .. tostring(id))
end

function M.choose(ai, last, previous, roll)
    if last == previous then
        if last == ai.stabIntent then return ai.rakeIntent end
        if last == ai.rakeIntent then return ai.stabIntent end
    end
    return roll < ai.stabCutoff and ai.rakeIntent or ai.stabIntent
end

function M.initialize(state, enemy, random)
    enemy.blueLast, enemy.bluePrevious = nil, nil
    select(enemy, M.choose(enemy.ai, nil, nil, random(state, enemy.ai.rollRange) - 1))
end

function M.advance(state, enemy, random)
    enemy.bluePrevious, enemy.blueLast = enemy.blueLast, enemy.intents[enemy.intentIndex].id
    select(enemy, M.choose(enemy.ai, enemy.blueLast, enemy.bluePrevious, random(state, enemy.ai.rollRange) - 1))
end

return M
