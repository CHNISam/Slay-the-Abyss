local Copy = require("abyss_copy")
-- Source-derived discard-card state; the shared action queue owns execution.
local Actors = require("abyss_actor")
local Events = require("abyss_events")
local M = {}
local MAX = 2147483647
local function integer(n)
    return type(n) == "number" and n == n and n % 1 == 0 and n >= 0 and n <= MAX
end
local function counter(state)
    local n = state.discardedThisTurn or 0
    assert(integer(n), "unsupported discard counter")
    return n
end
local function cost(instance)
    local n = instance.storedDiscardCost
    if n == nil then n = 3 end
    assert(integer(n), "unsupported stored discard cost")
    return n
end
local function affected(state)
    local result, seen = {}, {}
    -- AbstractPlayer.updateCardsOnDiscard and applyStartOfTurnCards omit exhaust.
    for _, pile in ipairs({state.hand,state.discard,state.draw}) do
        for _, instance in ipairs(pile) do
            if instance.cardId == "eviscerate" then
                assert(not seen[instance], "duplicate Eviscerate instance")
                seen[instance] = true
                cost(instance) -- preflight every instance before a batch mutation
                result[#result + 1] = instance
            end
        end
    end
    return result
end
function M.withCardDefinitions(data)
    local result = Copy.copy(data)
    local additions = {
        {id="sneaky_strike",sourceId="Underhanded Strike",type="attack",rarity="common",cost=2,
            tags={"STRIKE"},effects={{op="damage",value=12},{op="gainEnergyIfDiscard",value=2}},
            upgrade={effects={{op="damage",value=16},{op="gainEnergyIfDiscard",value=2}}}},
        {id="eviscerate",sourceId="Eviscerate",type="attack",rarity="uncommon",cost=3,
            effects={{op="damage",value=7,times=3}},upgrade={effects={{op="damage",value=9,times=3}}}},
        {id="calculated_gamble",sourceId="Calculated Gamble",type="skill",rarity="uncommon",cost=0,
            exhaust=true,effects={{op="calculatedGamble"}},upgrade={exhaust=false}},
    }
    for _, card in ipairs(additions) do
        for _, existing in ipairs(result.cards.cards) do assert(existing.id ~= card.id, "discard card already registered") end
        result.cards.cards[#result.cards.cards + 1] = card
    end
    return result
end

-- A fresh constructor does not inherit discard history unless actually drawn.
function M.created(instance)
    if instance.cardId == "eviscerate" then instance.storedDiscardCost = 3 end
    return instance
end
function M.costAdapter(_state, instance, definition)
    if instance.cardId == "eviscerate" then definition.cost = cost(instance) end
    return definition
end
function M.onDraw(state, instance)
    if instance.cardId ~= "eviscerate" then return end
    instance.storedDiscardCost = math.max(0, 3 - counter(state))
end
function M.rememberDiscard(state, endTurn)
    assert(endTurn == nil or type(endTurn) == "boolean", "invalid discard reason")
    local n = counter(state)
    assert(n < MAX, "discard counter overflow")
    local cards = endTurn and {} or affected(state)
    state.discardedThisTurn = n + 1
    for _, instance in ipairs(cards) do
        instance.storedDiscardCost = math.max(0, cost(instance) - 1)
    end
    return state.discardedThisTurn
end
function M.beginTurn(state)
    local cards = affected(state)
    state.discardedThisTurn = 0
    for _, instance in ipairs(cards) do instance.storedDiscardCost = 3 end
end

-- GainEnergyIfDiscardAction reads history when this queued action executes,
-- after damage. It is not retained by clearPostCombatActions on final kill.
function M.gainEnergyIfDiscard(state, value)
    assert(value == 2, "unsupported discard refund")
    if not Actors.isActive(state.player) then return false end
    local enemyAlive = false
    for _, enemy in ipairs(state.enemies) do if Actors.isPresent(enemy) then enemyAlive = true end end
    if not enemyAlive or counter(state) == 0 then return false end
    assert(integer(state.energy) and state.energy <= MAX - value, "discard refund overflow")
    state.energy = state.energy + value
    Events.emit(state, "discard_refund_energy", {amount=value})
    return true
end

-- Expand only when CalculatedGambleAction executes, after the played card has
-- left hand. The caller pushes these actions ahead of existing UseCard cleanup
-- in this order. Manual discard hooks add Tactician at TOP, Reflex at BOTTOM.
function M.gambleActions(state)
    local n = #state.hand
    assert(integer(n) and n <= 10, "unsupported Gamble hand size")
    if n == 0 then return {} end
    return {
        {kind="effect",effect={op="requestDiscard",value=n}},
        {kind="effect",effect={op="draw",value=n}},
    }
end
return M
