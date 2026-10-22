-- Actor arithmetic and turn status rules; no UI or platform globals.
local M = {}

function M.addStatus(actor, id, amount)
    local value = (actor.statuses[id] or 0) + amount
    actor.statuses[id] = (id == "strength" or id == "dexterity") and value or math.max(0, value)
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
    return lost
end

function M.block(state, actor, amount, fixed)
    if not fixed then
        amount = amount + (actor.statuses.dexterity or 0)
        if (actor.statuses.frail or 0) > 0 then amount = amount * state.rules.combat.frailPercent / 100 end
    end
    actor.block = actor.block + math.max(0, math.floor(amount))
end

function M.endTurn(actor)
    for _, id in ipairs({ "weak", "vulnerable", "frail" }) do
        actor.statuses[id] = math.max(0, (actor.statuses[id] or 0) - 1)
    end
end

function M.startTurn(actor)
    if (actor.statuses.barricade or 0) <= 0 then actor.block = 0 end
end

return M
