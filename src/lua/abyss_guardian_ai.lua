-- Guardian's damage budget, two modes, and queued per-card Sharp Hide.
local Actors = require("abyss_actor")
local Events = require("abyss_events")
local M = {}

local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown Guardian intent: " .. tostring(id))
end

local function status(state, enemy, id, amount)
    local before = enemy.statuses[id] or 0
    enemy.statuses[id] = amount
    Events.emit(state, "status", {source = enemy.id, target = enemy.id, status = id, amount = amount - before})
end

function M.initialize(state, enemy)
    enemy.aiPhase, enemy.aiCycle, enemy.aiThreshold = "offense", 1, enemy.ai.initialThreshold
    status(state, enemy, "mode_shift", enemy.aiThreshold)
    select(enemy, enemy.ai.offenseCycle[enemy.aiCycle])
end

function M.hpLost(state, enemy, before)
    if enemy.aiPhase ~= "offense" or enemy.aiShiftPending or enemy.hp >= before or enemy.hp <= 0 then return end
    if enemy.aiReturning then
        -- The shell opens before Twin Slam, but Apply Mode Shift and Reset
        -- Threshold are queued after both hits. Subthreshold retaliation is
        -- reset away; reaching the threshold still queues a defensive shift.
        enemy.aiReturnDamage = (enemy.aiReturnDamage or 0) + before - enemy.hp
        if enemy.aiReturnDamage >= enemy.aiThreshold then enemy.aiShiftPending = true end
        return
    end
    local remaining = math.max(0, enemy.statuses.mode_shift - (before - enemy.hp))
    status(state, enemy, "mode_shift", remaining)
    if remaining > 0 then return end
    enemy.aiShiftPending = true
end

-- Mode Shift is queued behind the card/enemy action already resolving. Twin
-- Strike's two Damage actions both complete before the resulting 20 Block.
function M.flush(state, enemy, actingSource)
    if not enemy.aiShiftPending then return end
    enemy.aiShiftPending = nil
    if enemy.hp <= 0 then return end
    if enemy == actingSource then enemy.aiSkipAdvance = true end
    enemy.aiPhase, enemy.aiCycle = "defense", 1
    enemy.aiThreshold = enemy.aiThreshold + enemy.ai.thresholdIncrement
    select(enemy, enemy.ai.defenseCycle[enemy.aiCycle])
    if (enemy.statuses.mode_shift or 0) ~= 0 then status(state, enemy, "mode_shift", 0) end
    Actors.block(state, enemy, enemy.ai.shiftBlock, true)
    Events.emit(state, "enemy_mode", {enemy = enemy.id, mode = enemy.aiPhase})
end

function M.beforeAction(state, enemy)
    if enemy.aiPhase ~= "defense" or enemy.aiCycle ~= #enemy.ai.defenseCycle then return end
    -- Twin Slam opens the shell before attacking. Applying the new Mode Shift
    -- power and resetting its counter remain queued until the two hits finish.
    enemy.aiPhase, enemy.aiReturning = "offense", true
    enemy.aiReturnDamage = 0
    for i, id in ipairs(enemy.ai.offenseCycle) do if id == enemy.ai.returnIntent then enemy.aiCycle = i; break end end
    select(enemy, enemy.ai.returnIntent)
    Events.emit(state, "enemy_mode", {enemy = enemy.id, mode = enemy.aiPhase})
end

function M.afterEffects(state, enemy)
    -- Lethal Twin Slam opens the death screen before its queued Remove Power,
    -- Apply Mode Shift and Reset Threshold actions can run.
    if not enemy.aiReturning or state.player.hp <= 0 then return end
    enemy.aiReturning, enemy.aiSkipAdvance, enemy.aiReturnDamage = nil, true, nil
    if enemy.hp > 0 then
        status(state, enemy, "sharp_hide", 0)
        status(state, enemy, "mode_shift", enemy.aiThreshold)
        if enemy.block > 0 then
            enemy.block = 0
            Events.emit(state, "block_reset", {target = enemy.id})
        end
    end
end

function M.advance(state, enemy)
    local ai = enemy.ai
    if enemy.aiSkipAdvance then enemy.aiSkipAdvance = nil; return end
    if enemy.aiPhase == "offense" then
        enemy.aiCycle = enemy.aiCycle % #ai.offenseCycle + 1
        select(enemy, ai.offenseCycle[enemy.aiCycle])
    elseif enemy.aiCycle < #ai.defenseCycle then
        enemy.aiCycle = enemy.aiCycle + 1
        select(enemy, ai.defenseCycle[enemy.aiCycle])
    end
end

-- Capture owners at card play, before its effects can kill them. These queued
-- reactions run after the card's own effects, including Iron Wave's Block.
function M.cardReactions(state, card)
    local reactions = {}
    if card.type ~= "attack" then return reactions end
    for _, enemy in ipairs(state.enemies) do
        local amount = enemy.statuses.sharp_hide or 0
        if enemy.hp > 0 and amount > 0 then reactions[#reactions + 1] = {source = enemy.id, amount = amount} end
    end
    return reactions
end

function M.afterCard(state, reactions)
    for _, reaction in ipairs(reactions) do
        local player = state.player
        if player.hp <= 0 then break end
        -- THORNS-type damage can outlive its owner. It consumes Block, ignores
        -- attack modifiers, and cannot trigger normal thorns recursively.
        local blocked = math.min(player.block, reaction.amount)
        local lost = math.min(player.hp, reaction.amount - blocked)
        player.block, player.hp = player.block - blocked, player.hp - lost
        Events.emit(state, "status_damage", {source = reaction.source, target = player.id,
            status = "sharp_hide", amount = lost, blocked = blocked})
    end
end

return M
