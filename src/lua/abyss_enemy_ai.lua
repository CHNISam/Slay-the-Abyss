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
        enemy.aiPhase = "ritual_opening"
        select(enemy, enemy.ai.openingIntent)
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
        if enemy.aiPhase == "ritual_opening" then
            enemy.aiPhase = "ritual_attacking"
            enemy.ritualSkipRound = true
        end
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

-- Called once after the entire enemy group, never from per-enemy advance.
-- Other status timings are deliberately unchanged by this Cultist slice.
function M.endRound(state, enemy)
    if state.player.hp <= 0 or enemy.hp <= 0 or not enemy.ai
        or enemy.ai.kind ~= "ritual_then_attack" or enemy.aiPhase ~= "ritual_attacking" then return end
    if enemy.ritualSkipRound then
        enemy.ritualSkipRound = false
    else
        local amount = enemy.statuses.ritual or 0
        if amount > 0 then Actors.status(state, enemy, "strength", amount) end
    end
end

return M
