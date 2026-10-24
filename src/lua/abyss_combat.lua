-- Pure Lua 5.3 battle state. No game/script/io globals; the UI issues commands.
local Actors = require("abyss_actor")
local Effects = require("abyss_effects")
local Events = require("abyss_events")
local EnemyAI = require("abyss_enemy_ai")
local M = { addStatus = Actors.addStatus, addTemporaryStrength = Actors.addTemporaryStrength,
    statusView = Actors.statusView, block = Actors.block,
    attackAmount = Actors.attackAmount, blockAmount = Actors.blockAmount }

function M.damage(state, source, target, base, fixed, retaliation)
    local before, sourceBefore = target.hp, source.hp
    local thornsCallback = before > 0 and sourceBefore > 0 and not fixed and not retaliation
        and (target.statuses.thorns or 0) > 0
    local lost = Actors.damage(state, source, target, base, fixed, retaliation)
    EnemyAI.hpLost(state, target, before, before > 0 and sourceBefore > 0)
    if source ~= target then EnemyAI.hpLost(state, source, sourceBefore, thornsCallback) end -- normal thorns
    if not state.resolvingEffects then
        EnemyAI.flush(state)
        if not state.resolvingCard then Actors.flushCurlUp(state) end
    end
    return lost
end

function M.retaliate(state, source, target, amount)
    local before = target.hp
    local lost = Actors.retaliate(state, source, target, amount)
    EnemyAI.hpLost(state, target, before, before > 0)
    if not state.resolvingEffects then EnemyAI.flush(state) end
    return lost
end

local function resolveEffects(state, effects, source, target, playedCard, queuedEnemyAction)
    if queuedEnemyAction then
        assert(state.phase == "enemy" and source ~= state.player and target == state.player, "invalid queued enemy action")
    end
    local previous = state.resolvingEffects
    state.resolvingEffects = true
    local called, dealt = pcall(Effects.apply, M, state, effects, source, target, playedCard, queuedEnemyAction)
    state.resolvingEffects = previous
    if not called then error(dealt, 0) end
    if not previous then
        EnemyAI.afterEffects(state, source)
        EnemyAI.flush(state, source)
        if not state.resolvingCard and not queuedEnemyAction then Actors.flushCurlUp(state) end
    end
    return dealt
end

function M.applyEffects(state, effects, source, target, playedCard)
    return resolveEffects(state, effects, source, target, playedCard, false)
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

-- Both ordinary enemies and spawned children use the same actor contract.
-- Split children use the source's explicit-HP constructor, without an HP draw.
local function makeEnemy(state, id, serial, explicitHp)
    local enemy = copy(assert(state.catalog.enemies[id], "unknown enemy: " .. tostring(id)))
    if explicitHp then enemy.hp = explicitHp
    elseif enemy.hpRange then
        enemy.hp = enemy.hpRange.min + M.random(state, enemy.hpRange.max - enemy.hpRange.min + 1) - 1
    end
    EnemyAI.prepare(state, enemy, M.random)
    for _, intent in ipairs(enemy.intents) do
        if intent.kind == "charge" or intent.kind == "split" then
            local kind = intent.kind
            local policy = kind == "charge" and "charge_then_attack" or "spike_slime_l"
            assert(enemy.ai and enemy.ai.kind == policy and enemy.ai[kind .. "Intent"] == intent.id,
                kind .. " intent requires matching AI")
            assert(type(intent.effects) == "table" and next(intent.effects) == nil, kind .. " intent has effects")
        elseif intent.kind == "sleep" or intent.kind == "stunned" then
            assert(type(intent.effects) == "table" and next(intent.effects) == nil, "inactive enemy intent has effects")
        else assert(Effects.supported(intent.effects), "unsupported enemy intent") end
    end
    enemy.definitionId, enemy.id, enemy.maxHp = id, id .. "_" .. serial, enemy.hp
    enemy.block, enemy.statuses, enemy.intentIndex = 0, {}, 1
    Actors.bindStatuses(enemy, state.catalog.statuses)
    return enemy
