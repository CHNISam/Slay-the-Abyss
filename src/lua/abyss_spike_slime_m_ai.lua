-- Shared A0 Spike decisions; Large's interrupt is restored after queued rolls.
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
    error("unknown Spike Slime intent: " .. tostring(id))
end

function M.initialize(state, enemy, random)
    enemy.spikeLast, enemy.spikePrevious = nil, nil
    select(enemy, M.choose(enemy.ai, nil, nil, random(state, enemy.ai.rollRange) - 1))
end

function M.advance(state, enemy, random)
    enemy.spikePrevious, enemy.spikeLast = enemy.spikeLast, enemy.intents[enemy.intentIndex].id
    select(enemy, M.choose(enemy.ai, enemy.spikeLast, enemy.spikePrevious, random(state, enemy.ai.rollRange) - 1))
    -- damage() queues SetMove behind an already queued RollMove. Retaliation
    -- cannot replace that action's payload, nor erase next turn's split.
    if enemy.hp > 0 and enemy.splitTriggered then select(enemy, enemy.ai.splitIntent) end
end


return M
