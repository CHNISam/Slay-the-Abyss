-- Effect interpreter for the core-supported operations.
local M = {}

local coreOps = { damage = true, damageAll = true, block = true, draw = true, energy = true,
    applyStatus = true, applyStatusAll = true, gainStatus = true, doubleBlock = true, noDrawThisTurn = true,
    loseHp = true, gainTemporaryStrength = true, damageEqualToBlock = true, addCardToDiscard = true }

local function supported(effects, branch)
    if type(effects) ~= "table" then return false, "invalid_effect" end
    -- Both levels must be nonempty dense arrays: ipairs alone would silently
    -- accept objects, empty branches or unknown operations after a hole.
    local count = 0
    for key in pairs(effects) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then return false, "invalid_effect" end
        count = count + 1
    end
    if count == 0 then return false, "invalid_effect" end
    for i = 1, count do if effects[i] == nil then return false, "invalid_effect" end end
    local targetChecked = false
    for _, effect in ipairs(effects) do
        if type(effect) ~= "table" then return false, "invalid_effect" end
        local op = effect.op
        if type(op) ~= "string" then return false, "invalid_effect" end
        if op == "conditional" then
            -- Combat preflights top-level damage targets; never enable a
            -- conditional-only card or recursively hidden target requirement.
            if branch or not targetChecked or effect["if"] ~= "target_vulnerable"
                or effect["else"] ~= nil then return false, "conditional" end
            local ok, unsupported = supported(effect["then"], true)
            if not ok then return false, unsupported end
        elseif not coreOps[op] or (branch and op ~= "energy" and op ~= "draw") then
            return false, op or "invalid_effect"
        end
        if op == "damage" then targetChecked = true end
    end
    return true
end

function M.supported(effects)
    return supported(effects, false)
end

local function targets(state, source)
    if source == state.player then return state.enemies end
    return { state.player }
end

function M.apply(combat, state, effects, source, target, playedCard)
    local dealt = 0
    for _, effect in ipairs(effects) do
        if source.hp <= 0 then break end
        local op, value = effect.op, effect.value
        if op == "damage" or op == "damageAll" then
            local selected = op == "damageAll" and targets(state, source) or { target }
            for _ = 1, effect.times or 1 do
                for _, victim in ipairs(selected) do
                    dealt = dealt + combat.damage(state, source, victim, value)
                end
                if combat.outcome(state) then break end
            end
        elseif op == "damageEqualToBlock" then
            -- Current block is the attack base, not a payment or fixed damage.
            dealt = dealt + combat.damage(state, source, target, source.block)
        elseif op == "conditional" then
            -- Damage leaves the target's statuses intact, even on a lethal hit.
            -- The outer source-alive guard still stops thorns-killed attackers.
            assert(effect["if"] == "target_vulnerable", "unsupported condition")
            if target and (target.statuses.vulnerable or 0) > 0 then
                dealt = dealt + M.apply(combat, state, effect["then"], source, target, playedCard)
            end
        elseif op == "addCardToDiscard" then
            -- This operation copies the resolving card, not its catalog default.
            -- New combat-only instances must never mutate Run's permanent deck.
            assert(type(playedCard) == "table", "copy requires played card")
            assert(type(effect.card) == "string" and state.catalog.cards[effect.card], "unknown copy card")
            assert(effect.card == playedCard.cardId, "copy must match played card")
            local uid = state.nextUid
            assert(type(uid) == "number" and uid > 0 and uid % 1 == 0, "invalid nextUid")
            local nextUid = uid + 1.0 -- do not wrap signed 32-bit Fengari integers
            assert(nextUid > uid and nextUid < math.huge, "nextUid cannot advance")
            state.discard[#state.discard + 1] = { uid = uid, cardId = effect.card, upgraded = playedCard.upgraded == true }
            state.nextUid = nextUid
        elseif op == "loseHp" then
            -- HP payment is not an attack or a status tick. The next effect's
            -- source-alive guard stops the card when this payment is lethal.
            source.hp = math.max(0, source.hp - value)
        elseif op == "block" then combat.block(state, source, value)
        elseif op == "doubleBlock" then combat.block(state, source, source.block, true)
        elseif op == "draw" then combat.draw(state, value)
        elseif op == "noDrawThisTurn" then source.noDraw = true
        elseif op == "energy" then state.energy = state.energy + value
        elseif op == "gainStatus" then combat.addStatus(source, effect.status, value)
        elseif op == "gainTemporaryStrength" then combat.addTemporaryStrength(source, value)
        elseif op == "applyStatus" then
            if target and target.hp > 0 then combat.addStatus(target, effect.status, value) end
        elseif op == "applyStatusAll" then
            for _, victim in ipairs(targets(state, source)) do
                if victim.hp > 0 then combat.addStatus(victim, effect.status, value) end
            end
        else error("unsupported effect: " .. tostring(op)) end
    end
    return dealt
end

return M