end

local function splitEnemy(state, parent)
    local ai, position = parent.ai, nil
    assert(ai and ai.kind == "spike_slime_l" and ai.splitCount == 2, "unsupported enemy split")
    for i, enemy in ipairs(state.enemies) do if enemy == parent then position = i; break end end
    assert(position and parent.hp > 0, "invalid split parent")
    local children, hp = {}, parent.hp -- capture before the non-triggering death
    for i = 1, ai.splitCount do
        children[i] = makeEnemy(state, ai.splitEnemy, state.nextEnemyId, hp)
        state.nextEnemyId = state.nextEnemyId + 1
    end
    -- Suicide(false): no damage, death Power, relic callback or extra reward.
    -- Complete both spawns before checking outcome (source CannotLose/CanLose).
    parent.hp = 0
    for i, child in ipairs(children) do
        EnemyAI.initialize(state, child, M.random)
        table.insert(state.enemies, position + (i - 1) * 2, child)
    end
    Events.emit(state, "enemy_split", {enemy=parent.id, children={children[1].id, children[2].id}, hp=hp})
end

local function shuffle(state, pile)
    for i = #pile, 2, -1 do
        local j = M.random(state, i)
        pile[i], pile[j] = pile[j], pile[i]
    end
end

local function event(state, kind, detail)
    Events.emit(state, kind, detail)
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
    if outcome then Actors.flushCurlUp(state) end
    if outcome and state.phase ~= outcome then
        state.phase = outcome
        event(state, outcome)
    end
    return outcome
end

