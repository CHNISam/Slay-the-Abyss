-- Pure Lua 5.3 battle state. No game/script/io globals; the UI issues commands.
local Actors = require("abyss_actor")
local Effects = require("abyss_effects")
local M = { addStatus = Actors.addStatus, addTemporaryStrength = Actors.addTemporaryStrength,
    statusView = Actors.statusView, damage = Actors.damage, block = Actors.block,
    attackAmount = Actors.attackAmount, blockAmount = Actors.blockAmount }

function M.applyEffects(state, effects, source, target)
    return Effects.apply(M, state, effects, source, target)
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
M.copy = copy

local function index(entries)
    local result = {}
    for _, entry in ipairs(entries) do result[entry.id] = entry end
    return result
end

-- Small-state LCG: all products stay below 2^31 on both Fengari and game Lua.
function M.random(state, maximum)
    assert(maximum >= 1 and maximum % 1 == 0, "invalid random range")
    state.seed = (state.seed * 25173 + 13849) % 65536
    return state.seed % maximum + 1
end

local function shuffle(state, pile)
    for i = #pile, 2, -1 do
        local j = M.random(state, i)
        pile[i], pile[j] = pile[j], pile[i]
    end
end

local function event(state, kind, detail)
    state.events[#state.events + 1] = { kind = kind, detail = detail }
end

local function aliveEnemies(state)
    for _, enemy in ipairs(state.enemies) do if enemy.hp > 0 then return true end end
    return false
end

function M.outcome(state)
    if state.player.hp <= 0 then return "defeat" end -- simultaneous death loses
    if not aliveEnemies(state) then return "victory" end
    return nil
end

local function finish(state)
    local outcome = M.outcome(state)
    if outcome and state.phase ~= outcome then
        state.phase = outcome
        event(state, outcome)
    end
    return outcome
end

function M.draw(state, count)
    if state.player.noDraw then return end
    local overflow = {} -- cannot re-enter the draw pool within this draw action
    for _ = 1, count do
        if #state.draw == 0 then
            if #state.discard == 0 then break end
            state.draw, state.discard = state.discard, {}
            shuffle(state, state.draw)
            event(state, "reshuffle")
        end
        local card = table.remove(state.draw)
        if #state.hand < state.rules.player.maxHand then
            state.hand[#state.hand + 1] = card
        else
            overflow[#overflow + 1] = card
        end
    end
    for _, card in ipairs(overflow) do state.discard[#state.discard + 1] = card end
end

function M.cardDefinition(state, instance)
    local card = copy(assert(state.catalog.cards[instance.cardId], "unknown card"))
    if instance.upgraded then for k, v in pairs(card.upgrade or {}) do card[k] = copy(v) end end
    return card
end

local function findInstance(state, uid)
    for i, card in ipairs(state.hand) do if card.uid == uid then return card, i end end
end

function M.canPlay(state, uid, targetIndex)
    if state.phase ~= "player" then return false, "not_player_turn" end
    local instance = findInstance(state, uid)
    if not instance then return false, "card_not_in_hand" end
    local card = M.cardDefinition(state, instance)
    local ok, op = Effects.supported(card.effects)
    if not ok then return false, "unsupported_effect:" .. op end
    if card.costMode or card.condition then return false, "advanced_card_not_enabled" end
    if state.energy < card.cost then return false, "insufficient_energy" end
    for _, effect in ipairs(card.effects) do
        if effect.op == "damage" or effect.op == "damageEqualToBlock" or effect.op == "applyStatus" then
            local enemy = state.enemies[targetIndex]
            if not enemy or enemy.hp <= 0 then return false, "invalid_target" end
        end
    end
    return true
end

-- Only the mutable tables used by a card resolution. Keep original references:
-- draw may swap piles, and callers may retain actors, statuses, cards or events.
-- Catalog/rules/intents and existing card/event contents are read-only here.
local function savePlayState(state)
    local saved = {}
    local function save(t)
        if saved[t] then return end
        local values = {}
        for k, v in pairs(t) do values[k] = v end
        saved[t] = values
    end
    local function actor(a) save(a); save(a.statuses) end
    save(state); actor(state.player); save(state.enemies)
    for _, enemy in ipairs(state.enemies) do actor(enemy) end
    save(state.hand); save(state.draw); save(state.discard); save(state.exhaust); save(state.events)
    return function()
        for original, values in pairs(saved) do
            for k in pairs(original) do original[k] = nil end
            for k, v in pairs(values) do original[k] = v end
        end
    end
end

local function resolvePlay(state, uid, targetIndex, instance, position, card)
    state.energy = state.energy - card.cost
    table.remove(state.hand, position) -- played card cannot be drawn by its own draw
    event(state, "play", { uid = uid, cardId = instance.cardId, target = targetIndex })
    M.applyEffects(state, card.effects, state.player, state.enemies[targetIndex])
    local pile
    if card.exhaust or card.type == "power" then pile = state.exhaust else pile = state.discard end
    pile[#pile + 1] = instance
    finish(state)
    return true
end

function M.play(state, uid, targetIndex)
    local ok, reason = M.canPlay(state, uid, targetIndex)
    if not ok then return false, reason end -- validate before changing any state/RNG
    local instance, position = findInstance(state, uid)
    local card = M.cardDefinition(state, instance)
    local restore = savePlayState(state)
    local called, result = pcall(resolvePlay, state, uid, targetIndex, instance, position, card)
    if not called then
        restore()
        error(result, 0) -- preserve the rule error, including non-string errors
    end
    return result
end

function M.intent(state, enemyIndex)
    local enemy = state.enemies[enemyIndex]
    if not enemy or enemy.hp <= 0 then return nil end
    return copy(enemy.intents[enemy.intentIndex]) -- UI cannot mutate the queued intent
end

function M.startPlayerTurn(state)
    if finish(state) then return end
    state.turn = state.turn + 1
    state.phase = "player"
    Actors.startTurn(state, state.player)
    if finish(state) then return end
    state.player.noDraw = false
    state.energy = state.rules.player.energyPerTurn
    M.draw(state, state.rules.player.drawPerTurn)
    event(state, "player_turn", state.turn)
end

function M.endTurn(state)
    if state.phase ~= "player" then return false, "not_player_turn" end
    for _, instance in ipairs(state.hand) do
        local card = M.cardDefinition(state, instance)
        local pile = card.ethereal and state.exhaust or state.discard
        pile[#pile + 1] = instance
    end
    state.hand = {}
    Actors.endTurn(state, state.player)
    if finish(state) then return true end
    state.phase = "enemy"
    event(state, "enemy_turn")
    for _, enemy in ipairs(state.enemies) do
        if enemy.hp > 0 then
            Actors.startTurn(state, enemy)
            if finish(state) then return true end
            if enemy.hp > 0 then
                local intent = enemy.intents[enemy.intentIndex]
                event(state, "intent", { enemy = enemy.id, id = intent.id })
                M.applyEffects(state, intent.effects, enemy, state.player)
                if finish(state) then return true end
                -- Thorns can kill this attacker while other enemies remain alive.
                if enemy.hp > 0 then
                    Actors.endTurn(state, enemy)
                    if enemy.hp > 0 then enemy.intentIndex = enemy.intentIndex % #enemy.intents + 1 end
                end
                if finish(state) then return true end
            end
        end
    end
    M.startPlayerTurn(state)
    return true
end

function M.new(data, options)
    options = options or {}
    assert(type(options.seed or 1) == "number" and (options.seed or 1) % 1 == 0, "seed must be an integer")
    local rules = copy(data.rules)
    local hp = options.hp or rules.player.maxHp
    assert(hp > 0 and hp <= rules.player.maxHp and hp % 1 == 0, "invalid starting hp")
    local state = { rules = rules, catalog = { cards = index(copy(data.cards.cards)), enemies = index(copy(data.enemies.enemies)),
            statuses = index(copy(data.statuses.statuses)) },
        seed = (options.seed or 1) % 65536, turn = 0, energy = 0, phase = "setup", nextUid = 1,
        player = { id = "player", hp = hp, maxHp = rules.player.maxHp, block = 0, statuses = {} },
        enemies = {}, draw = {}, hand = {}, discard = {}, exhaust = {}, events = {} }
    Actors.bindStatuses(state.player, state.catalog.statuses)
    local deck = options.deck or data.cards.starter_deck.cards
    assert(#deck > 0, "empty deck")
    for _, value in ipairs(deck) do
        local id = type(value) == "table" and value.cardId or value
        assert(state.catalog.cards[id], "unknown deck card: " .. tostring(id))
        state.draw[#state.draw + 1] = { uid = state.nextUid, cardId = id, upgraded = type(value) == "table" and value.upgraded == true }
        state.nextUid = state.nextUid + 1
    end
    local enemyIds = options.enemies or { "cultist" }
    assert(#enemyIds > 0, "empty encounter")
    for i, id in ipairs(enemyIds) do
        local enemy = copy(assert(state.catalog.enemies[id], "unknown enemy: " .. tostring(id)))
        for _, intent in ipairs(enemy.intents) do assert(Effects.supported(intent.effects), "unsupported enemy intent") end
        enemy.definitionId, enemy.id, enemy.maxHp = id, id .. "_" .. i, enemy.hp
        enemy.block, enemy.statuses, enemy.intentIndex = 0, {}, 1
        Actors.bindStatuses(enemy, state.catalog.statuses)
        state.enemies[#state.enemies + 1] = enemy
    end
    shuffle(state, state.draw)
    M.startPlayerTurn(state)
    return state
end

return M
