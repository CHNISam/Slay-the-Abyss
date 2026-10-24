-- Inventory effects use combat actors and data, with fixed potion/relic damage and block.
-- Callers execute on an uncommitted battle: a refusal may discard this candidate safely.
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local M = {}
local supported = { damage = true, block = true, draw = true, energy = true,
    gainStatus = true, applyStatus = true }
local maximum = 2147483647
local bossRelics = { black_blood = true, slavers_collar = true, sozu = true }

function M.bossEligible(relic, owned)
    if relic.rarity ~= "boss" or not bossRelics[relic.id] then return false end
    local prerequisite = relic.replaces == nil
    for _, id in ipairs(owned) do
        if id == relic.id then return false end
        if id == relic.replaces then prerequisite = true end
    end
    return prerequisite
end

-- These two relics modify the prepared energy master, not a queued opening
-- energy action (Lantern). Give Combat its own adjusted rules copy per battle.
function M.energyBonus(definitions, owned, tier)
    local bonus = 0
    for _, id in ipairs(owned) do
        local relic
        for _, entry in ipairs(definitions) do if entry.id == id then relic = entry; break end end
        if not relic then return nil, "unknown_relic" end
        if relic.trigger == "turn_start" then
            if id ~= "sozu" and id ~= "slavers_collar" then return nil, "unsupported_turn_relic:" .. id end
            local eligible = not relic.encounterTiers
            for _, allowed in ipairs(relic.encounterTiers or {}) do if tier == allowed then eligible = true end end
            if eligible then
                for _, effect in ipairs(relic.effects) do
                    if effect.op ~= "energy" or type(effect.value) ~= "number" or effect.value < 0
                        or effect.value % 1 ~= 0 or bonus + 0.0 + effect.value > maximum then
                        return nil, "invalid_relic_energy"
                    end
                    bonus = bonus + effect.value
                end
            end
        end
    end
    return bonus
end

-- Source-defined hook/queue positions, not effect values. New relics need their
-- own ordering evidence before entering this supported opening set.
local openingPosition = { lantern = "turn_top", vajra = "battle_top",
    oddly_smooth_stone = "battle_top", bronze_scales = "battle_top",
    anchor = "battle_bottom", bag_of_preparation = "battle_bottom" }

function M.opening(definitions, owned)
    local turnTop, battleTop, bottom = {}, {}, {}
    for _, id in ipairs(owned) do
        local relic
        for _, entry in ipairs(definitions) do if entry.id == id then relic = entry; break end end
        if not relic then return nil, "unknown_relic" end
        if relic.trigger == "combat_start" then
            local position = openingPosition[id]
            if not position then return nil, "unsupported_opening_relic:" .. tostring(id) end
            if position == "turn_top" then table.insert(turnTop, 1, relic.effects)
            elseif position == "battle_top" then table.insert(battleTop, 1, relic.effects)
            else bottom[#bottom + 1] = relic.effects end
        end
    end
    -- Turn-start hooks are dispatched after battle-start hooks, so their TOP
    -- actions execute first. BOTTOM actions retain the held-list order.
    for _, effects in ipairs(battleTop) do turnTop[#turnTop + 1] = effects end
    return { beforeDraw = turnTop, afterDraw = bottom }
end

function M.applyOpening(state, groups)
    for _, effects in ipairs(groups) do
        local ok, reason = M.apply(state, effects)
        if not ok then return false, reason end
    end
    return true
end

local function integer(value)
    return type(value) == "number" and value == value and value % 1 == 0
        and value >= 0 and value <= maximum
end

function M.needTarget(effects)
    for _, effect in ipairs(effects) do
        if effect.op == "damage" or effect.op == "applyStatus" then return true end
    end
    return false
end

local function validate(state, effects, targetIndex)
    if M.needTarget(effects) then
        if not integer(targetIndex) or not Actors.isActive(state.enemies[targetIndex]) then
            return false, "invalid_target"
        end
    end
    for _, effect in ipairs(effects) do
        if not supported[effect.op] then return false, "unsupported_effect:" .. tostring(effect.op) end
        if not integer(effect.value) then return false, "invalid_effect_value" end
        if effect.op == "gainStatus" or effect.op == "applyStatus" then
            local actor = effect.op == "gainStatus" and state.player or state.enemies[targetIndex]
            if not actor.statusDefinitions[effect.status] then return false, "unknown_status:" .. tostring(effect.status) end
        end
    end
    return true
end

function M.apply(state, effects, targetIndex)
    local ok, reason = validate(state, effects, targetIndex)
    if not ok then return false, reason end
    local target = state.enemies[targetIndex]
    for _, effect in ipairs(effects) do
        local op, value = effect.op, effect.value
        if op == "damage" then
            Combat.damage(state, state.player, target, value, true)
        elseif op == "block" then
            if state.player.block + 0.0 + value > maximum then return false, "effect_overflow" end
            Combat.block(state, state.player, value, true)
        elseif op == "draw" then Combat.draw(state, value)
        elseif op == "energy" then
            if state.energy + 0.0 + value > maximum then return false, "effect_overflow" end
            state.energy = state.energy + 0.0 + value
        elseif op == "gainStatus" or op == "applyStatus" then
            local actor = op == "gainStatus" and state.player or target
            if (actor.statuses[effect.status] or 0) + 0.0 + value > maximum
                and not Actors.artifactBlocksPower(actor, effect.status, value) then return false, "effect_overflow" end
            -- Artifact blocking is a resolved application, not a rejected use.
            Actors.applyPower(state, actor, effect.status, value, state.player)
        end
    end
    return true
end

return M