function M.draw(state, count)
    if state.player.noDraw then return end
    for _ = 1, count do
        -- Full hands stop drawing before touching either pile or the shuffle RNG.
        if #state.hand >= state.rules.player.maxHand then break end
        if #state.draw == 0 then
            if #state.discard == 0 then break end
            state.draw, state.discard = state.discard, {}
            shuffle(state, state.draw)
            event(state, "reshuffle")
        end
        local card = table.remove(state.draw)
        state.hand[#state.hand + 1] = card
    end
end

function M.cardDefinition(state, instance)
    local card = copy(assert(state.catalog.cards[instance.cardId], "unknown card"))
    if instance.upgraded then for k, v in pairs(card.upgrade or {}) do card[k] = copy(v) end end
    if instance.damageBonus ~= nil then
        local bonus = instance.damageBonus
        assert(type(bonus) == "number" and bonus >= 0 and bonus < math.huge and bonus % 1 == 0, "invalid card damage bonus")
        for _, effect in ipairs(card.effects) do
            if effect.op == "damage" then
                effect.value = effect.value + 0.0 + bonus -- avoid 32-bit integer wrap
                assert(effect.value < math.huge, "card damage overflow")
            end
        end
    end
    return card
end

-- Read-only display numbers for one hand card, from the same modifier arithmetic
-- resolution uses. Keyed by top-level effect index: {op, low, high}. A single-target
-- hit uses targetIndex when it names a living enemy, otherwise the range across all
-- living enemies; area hits always span every living enemy. Nothing is mutated.
function M.cardPreview(state, instance, targetIndex)
    local card, player, result = M.cardDefinition(state, instance), state.player, {}
    local aimed = state.enemies[targetIndex]
    local function span(op, base)
        local victims = {}
        if op == "damage" and aimed and aimed.hp > 0 then victims = {aimed}
        else for _, enemy in ipairs(state.enemies) do if enemy.hp > 0 then victims[#victims + 1] = enemy end end end
        if #victims == 0 then victims = {{statuses = {}}} end
        local low, high
        for _, victim in ipairs(victims) do
            local amount = Actors.attackAmount(state, player, victim, base)
            low, high = math.min(low or amount, amount), math.max(high or amount, amount)
        end
        return {op = op, low = low, high = high}
    end
    for i, effect in ipairs(card.effects) do
        if effect.op == "damage" or effect.op == "damageAll" then result[i] = span(effect.op, effect.value)
        elseif effect.op == "damageEqualToBlock" then result[i] = span("damage", player.block)
            result[i].op = effect.op
        elseif effect.op == "block" then
            local amount = Actors.blockAmount(state, player, effect.value)
            result[i] = {op = effect.op, low = amount, high = amount}
        end
    end
    return result
end

local function findInstance(state, uid)
    for i, card in ipairs(state.hand) do if card.uid == uid then return card, i end end
end

function M.canPlay(state, uid, targetIndex)
    if state.phase ~= "player" then return false, "not_player_turn" end
    local instance = findInstance(state, uid)
    if not instance then return false, "card_not_in_hand" end
    local card = M.cardDefinition(state, instance)
    if card.cost == -2 then return false, "unplayable_card" end
    if card.type == "attack" and (state.player.statuses.entangled or 0) > 0 then return false, "entangled" end
    local ok, op
    if card.id == "slimed" then
        -- Slimed's use is genuinely empty, not a fake zero-value effect.
        -- Keep this source-verified exception narrower than arbitrary statuses.
        ok = card.type == "status" and card.cost == 1 and card.exhaust == true
            and not card.ethereal and not card.costMode and not card.condition
            and card.upgrade == nil and type(card.effects) == "table" and next(card.effects) == nil
        op = "invalid_empty_status"
    else ok, op = Effects.supported(card.effects) end
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
-- Catalog/rules/intents, other cards and existing events remain read-only.
-- The resolving instance can gain combat-only damage and must roll back in place.
local function savePlayState(state, playedCard)
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
    if state.curlUpQueue then save(state.curlUpQueue) end
    save(playedCard)
    return function()
        for original, values in pairs(saved) do
            for k in pairs(original) do original[k] = nil end
            for k, v in pairs(values) do original[k] = v end
        end
    end
end

local function resolvePlay(state, uid, targetIndex, instance, position, card)
    local previous = state.resolvingCard
    state.resolvingCard = true
    local reactions = EnemyAI.cardReactions(state, card)
    state.energy = state.energy - card.cost
    table.remove(state.hand, position) -- played card cannot be drawn by its own draw
    event(state, "play", { uid = uid, cardId = instance.cardId, target = targetIndex })
    M.applyEffects(state, card.effects, state.player, state.enemies[targetIndex], instance)
    EnemyAI.afterCard(state, reactions)
    -- A used Power leaves the combat piles; it is not an exhausted card.
    -- The Power destination takes precedence over exhaust-on-use, while an
    -- unplayed Power still follows the ordinary endTurn hand lifecycle.
    if card.type ~= "power" then
        local pile = card.exhaust and state.exhaust or state.discard
        pile[#pile + 1] = instance
    end
    state.resolvingCard = previous
    if not previous then Actors.flushCurlUp(state) end
    finish(state)
    return true
end

function M.play(state, uid, targetIndex)
    local ok, reason = M.canPlay(state, uid, targetIndex)
    if not ok then return false, reason end -- validate before changing any state/RNG
    local instance, position = findInstance(state, uid)
    local card = M.cardDefinition(state, instance)
    local restore = savePlayState(state, instance)
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

function M.startPlayerTurn(state, beforeOpeningDraw)
    if finish(state) then return end
    state.turn = state.turn + 1
    state.phase = "player"
    Actors.startTurn(state, state.player)
    if finish(state) then return end
    state.player.noDraw = false
    state.energy = 0
    -- Only Combat.new supplies this one-shot callback. Do not store it in state:
    -- snapshots and subsequent turns contain data only.
    if beforeOpeningDraw then
        local ok, reason = beforeOpeningDraw(state)
        if not ok then return false, reason end
        if state.energy + 0.0 + state.rules.player.energyPerTurn > 2147483647 then return false, "effect_overflow" end
    end
    state.energy = state.energy + state.rules.player.energyPerTurn
    M.draw(state, state.rules.player.drawPerTurn)
    event(state, "player_turn", state.turn)
    return true
end

function M.endTurn(state)
    if state.phase ~= "player" then return false, "not_player_turn" end
    -- Regret snapshots every copy's amount before the end-turn card queue runs.
    -- Auto-use is not a player play: no energy, play hooks or attack modifiers.
    local handSize, regrets = #state.hand, {}
    for _, instance in ipairs(state.hand) do
        if instance.cardId == "regret" then regrets[#regrets + 1] = instance.uid end
    end
    for _, uid in ipairs(regrets) do
        local instance, position = findInstance(state, uid)
        table.remove(state.hand, position)
        state.cardInUse = instance
        M.applyEffects(state, {{op="loseHp", value=handSize}}, state.player, state.player)
        -- Death opens the source death screen before UseCardAction can discard.
        -- Keep the current UID in cardInUse; later cards and cleanup never run.
        if finish(state) then return true end
        state.discard[#state.discard + 1] = instance
        state.cardInUse = nil
    end
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
    -- The group pre-turn hook clears every monster's old Block before its
    -- queued start powers resolve. Drain supported start powers before moves,
    -- so ally Block granted during a move survives later teammates' actions.
    for _, enemy in ipairs(state.enemies) do Actors.resetBlock(state, enemy) end
    for _, enemy in ipairs(state.enemies) do
        if enemy.hp > 0 then
            local before = enemy.hp
            Actors.startTurnEffects(state, enemy)
            EnemyAI.hpLost(state, enemy, before) -- poison is direct HP loss
            EnemyAI.flush(state)
            if finish(state) then return true end
        end
    end
    local actionQueue = {}
    for i, enemy in ipairs(state.enemies) do actionQueue[i] = enemy end
    for _, enemy in ipairs(actionQueue) do
        if enemy.hp > 0 then
            local intent = enemy.intents[enemy.intentIndex]
            event(state, "intent", { enemy = enemy.id, id = intent.id })
            EnemyAI.beforeAction(state, enemy)
            -- takeTurn has already queued this enemy's action payload.
            if intent.kind == "split" then splitEnemy(state, enemy)
            else resolveEffects(state, intent.effects, enemy, state.player, nil, true) end
            if finish(state) then return true end
            -- Thorns can kill this attacker while other enemies remain alive.
            if enemy.hp > 0 then
                Actors.endTurn(state, enemy)
            end
            -- A source-queued RollMove survives its owner's death while
            -- teammates live. finish above clears it on the final death.
            EnemyAI.afterAction(state, enemy, M.random)
            Actors.flushCurlUp(state)
            if finish(state) then return true end
        end
    end
    -- Duration powers belong to the shared round boundary, after all actions.
    -- A new monster-sourced power can suppress its first reduction.
    Actors.endRound(state, state.player)
    for _, enemy in ipairs(state.enemies) do
        if enemy.hp > 0 then Actors.endRound(state, enemy) end
    end
    EnemyAI.endRound(state)
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
        seed = (options.seed or 1) % 65536, turn = 0, energy = 0, phase = "setup", nextUid = 1, nextEnemyId = 1,
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
        state.enemies[#state.enemies + 1] = makeEnemy(state, id, i)
        state.nextEnemyId = i + 1
    end
    for _, enemy in ipairs(state.enemies) do EnemyAI.initialize(state, enemy, M.random) end
    shuffle(state, state.draw)
    -- MonsterRoom initializes all actors first; preBattlePrep shuffles the
    -- deck before calling the group's pre-battle powers in encounter order.
    for _, enemy in ipairs(state.enemies) do EnemyAI.preBattle(state, enemy, M.random) end
    local ok, reason = M.startPlayerTurn(state, options.beforeOpeningDraw)
    if ok == false then return nil, reason end
    return state
end

return M
