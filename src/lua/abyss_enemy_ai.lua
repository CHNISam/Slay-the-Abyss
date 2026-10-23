-- Enemy-specific decision state; all values and intent references come from data.
local M = {}
local Actors = require("abyss_actor")
local Events = require("abyss_events")
local Guardian = require("abyss_guardian_ai")
local JawWorm = require("abyss_jaw_worm_ai")
local GremlinNob = require("abyss_gremlin_nob_ai")
local BlueSlaver = require("abyss_blue_slaver_ai")
local RedSlaver = require("abyss_red_slaver_ai")
local AcidSlimeS = require("abyss_acid_slime_s_ai")
local Sentry = require("abyss_sentry_ai")

local function select(enemy, id)
    for i, intent in ipairs(enemy.intents) do
        if intent.id == id then enemy.intentIndex = i; return end
    end
    error("unknown AI intent: " .. tostring(id))
end

-- A fixed attack may still queue rollMove, consuming a primary draw even though
-- its decision ignores the value. Source contract: TASK-15-spike-slime-s-ai.md.
local function rollAttack(state, enemy, random)
    random(state, enemy.ai.rollRange)
    select(enemy, enemy.ai.attackIntent)
end

function M.initialize(state, enemy, random)
    if not enemy.ai then return end -- legacy enemies retain the declared cycle
    if enemy.ai.kind == "rolled_attack" or enemy.ai.kind == "opening_roll_attack" then return rollAttack(state, enemy, random) end
    if enemy.ai.kind == "charge_then_attack" then
        -- Wizard's inherited init rolls once although getMove fixes Charge.
        -- Its later charge/attack transitions use SetMove, not RollMove.
        random(state, enemy.ai.rollRange)
        enemy.aiCharge = enemy.ai.initialCharge
        select(enemy, enemy.ai.chargeIntent)
        return
    end
    if enemy.ai.kind == "jaw_worm" then return JawWorm.initialize(state, enemy, random) end
    if enemy.ai.kind == "gremlin_nob" then return GremlinNob.initialize(state, enemy, random) end
    if enemy.ai.kind == "blue_slaver" then return BlueSlaver.initialize(state, enemy, random) end
    if enemy.ai.kind == "red_slaver" then return RedSlaver.initialize(state, enemy, random) end
    if enemy.ai.kind == "acid_slime_s" then return AcidSlimeS.initialize(state, enemy, random) end
    if enemy.ai.kind == "sentry" then return Sentry.initialize(state, enemy, random) end
    if enemy.ai.kind == "ritual_then_attack" then
        -- Inherited init calls rollMove even though the first move is Ritual.
        random(state, enemy.ai.rollRange)
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

function M.advance(state, enemy, random)
    if not enemy.ai then
        enemy.intentIndex = enemy.intentIndex % #enemy.intents + 1
    elseif enemy.ai.kind == "rolled_attack" then return rollAttack(state, enemy, random)
    elseif enemy.ai.kind == "opening_roll_attack" then select(enemy, enemy.ai.attackIntent)
    elseif enemy.ai.kind == "charge_then_attack" then
        if enemy.intents[enemy.intentIndex].id == enemy.ai.chargeIntent then
            enemy.aiCharge = enemy.aiCharge + 1
        end
        select(enemy, enemy.aiCharge == enemy.ai.chargeLimit and enemy.ai.attackIntent or enemy.ai.chargeIntent)
    elseif enemy.ai.kind == "jaw_worm" then return JawWorm.advance(state, enemy, random)
    elseif enemy.ai.kind == "gremlin_nob" then return GremlinNob.advance(state, enemy, random)
    elseif enemy.ai.kind == "blue_slaver" then return BlueSlaver.advance(state, enemy, random)
    elseif enemy.ai.kind == "red_slaver" then return RedSlaver.advance(state, enemy, random)
    elseif enemy.ai.kind == "acid_slime_s" then return AcidSlimeS.advance(state, enemy)
    elseif enemy.ai.kind == "sentry" then return Sentry.advance(state, enemy, random)
    elseif enemy.ai.kind == "ritual_then_attack" then
        -- Both Ritual and Strike enqueue RollMoveAction; its result is ignored.
        random(state, enemy.ai.rollRange)
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

-- Only these source-verified policies enqueue RollMoveAction during takeTurn.
-- That action has no owner-death guard and survives while another enemy lives.
-- Acid S sets its next move directly instead; do not invent a queued roll.
local queuedRoll = { jaw_worm=true, gremlin_nob=true, blue_slaver=true, red_slaver=true, rolled_attack=true, sentry=true, ritual_then_attack=true }
function M.afterAction(state, enemy, random)
    if enemy.hp > 0 or (enemy.ai and queuedRoll[enemy.ai.kind]) then
        M.advance(state, enemy, random)
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

function M.cardReactions(state, card)
    GremlinNob.beforeCard(state, card)
    return Guardian.cardReactions(state, card)
end

M.afterCard = Guardian.afterCard

function M.flush(state, actingSource)
    for _, enemy in ipairs(state.enemies) do
        if enemy.ai and enemy.ai.kind == "guardian" then Guardian.flush(state, enemy, actingSource) end
    end
end

function M.beforeAction(state, enemy)
    if enemy.ai and enemy.ai.kind == "red_slaver" then RedSlaver.beforeAction(enemy) end
    if enemy.ai and enemy.ai.kind == "charge_then_attack" and enemy.intents[enemy.intentIndex].id == enemy.ai.attackIntent then
        enemy.aiCharge = 0 -- Reset before damage, including lethal retaliation.
    end
    if enemy.ai and enemy.ai.kind == "guardian" then Guardian.beforeAction(state, enemy) end
end

function M.afterEffects(state, source)
    if source.ai and source.ai.kind == "guardian" then Guardian.afterEffects(state, source) end
end

return M
