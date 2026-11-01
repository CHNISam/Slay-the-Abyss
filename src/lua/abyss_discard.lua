-- Final-action discard selection for the Silent foundation. Combat owns turns.
local Events = require("abyss_events");local Actors=require('abyss_actor')
local M = {}
local MAX = 2147483647
local function integer(n, lo, hi)
    return type(n) == "number" and n == n and n % 1 == 0 and n >= lo and n <= hi
end
local function dense(t)
    if type(t) ~= "table" or getmetatable(t) ~= nil then return nil end
    local count = 0
    for k in next, t do
        if not integer(k, 1, MAX) then return nil end
        count = count + 1
    end
    for i = 1, count do if rawget(t, i) == nil then return nil end end
    return count
end
local function live(state)
    if type(state) ~= "table" or state.phase ~= "player" or state.player.hp <= 0 then return false end
    for _, enemy in ipairs(state.enemies) do
        if Actors.isPresent(enemy) then return true end
    end
    return false
end

-- Snapshot original table contents, not copies replacing pile/card identities.
-- Draw can replace piles and advance nested RNG words before failing.
local function transaction(state, fn)
    local saved, pending = {}, {state}
    while #pending > 0 do
        local original = table.remove(pending)
        if not saved[original] then
            local values = {}
            saved[original] = values
            for k, v in next, original do
                values[k] = v
                if type(k) == "table" then pending[#pending + 1] = k end
                if type(v) == "table" then pending[#pending + 1] = v end
            end
        end
    end
    local ok, result, detail = pcall(fn)
    if not ok then
        for original, values in next, saved do
            for k in next, original do rawset(original, k, nil) end
            for k, v in next, values do rawset(original, k, v) end
        end
        error(result, 0)
    end
    return result, detail
end

function M.active(state) return state.pendingDiscard ~= nil end

local function handIndex(state)
    local count = dense(state.hand)
    if not count or count > 10 then return nil end
    local byUid = {}
    for position, instance in ipairs(state.hand) do
        if type(instance) ~= "table" or not integer(instance.uid, 1, MAX)
            or byUid[instance.uid] then return nil end
        if not state.catalog.cards[instance.cardId] then return nil end
        byUid[instance.uid] = {position=position, instance=instance}
    end
    return byUid
end

local function validDrawQueue(queue)
    local n = dense(queue)
    if not n then return false end
    for _, draw in ipairs(queue) do
        if type(draw) ~= "table" or getmetatable(draw) ~= nil
            or not integer(draw.uid, 1, MAX) or not integer(draw.amount, 2, 3) then return false end
        for key in next, draw do if key ~= "uid" and key ~= "amount" then return false end end
    end
    return true
end

local function resolve(state, selected, api, incrementFirst)
    api = api or require("abyss_combat")
    local energy, gains, draws = 0, {}, {}
    -- DiscardAction completes every move before its queued trigger actions run.
    -- Tactician adds to the front; Reflex appends to the back. For this final
    -- action subset all energy therefore resolves before every queued draw.
    for _, entry in ipairs(selected) do
        local instance = entry.instance
        if instance.cardId == "tactician" then
            local gain = instance.upgraded and 2 or 1
            energy = energy + gain
            gains[#gains + 1] = {uid=instance.uid, amount=gain}
        elseif instance.cardId == "reflex" then
            draws[#draws + 1] = {uid=instance.uid, amount=instance.upgraded and 3 or 2}
        end
    end
    if not integer(state.energy, 0, MAX - energy) then return false, "energy_overflow" end
    if #draws > 0 and not state.resolvingCard and type(api.draw) ~= "function" then return false, "missing_draw_api" end
    if state.pendingDiscardDraws and not validDrawQueue(state.pendingDiscardDraws) then
        return false, "invalid_discard_draw_queue"
    end
    return transaction(state, function()
        local queued = state.actionQueue ~= nil
        local queue = queued and require("abyss_action_queue")
        local function trigger(instance)
            if not queued then return end -- legacy triggers resolve below
            if instance.cardId == "tactician" then
                queue.pushTop(state, {kind="effect", effect={op="discardTacticianEnergy",
                    value=instance.upgraded and 2 or 1, uid=instance.uid}})
            elseif instance.cardId == "reflex" then
                queue.pushBottom(state, {kind="effect", effect={op="discardReflexDraw",
                    value=instance.upgraded and 3 or 2, uid=instance.uid}})
            end
        end
        -- Both source actions move first. DiscardSpecificCardAction increments
        -- before triggerOnManualDiscard; DiscardAction does the reverse.
        for _, entry in ipairs(selected) do
            local instance = entry.instance
            for i, current in ipairs(state.hand) do
                if current == instance then table.remove(state.hand, i); break end
            end
            state.discard[#state.discard + 1] = instance
            if (state.player.statuses.corruption or 0)~=0 then require("abyss_corruption").onDrawOrDiscard(state) end
            if (state.player.statuses.accuracy or 0)>0 then require("abyss_shivs").onDrawOrDiscard(state) end
            if incrementFirst then require("abyss_silent_discard_cards").rememberDiscard(state,false) end
            trigger(instance)
            if not incrementFirst then require("abyss_silent_discard_cards").rememberDiscard(state,false) end
            Events.emit(state, "manual_discard", {uid=instance.uid, cardId=instance.cardId})
        end
        state.pendingDiscard = nil
        -- A real queue owns the trigger effects; do not also apply them here.
        if queued then return true end
        for i = #gains, 1, -1 do
            local gain = gains[i]
            state.energy = state.energy + gain.amount
            Events.emit(state, "discard_energy", {uid=gain.uid, amount=gain.amount})
        end
        if state.resolvingCard then
            -- Fast-path UseCard cleanup precedes these Reflex BOTTOM tails.
            if #draws > 0 then
                state.pendingDiscardDraws = state.pendingDiscardDraws or {}
                for _, draw in ipairs(draws) do
                    state.pendingDiscardDraws[#state.pendingDiscardDraws + 1] = draw
                end
            end
        else
            for _, draw in ipairs(draws) do
                api.draw(state, draw.amount)
                Events.emit(state, "discard_draw", {uid=draw.uid, amount=draw.amount})
            end
        end
        return true
    end)
end

-- Called after shared UseCard cleanup has placed the played card in its pile.
-- Removing the queue before drawing prevents accidental reentrant double use.
function M.flushDraws(state, api)
    local queue = state.pendingDiscardDraws
    if queue == nil then return true end
    if not validDrawQueue(queue) then return false, "invalid_discard_draw_queue" end
    api = api or require("abyss_combat")
    if live(state) and #queue > 0 and type(api.draw) ~= "function" then return false, "missing_draw_api" end
    return transaction(state, function()
        state.pendingDiscardDraws = nil
        if not live(state) then return true end
        for _, draw in ipairs(queue) do
            if not live(state) then break end
            api.draw(state, draw.amount)
            Events.emit(state, "discard_draw", {uid=draw.uid, amount=draw.amount})
        end
        return true
    end)
end

function M.choose(state, uids, token, api)
    if not live(state) then return false, "not_player_turn" end
    local pending = state.pendingDiscard
    if not pending or not integer(token, 1, MAX) or pending.token ~= token then
        return false, "stale_discard_token"
    end
    local n = dense(uids)
    if not n or n ~= pending.count then return false, "invalid_discard_count" end
    local byUid = handIndex(state)
    if not byUid or state.turn ~= pending.turn or #state.hand ~= #pending.handUids then
        return false, "stale_discard_hand"
    end
    for i, instance in ipairs(state.hand) do
        if instance.uid ~= pending.handUids[i] then return false, "stale_discard_hand" end
    end
    local seen, selected = {}, {}
    for _, uid in ipairs(uids) do
        if not integer(uid, 1, MAX) or seen[uid] or not byUid[uid] then
            return false, "invalid_discard_uid"
        end
        seen[uid] = true
        selected[#selected + 1] = byUid[uid]
    end
    return resolve(state, selected, api)
end

function M.begin(state, count)
    if not live(state) then return false, "not_player_turn" end
    if M.active(state) then return false, "discard_pending" end
    if not integer(count, 0, 10) then return false, "invalid_discard_count" end
    if not handIndex(state) then return false, "invalid_discard_hand" end
    if not integer(state.discardSerial or 0, 0, MAX - 1) then return false, "discard_token_overflow" end
    if count == 0 or #state.hand == 0 then return true end
    return transaction(state, function()
        state.discardSerial = (state.discardSerial or 0) + 1
        local token, handUids = state.discardSerial, {}
        for i, instance in ipairs(state.hand) do handUids[i] = instance.uid end
        state.pendingDiscard = {serial=token, token=token, turn=state.turn,
            count=math.min(count, #state.hand), handUids=handUids}
        if #state.hand <= count then
            -- Source CardGroup.getTopCard is the last element. Auto-all moves
            -- from the top, rather than pretending the player selected an order.
            local uids = {}
            for i = #handUids, 1, -1 do uids[#uids + 1] = handUids[i] end
            local ok, reason = M.choose(state, uids, token)
            if not ok then error(reason, 0) end
            return true
        end
        return true, token
    end)
end

-- Explicit manual-discard action only. Combat.endTurn does not call this API.
function M.manualDiscard(state, uid, api)
    if not live(state) then return false, "not_player_turn" end
    if M.active(state) then return false, "discard_pending" end
    local byUid = handIndex(state)
    if not byUid or not integer(uid, 1, MAX) or not byUid[uid] then return false, "invalid_discard_uid" end
    return resolve(state, {byUid[uid]}, api)
end

-- Source DiscardSpecificCardAction silently skips a valid UID no longer in
-- hand. Ordinary manualDiscard keeps its strict missing-UID refusal above.
-- incrementFirst=true is Unload's specific action; false is ordinary/random.
function M.discardSpecific(state, uid, incrementFirst, api)
    if not live(state) then return false, "not_player_turn" end
    if M.active(state) then return false, "discard_pending" end
    if type(incrementFirst) ~= "boolean" then return false, "invalid_discard_order" end
    if not integer(uid, 1, MAX) then return false, "invalid_discard_uid" end
    local byUid = handIndex(state)
    if not byUid then return false, "invalid_discard_hand" end
    if not byUid[uid] then return true, "card_not_in_hand" end
    return resolve(state, {byUid[uid]}, api, incrementFirst)
end

return M
