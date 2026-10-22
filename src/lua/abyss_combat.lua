-- Pure Lua 5.3 battle state. No game/script/io globals; the UI issues commands.
local M = {}

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
            state.discard[#state.discard + 1] = card
        end
    end
end

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
    event(state, "damage", { source = source.id, target = target.id, amount = lost, blocked = absorbed })
    return lost
end

function M.block(state, actor, amount, fixed)
    if not fixed then
        amount = amount + (actor.statuses.dexterity or 0)
        if (actor.statuses.frail or 0) > 0 then amount = amount * state.rules.combat.frailPercent / 100 end
    end
    actor.block = actor.block + math.max(0, math.floor(amount))
end

local coreOps = { damage = true, damageAll = true, block = true, draw = true, energy = true,
    applyStatus = true, applyStatusAll = true, gainStatus = true }

local function supported(effects)
    for _, effect in ipairs(effects) do if not coreOps[effect.op] then return false, effect.op end end
    return true
end

local function targets(state, source)
    if source == state.player then return state.enemies end
    return { state.player }
end

function M.applyEffects(state, effects, source, target)
    local dealt = 0
    for _, effect in ipairs(effects) do
        if source.hp <= 0 then break end
        local op, value = effect.op, effect.value
        if op == "damage" or op == "damageAll" then
            local selected = op == "damageAll" and targets(state, source) or { target }
            for _ = 1, effect.times or 1 do
                for _, victim in ipairs(selected) do
                    dealt = dealt + M.damage(state, source, victim, value)
                end
                if M.outcome(state) then break end
            end
        elseif op == "block" then M.block(state, source, value)
        elseif op == "draw" then M.draw(state, value)
        elseif op == "energy" then state.energy = state.energy + value
        elseif op == "gainStatus" then M.addStatus(source, effect.status, value)
        elseif op == "applyStatus" then
            if target and target.hp > 0 then M.addStatus(target, effect.status, value) end
        elseif op == "applyStatusAll" then
            for _, victim in ipairs(targets(state, source)) do
                if victim.hp > 0 then M.addStatus(victim, effect.status, value) end
            end
        else error("unsupported effect: " .. tostring(op)) end
    end
    return dealt
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
    local ok, op = supported(card.effects)
    if not ok then return false, "unsupported_effect:" .. op end
    if card.costMode or card.condition then return false, "advanced_card_not_enabled" end
    if state.energy < card.cost then return false, "insufficient_energy" end
    for _, effect in ipairs(card.effects) do
        if effect.op == "damage" or effect.op == "applyStatus" then
            local enemy = state.enemies[targetIndex]
            if not enemy or enemy.hp <= 0 then return false, "invalid_target" end
        end
    end
    return true
end

function M.play(state, uid, targetIndex)
    local ok, reason = M.canPlay(state, uid, targetIndex)
    if not ok then return false, reason end -- validate before changing any state/RNG
    local instance, position = findInstance(state, uid)
    local card = M.cardDefinition(state, instance)
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

local function endActorTurn(actor)
    for _, id in ipairs({ "weak", "vulnerable", "frail" }) do
        actor.statuses[id] = math.max(0, (actor.statuses[id] or 0) - 1)
    end
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
    if (state.player.statuses.barricade or 0) <= 0 then state.player.block = 0 end
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
    endActorTurn(state.player)
    state.phase = "enemy"
    event(state, "enemy_turn")
    for _, enemy in ipairs(state.enemies) do
        if enemy.hp > 0 then
            if (enemy.statuses.barricade or 0) <= 0 then enemy.block = 0 end
            local intent = enemy.intents[enemy.intentIndex]
            event(state, "intent", { enemy = enemy.id, id = intent.id })
            M.applyEffects(state, intent.effects, enemy, state.player)
            endActorTurn(enemy)
            enemy.intentIndex = enemy.intentIndex % #enemy.intents + 1
            if finish(state) then return true end
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
    local state = { rules = rules, catalog = { cards = index(data.cards.cards), enemies = index(data.enemies.enemies) },
        seed = (options.seed or 1) % 65536, turn = 0, energy = 0, phase = "setup", nextUid = 1,
        player = { id = "player", hp = hp, maxHp = rules.player.maxHp, block = 0, statuses = {} },
        enemies = {}, draw = {}, hand = {}, discard = {}, exhaust = {}, events = {} }
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
        for _, intent in ipairs(enemy.intents) do assert(supported(intent.effects), "unsupported enemy intent") end
        enemy.definitionId, enemy.id, enemy.maxHp = id, id .. "_" .. i, enemy.hp
        enemy.block, enemy.statuses, enemy.intentIndex = 0, {}, 1
        state.enemies[#state.enemies + 1] = enemy
    end
    shuffle(state, state.draw)
    M.startPlayerTurn(state)
    return state
end

return M
