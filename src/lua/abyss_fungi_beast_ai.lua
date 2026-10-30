-- Fungi Beast / A0 decisions and death power; TASK-15.8 and TASK-15.9 ledgers.
local M = {}

local function choose(ai, last, previous, roll)
    if roll < ai.biteCutoff then
        if last == ai.biteIntent and previous == ai.biteIntent then return ai.growIntent end
        return ai.biteIntent
    end
    return last == ai.growIntent and ai.biteIntent or ai.growIntent
end

local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown Fungi Beast intent: " .. tostring(id))
end

function M.initialize(state, enemy, random, applyPower)
    enemy.fungiLast, enemy.fungiPrevious = nil, nil
    select(enemy, choose(enemy.ai, nil, nil, random(state, enemy.ai.rollRange) - 1))
    applyPower(state, enemy, "spore_cloud", enemy.ai.sporeCloudStacks, enemy)
end

function M.advance(state, enemy, random)
    enemy.fungiPrevious, enemy.fungiLast = enemy.fungiLast, enemy.intents[enemy.intentIndex].id
    select(enemy, choose(enemy.ai, enemy.fungiLast, enemy.fungiPrevious, random(state, enemy.ai.rollRange) - 1))
end

return M
