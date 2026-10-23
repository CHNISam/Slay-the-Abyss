-- Enemy-specific decision state; all values and intent references come from data.
local M = {}
local Actors = require("abyss_actor")
local Events = require("abyss_events")
local Guardian = require("abyss_guardian_ai")

local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown AI intent: " .. tostring(id))
end

function M.initialize(state, enemy)
    if not enemy.ai then return end -- legacy enemies retain the declared cycle
    if enemy.ai.kind == "ritual_then_attack" then
        enemy.aiPhase, enemy.ritualSkipRound = "opening", true
        select(enemy, enemy.ai.ritualIntent)
        return
    end
    if enemy.ai.kind == "guardian" then return Guardian.initialize(state, enemy) end
    assert(enemy.ai.kind == "sleep_then_cycle", "unsupported enemy AI")
    enemy.aiPhase, enemy.aiTurns, enemy.aiCycle = "sleep", 0, 1
    select(enemy, enemy.ai.sleepIntent)
    Actors.block(state, enemy, enemy.ai.sleepBlock, true)
end

function M.hpLost(state, enemy, before)
    if enemy.ai and enemy.ai.kind == "guardian" then return Guardian.hpLost(state, enemy, before) end
    if enemy.aiPhase ~= "sleep" or enemy.hp >= before or enemy.hp <= 0 then return end
    enemy.aiPhase = "stunned"
    select(enemy, enemy.ai.stunnedIntent)
    Events.emit(state, "enemy_wake", { enemy = enemy.id, reason = "hp_loss" })
end

function M.advance(state, enemy)
    if not enemy.ai then
        enemy.intentIndex = enemy.intentIndex % #enemy.intents + 1
    elseif enemy.ai.kind == "ritual_then_attack" then
        enemy.aiPhase = "attacking"
        select(enemy, enemy.ai.attackIntent)
    elseif enemy.ai.kind == "guardian" then return Guardian.advance(state, enemy)
    elseif enemy.aiPhase == "sleep" then
        enemy.aiTurns = enemy.aiTurns + 1
        if enemy.aiTurns < enemy.ai.sleepTurns then
            Actors.block(state, enemy, enemy.ai.sleepBlock, true)
        else
            enemy.aiPhase = "awake"
            select(enemy, enemy.ai.awakeCycle[enemy.aiCycle])
            Events.emit(state, "enemy_wake", { enemy = enemy.id, reason = "sleep_complete" })
        end
    elseif enemy.aiPhase == "stunned" then
        enemy.aiPhase = "awake"
        select(enemy, enemy.ai.awakeCycle[enemy.aiCycle])
    else
        enemy.aiCycle = enemy.aiCycle % #enemy.ai.awakeCycle + 1
        select(enemy, enemy.ai.awakeCycle[enemy.aiCycle])
    end
end

-- Ritual's first suppression and Strength growth belong to the shared round
-- boundary, after every living enemy's action and end-of-turn effects.
function M.endRound(state)
    for _, enemy in ipairs(state.enemies) do
        if enemy.hp > 0 and enemy.ai and enemy.ai.kind == "ritual_then_attack" then
            if enemy.ritualSkipRound then
                enemy.ritualSkipRound = false
            elseif (enemy.statuses.ritual or 0) > 0 then
                Actors.status(state, enemy, "strength", enemy.statuses.ritual)
            end
        end
    end
end

M.cardReactions, M.afterCard = Guardian.cardReactions, Guardian.afterCard

function M.flush(state, actingSource)
    for _, enemy in ipairs(state.enemies) do
        if enemy.ai and enemy.ai.kind == "guardian" then Guardian.flush(state, enemy, actingSource) end
    end
end

function M.beforeAction(state, enemy)
    if enemy.ai and enemy.ai.kind == "guardian" then Guardian.beforeAction(state, enemy) end
end

function M.afterEffects(state, source)
    if source.ai and source.ai.kind == "guardian" then Guardian.afterEffects(state, source) end
end

return M
