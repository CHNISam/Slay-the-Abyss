-- SphericGuardian / PC A0. Pinned source facts: spheric-guardian-source.json.
-- Gameplay rolls remain separate from the source's visual/SFX MathUtils draws.
local Actors = require("abyss_actor")
local M = {}

local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown SphericGuardian intent: " .. tostring(id))
end

function M.initialize(state, enemy, random)
    random(state, enemy.ai.rollRange)
    select(enemy, enemy.ai.activateIntent)
end

function M.preBattle(state, enemy)
    Actors.applyPower(state, enemy, "barricade", 1, enemy)
    Actors.applyPower(state, enemy, "artifact", enemy.ai.artifactStacks, enemy)
    Actors.block(state, enemy, enemy.ai.startingBlock, true)
end

function M.advance(state, enemy, random)
    -- takeTurn queues this even if retaliation killed its owner. Combat alone
    -- clears the queue when the final monster or player dies.
    random(state, enemy.ai.rollRange)
    local executed = enemy.intents[enemy.intentIndex].id
    if executed == enemy.ai.activateIntent then select(enemy, enemy.ai.frailIntent)
    elseif executed == enemy.ai.slamIntent then select(enemy, enemy.ai.hardenIntent)
    else select(enemy, enemy.ai.slamIntent) end
end

return M
