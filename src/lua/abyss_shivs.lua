-- Accuracy changes a Shiv instance's base, not the later attack modifiers.
local Actors = require("abyss_actor")
local Events = require("abyss_events")
local M = {}
local MAX = 2147483647
local function integer(n)
    return type(n) == "number" and n == n and n % 1 == 0 and n >= 0 and n <= MAX - 6
end
local function layerInteger(n)
    return type(n) == "number" and n == n and n % 1 == 0 and n >= 0 and n <= MAX
end
local function amount(state)
    local n = state.player.statuses.accuracy or 0
    assert(integer(n), "unsupported Accuracy amount")
    return n
end
local function instances(state, handOnly)
    local out, seen = {}, {}
    local piles = handOnly and {state.hand} or {state.hand,state.draw,state.discard,state.exhaust}
    for _, pile in ipairs(piles) do
        for _, instance in ipairs(pile) do
            if instance.cardId == "shiv" then
                assert(not seen[instance], "duplicate Shiv instance")
                assert(instance.upgraded == nil or type(instance.upgraded) == "boolean", "invalid Shiv upgrade")
                seen[instance] = true
                out[#out + 1] = instance
            end
        end
    end
    return out
end
function M.withCardDefinitions(data)
    local result = require("abyss_combat").copy(data)
    for _, card in ipairs(result.cards.cards) do assert(card.id ~= "accuracy", "Accuracy already registered") end
    for _, status in ipairs(result.statuses.statuses) do assert(status.id ~= "accuracy", "Accuracy already registered") end
    result.cards.cards[#result.cards.cards + 1] = {id="accuracy",type="power",rarity="uncommon",cost=1,
        effects={{op="gainStatus",status="accuracy",value=4}},
        upgrade={effects={{op="gainStatus",status="accuracy",value=6}}}}
    result.statuses.statuses[#result.statuses.statuses + 1] = {
        id="accuracy",name="精准",kind="buff",stack="intensity",decay="none",
        description="每层令飞刃的基础伤害增加1。"}
    return result
end

-- Deliberately separate opt-in until shared Innate and pre-draw hooks exist.
function M.withInfiniteBladesDefinition(data)
    local result = require("abyss_combat").copy(data)
    for _, card in ipairs(result.cards.cards) do assert(card.id ~= "infinite_blades", "Infinite Blades already registered") end
    for _, status in ipairs(result.statuses.statuses) do assert(status.id ~= "infinite_blades", "Infinite Blades already registered") end
    result.cards.cards[#result.cards.cards + 1] = {
        id="infinite_blades",sourceId="Infinite Blades",name="无限刀刃",type="power",rarity="uncommon",cost=1,
        effects={{op="gainStatus",status="infinite_blades",value=1}},upgrade={innate=true}}
    result.statuses.statuses[#result.statuses.statuses + 1] = {
        id="infinite_blades",name="无限刀刃",kind="buff",stack="intensity",decay="none",
        description="从下回合起，每个你的回合抽牌前获得等同层数的飞刃。"}
    return result
end

-- Called once when a new generated/copied Shiv instance is constructed.
function M.created(state, instance)
    assert(type(instance) == "table" and instance.cardId == "shiv", "expected generated Shiv")
    assert(instance.upgraded == nil or type(instance.upgraded) == "boolean", "invalid Shiv upgrade")
    instance.shivAccuracyBonus = amount(state)
    return instance
end

-- ApplyPower's constructor/stack lifecycle refreshes all four combat piles.
-- This is deliberately not +=: repeated redraws must never compound damage.
function M.onApplied(state)
    local value, cards = amount(state), instances(state, false)
    for _, instance in ipairs(cards) do instance.shivAccuracyBonus = value end
end
function M.applyAccuracy(state, value)
    assert(value == 4 or value == 6, "unsupported Accuracy application")
    if not Actors.isActive(state.player) then return false end
    local current = amount(state)
    assert(integer(current + 0.0 + value), "Accuracy stack overflow")
    local cards = instances(state, false) -- preflight before status mutation
    local eventCount = #state.events
    local applied = Actors.applyPower(state, state.player, "accuracy", value, state.player)
    if applied then
        for _, instance in ipairs(cards) do instance.shivAccuracyBonus = amount(state) end
        -- Keep this operation's new status frame consistent with its updated
        -- card bases, without replacing any frame from an earlier operation.
        for i = eventCount + 1, #state.events do
            local event = state.events[i]
            if event.kind == "status" and event.detail.status == "accuracy" then
                event.frame = Events.frame(state)
            end
        end
    end
    return applied
end
function M.onDrawOrDiscard(state)
    local value = amount(state)
    if value == 0 then return end -- removed power has no hook to reset old bases
    local cards = instances(state, true)
    for _, instance in ipairs(cards) do instance.shivAccuracyBonus = value end
end

-- A supported explicit RemovePower adapter. Source Accuracy has no onRemove
-- override, so previously modified Shiv instances retain their stored bonus.
function M.removeAccuracy(state)
    local before = amount(state)
    if before == 0 or not Actors.isActive(state.player) then return false end
    state.player.statuses.accuracy = 0
    Events.emit(state, "status", {source=state.player.id,target=state.player.id,status="accuracy",amount=-before})
    return true
end

function M.applyInfiniteBlades(state, value)
    assert(value == 1, "unsupported Infinite Blades application")
    if not Actors.isActive(state.player) then return false end
    local current = state.player.statuses.infinite_blades or 0
    assert(layerInteger(current) and layerInteger(current + 0.0 + 1), "Infinite Blades stack overflow")
    return Actors.applyPower(state, state.player, "infinite_blades", 1, state.player)
end

-- Invoke in the source start-of-turn Power slot, before the ordinary draw.
-- The shared generator is a call-stack argument, never persisted in state.
function M.startTurn(state, generate)
    if not Actors.isActive(state.player) then return false end
    local active = false
    for _, enemy in ipairs(state.enemies) do if Actors.isActive(enemy) then active = true end end
    if not active then return false end
    local count = state.player.statuses.infinite_blades or 0
    assert(layerInteger(count), "invalid Infinite Blades amount")
    if count == 0 then return false end
    assert(type(generate) == "function", "missing shared Shiv generator")
    local bonus, before = amount(state), {}
    for _, pile in ipairs({state.hand,state.draw,state.discard,state.exhaust}) do
        for _, card in ipairs(pile) do before[card.uid] = true end
    end
    local eventCount = #state.events
    local uids = generate(state, count, false)
    assert(type(uids) == "table" and getmetatable(uids) == nil and #uids == count,
        "generator returned wrong Shiv count")
    for key in pairs(uids) do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= count,
            "generator returned malformed UIDs")
    end
    local byUid, seen = {}, {}
    for _, pile in ipairs({state.hand,state.discard}) do
        for _, card in ipairs(pile) do byUid[card.uid] = card end
    end
    for _, uid in ipairs(uids) do
        local card = byUid[uid]
        assert(type(uid) == "number" and uid % 1 == 0 and uid >= 1 and uid <= MAX and not seen[uid] and not before[uid]
            and card and card.cardId == "shiv" and card.upgraded == false, "invalid generated Shiv")
        seen[uid] = true
    end
    for _, uid in ipairs(uids) do byUid[uid].shivAccuracyBonus = bonus end
    -- Preserve each generation frame's original pile count/order; only stamp
    -- the new instances already present in that detached historical frame.
    for i = eventCount + 1, #state.events do
        local event = state.events[i]
        if event.kind == "silent_generate" then
            for _, pile in ipairs({event.frame.hand,event.frame.draw,event.frame.discard,event.frame.exhaust}) do
                for _, card in ipairs(pile) do
                    if seen[card.uid] then card.shivAccuracyBonus = bonus end
                end
            end
        end
    end
    return true, uids
end

-- Called on the detached card definition after upgrade, BEFORE general
-- per-instance damageBonus and Strength/Weak/Vulnerable/stance arithmetic.
function M.adaptDefinition(state, instance, card)
    if instance.cardId ~= "shiv" then return card end
    local bonus = instance.shivAccuracyBonus
    assert(bonus == nil or integer(bonus), "unsupported stored Accuracy bonus")
    if bonus == nil then
        -- Legacy Shivs born without this mechanic are legal only before any
        -- Accuracy is active; generated cards under Accuracy must be stamped.
        assert(amount(state) == 0, "generated Shiv missing Accuracy initialization")
        bonus = 0
    end
    local found = false
    for _, effect in ipairs(card.effects) do
        if effect.op == "damage" then
            effect.value = (instance.upgraded and 6 or 4) + 0.0 + bonus
            found = true
        end
    end
    assert(found, "Shiv definition lacks damage")
    return card
end
return M
