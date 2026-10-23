-- Act 1 / Ascension 0 only. Fixed-source evidence: TASK-15-gremlin-nob-ai.md.
local Actors = require("abyss_actor")
local M = {}

local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown Gremlin Nob intent: " .. tostring(id))
end

function M.choose(ai, last, previous, roll)
    if roll < ai.bashCutoff or (last == ai.rushIntent and previous == ai.rushIntent) then return ai.bashIntent end
    return ai.rushIntent
end

function M.initialize(state, enemy, random)
    enemy.nobLast, enemy.nobPrevious = nil, nil
    random(state, enemy.ai.rollRange) -- rollMove draws even for forced Bellow.
    select(enemy, enemy.ai.bellowIntent)
end

function M.advance(state, enemy, random)
    enemy.nobPrevious, enemy.nobLast = enemy.nobLast, enemy.intents[enemy.intentIndex].id
    select(enemy, M.choose(enemy.ai, enemy.nobLast, enemy.nobPrevious, random(state, enemy.ai.rollRange) - 1))
end

function M.beforeCard(state, card)
    if card.type ~= "skill" then return end
    -- AngerPower adds its Strength action to the top before queued card effects.
    -- Reverse owner order matches repeated addToTop for multiple living owners.
    for i = #state.enemies, 1, -1 do
        local enemy = state.enemies[i]
        if enemy.hp > 0 and (enemy.statuses.enrage or 0) > 0 then
            Actors.status(state, enemy, "strength", enemy.statuses.enrage)
        end
    end
end

return M
