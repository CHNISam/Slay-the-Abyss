-- Effect interpreter for the core-supported operations.
local M = {}
local Actors = require("abyss_actor")
local Events = require("abyss_events")

local coreOps = { damage = true, damageAll = true, block = true, draw = true, energy = true,
    applyStatus = true, applyStatusAll = true, gainStatus = true, doubleBlock = true, noDrawThisTurn = true,
    loseHp = true, gainTemporaryStrength = true, damageEqualToBlock = true, addCardToDiscard = true,
    increaseDamageThisCombat = true, makeTempCardInDiscard = true }

-- Source-verified queued actions removed by clearPostCombatActions. Its
-- exceptions are specific GainBlock/Heal/UseCard actions and DAMAGE actions,
-- not every action with BLOCK type (DoubleYourBlock is removed).
-- The conditional ABI contains only Dropkick's queued energy/draw tail.
local clearedAfterDamage = { draw=true, energy=true, applyStatus=true, applyStatusAll=true,
    gainStatus=true, doubleBlock=true, noDrawThisTurn=true, gainTemporaryStrength=true,
    addCardToDiscard=true, increaseDamageThisCombat=true, makeTempCardInDiscard=true, conditional=true }
local clearsOnFinalDamage = { damage=true, damageAll=true, damageEqualToBlock=true, loseHp=true }

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
        if effect.target ~= nil and (op ~= "block" or effect.target ~= "random_ally") then
            return false, "invalid_effect_target"
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

function M.apply(combat, state, effects, source, target, playedCard, queuedEnemyAction)
    local dealt = 0
    local cleared = false
    for _, effect in ipairs(effects) do
        if source.hp <= 0 and (not queuedEnemyAction or combat.outcome(state)) then break end
        local op, value = effect.op, effect.value
        if cleared and clearedAfterDamage[op] then
            -- Cancel only still-queued mapped actions, never earlier effects or
            -- retained Block/HP-loss. Card disposal remains owned by Combat.
        elseif source.hp <= 0 then
            assert(coreOps[op] or op == "conditional", "unsupported effect: " .. tostring(op))
            -- ApplyPower guards its target, not its dead source. Only the
            -- source-verified single-player queued status path is enabled.
            -- Later damage, dead-owner Block/buffs and unverified ops stay off.
            if op == "applyStatus" and target == state.player and target.hp > 0 then
                Actors.applyPower(state, target, effect.status, value, source)
            end
        elseif op == "damage" or op == "damageAll" then
            local selected = op == "damageAll" and targets(state, source) or { target }
            for _ = 1, effect.times or 1 do
                local retaliation = op == "damageAll" and {} or nil
                for _, victim in ipairs(selected) do
                    dealt = dealt + combat.damage(state, source, victim, value, nil, retaliation)
                end
                -- Angry and Thorns add reactions to the top of the queue:
                -- finish this area hit, then resolve in reverse target order.
                if retaliation then
                    for i = #retaliation, 1, -1 do
                        local hit = retaliation[i]
                        if hit.status then Actors.applyPower(state, hit.target, hit.status, hit.amount, hit.source)
                        else combat.retaliate(state, hit.source, hit.target, hit.amount) end
                    end
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
        elseif op == "increaseDamageThisCombat" then
            assert(type(playedCard) == "table", "growth requires played card")
            assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0, "invalid card damage growth")
            local previous = playedCard.damageBonus or 0
            local bonus = previous + 0.0 + value
            assert(bonus < math.huge and (value == 0 or bonus > previous), "card damage growth cannot advance")
            playedCard.damageBonus = bonus
        elseif op == "makeTempCardInDiscard" then
            -- Bounded action ABI: fresh catalog copies, never the Run deck or
            -- a copy of the resolving card (Anger has a separate operation).
            assert(type(effect.card) == "string" and state.catalog.cards[effect.card], "unknown temporary card")
            assert(type(value) == "number" and value % 1 == 0 and value >= 0 and value <= 5, "invalid temporary card count")
            local uid = state.nextUid
            assert(type(uid) == "number" and uid > 0 and uid < math.huge and uid % 1 == 0, "invalid nextUid")
            local nextUid = uid + 0.0 + value
            -- Check each increment as well as the batch before mutating piles;
            -- binary64 may round a batch into duplicate/nonadvancing UIDs.
            for i = 1, value do
                assert(uid + 0.0 + i > uid + 0.0 + (i - 1), "nextUid cannot advance")
            end
            assert(nextUid < math.huge and nextUid - uid == value, "nextUid cannot advance")
            for i = 0, value - 1 do
                state.discard[#state.discard + 1] = {uid = uid + 0.0 + i, cardId = effect.card, upgraded = false}
            end
            state.nextUid = nextUid
            if value > 0 then Events.emit(state, "cards_created", {source = source.id, cardId = effect.card, amount = value, pile = "discard"}) end
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
            local before = source.hp
            source.hp = math.max(0, source.hp - value)
            Events.emit(state, "hp_loss", {source = source.id, target = source.id, amount = before - source.hp, blocked = 0})
        elseif op == "block" then
            if effect.target == "random_ally" then
                assert(source ~= state.player, "random ally Block requires an enemy")
                local candidates, member = {}, false
                for _, ally in ipairs(state.enemies) do
                    if ally == source then member = true
                    elseif ally.hp > 0 and ally.intents[ally.intentIndex].kind ~= "escape" then
                        candidates[#candidates + 1] = ally
                    end
                end
                assert(member, "random ally Block source is not in the encounter")
                -- The source action draws even for one eligible ally, but not
                -- for the empty-list self fallback. Use fixed Block, not cards.
                local recipient = #candidates > 0 and candidates[combat.random(state, #candidates)] or source
                combat.block(state, recipient, value, true)
            else combat.block(state, source, value) end
        elseif op == "doubleBlock" then combat.block(state, source, source.block, true)
        elseif op == "draw" then combat.draw(state, value)
        elseif op == "noDrawThisTurn" then Actors.applyNoDraw(state, source)
        elseif op == "energy" then state.energy = state.energy + value
        elseif op == "gainStatus" then Actors.applyPower(state, source, effect.status, value, source)
        elseif op == "gainTemporaryStrength" then
            combat.addTemporaryStrength(source, value, state)
        elseif op == "applyStatus" then
            if target and target.hp > 0 then Actors.applyPower(state, target, effect.status, value, source) end
        elseif op == "applyStatusAll" then
            for _, victim in ipairs(targets(state, source)) do
                if victim.hp > 0 then Actors.applyPower(state, victim, effect.status, value, source) end
            end
        else error("unsupported effect: " .. tostring(op)) end
        if clearsOnFinalDamage[op] and combat.outcome(state) == "victory" then cleared = true end
    end
    return dealt
end

return M
