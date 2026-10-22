-- Actor arithmetic and turn status rules; no UI or platform globals.
local M = {}

local stacks = { intensity = true, duration = true, none = true }
local decays = { none = true, turn_end_minus_1 = true,
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
    local value = (actor.statuses[id] or 0) + 0.0 + amount
    assert(integer(value), "status stack overflow") -- reject before mutating
    if definition.stack == "none" then value = value > 0 and 1 or 0 end
    actor.statuses[id] = signed[id] and value or math.max(0, value)
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

local function directDamage(state, source, target, amount, status)
    local lost = math.min(target.hp, amount)
    target.hp = target.hp - lost
    state.events[#state.events + 1] = { kind = "status_damage", detail = {
        source = source.id, target = target.id, status = status, amount = lost } }
    return lost
end

function M.damage(state, source, target, base, fixed)
    if target.hp <= 0 or source.hp <= 0 then return 0 end
    local amount = base
    if not fixed then
        amount = amount + (source.statuses.strength or 0)
        if (source.statuses.weak or 0) > 0 then amount = amount * state.rules.combat.weakPercent / 100 end
        if (target.statuses.vulnerable or 0) > 0 then amount = amount * state.rules.combat.vulnerablePercent / 100 end
    end
    amount = math.max(0, math.floor(amount))
    local absorbed = math.min(target.block, amount)
    target.block = target.block - absorbed
    local lost = math.min(target.hp, amount - absorbed)
    target.hp = target.hp - lost
    state.events[#state.events + 1] = { kind = "damage", detail = { source = source.id, target = target.id, amount = lost, blocked = absorbed } }
    -- Retaliation is direct HP loss: no modifiers, block or recursive retaliation.
    -- The defender retaliates even if this positive attack was blocked or lethal.
    if not fixed and amount > 0 and (target.statuses.thorns or 0) > 0 then
        directDamage(state, target, source, target.statuses.thorns, "thorns")
    end
    return lost
end

function M.block(state, actor, amount, fixed)
    if not fixed then
        amount = amount + (actor.statuses.dexterity or 0)
        if (actor.statuses.frail or 0) > 0 then amount = amount * state.rules.combat.frailPercent / 100 end
    end
    actor.block = actor.block + math.max(0, math.floor(amount))
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
        if amount > 0 and decay:sub(1, #phase) == phase then
            if decay:find("trigger", 1, true) then
                if id == "poison" then directDamage(state, actor, actor, amount, "poison")
                elseif id == "regen" then
                    local healed = math.min(actor.maxHp - actor.hp, amount)
                    actor.hp = actor.hp + healed
                    state.events[#state.events + 1] = { kind = "heal", detail = { target = actor.id, amount = healed, status = id } }
                end
            end
            actor.statuses[id] = amount - 1
            if actor.hp <= 0 then return end
        end
    end
end

function M.endTurn(state, actor)
    tick(state, actor, "turn_end")
    if actor.hp <= 0 then return end
    local temporary = actor.temporaryStrength or 0
    if temporary ~= 0 then
        M.addStatus(actor, "strength", -temporary)
        actor.temporaryStrength = 0
    end
end

function M.startTurn(state, actor)
    if actor.hp <= 0 then return end
    if (actor.statuses.barricade or 0) <= 0 then actor.block = 0 end
    tick(state, actor, "turn_start")
end

return M
