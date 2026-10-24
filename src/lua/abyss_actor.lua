-- Actor arithmetic and turn status rules; no UI or platform globals.
local M = {}
local Events = require("abyss_events")

function M.isActive(actor) return actor ~= nil and actor.hp > 0 and not actor.escaped end

function M.status(state, actor, id, amount, source, sourceIsMonster)
    local before = actor.statuses[id] or 0
    M.addStatus(actor, id, amount)
    if before <= 0 and actor.statuses[id] > 0
        and actor.statusDefinitions[id].decay == "round_end_minus_1" then
        local monster = sourceIsMonster
        if monster == nil then monster = source ~= nil and source ~= state.player end
        actor[id .. "JustApplied"] = monster and (id ~= "vulnerable" or state.phase == "enemy") or nil
    end
    local sourceId = (source or actor).id
    if source == nil and sourceIsMonster ~= nil then sourceId = nil end
    Events.emit(state, "status", {source = sourceId, target = actor.id,
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

-- Only source-verified ApplyPower categories; raw status mutation stays separate.
local debuffs = { weak=true, vulnerable=true, frail=true, poison=true, entangled=true }
local function blockDebuff(state, actor, id)
    local before = actor.statuses.artifact or 0
    if before <= 0 then return false end
    actor.statuses.artifact = before - 1
    Events.emit(state, "status", {source=actor.id, target=actor.id, status="artifact",
        amount=-1, blockedStatus=id})
    return true
end

-- Pure prediction for an already validated application. Artifact's gate occurs
-- before stackPower, so a blocked application has no prospective stack overflow.
function M.artifactBlocksPower(actor, id, amount)
    return M.isActive(actor) and (actor.statuses.artifact or 0) > 0
        and (debuffs[id] == true or (signed[id] == true and amount <= 0)) or false
end

function M.applyPower(state, actor, id, amount, source, sourceIsMonster)
    if not M.isActive(actor) then return false end -- ApplyPower cancels for a dead target.
    assert(actor.statusDefinitions and actor.statusDefinitions[id], "unknown status: " .. tostring(id))
    assert(integer(amount) and (signed[id] or amount >= 0), "invalid status amount")
    -- Strength/Dexterity's incoming Power has DEBUFF type at amount <= 0,
    -- regardless of the target's existing signed total. Zero is not an early exit.
    if M.artifactBlocksPower(actor, id, amount) then blockDebuff(state, actor, id); return false end
    M.status(state, actor, id, amount, source, sourceIsMonster)
    return true
end

function M.applyNoDraw(state, actor)
    -- ApplyPowerAction's duplicate NoDraw gate precedes Artifact's generic gate.
    if not M.isActive(actor) or actor.noDraw then return false end
    if blockDebuff(state, actor, "no_draw") then return false end
    actor.noDraw = true
    return true
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

function M.addTemporaryStrength(actor, amount, state)
    assert(integer(amount) and amount >= 0, "invalid temporary strength")
    assert(not state or amount > 0, "zero temporary Strength application unsupported")
    if state and not M.isActive(actor) then return false end
    local total = (actor.temporaryStrength or 0) + 0.0 + amount
    -- Positive Strength cannot spend Artifact. If LoseStrength will be blocked,
    -- its old debt is never stacked and must not fail a nonexistent addition.
    local blockedLoss = state and (actor.statuses.artifact or 0) > 0
    if not blockedLoss then assert(integer(total), "temporary strength overflow") end
    if state then
        -- Flex queues Strength then a separate LoseStrength DEBUFF. Artifact can
        -- block that latter application while preserving the positive Strength.
        M.applyPower(state, actor, "strength", amount, actor)
        if not blockDebuff(state, actor, "lose_strength") then
            actor.temporaryStrength = total
            state.events[#state.events].frame = Events.frame(state)
        end
    else
        -- Public two-argument helper is raw setup/bookkeeping, not ApplyPower.
        M.addStatus(actor, "strength", amount)
        actor.temporaryStrength = total
    end
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

-- Death powers join the current damage action's TOP reactions. They must not
-- run inside an area target loop, or survive that action killing the final foe.
local function battleEnding(state)
    if state.phase == "victory" or state.phase == "defeat" then return true end
    for _, enemy in ipairs(state.enemies) do if M.isActive(enemy) then return false end end
    return true
end

local function queueDeathPower(state, target, before, reactions)
    if before > 0 and target.hp <= 0 and not target.escaped and target.ai and target.ai.kind == "looter"
        and not target.stolenGoldRewarded then
        local stolen = target.stolenGold or 0
        local total = (state.stolenGoldReward or 0) + 0.0 + stolen
        assert(integer(stolen) and stolen >= 0 and integer(total), "stolen gold overflow")
        state.stolenGoldReward, target.stolenGoldRewarded = total, true
    end
    local amount = target.statuses.spore_cloud or 0
    if before > 0 and target.hp <= 0 and target ~= state.player and amount > 0 and not battleEnding(state) then
        -- ApplyPower's source is null, independently of Vulnerable's explicit
        -- monster-origin flag used for its first enemy-round decay suppression.
        reactions[#reactions + 1] = {target=state.player, status="vulnerable", amount=amount,
            sourceIsMonster=true}
    end
end

function M.resolveDamageReactions(state, reactions, retaliate)
    for i = #reactions, 1, -1 do
        local hit = reactions[i]
        if hit.status then
            if not battleEnding(state) then
                M.applyPower(state, hit.target, hit.status, hit.amount, hit.source, hit.sourceIsMonster)
            end
        else
            -- DAMAGE survives final-kill cleanup; recursive death reactions
            -- belong above the remaining actions in this local batch.
            (retaliate or M.retaliate)(state, hit.source, hit.target, hit.amount)
        end
    end
end

local function directDamage(state, source, target, amount, status, blocked, reactions)
    local before = target.hp
    local lost = math.min(target.hp, amount)
    target.hp = target.hp - lost
    Events.emit(state, "status_damage", {
        source = source.id, target = target.id, status = status, amount = lost, blocked = blocked or 0 })
    queueDeathPower(state, target, before, reactions)
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
    if not M.isActive(target) then return 0 end
    local blocked = math.min(target.block, amount)
    target.block = target.block - blocked
    local reactions = {}
    local lost = directDamage(state, source, target, amount - blocked, "thorns", blocked, reactions)
    M.resolveDamageReactions(state, reactions)
    return lost
end

function M.damage(state, source, target, base, fixed, retaliation)
    if not M.isActive(target) or not M.isActive(source) then return 0 end
    local before, reactions = target.hp, retaliation or {}
    local amount = M.attackAmount(state, source, target, base, fixed)
    local absorbed = math.min(target.block, amount)
    target.block = target.block - absorbed
    local lost = math.min(target.hp, amount - absorbed)
    target.hp = target.hp - lost
    Events.emit(state, "damage", { source = source.id, target = target.id, amount = lost, blocked = absorbed })
    -- Curl Up locks on the first nonlethal NORMAL hit, but its actions go to
    -- the BOTTOM, behind every already-queued hit/effect and card disposal.
    -- Keep this FIFO separate from Angry/Thorns/Spore's reverse TOP reactions.
    local curl = target.statuses.curl_up or 0
    if target ~= state.player and not fixed and lost > 0 and target.hp > 0
        and curl > 0 and not target.curlUpTriggered then
        target.curlUpTriggered = true
        state.curlUpQueue = state.curlUpQueue or {}
        state.curlUpQueue[#state.curlUpQueue + 1] = {target=target, amount=curl}
    end
    -- Angry is a queued positive Strength Power after an unblocked NORMAL hit.
    -- Fixed inventory damage, poison and retaliation use non-NORMAL paths.
    -- For an area action, all targets take damage before top-of-queue reactions.
    local angry = not fixed and lost > 0 and (target.statuses.angry or 0) or 0
    if angry > 0 then
        reactions[#reactions + 1] = { source = target, target = target, amount = angry, status = "strength" }
    end
    -- Thorns consumes block, but has no attack modifiers or recursive retaliation.
    -- Being attacked triggers Thorns, even at zero damage, fully blocked or lethal.
    if not fixed and (target.statuses.thorns or 0) > 0 then
        local thorns = target.statuses.thorns
        reactions[#reactions + 1] = { source = target, target = source, amount = thorns }
    end
    -- onDeath queues after onAttacked, so its TOP Power resolves before Thorns.
    queueDeathPower(state, target, before, reactions)
    if not retaliation then M.resolveDamageReactions(state, reactions) end
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

-- Only the bounded Curl Up bottom tail. Combat owns the outer action boundary.
function M.flushCurlUp(state)
    local queue = state.curlUpQueue
    state.curlUpQueue = nil
    -- The original death screen stops action-manager updates immediately.
    if not queue or state.player.hp <= 0 then return end
    for _, entry in ipairs(queue) do
        local target = entry.target
        -- GainBlock/RemovePower each reject a dead owner. A later queued hit
        -- may have killed it after the initial nonlethal trigger.
        if M.isActive(target) then
            M.block(state, target, entry.amount, true)
            local amount = target.statuses.curl_up or 0
            target.statuses.curl_up = 0
            Events.emit(state, "status", {source=target.id, target=target.id,
                status="curl_up", amount=-amount})
        end
    end
end

local function tick(state, actor, phase)
    if not M.isActive(actor) then return end
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
            local reactions = {}
            if decay:find("trigger", 1, true) then
                if id == "poison" then directDamage(state, actor, actor, amount, "poison", nil, reactions)
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
            M.resolveDamageReactions(state, reactions)
            if not M.isActive(actor) then return end
        end
    end
end

function M.endRound(state, actor)
    tick(state, actor, "round_end")
end

function M.endTurn(state, actor)
    tick(state, actor, "turn_end")
    if not M.isActive(actor) then return end
    -- EntanglePower removes itself only for isPlayer=true, rather than reducing
    -- one stack at the monster round boundary or applying another Power.
    local entangled = actor.statuses.entangled or 0
    if actor == state.player and entangled > 0 then
        actor.statuses.entangled = 0
        Events.emit(state, "status", {source = actor.id, target = actor.id, status = "entangled", amount = -entangled})
    end
    local temporary = actor.temporaryStrength or 0
    if temporary ~= 0 then
        -- LoseStrength's owner-end trigger queues a negative Strength Power.
        M.applyPower(state, actor, "strength", -temporary, actor)
        actor.temporaryStrength = 0
        -- Status removal and its bookkeeping are one presentation step.
        state.events[#state.events].frame = Events.frame(state)
    end
end

function M.resetBlock(state, actor)
    if not M.isActive(actor) then return end
    if (actor.statuses.barricade or 0) <= 0 and actor.block ~= 0 then
        actor.block = 0
        Events.emit(state, "block_reset", {target = actor.id})
    end
end

function M.startTurnEffects(state, actor)
    if M.isActive(actor) then tick(state, actor, "turn_start") end
end

function M.startTurn(state, actor)
    M.resetBlock(state, actor)
    M.startTurnEffects(state, actor)
end

return M
