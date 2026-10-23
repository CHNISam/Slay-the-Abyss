-- Spike Slime M / A0; see TASK-15.6-spike-slime-m.md for the fixed source.
local M = {}

function M.choose(ai, last, previous, roll)
    if last == previous then
        if last == ai.tackleIntent then return ai.frailIntent end
        if last == ai.frailIntent then return ai.tackleIntent end
    end
    return roll < ai.tackleCutoff and ai.tackleIntent or ai.frailIntent
end

local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown Spike Slime M intent: " .. tostring(id))
end

function M.initialize(state, enemy, random)
    enemy.spikeLast, enemy.spikePrevious = nil, nil
    select(enemy, M.choose(enemy.ai, nil, nil, random(state, enemy.ai.rollRange) - 1))
end

function M.advance(state, enemy, random)
    enemy.spikePrevious, enemy.spikeLast = enemy.spikeLast, enemy.intents[enemy.intentIndex].id
    select(enemy, M.choose(enemy.ai, enemy.spikeLast, enemy.spikePrevious, random(state, enemy.ai.rollRange) - 1))
end

return M
