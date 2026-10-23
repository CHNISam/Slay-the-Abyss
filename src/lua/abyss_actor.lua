-- Actor arithmetic and turn status rules; no UI or platform globals.
local M = {}
local Events = require("abyss_events")

function M.status(state, actor, id, amount, source)
    local before = actor.statuses[id] or 0
    M.addStatus(actor, id, amount)
    if before <= 0 and actor.statuses[id] > 0
        and actor.statusDefinitions[id].decay == "round_end_minus_1" then
        local monster = source ~= nil and source ~= state.player
        actor[id .. "JustApplied"] = monster and (id ~= "vulnerable" or state.phase == "enemy") or nil
    end
    Events.emit(state, "status", {source = (source or actor).id, target = actor.id,
        status = id, amount = actor.statuses[id] - before})
end

local stacks = { intensity = true, duration = true, none = true }
local decays = { none = true, turn_end_minus_1 = true, round_end_minus_1 = true,
    turn_start_trigger_then_minus_1 = true, turn_end_trigger_then_minus_1 = true }
local signed = { strength = true, dexterity = true }

local function integer(amount)
    return type(amount) == "number" and amount == amount and amount % 1 == 0
        and amount >= -2147483647 and amount <= 2147483647
end

function M.bindStatuses(actor, definitions)
    assert(type(definitions) == "table", "missing status definitions")
    for id, definition in pairs(definitions) do
        assert(definition.id == id and stacks[definition.stack] and decays[definition.decay], "invalid status definition")
        if definition.decay:find("trigger", 1, true) then
            assert(id == "poison" or id == "regen", "unknown status trigger")
        end
    end
    actor.statusDefinitions = definitions
end

function M.addStatus(actor, id, amount)
    local definition = assert(actor.statusDefinitions and actor.statusDefinitions[id], "unknown status: " .. tostring(id))
    assert(integer(amount) and (signed[id] or amount >= 0), "invalid status amount")
    local before = actor.statuses[id] or 0
    local value = before + 0.0 + amount
    assert(integer(value), "status stack overflow") -- reject before mutating
    -- Strength/Dexterity clamp after stacking, for either actor and either sign.
    if signed[id] then value = math.max(-999, math.min(999, value)) end
    if definition.stack == "none" then value = value > 0 and 1 or 0 end
    actor.statuses[id] = signed[id] and value or math.max(0, value)
    if (actor.statuses[id] == 0 or before <= 0) and definition.decay == "round_end_minus_1" then
        actor[id .. "JustApplied"] = nil
    end
    return actor.statuses[id]
end

function M.addTemporaryStrength(actor, amount)
    assert(integer(amount) and amount >= 0, "invalid temporary strength")
    local total = (actor.temporaryStrength or 0) + 0.0 + amount
    assert(integer(total), "temporary strength overflow")
    M.addStatus(actor, "strength", amount)
    actor.temporaryStrength = total
end

