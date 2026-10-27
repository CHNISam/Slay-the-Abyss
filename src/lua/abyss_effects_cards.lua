-- Synchronous cards operations. No continuation-queue ownership is transferred here.
local Events=require('abyss_events')
local M={}
function M.gainEnergyIfDiscard(context)
    local state=context.state
    local source=context.source
    local value=context.effect.value
    assert(source==state.player,"player discard refund only")
    require("abyss_silent_discard_cards").gainEnergyIfDiscard(state,value)
end

function M.calculatedGamble()
    error("Gamble requires the continuation queue")
end

function M.handChoice()
    error("effect requires the continuation queue")
end
M.whirlwind=M.handChoice
M.reaperDamage=M.handChoice

function M.scry()
    error("scry requires the continuation queue")
end

function M.requestDiscard(context)
    local combat=context.combat
    local state=context.state
    local source=context.source
    local queuedEnemyAction=context.queuedEnemyAction
    local value=context.effect.value
    assert(source == state.player and not queuedEnemyAction, "player discard only")
    if not combat.outcome(state) then
        local ok, reason = require("abyss_discard").begin(state, value)
        assert(ok, reason)
    end
end

function M.generateShivs(context)
    local combat=context.combat
    local state=context.state
    local effect=context.effect
    local source=context.source
    local queuedEnemyAction=context.queuedEnemyAction
    local value=context.effect.value
    assert(source == state.player and not queuedEnemyAction, "player generation only")
    if not combat.outcome(state) then
        assert(effect.upgraded==nil or type(effect.upgraded)=='boolean','invalid generated Shiv upgrade')
        require("abyss_silent").generateShivs(state, value, effect.upgraded==true)
    end
end

function M.increaseDamageThisCombat(context)
    local state=context.state
    local playedCard=context.playedCard
    local value=context.effect.value
    assert(type(playedCard) == "table", "growth requires played card")
    assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0, "invalid card damage growth")
    -- Double Tap's makeSameInstanceOf shares the original UUID. Its
    -- queued copy, resolving instance and all matching combat piles
    -- grow together; stat-equivalent copies have a fresh UID instead.
    local seen={}
    local function grow(c)
        if not c or (c.uuid or c.uid)~=(playedCard.uuid or playedCard.uid) or seen[c] then return end
        seen[c]=true
        local previous=c.damageBonus or 0
        local bonus=previous+0.0+value
        assert(bonus<math.huge and (value==0 or bonus>previous),"card damage growth cannot advance")
        c.damageBonus=bonus
    end
    grow(playedCard);grow(state.cardInUse)
    for _,pile in ipairs({state.hand,state.draw,state.discard,state.exhaust}) do for _,c in ipairs(pile) do grow(c) end end
    for _,queued in ipairs(state.queuedCards or {}) do grow(queued.card) end
end

function M.makeTempCardInDiscard(context)
    local combat=context.combat
    local state=context.state
    local effect=context.effect
    local source=context.source
    local value=context.effect.value
    -- Bounded action ABI: fresh catalog copies, never the Run deck or
    -- a copy of the resolving card (Anger has a separate operation).
    -- A queued MakeTempCard action has no owner-death guard. The outer
    -- gate still rejects dead public sources and final-combat tails.
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
        local generated={uid = uid + 0.0 + i, cardId = effect.card, upgraded = effect.upgraded==true}
        require('abyss_watcher_final_cards').created(combat,state,generated)
        state.discard[#state.discard + 1] = generated
    end
    state.nextUid = nextUid
    if value > 0 then Events.emit(state, "cards_created", {source = source.id, cardId = effect.card, amount = value, pile = "discard"}) end
end

function M.addCardToDiscard(context)
    local combat=context.combat
    local state=context.state
    local effect=context.effect
    local playedCard=context.playedCard
    -- This operation copies the resolving card, not its catalog default.
    -- New combat-only instances must never mutate Run's permanent deck.
    assert(type(playedCard) == "table", "copy requires played card")
    assert(type(effect.card) == "string" and state.catalog.cards[effect.card], "unknown copy card")
    assert(effect.card == playedCard.cardId, "copy must match played card")
    local uid = state.nextUid
    assert(type(uid) == "number" and uid > 0 and uid % 1 == 0, "invalid nextUid")
    local nextUid = uid + 1.0 -- do not wrap signed 32-bit Fengari integers
    assert(nextUid > uid and nextUid < math.huge, "nextUid cannot advance")
    -- Anger uses a stat-equivalent copy, including combat damage and
    -- costForTurn. The new identity remains independent of its source.
    local created = combat.copy(playedCard)
    created.uid = uid
    require('abyss_watcher_final_cards').created(combat,state,created)
    state.discard[#state.discard + 1] = created
    state.nextUid = nextUid
end

function M.draw(context)
    local combat=context.combat
    local state=context.state
    local value=context.effect.value
    combat.draw(state, value)
end

function M.energy(context)
    local state=context.state
    local value=context.effect.value
    state.energy = state.energy + value
end

return M
