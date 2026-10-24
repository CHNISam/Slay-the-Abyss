-- Pure Lua 5.3 battle state. No game/script/io globals; the UI issues commands.
local Actors = require("abyss_actor")
local Effects = require("abyss_effects")
local Events = require("abyss_events")
local EnemyAI = require("abyss_enemy_ai")
local CardActions = require("abyss_card_actions")
local CardRandom = require("abyss_sts_random")
local M = { addStatus = Actors.addStatus, addTemporaryStrength = Actors.addTemporaryStrength,
    statusView = Actors.statusView, block = Actors.block,
    attackAmount = Actors.attackAmount, blockAmount = Actors.blockAmount }

function M.damage(state, source, target, base, fixed, retaliation, resolved)
    local before, sourceBefore = target.hp, source.hp
    local thornsCallback = before > 0 and sourceBefore > 0 and not fixed and not retaliation
        and (target.statuses.thorns or 0) > 0
    local lost = Actors.damage(state, source, target, base, fixed, retaliation,resolved)
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
function M.cardRandom(state,maximum)
    assert(maximum>=1 and maximum%1==0,'invalid card random range')
    return CardRandom.randomInt(state.cardRandomRng,maximum-1)+1
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
        if intent.kind == "charge" or intent.kind == "split" or intent.kind == "escape" then
            local kind = intent.kind
            local policy = enemy.ai and enemy.ai.kind
            local supported = kind == "escape" and policy == "looter"
                or kind == "charge" and policy == "charge_then_attack"
                or kind == "split" and (policy == "spike_slime_l" or policy == "acid_slime_l")
            assert(supported and enemy.ai[kind .. "Intent"] == intent.id,
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
    assert(ai and (ai.kind == "spike_slime_l" or ai.kind == "acid_slime_l") and ai.splitCount == 2, "unsupported enemy split")
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

function M.allEnemiesEscaped(state)
    if #state.enemies == 0 then return false end
    for _, enemy in ipairs(state.enemies) do if not enemy.escaped then return false end end
    return true
end

local function goldInteger(n)
    return type(n) == "number" and n == n and n % 1 == 0 and n >= 0 and n <= 2147483647
end
function M.stealGold(state, enemy, limit)
    assert(enemy.ai and enemy.ai.kind == "looter" and Actors.isActive(enemy) and Actors.isActive(state.player), "invalid thief")
    assert(goldInteger(limit) and goldInteger(state.player.gold) and goldInteger(enemy.stolenGold), "invalid gold")
    local amount = math.min(limit, state.player.gold)
    local total = enemy.stolenGold + 0.0 + amount
    assert(goldInteger(total), "stolen gold overflow")
    enemy.stolenGold, state.player.gold = total, state.player.gold - amount
    if amount > 0 then event(state, "gold_stolen", {enemy=enemy.id, target=state.player.id, amount=amount}) end
    return amount
end
function M.escapeEnemy(state, enemy)
    if not Actors.isActive(enemy) or not enemy.ai or enemy.ai.kind ~= "looter"
        or enemy.intents[enemy.intentIndex].id ~= enemy.ai.escapeIntent then return false end
    enemy.escaped, state.mugged = true, true
    event(state, "enemy_escape", {enemy=enemy.id})
    return true
end

local function aliveEnemies(state)
    for _, enemy in ipairs(state.enemies) do if Actors.isActive(enemy) then return true end end
    return false
end

function M.outcome(state)
    if state.player.hp <= 0 then return "defeat" end -- simultaneous death loses
    if not aliveEnemies(state) then return "victory" end
    return nil
end

local function finish(state)
    local outcome = M.outcome(state)
    if outcome then
        Actors.flushCurlUp(state)
        for _, enemy in ipairs(state.enemies) do enemy.looterQueuedIntent = nil end
    end
    if outcome and state.phase ~= outcome then
        state.phase = outcome
        event(state, outcome, {allEnemiesEscaped=M.allEnemiesEscaped(state), mugged=state.mugged})
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
        local kind=state.catalog.cards[card.cardId].type
        if kind=="status" and (state.player.statuses.evolve or 0)>0 then
            CardActions.enqueue(state,{op="draw",value=state.player.statuses.evolve})
        end
        if (kind=="status" or kind=="curse") and (state.player.statuses.fire_breathing or 0)>0 then
            CardActions.enqueue(state,{op="damageAll",value=state.player.statuses.fire_breathing,fixed=true})
        end
    end
end

function M.cardDefinition(state, instance)
    local card = copy(assert(state.catalog.cards[instance.cardId], "unknown card"))
    if instance.upgraded then for k, v in pairs(card.upgrade or {}) do card[k] = copy(v) end end
    if card.id=="searing_blow" then
        local n=instance.upgrades or (instance.upgraded and 1 or 0)
        card.effects[1].value=12+3.5*n+0.5*n*n
    end
    if card.id=="blood_for_blood" then card.cost=math.max(0,card.cost-(instance.costReduction or 0)) end
    if instance.costForTurn~=nil then card.cost=instance.costForTurn end
    if state.player and card.type=="skill" and (state.player.statuses.corruption or 0)>0 then card.cost=0 end
    if card.id=="perfected_strike" and state.hand then
        local count=0
        for _,pile in ipairs({state.hand,state.draw,state.discard}) do
            for _,held in ipairs(pile) do if state.catalog.cards[held.cardId].strikeTag then count=count+1 end end
        end
        card.effects[1].value=6+count*card.strikeBonus
    end
    if card.strengthMultiplier and state.player then
        card.effects[1].value=card.effects[1].value+(state.player.statuses.strength or 0)*(card.strengthMultiplier-1)
    end
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

function M.canUpgrade(state,instance)
    local d=state.catalog.cards[instance.cardId]
    return d and d.upgrade~=nil and (not instance.upgraded or d.repeatable==true)
end
function M.upgrade(state,instance)
    if not M.canUpgrade(state,instance) then return false end
    instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1
    instance.upgraded=true
    return true
end

-- Read-only display numbers for one hand card, from the same modifier arithmetic
-- resolution uses. Without an aimed enemy, only player modifiers apply. Aimed
-- cards add receiving modifiers; area calculations retain per-monster values
-- and display the first monster slot. Never invent a min/max damage range.
function M.cardPreview(state, instance, targetIndex)
    local card, player, result = M.cardDefinition(state, instance), state.player, {}
    local aimed = state.enemies[targetIndex]
    local function previewDamage(op, base)
        local neutral = {statuses = {}}
        local targeted = Actors.isActive(aimed)
        local targets, value
        if op == "damageAll" and targeted then
            targets = {}
            for i, enemy in ipairs(state.enemies) do
                targets[i] = Actors.attackAmount(state, player, Actors.isActive(enemy) and enemy or neutral, base)
            end
            value = targets[1]
        else
            value = Actors.attackAmount(state, player, targeted and aimed or neutral, base)
        end
        return {op = op, low = value, high = value, targets = targets}
    end
    for i, effect in ipairs(card.effects) do
        if effect.op == "damage" or effect.op == "damageAll" or effect.op=="fiendFire"
            or effect.op=="feed" or effect.op=="reaper" or effect.op=="damageRandom" then
            result[i] = previewDamage(effect.op=="reaper" and "damageAll" or effect.op=="damageAll" and "damageAll" or "damage", effect.value)
            result[i].op=effect.op
        elseif effect.op == "damageEqualToBlock" then result[i] = previewDamage("damage", player.block)
            result[i].op = effect.op
        elseif effect.op == "block" then
            local amount = Actors.blockAmount(state, player, effect.value)
            result[i] = {op = effect.op, low = amount, high = amount}
        elseif effect.op=="secondWind" then
            local amount=Actors.blockAmount(state,player,effect.value)
            result[i]={op=effect.op,low=amount,high=amount}
        end
    end
    return result
end

local function findInstance(state, uid)
    for i, card in ipairs(state.hand) do if card.uid == uid then return card, i end end
end

function M.canPlay(state, uid, targetIndex)
    if state.phase ~= "player" then return false, "not_player_turn" end
    if state.pendingChoice or state.cardActions then return false,"card_choice_pending" end
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
    if card.condition=="only_attacks_in_hand" then
        for _,held in ipairs(state.hand) do
            if state.catalog.cards[held.cardId].type~="attack" then return false,"requires_only_attacks" end
        end
    elseif card.condition then return false,"advanced_card_not_enabled" end
    if state.energy < card.cost then return false, "insufficient_energy" end
    for _, effect in ipairs(card.effects) do
        if effect.op == "damage" or effect.op == "damageEqualToBlock" or effect.op == "applyStatus"
            or effect.op=="feed" or effect.op=="fiendFire" or effect.op=="spotWeakness" then
            local enemy = state.enemies[targetIndex]
            if not Actors.isActive(enemy) then return false, "invalid_target" end
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
    -- Selection, upgrades, Blood for Blood and exhaust callbacks mutate other
    -- instances too. Roll back each original table rather than replacing it.
    local visited={}
    local function mutable(t)
        if type(t)~="table" or visited[t] then return end
        visited[t]=true; save(t)
        for k,v in pairs(t) do
            if k~="catalog" and k~="rules" and k~="statusDefinitions" and k~="intents"
                and k~="ai" and k~="frame" then mutable(v) end
        end
    end
    for _,pile in ipairs({state.hand,state.draw,state.discard,state.exhaust,state.cardActions or {}}) do mutable(pile) end
    if state.pendingChoice then mutable(state.pendingChoice) end
    if state.cardRandomRng then mutable(state.cardRandomRng) end
    save(playedCard)
    return function()
        for original, values in pairs(saved) do
            for k in pairs(original) do original[k] = nil end
            for k, v in pairs(values) do original[k] = v end
        end
    end
end

local function queuePlay(state, uid, targetIndex, instance, card, free, forceExhaust, purge, top)
    state.resolvingCard = true
    state.cardInUse=instance
    local reactions = EnemyAI.cardReactions(state, card)
    local x=state.energy
    if not free then state.energy=state.energy-(card.costMode=="all_energy" and state.energy or card.cost) end
    event(state, "play", { uid = uid, cardId = instance.cardId, target = targetIndex })
    local items={}
    for i,effect in ipairs(card.effects) do
        if not (effect.targetGroup and card.effects[i-1] and card.effects[i-1].targetGroup) then
            local e=copy(effect)
            if e.op=="damage" or e.op=="damageAll" or e.op=="fiendFire" or e.op=="feed"
                or e.op=="reaper" or e.op=="damageRandom" or e.op=="damageEqualToBlock" then
                e.resolved={}
                for j,enemy in ipairs(state.enemies) do
                    e.resolved[enemy.id]=Actors.attackAmount(state,state.player,enemy,e.op=="damageEqualToBlock" and state.player.block or e.value)
                end
            end
            if e.targetGroup then e={op="effectBatch",effects={e,copy(card.effects[i+1])}} end
            if e.times=="X" then e.times=x; if x==0 then e=nil end end
            if e then items[#items+1]=e end
        end
    end
    local coreOnly=true
    for _,e in ipairs(items) do if CardActions.supports(e.op) then coreOnly=false end end
    if coreOnly and not (state.player.statuses.rupture and state.player.statuses.rupture>0) then
        local batch={}
        for _,e in ipairs(items) do
            if e.op=="effectBatch" then for _,part in ipairs(e.effects) do batch[#batch+1]=part end
            else batch[#batch+1]=e end
        end
        if #batch>0 then items={{op="effectBatch",effects=batch}} end
    end
    if card.type=="attack" and (state.player.statuses.rage or 0)>0 then
        items[#items+1]={op="block",value=state.player.statuses.rage,fixed=true}
    end
    local exhaust=card.exhaust or forceExhaust or card.type=="skill" and (state.player.statuses.corruption or 0)>0
    items[#items+1]={op="dispose",exhaust=exhaust,purge=purge,cardType=card.type,reactions=reactions}
    local repeats=card.type=="attack" and not purge and (state.player.statuses.double_tap or 0)>0
    if repeats then
        state.player.statuses.double_tap=state.player.statuses.double_tap-1
        items[#items+1]={op="repeatCard",card=copy(instance),targetIndex=targetIndex}
    end
    if top then
        for i=#items,1,-1 do CardActions.enqueue(state,items[i],state.player,state.enemies[targetIndex],instance,true) end
    else for _,e in ipairs(items) do CardActions.enqueue(state,e,state.player,state.enemies[targetIndex],instance) end end
end

function M.disposeCard(state,item)
    local e,instance=item.effect,item.instance
    EnemyAI.afterCard(state,e.reactions)
    if state.cardInUse==instance then state.cardInUse=nil end
    -- A used Power leaves the combat piles; it is not an exhausted card.
    -- The Power destination takes precedence over exhaust-on-use, while an
    -- unplayed Power still follows the ordinary endTurn hand lifecycle.
    if e.cardType ~= "power" and not e.purge then
        if e.exhaust then CardActions.exhaust(M,state,instance)
        else state.discard[#state.discard+1]=instance end
    end
end

local function resolvePlay(state,uid,targetIndex,instance,position,card)
    table.remove(state.hand,position)
    queuePlay(state,uid,targetIndex,instance,card)
    CardActions.drain(M,state)
    if not state.pendingChoice then Actors.flushCurlUp(state) end
    finish(state)
    return true
end

function M.chooseCard(state,token,uid)
    local restore=savePlayState(state,{})
    local called,ok,reason=pcall(CardActions.choose,M,state,token,uid)
    if not called then restore(); error(ok,0) end
    if ok and not state.pendingChoice then Actors.flushCurlUp(state); finish(state) end
    return ok,reason
end

function M.repeatCard(state,e)
    local target=state.enemies[e.targetIndex]
    if target and not Actors.isActive(target) then
        local pool={}; for i,v in ipairs(state.enemies) do if Actors.isActive(v) then pool[#pool+1]=i end end
        if #pool==0 then return end
        e.targetIndex=pool[M.cardRandom(state,#pool)]
    end
    local c=e.card
    queuePlay(state,c.uid,e.targetIndex,c,M.cardDefinition(state,c),true,false,true,true)
end

function M.autoplayTop(state)
    if #state.draw==0 then
        if #state.discard==0 then return end
        state.draw,state.discard=state.discard,{}; shuffle(state,state.draw); event(state,"reshuffle")
    end
    local c=table.remove(state.draw)
    local d=M.cardDefinition(state,c)
    local targets={}; for i,v in ipairs(state.enemies) do if Actors.isActive(v) then targets[#targets+1]=i end end
    local target=#targets>0 and targets[M.cardRandom(state,#targets)] or nil
    local invalid=d.cost==-2 or d.type=="attack" and (state.player.statuses.entangled or 0)>0
    if d.condition=="only_attacks_in_hand" then
        for _,held in ipairs(state.hand) do if state.catalog.cards[held.cardId].type~="attack" then invalid=true end end
    end
    if invalid then CardActions.exhaust(M,state,c);return end
    queuePlay(state,c.uid,target,c,d,true,true,false,true)
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
    if not Actors.isActive(enemy) then return nil end
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
    for _,pile in ipairs({state.hand,state.draw,state.discard,state.exhaust}) do for _,c in ipairs(pile) do c.costForTurn=nil end end
    for _,id in ipairs({"rage","double_tap","flame_barrier"}) do state.player.statuses[id]=nil end
    local p=state.player
    if (p.statuses.demon_form or 0)>0 then CardActions.enqueue(state,{op="gainStatus",status="strength",value=p.statuses.demon_form}) end
    if (p.statuses.berserk or 0)>0 then CardActions.enqueue(state,{op="energy",value=p.statuses.berserk}) end
    CardActions.drain(M,state)
    if finish(state) then return end
    M.draw(state, state.rules.player.drawPerTurn)
    if (p.statuses.brutality or 0)>0 then
        CardActions.enqueue(state,{op="draw",value=p.statuses.brutality})
        CardActions.enqueue(state,{op="loseHp",value=p.statuses.brutality})
    end
    CardActions.drain(M,state)
    event(state, "player_turn", state.turn)
    return true
end

function M.endTurn(state)
    if state.phase ~= "player" then return false, "not_player_turn" end
    if state.pendingChoice or state.cardActions then return false,"card_choice_pending" end
    if (state.player.statuses.metallicize or 0)>0 then
        CardActions.enqueue(state,{op="block",value=state.player.statuses.metallicize,fixed=true})
        CardActions.drain(M,state)
        if finish(state) then return true end
    end
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
    for _,instance in ipairs(state.hand) do
        if instance.cardId=="burn" then
            M.damage(state,state.player,state.player,2,true)
            if finish(state) then return true end
        end
    end
    local p=state.player
    if (p.statuses.combust or 0)>0 then
        CardActions.enqueue(state,{op="loseHp",value=p.combustHpLoss})
        CardActions.enqueue(state,{op="damageAll",value=p.statuses.combust,fixed=true})
    end
    CardActions.drain(M,state)
    if finish(state) then return true end
    for _,id in ipairs({'rage','double_tap'}) do
        local amount=state.player.statuses[id] or 0
        if amount>0 then
            state.player.statuses[id]=nil
            event(state,'status',{source=state.player.id,target=state.player.id,status=id,amount=-amount})
        end
    end
    local endingHand={}; for i,c in ipairs(state.hand) do endingHand[i]=c end
    for _, instance in ipairs(endingHand) do
        local card = M.cardDefinition(state, instance)
        if card.ethereal then CardActions.exhaust(M,state,instance,state.hand) end
    end
    -- End-turn exhaust draws occur before DiscardAtEndOfTurn in the original;
    -- the detailed end-turn action ordering remains guarded by dedicated tests.
    CardActions.drain(M,state)
    if finish(state) then return true end
    for _,instance in ipairs(state.hand) do state.discard[#state.discard+1]=instance end
    state.hand={}
    Actors.endTurn(state, state.player)
    if finish(state) then return true end
    state.phase = "enemy"
    event(state, "enemy_turn")
    -- The group pre-turn hook clears every monster's old Block before its
    -- queued start powers resolve. Drain supported start powers before moves,
    -- so ally Block granted during a move survives later teammates' actions.
    for _, enemy in ipairs(state.enemies) do if Actors.isActive(enemy) then Actors.resetBlock(state, enemy) end end
    for _, enemy in ipairs(state.enemies) do
        if Actors.isActive(enemy) then
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
        if Actors.isActive(enemy) then
            local intent = enemy.intents[enemy.intentIndex]
            event(state, "intent", { enemy = enemy.id, id = intent.id })
            EnemyAI.beforeAction(state, enemy, M.random, intent)
            -- takeTurn has already queued this enemy's action payload.
            if enemy.ai and enemy.ai.kind == "looter"
                and (intent.id == enemy.ai.mugIntent or intent.id == enemy.ai.lungeIntent) then
                M.stealGold(state, enemy, enemy.ai.stealAmount)
            end
            if intent.kind == "split" then splitEnemy(state, enemy)
            elseif intent.kind == "escape" then assert(M.escapeEnemy(state, enemy), "invalid escape")
            else resolveEffects(state, intent.effects, enemy, state.player, nil, true) end
            CardActions.drain(M,state)
            if finish(state) then return true end
            -- Thorns can kill this attacker while other enemies remain alive.
            if Actors.isActive(enemy) then
                Actors.endTurn(state, enemy)
            end
            -- A source-queued RollMove survives its owner's death while
            -- teammates live. finish above clears it on the final death.
            EnemyAI.afterAction(state, enemy, M.random, intent)
            Actors.flushCurlUp(state)
            if finish(state) then return true end
        end
    end
    -- Duration powers belong to the shared round boundary, after all actions.
    -- A new monster-sourced power can suppress its first reduction.
    Actors.endRound(state, state.player)
    for _, enemy in ipairs(state.enemies) do
        if Actors.isActive(enemy) then Actors.endRound(state, enemy) end
    end
    EnemyAI.endRound(state)
    M.startPlayerTurn(state)
    return true
end

function M.new(data, options)
    options = options or {}
    assert(type(options.seed or 1) == "number" and (options.seed or 1) % 1 == 0, "seed must be an integer")
    local rules = copy(data.rules)
    rules.player.maxHp=options.maxHp or rules.player.maxHp
    local hp = options.hp or rules.player.maxHp
    assert(hp > 0 and hp <= rules.player.maxHp and hp % 1 == 0, "invalid starting hp")
    local gold = options.gold == nil and rules.player.startingGold or options.gold
    assert(goldInteger(gold), "invalid starting gold")
    local state = { stolenGoldReward = 0, mugged = false, rules = rules,sourcePools=copy(data.cards.sourcePools), catalog = { cards = index(copy(data.cards.cards)), enemies = index(copy(data.enemies.enemies)),
            statuses = index(copy(data.statuses.statuses)) },
        seed = (options.seed or 1) % 65536, turn = 0, energy = 0, phase = "setup", nextUid = 1, nextEnemyId = 1,
        cardRandomRng=CardRandom.fromSeed(options.cardRandomSeed or string.format('%.0f',options.seed or 1)),
        player = { id = "player", gold = gold, hp = hp, maxHp = rules.player.maxHp, block = 0, statuses = {} },
        enemies = {}, draw = {}, hand = {}, discard = {}, exhaust = {}, events = {} }
    Actors.bindStatuses(state.player, state.catalog.statuses)
    local deck = options.deck or data.cards.starter_deck.cards
    -- Removing the final permanent card is legal; draw already handles empty piles.
    assert(type(deck) == "table", "invalid deck")
    for _, value in ipairs(deck) do
        local id = type(value) == "table" and value.cardId or value
        assert(state.catalog.cards[id], "unknown deck card: " .. tostring(id))
        state.draw[#state.draw + 1] = { uid = state.nextUid, cardId = id, upgraded = type(value) == "table" and value.upgraded == true,
            upgrades=type(value)=="table" and value.upgrades or nil }
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
    local innate,ordinary={},{}
    for _,c in ipairs(state.draw) do
        if M.cardDefinition(state,c).innate then innate[#innate+1]=c else ordinary[#ordinary+1]=c end
    end
    for _,c in ipairs(innate) do ordinary[#ordinary+1]=c end
    state.draw=ordinary
    -- MonsterRoom initializes all actors first; preBattlePrep shuffles the
    -- deck before calling the group's pre-battle powers in encounter order.
    for _, enemy in ipairs(state.enemies) do EnemyAI.preBattle(state, enemy, M.random) end
    local ok, reason = M.startPlayerTurn(state, options.beforeOpeningDraw)
    if ok == false then return nil, reason end
    return state
end

return M