-- UI receives values, never references to the combat state or definitions.
function M.statusView(actor)
    local ids, result = {}, {}
    for id, amount in pairs(actor.statuses) do if amount ~= 0 then ids[#ids + 1] = id end end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local definition = assert(actor.statusDefinitions[id], "unknown active status")
        result[#result + 1] = { id = id, amount = actor.statuses[id], name = definition.name,
            kind = definition.kind, stack = definition.stack, decay = definition.decay,
            description = definition.description, temporary = id == "strength" and (actor.temporaryStrength or 0) or 0 }
    end
    return result
end

local function directDamage(state, source, target, amount, status, blocked)
    local lost = math.min(target.hp, amount)
    target.hp = target.hp - lost
    Events.emit(state, "status_damage", {
        source = source.id, target = target.id, status = status, amount = lost, blocked = blocked or 0 })
    return lost
end

function M.attackAmount(state, source, target, base, fixed)
    -- Force float arithmetic before modifiers: Fengari integers are 32-bit,
    -- while game Lua uses wider integers. Integer multiplication would wrap.
    local amount = base + 0.0
    if not fixed then
        amount = amount + (source.statuses.strength or 0)
        if (source.statuses.weak or 0) > 0 then amount = amount * state.rules.combat.weakPercent / 100 end
        if (target.statuses.vulnerable or 0) > 0 then amount = amount * state.rules.combat.vulnerablePercent / 100 end
    end
    return math.max(0, math.floor(amount))
end

-- An area attack collects retaliation until all of its targets are damaged.
-- A dead attacker may still own a queued Thorns hit; dead victims cannot lose HP.
function M.retaliate(state, source, target, amount)
    if target.hp <= 0 then return 0 end
    local blocked = math.min(target.block, amount)
    target.block = target.block - blocked
    return directDamage(state, source, target, amount - blocked, "thorns", blocked)
end

function M.damage(state, source, target, base, fixed, retaliation)
    if target.hp <= 0 or source.hp <= 0 then return 0 end
    local amount = M.attackAmount(state, source, target, base, fixed)
    local absorbed = math.min(target.block, amount)
    target.block = target.block - absorbed
    local lost = math.min(target.hp, amount - absorbed)
    target.hp = target.hp - lost
    Events.emit(state, "damage", { source = source.id, target = target.id, amount = lost, blocked = absorbed })
    -- Thorns consumes block, but has no attack modifiers or recursive retaliation.
    -- Being attacked triggers Thorns, even at zero damage, fully blocked or lethal.
    if not fixed and (target.statuses.thorns or 0) > 0 then
        local thorns = target.statuses.thorns
        if retaliation then
            retaliation[#retaliation + 1] = { source = target, target = source, amount = thorns }
        else
            M.retaliate(state, target, source, thorns)
        end
    end
    return lost
end

function M.blockAmount(state, actor, amount, fixed)
    amount = amount + 0.0
    if not fixed then
        amount = amount + (actor.statuses.dexterity or 0)
        if (actor.statuses.frail or 0) > 0 then amount = amount * state.rules.combat.frailPercent / 100 end
    end
    return math.max(0, math.floor(amount))
end

function M.block(state, actor, amount, fixed)
    local before = actor.block
    -- Cap the final state, not the modifier calculation or its float precision.
    actor.block = math.min(999, actor.block + 0.0 + M.blockAmount(state, actor, amount, fixed))
    Events.emit(state, "block", {source = actor.id, target = actor.id, amount = actor.block - before})
end

local function tick(state, actor, phase)
    if actor.hp <= 0 then return end
    local ids = {}
    for id in pairs(actor.statuses) do ids[#ids + 1] = id end
    table.sort(ids) -- deterministic event ordering across Lua runtimes
    for _, id in ipairs(ids) do
        local definition = assert(actor.statusDefinitions[id], "unknown active status")
        local amount = actor.statuses[id]
        local decay = definition.decay
        local skip = phase == "round_end" and actor[id .. "JustApplied"]
        if skip then actor[id .. "JustApplied"] = nil end
        if amount > 0 and decay:sub(1, #phase) == phase and not skip then
            if decay:find("trigger", 1, true) then
                if id == "poison" then directDamage(state, actor, actor, amount, "poison")
                elseif id == "regen" then
                    local healed = math.min(actor.maxHp - actor.hp, amount)
                    actor.hp = actor.hp + healed
                    Events.emit(state, "heal", { target = actor.id, amount = healed, status = id })
                end
            end
            actor.statuses[id] = amount - 1
            if decay:find("trigger", 1, true) then
                -- Trigger and decay are one presentation step, including lethal poison.
                state.events[#state.events].frame = Events.frame(state)
            else
                Events.emit(state, "status", {source = actor.id, target = actor.id, status = id, amount = -1})
            end
            if actor.hp <= 0 then return end
        end
    end
end

function M.endRound(state, actor)
    tick(state, actor, "round_end")
end

function M.endTurn(state, actor)
    tick(state, actor, "turn_end")
    if actor.hp <= 0 then return end
    local temporary = actor.temporaryStrength or 0
    if temporary ~= 0 then
        M.status(state, actor, "strength", -temporary)
        actor.temporaryStrength = 0
        -- Status removal and its bookkeeping are one presentation step.
        state.events[#state.events].frame = Events.frame(state)
    end
end

function M.startTurn(state, actor)
    if actor.hp <= 0 then return end
    if (actor.statuses.barricade or 0) <= 0 and actor.block ~= 0 then
        actor.block = 0
        Events.emit(state, "block_reset", {target = actor.id})
    end
    tick(state, actor, "turn_start")
end

return M
