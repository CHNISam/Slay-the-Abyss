-- Pure Lua 5.3 battle state. No game/script/io globals; the UI issues commands.
local Actors = require("abyss_actor")
local Effects = require("abyss_effects")
local Events = require("abyss_events")
local EnemyAI = require("abyss_enemy_ai")
local CardActions = require("abyss_card_actions")
local PlatedArmor = require('abyss_plated_armor')
local Act2Powers = require('abyss_act2_powers')
local Curses = require("abyss_curses")
local EnemyRandom = require("abyss_enemy_random")
local SourceRandom = require("abyss_sts_random")
local Formation = require("abyss_encounter_formation")
local RelicHooks = require('abyss_relic_hooks')
local Awakened=require('abyss_awakened_one')
local M = { addStatus = Actors.addStatus, addTemporaryStrength = Actors.addTemporaryStrength,
    statusView = Actors.statusView, block = Actors.block,
    attackAmount = Actors.attackAmount, blockAmount = Actors.blockAmount }

local function actionOwned(state)
    return state.resolvingEffects or state.resolvingCard or state.actionQueue or state.drainingCardActions
        or state.pendingChoice or state.pendingPlay or state.pendingScry or state.pendingHandChoice
        or state.pendingDiscard or state.pendingPileChoice
end
local function standaloneBoundary(state,sharedBatch)
    return not sharedBatch and not actionOwned(state) and not state.cardActions and not state.queuedCards
end
local function settleStandalone(state,settle)
    -- New tails may now exist; recheck owners, not their newly created queue.
    if settle and not actionOwned(state) and (state.cardActions or state.queuedCards) then CardActions.drain(M,state)end
end
local function enemyEffectsPending(state)
    -- TOP reactions still belong to the queued enemy completion. BOTTOM
    -- callbacks after that completion must flush now, before player input.
    if state.drainingCardActions and state.phase=='enemy' then
        for _,item in ipairs(state.cardActions or {})do
            if item.effect.op=='enemyAction' and item.effect.stage=='effectsComplete' then return true end
        end
    end
    return false
end

function M.damage(state, source, target, base, fixed, retaliation, normalAmount)
    local settle=standaloneBoundary(state,retaliation)
    local before, sourceBefore = target.hp, source and source.hp or 0
    local poison
    if source==state.player and not fixed and (source.statuses.envenom or 0)>0 then
        local amount=normalAmount or Actors.attackAmount(state,source,target,base)
        poison=require('abyss_card_triggers').onAttack(state,source,target,math.max(0,amount-target.block),'NORMAL')
    end
    local thornsCallback = source and before > 0 and sourceBefore > 0 and not fixed and not retaliation
        and (target.statuses.thorns or 0)+(target.statuses.flame_barrier or 0) > 0
    if state.originalV4 then base,normalAmount=require('abyss_original_v4').reduceAttack(state,source,target,base,fixed,normalAmount) end
    local previewAmount=state.originalV4Preview and source==state.player and target~=state.player
        and (normalAmount or Actors.attackAmount(state,source,target,base,fixed)) or nil
    local previewBlock=previewAmount and math.min(target.block,previewAmount) or 0
    local lost = Actors.damage(state, source, target, base, fixed, retaliation, normalAmount,poison)
    if previewAmount then state.originalV4Preview[#state.originalV4Preview+1]={op=fixed and 'derived' or 'damage',target=target.id,
        low=previewAmount,high=previewAmount,actual=lost,blocked=previewBlock}end
    if state.originalV4 then require('abyss_original_v4').enemyDied(state,target,before) end
    EnemyAI.hpLost(state, target, before, before > 0 and (not source or sourceBefore > 0))
    if source and source ~= target then EnemyAI.hpLost(state, source, sourceBefore, thornsCallback) end -- normal thorns
    if not state.resolvingEffects then
        if not enemyEffectsPending(state) then EnemyAI.flush(state) end
        if not state.resolvingCard then Actors.flushCurlUp(state) end
    end
    settleStandalone(state,settle)
    return lost
end

function M.retaliate(state, source, target, amount)
    local before = target.hp
    local lost = Actors.retaliate(state, source, target, amount)
    if state.originalV4 then require('abyss_original_v4').enemyDied(state,target,before) end
    EnemyAI.hpLost(state, target, before, before > 0)
    if not state.resolvingEffects and not enemyEffectsPending(state) then EnemyAI.flush(state) end
    return lost
end

-- SuicideAction is not an attack or HP-loss action. Keep its death notification
-- in Combat, which already owns the optional character ledger boundary.
function M.suicideExploder(state,enemy)
    assert(Actors.isActive(enemy) and enemy.ai and enemy.ai.kind=='act3' and enemy.ai.policy=='exploder',
        'Exploder suicide only')
    local before=enemy.hp;enemy.hp=0
    Events.emit(state,'enemy_suicide',{enemy=enemy.id})
    if state.originalV4 then require('abyss_original_v4').enemyDied(state,enemy,before)end
end

function M.suicideTransient(state,enemy)
    local before=enemy.hp;Actors.suicideTransient(state,enemy)
    if state.originalV4 then require('abyss_original_v4').enemyDied(state,enemy,before)end
    CardActions.drain(M,state)
end

local function resolveEffects(state, effects, source, target, playedCard, queuedEnemyAction, deferCompletion)
    local settle=standaloneBoundary(state,queuedEnemyAction)
    if queuedEnemyAction then
        assert(state.phase == "enemy" and source ~= state.player and target == state.player, "invalid queued enemy action")
    end
    local previous = state.resolvingEffects
    state.resolvingEffects = true
    local called, dealt = pcall(Effects.apply, M, state, effects, source, target, playedCard, queuedEnemyAction)
    state.resolvingEffects = previous
    if not called then error(dealt, 0) end
    if not previous and not deferCompletion then
        EnemyAI.afterEffects(state, source)
        if not enemyEffectsPending(state) then EnemyAI.flush(state, source) end
        if not state.resolvingCard and not queuedEnemyAction then Actors.flushCurlUp(state) end
    end
    settleStandalone(state,settle)
    return dealt
end

function M.applyEffects(state, effects, source, target, playedCard)
    return resolveEffects(state, effects, source, target, playedCard, false)
end

local copy = require("abyss_copy").copy
M.copy = copy


local function index(entries)
    local result = {}
    for _, entry in ipairs(entries) do result[entry.id] = entry end
    return result
end

-- Small-state LCG: all products stay below 2^31 on both Fengari and game Lua.
function M.random(state, maximum)
    return EnemyRandom.legacyInteger(state,maximum)
end
function M.cardRandom(state,maximum)
    assert(maximum>=1 and maximum%1==0,'invalid card random range')
    return SourceRandom.randomInt(state.cardRandomRng,maximum-1)+1
end
function M.onHpLost(state,owner,amount)
    require('abyss_hp_loss').notify(state,owner,state.player,amount)
end
local function drainNative(state)
    if state.player.hp>0 and not state.drainingCardActions and not state.pendingChoice
        and (state.cardActions or state.queuedCards) then CardActions.drain(M,state) end
end
local function nativeDefinition(state,card)
    return (state.experimentalCharacter==nil or card.silentFinalCard or card.runNativeABI) and card.target~=nil and not card.silentFinalLegacy and (card.experimental~=true or card.silentFinalCard)
end
local function aiRandom(state,maximum)return EnemyRandom.integer(state,maximum,M.random)end
local function hpRandom(state,maximum)
    if state.monsterHpRng then return SourceRandom.randomInt(state.monsterHpRng,maximum-1)+1 end
    return M.random(state,maximum)
end

-- Both ordinary enemies and spawned children use the same actor contract.
-- Split children use the source's explicit-HP constructor, without an HP draw.
local function makeEnemy(state, id, serial, explicitHp)
    local enemy = copy(assert(state.catalog.enemies[id], "unknown enemy: " .. tostring(id)))
    if enemy.ai and enemy.ai.kind=='act3'and enemy.ai.policy=='transient'then
        require('abyss_act3_enemies').bindSharedStatuses(state.catalog.statuses,copy)
    end
    if not explicitHp and enemy.ai and enemy.ai.preHpRoll then hpRandom(state,enemy.ai.preHpRoll) end
    if explicitHp then enemy.hp = explicitHp
    elseif enemy.hpRange then
        enemy.hp = enemy.hpRange.min + hpRandom(state, enemy.hpRange.max - enemy.hpRange.min + 1) - 1
    elseif state.monsterHpRng and not (enemy.ai and enemy.ai.noHpRoll) then
        -- AbstractMonster.setHp(hp) delegates to setHp(hp,hp), drawing even at 0..0.
        hpRandom(state,1)
    end
    EnemyAI.prepare(state, enemy, hpRandom)
    for _, intent in ipairs(enemy.intents) do
        if intent.kind == "charge" or intent.kind == "split" or intent.kind == "escape" then
            local kind = intent.kind
            local policy = enemy.ai and enemy.ai.kind
            local supported = kind == "escape" and policy == "looter"
                or kind == "charge" and policy == "charge_then_attack"
                or kind == "split" and (policy == "spike_slime_l" or policy == "acid_slime_l" or policy == "act1_boss" and enemy.ai.policy=="slime_boss")
            assert(supported and enemy.ai[kind .. "Intent"] == intent.id,
                kind .. " intent requires matching AI")
            assert(type(intent.effects) == "table" and next(intent.effects) == nil, kind .. " intent has effects")
        elseif intent.kind=='unknown' and Awakened.owns(enemy)and intent.id=='rebirth'then
            assert(type(intent.effects)=='table'and next(intent.effects)==nil,'Rebirth has effects')
        elseif intent.kind == 'unknown' and enemy.ai and enemy.ai.kind=='act3'
            and enemy.ai.policy=='exploder' and intent.id=='wait' then
            assert(type(intent.effects)=='table'and next(intent.effects)==nil,'Exploder wait has effects')
        elseif intent.kind == "sleep" or intent.kind == "stunned" or intent.kind=="unknown" and enemy.ai and enemy.ai.kind=="act1_boss" then
            assert(type(intent.effects) == "table" and next(intent.effects) == nil, "inactive enemy intent has effects")
        else assert(Effects.supported(intent.effects), "unsupported enemy intent") end
    end
    enemy.definitionId, enemy.id, enemy.maxHp = id, id .. "_" .. serial, enemy.hp
    enemy.block, enemy.statuses, enemy.intentIndex = 0, {}, 1
    Actors.bindStatuses(enemy, state.catalog.statuses)
    return enemy
end

function M.summonEnemies(state,descriptors)
    local created={}
    for i,entry in ipairs(descriptors)do
        local e=makeEnemy(state,entry.id,state.nextEnemyId);state.nextEnemyId=state.nextEnemyId+1
        e.sourcePosition={x=entry.x,y=entry.y};e.minion=true;created[i]=e
        for _,id in ipairs(state.relics or {})do if id=="Philosopher's Stone" then Actors.applyPower(state,e,'strength',1,e) end end
    end
    for _,e in ipairs(created)do
        EnemyAI.initialize(state,e,aiRandom)
        local position=1
        while state.enemies[position] and (state.enemies[position].sourcePosition or {x=0}).x<e.sourcePosition.x do position=position+1 end
        table.insert(state.enemies,position,e)
        Actors.applyPower(state,e,'minion',1,e)
        EnemyAI.preBattle(state,e,hpRandom)
        Events.emit(state,'enemy_spawn',{enemy=e.id,definitionId=e.definitionId})
    end
    return created
end

local function splitEnemy(state, parent)
    local ai, position = parent.ai, nil
    assert(ai and (ai.kind == "spike_slime_l" or ai.kind == "acid_slime_l" or ai.kind=="act1_boss" and ai.policy=="slime_boss") and ai.splitCount == 2, "unsupported enemy split")
    for i, enemy in ipairs(state.enemies) do if enemy == parent then position = i; break end end
    assert(position and parent.hp > 0, "invalid split parent")
    local children, hp = {}, parent.hp -- capture before the non-triggering death
    for i = 1, ai.splitCount do
        children[i] = makeEnemy(state, ai.splitEnemies and ai.splitEnemies[i] or ai.splitEnemy, state.nextEnemyId, hp)
        if ai.splitPositions then children[i].sourcePosition=copy(ai.splitPositions[i]) end
        state.nextEnemyId = state.nextEnemyId + 1
    end
    -- Suicide(false): no damage, death Power, relic callback or extra reward.
    -- Complete both spawns before checking outcome (source CannotLose/CanLose).
    parent.hp = 0
    for i, child in ipairs(children) do
        EnemyAI.initialize(state, child, aiRandom)
        table.insert(state.enemies, position + (i - 1) * 2, child)
    end
    Events.emit(state, "enemy_split", {enemy=parent.id, children={children[1].id, children[2].id}, hp=hp})
end

local function shuffle(state, pile)
    if state.shuffleRng then
        -- CardGroup.shuffle: one source nextLong seeds Java48/Collections,
        -- even for an empty or singleton group. Legacy fixtures stay below.
        SourceRandom.shuffle(state.shuffleRng, pile)
        return
    end
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
    for _, enemy in ipairs(state.enemies) do if Actors.isPresent(enemy) then return true end end
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
        if outcome=='victory'then require('abyss_defect_final_cards').victory(M,state)end
        state.phase = outcome
        event(state, outcome, {allEnemiesEscaped=M.allEnemiesEscaped(state), mugged=state.mugged})
    end
    return outcome
end

local function draw(state, count, drawn)
    if state.player.noDraw then return end
    if state.shuffleRng then
        -- DrawCardAction splits a request before EmptyDeckShuffleAction.
        -- Draw the old pile first, then shuffle the discard even when empty;
        -- only a wholly empty request or a full hand skips that source call.
        if count <= 0 or #state.draw + #state.discard == 0
            or #state.hand >= state.rules.player.maxHand then return end
        count = math.min(count, state.rules.player.maxHand - #state.hand)
        local oldSize = #state.draw
        if count > oldSize then
            if oldSize > 0 then draw(state, oldSize,drawn) end
            shuffle(state, state.discard)
            state.draw, state.discard = state.discard, {}
            event(state, "reshuffle")
            draw(state, count - oldSize,drawn)
            return
        end
    end
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
        drawn[#drawn+1]=card
        require('abyss_act2_powers').onDraw(state,card,M.combatBaseCost(state,card))
        if card.cardId=='void' then
            if state.actionQueue then
                require('abyss_action_queue').pushBottom(state,{kind='effect',effect={op='voidEnergy',value=1}})
            else state.energy=math.max(0,(state.energy or 0)-1) end
        end
        if (state.player.statuses.corruption or 0)~=0 then require("abyss_corruption").onDraw(state,card) end
        require("abyss_silent_discard_cards").onDraw(state,card)
        require('abyss_silent_final_cards').onDraw(state,card)
        require('abyss_watcher_final_cards').drawn(state,card,M.cardDefinition(state,card))
        if state.drainingCardActions or not state.experimentalMechanics then
            local kind=state.catalog.cards[card.cardId].type
            for _,id in ipairs(Actors.powerSequence(state.player,{'evolve','fire_breathing'})) do
                if id=='evolve' and kind=='status' then CardActions.enqueue(state,{op='draw',value=state.player.statuses[id]})
                elseif id=='fire_breathing' and (kind=='status' or kind=='curse') then
                    CardActions.enqueue(state,{op='damageAll',value=state.player.statuses[id],fixed=true})
                end
            end
        else
            local plan=require('abyss_warrior_status_cards').onDraw(state,card)
            if #(plan.bottom or {})>0 then
                assert(state.actionQueue,'draw-trigger powers require the shared queue')
                require('abyss_flow_actions').enqueue(state,plan,require('abyss_action_queue'))
            end
        end
        if (state.player.statuses.corruption or 0)~=0 then require("abyss_corruption").onDrawOrDiscard(state) end
        if (state.player.statuses.accuracy or 0)>0 then require("abyss_shivs").onDrawOrDiscard(state) end
    end
end
function M.draw(state,count)
    local drawn={};draw(state,count,drawn);return drawn
end
function M.shuffleDiscardIntoDraw(state)
    assert(#state.draw==0,'EmptyDeckShuffle requires an empty draw pile')
    shuffle(state,state.discard)
    state.draw,state.discard=state.discard,{}
    event(state,'reshuffle')
end

function M.combatBaseCost(state, instance)
    local def=assert(state.catalog.cards[instance.cardId])
    if def.costMode=='all_energy' then return -1 end
    local cost=instance.upgraded and def.upgrade and def.upgrade.cost or def.cost
    if instance.costOverride~=nil then cost=instance.costOverride end
    if instance.cardId=='masterful_stab'then cost=instance.combatCost or (instance.costOverride~=nil and cost or cost+(instance.masterfulLosses or 0))end
    if instance.cardId=='blood_for_blood' then cost=math.max(0,cost-(instance.costReduction or 0)) end
    return cost
end

function M.cardDefinition(state, instance)
    local card = copy(assert(state.catalog.cards[instance.cardId], "unknown card"))
    if instance.upgraded then for k, v in pairs(card.upgrade or {}) do card[k] = copy(v) end end
    if card.id=='searing_blow' then
        local n=instance.upgrades or (instance.upgraded and 1 or 0)
        card.effects[1].value=12+3.5*n+0.5*n*n
    end
    if instance.costOverride~=nil then card.cost=instance.costOverride end
    if instance.exhaust~=nil then card.exhaust=instance.exhaust end
    if instance.dontTriggerOnUseCard~=nil then
        assert(type(instance.dontTriggerOnUseCard)=='boolean','invalid instance card trigger flag')
        card.dontTriggerOnUseCard=instance.dontTriggerOnUseCard
    end
    if card.burnDamage==nil and card.endTurnDamage~=nil then card.burnDamage=card.endTurnDamage end
    local native=nativeDefinition(state,card)
    if native and card.id=='perfected_strike' then
        local count=0
        for _,pile in ipairs({state.hand or {},state.draw or {},state.discard or {}}) do
            for _,held in ipairs(pile) do if state.catalog.cards[held.cardId].strikeTag then count=count+1 end end
        end
        card.effects[1].value=6+count*card.strikeBonus
    end
    card=require("abyss_silent_discard_cards").costAdapter(state,instance,card)
    if state.player then card=require("abyss_retained_cards").adaptDefinition(state,instance,card) end
    if state.player then
        if not (native and card.id=='perfected_strike') then card=require('abyss_warrior_strength_cards').adaptDefinition(state,instance,card) end
        card=require('abyss_watcher_attack_cards').adaptDefinition(state,instance,card)
        card=require('abyss_warrior_status_cards').adaptDefinition(state,instance,card)
        card=require('abyss_defect_engine_cards').adaptDefinition(state,instance,card)
        card=require('abyss_defect_final_cards').adaptDefinition(state,instance,card)
        card=require('abyss_silent_tactics_cards').adaptDefinition(state,instance,card)
    end
    if instance.cardId=="shiv" and state.player then
        card=require("abyss_shivs").adaptDefinition(state,instance,card)
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
    if instance.combatCost~=nil or instance.turnCost~=nil then
        card=require("abyss_corruption").adaptDefinition(state,instance,card)
    end
    -- Old generated copies can carry only the legacy counter. Once the new
    -- persistent costs exist they already include every loss; never double-deduct.
    if card.id=='blood_for_blood' and instance.combatCost==nil and instance.turnCost==nil and instance.costReduction~=nil then
        card.cost=math.max(0,card.cost-instance.costReduction)
    end
    if instance.costForTurn~=nil then card.cost=instance.costForTurn end
    if native and state.player and not state.experimentalMechanics and card.type=='skill' and (state.player.statuses.corruption or 0)>0 then card.cost=0 end
    if card.originalV4 then card.target=require('abyss_original_v4').needsTarget(state,card) and 'ENEMY' or 'SELF' end
    card=require('abyss_colorless_cards').adapt(state,instance,card)
    card=require('abyss_silent_final_cards').adapt(state,instance,card)
    if card.id=='expunger' then card.expungerHits=instance.expungerHits or 0 end
    if state.player and not card.costMode and require('abyss_watcher_final_cards').freeAttack(state,card) then card.cost=0 end
    return card
end
function M.canUpgrade(state,instance)
    local d=state.catalog.cards[instance.cardId]
    return d and d.type~='status' and d.type~='curse' and d.upgrade~=nil and (not instance.upgraded or d.repeatable==true)
end
function M.upgrade(state,instance)
    if not M.canUpgrade(state,instance) then return false end
    local def=state.catalog.cards[instance.cardId]
    if instance.cardId=='blood_for_blood' and not instance.upgraded then
        if instance.combatCost==nil then instance.combatCost=M.combatBaseCost(state,instance) end
        if instance.turnCost==nil and instance.costForTurn~=nil then instance.turnCost=instance.costForTurn end
        require('abyss_warrior_status_cards').onUpgrade(state,instance)
        instance.costOverride,instance.costReduction=nil,nil
        if instance.costForTurn~=nil then instance.costForTurn=instance.turnCost end
    elseif def.upgrade.cost~=nil and (instance.costOverride~=nil or instance.costForTurn~=nil) then
        local before=M.combatBaseCost(state,instance)
        local turn=instance.costForTurn or before
        local diff=turn-before
        local nextCost=def.upgrade.cost
        instance.costOverride=nil
        if turn>0 then instance.costForTurn=math.max(0,nextCost+diff) end
    end
    instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1
    instance.upgraded=true;return true
end

-- Read-only display numbers for one hand card, from the same modifier arithmetic
-- resolution uses. Without an aimed enemy, only player modifiers apply. Aimed
-- cards add receiving modifiers; area calculations retain per-monster values
-- and display the first monster slot. Never invent a min/max damage range.
function M.cardPreview(state, instance, targetIndex)
    local card, player = M.cardDefinition(state, instance), state.player
    if card.originalV4 then return require('abyss_original_v4').preview(M,state,instance,targetIndex) end
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
    local function previews(effects)
      local result={}
      for i, effect in ipairs(effects) do
        if effect.op == "damage" or effect.op == "damageAll" then result[i] = previewDamage(effect.op, effect.value)
        elseif effect.op=='colorless'and (effect.kind=='ritual'or effect.kind=='greed')then
            result[i]=previewDamage('damage',effect.damage or effect.value)
        elseif effect.op=='barrageDamage' or effect.op=='bowlingBash' or effect.op=='ftlDamage' or effect.op=='heelHook'
            or effect.op=='fiendFire' or effect.op=='fearNoEvil' or effect.op=='wallop' or effect.op=='flowDamage'
            or effect.op=='sunderDamage' or effect.op=='finisherDamage' or effect.op=='flechettesDamage'
            or effect.op=='skewer' or effect.op=='glassKnife' or effect.op=='watcherFinalRagnarok'
            or effect.op=='watcherFinalExpungerHits' or effect.op=='watcherFinalLessonLearned' then
            result[i]=previewDamage('damage',effect.value);result[i].op=effect.op
        elseif effect.op=='feed' or effect.op=='reaper' or effect.op=='damageRandom' then
            result[i]=previewDamage(effect.op=='reaper' and 'damageAll' or 'damage',effect.value);result[i].op=effect.op
        elseif effect.op=='blizzardDamage' then
            result[i]=previewDamage('damageAll',effect.value);result[i].op=effect.op
        elseif effect.op=='randomEngineAttack' or effect.op=='thunderStrike' then
            local amount=Actors.attackAmount(state,player,{statuses={}},effect.value)
            result[i]={op=effect.op,low=amount,high=amount}
        elseif effect.op == "whirlwind" or effect.op == "reaperDamage" then
            result[i] = previewDamage("damageAll",effect.value)
            result[i].op = effect.op
        elseif effect.op == "damageEqualToBlock" then result[i] = previewDamage("damage", player.block)
            result[i].op = effect.op
        elseif effect.op == "block" or effect.op=='nextBlock' or effect.op=='xBlock'
            or effect.op=='secondWind' or effect.op=='stackBlock' or effect.op=='autoShields' or effect.op=='escapePlan' then
            local amount = Actors.blockAmount(state, player, effect.value)
            result[i] = {op = effect.op, low = amount, high = amount}
        elseif effect.op=='watcherFinalSpiritShield' then
            local others=#state.hand
            for _,held in ipairs(state.hand)do if held.uid==instance.uid then others=others-1;break end end
            local amount=Actors.blockAmount(state,player,effect.value*others)
            result[i]={op=effect.op,low=amount,high=amount}
        elseif effect.op=='halt' then
            local amount=Actors.blockAmount(state,player,effect.value)
            if player.stance=='Wrath' then amount=amount+Actors.blockAmount(state,player,effect.wrathValue) end
            result[i]={op=effect.op,low=amount,high=amount}
        elseif effect.op=='conditional' then
            result[i]={op=effect.op,['then']=previews(effect['then'])}
        end
      end
      return result
    end
    return previews(card.effects)
end

local function findInstance(state, uid)
    for i, card in ipairs(state.hand) do if card.uid == uid then return card, i end end
end
local function paidCost(state,card)
    if card.costMode or card.type=="skill" and (state.player.statuses.corruption or 0)~=0 then return 0 end
    return card.cost
end

function M.canPlay(state, uid, targetIndex)
    if state.pendingChoice or state.cardActions then return false,'card_choice_pending' end
    if state.pendingPlay or state.pendingScry or state.pendingHandChoice or state.pendingPileChoice or state.actionQueue then return false, "selection_pending" end
    if state.pendingDiscard then return false, "discard_choice_pending" end
    if state.phase ~= "player" then return false, "not_player_turn" end
    local instance = findInstance(state, uid)
    if not instance then return false, "card_not_in_hand" end
    local card = M.cardDefinition(state, instance)
    if card.cost == -2 then return false, "unplayable_card" end
    if Curses.limitsPlay(state) then return false,"normality_limit" end
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
    if card.watcherFinal and not require('abyss_watcher_final_cards').supported(card) then return false,'card_content_unavailable' end
    local colorlessOk,colorlessReason=require('abyss_colorless_cards').canUse(state,card)
    if not colorlessOk then return false,colorlessReason end
    if card.color=='colorless' and card.target=='ENEMY' and not Actors.isActive(state.enemies[targetIndex]) then return false,'invalid_target' end
    if card.costMode or card.condition then
        if card.experimental ~= true and not nativeDefinition(state,card) then return false, "advanced_card_not_enabled" end
        if card.condition and card.condition ~= "only_attacks_in_hand" and card.condition~='draw_pile_empty' then return false,"advanced_card_not_enabled" end
        if card.costMode and (card.costMode ~= "all_energy"
            or card.cost ~= -1 and not nativeDefinition(state,card)) then return false,"advanced_card_not_enabled" end
    end
    if card.costMode and (type(state.energy)~="number" or state.energy%1~=0 or state.energy<0
        or state.energy>2147483647) then return false,"invalid_energy" end
    if not card.costMode and state.energy < card.cost then return false, "insufficient_energy" end
    for _, effect in ipairs(card.effects) do
        if effect.op == "damage" or effect.op == "damageEqualToBlock" or effect.op == "applyStatus" or effect.op == "multiplyPoison"
            or effect.op=='barrageDamage' or effect.op=='ftlDamage' or effect.op=='bowlingBash'
            or effect.op=='spotWeakness' or effect.op=='heelHook' or effect.op=='fiendFire'
            or effect.op=='sunderDamage' or effect.op=='removeBlock' or effect.op=='applyLockOn'
            or effect.op=='fearNoEvil' or effect.op=='wallop' or effect.op=='flowDamage' or effect.op=='applyWatcherFlowPower'
            or effect.op=='finisherDamage' or effect.op=='flechettesDamage' or effect.op=='skewer'
            or effect.op=='glassKnife' or effect.op=='malaise' or effect.op=='feed'
            or effect.op=='watcherFinalJudgment' or effect.op=='watcherFinalExpungerHits' or effect.op=='watcherFinalLessonLearned' then
            local enemy = state.enemies[targetIndex]
            if not Actors.isActive(enemy) then return false, "invalid_target" end
        end
    end
    if card.originalV4 then
        local usable,refusal=require('abyss_original_v4').preflight(state,card,targetIndex)
        if not usable then return false,refusal end
    end
    local usable,refusal=require('abyss_watcher_attack_cards').canUse(state,instance,card)
    if not usable then return false,refusal end
    if card.condition=='draw_pile_empty' and #state.draw>0 then return false,'requires_empty_draw_pile' end
    if card.condition == "only_attacks_in_hand" then
        for _, held in ipairs(state.hand) do
            if M.cardDefinition(state,held).type ~= "attack" then return false,"requires_only_attacks" end
        end
    end
    return true
end

-- Only the mutable tables used by a card resolution. Keep original references:
-- draw may swap piles, and callers may retain actors, statuses, cards or events.
-- Catalog/rules/intents and existing events remain read-only; instance fields
-- in every pile may change through cost, growth and discard hooks.
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
    if state.relicCombat then save(state.relicCombat) end
    if state.relicCounters then save(state.relicCounters) end
    for _,pile in ipairs({state.hand,state.draw,state.discard,state.exhaust}) do
        for _,instance in ipairs(pile) do save(instance) end
    end
    if state.shuffleRng then
        -- Source shuffle advances the counter and replaces primitive words.
        -- Restore these existing objects along with the piles on a failed play.
        save(state.shuffleRng); save(state.shuffleRng.primitive)
    end
    -- New mechanics mutate nested state and primitive RNG words. Restore each
    -- original table in place; callers may hold individual orb references.
    local function nested(value)
        if type(value) ~= "table" or saved[value] then return end
        save(value)
        for _, child in pairs(value) do nested(child) end
    end
    nested(state.orbs)
    nested(state.cardRandomRng)
    nested(state.aiRng)
    nested(state.stanceQueue)
    nested(state.stancePowerOrder)
    nested(state.pendingDiscard)
    nested(state.pendingDiscardDraws)
    nested(state.actionQueue)
    nested(state.pendingPlay)
    nested(state.act2StasisCards)
    nested(state.pendingScry)
    nested(state.pendingHandChoice)
    nested(state.exhaustPowerOrder)
    nested(state.orbPowerOrder)
    nested(state.cardsPlayedThisTurn)
    nested(state.cardsPlayedThisCombat)
    nested(state.postDrawPowerOrder)
    nested(state.cardTriggerPowerOrder)
    nested(state.orbChannelCounts)
    nested(state.statusDrawPowerOrder)
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
    state.cardsPlayedThisTurn=state.cardsPlayedThisTurn or {}
    state.cardsPlayedThisCombat=state.cardsPlayedThisCombat or {}
    state.cardsPlayedThisTurn[#state.cardsPlayedThisTurn+1]={type=card.type,cardId=card.id}
    state.cardsPlayedThisCombat[#state.cardsPlayedThisCombat+1]={type=card.type,cardId=card.id}
    state.energy = state.energy - paidCost(state,card)
    table.remove(state.hand, position) -- played card cannot be drawn by its own draw
    state.cardInUse=instance
    event(state, "play", { uid = uid, cardId = instance.cardId, target = targetIndex })
    M.applyEffects(state, card.effects, state.player, state.enemies[targetIndex], instance)
    if state.player.hp>0 then EnemyAI.afterCard(state,reactions) end
    if state.player.hp<=0 then
        state.resolvingCard=previous
        finish(state)
        return true
    end
    -- A used Power leaves the combat piles; it is not an exhausted card.
    -- The Power destination takes precedence over exhaust-on-use, while an
    -- unplayed Power still follows the ordinary endTurn hand lifecycle.
    instance.freeToPlayOnce=nil
    if card.type ~= "power" then
        local pile = card.exhaust and state.exhaust or state.discard
        pile[#pile + 1] = instance
        if (state.player.statuses.corruption or 0)~=0 then require("abyss_corruption").onDrawOrDiscard(state) end
    end
    state.cardInUse=nil
    state.resolvingCard = previous
    if not previous and state.player.stance then
        if M.outcome(state) then state.stanceQueue = nil
        else require("abyss_stances").flush(state, M) end
    end
    if not previous and state.pendingDiscardDraws then
        local ok, reason = require("abyss_discard").flushDraws(state, M)
        assert(ok, reason)
    end
    if not previous then Actors.flushCurlUp(state);drainNative(state) end
    finish(state)
    return true
end

-- Selections, advanced card actions and exhaust triggers use data-only
-- continuations. Ordinary immediate cards keep their smaller transaction.
local queuedHandlers = {}
queuedHandlers.allow = function(state, action)
    if state.player.hp <= 0 then return false end
    if M.outcome(state) then
        if action.kind=='effect'and (require('abyss_end_turn_powers').retained(action.effect)or action.effect.op=='combustDamage')then return true end
        if action.kind=='effect'and action.effect.op=='classPotionDarkness'and action.effect.kind=='evoke'then return true end
        return action.kind == "useCard" or CardActions.reactionRetained(action.effect) or Effects.allowedAfterVictory(action.effect)
    end
    return true
end
local function queueCurlUp(state, queue)
    local pending=state.curlUpQueue
    state.curlUpQueue=nil
    for _,entry in ipairs(pending or {}) do
        queue.pushBottom(state,{kind="effect",effect={op="resolveCurlUp",targetId=entry.target.id,value=entry.amount}})
    end
end
local function queueStanceGains(state,queue)
    local gains=state.stanceQueue
    state.stanceQueue=nil
    for _,gain in ipairs(gains or {}) do
        local op=gain.kind or "energy"
        local effect={op=op,value=gain.amount}
        if op=="block" then effect.fixed=true end
        queue.pushBottom(state,{kind="effect",effect=effect})
    end
    local recalls=state.stanceCardQueue;state.stanceCardQueue=nil
    for _,effect in ipairs(recalls or {}) do queue.pushBottom(state,{kind='effect',effect=effect}) end
end
local function normalMatrix(state, rows)
    local previous=state.resolvingEffects
    state.resolvingEffects=true
    local called,dealt=pcall(function()
        local total,reactions=0,{}
        for _,row in ipairs(rows) do
            local target
            for _,enemy in ipairs(state.enemies) do if enemy.id==row.targetId then target=enemy;break end end
            if target and Actors.isActive(target) and not target.isDying and not target.isEscaping then
                total=total+M.damage(state,state.player,target,row.amount,false,reactions,row.amount)
            end
        end
        Actors.resolveDamageReactions(state,reactions,M.retaliate)
        return total
    end)
    state.resolvingEffects=previous
    if not called then error(dealt,0) end
    if not previous then EnemyAI.afterEffects(state,state.player);EnemyAI.flush(state,state.player) end
    return dealt
end
queuedHandlers.effect = function(state, action, queue)
    if action.effect.op=='awakenedAction'then Awakened.resolve(Actors,state,action.effect);return true end
    if action.effect.op=='staticRetaliation'then return M.staticRetaliation(state,action.effect)end
    if PlatedArmor.supports(action.effect.op)then
        return PlatedArmor.apply(M,state,action.effect,CardActions.enqueueReaction)
    end
    if Act2Powers.supports(action.effect.op)then return Act2Powers.apply(Actors,state,action.effect)end
    if action.effect.op=='discover'then
        require('abyss_potion_discovery').begin(M,state,action.effect)
        return 'pause'
    end
    if action.effect.op=='potionStanceChoice'then return require('abyss_potion_stance').begin(state)end
    if require('abyss_end_turn_powers').ops[action.effect.op]then return require('abyss_end_turn_powers').apply(M,state,action.effect,queue)end
    if action.effect.op=='ownerEndRetain'then
        return require('abyss_silent_final_cards').beginRetain(state)and 'pause'or true
    end
    if action.effect.op=='classPotionDarkness'then
        return require('abyss_class_potions').darkness(M,state,action.effect,queue)
    end
    local final=require('abyss_watcher_final_cards')
    if final.ops[action.effect.op] then return final.execute(M,state,action.effect,queue) end
    if action.effect.op=='silentFinal'then
        local target;for _,e in ipairs(state.enemies)do if state.pendingPlay and e.id==state.pendingPlay.targetId then target=e end end
        require('abyss_silent_final_cards').apply(M,state,{effect=action.effect,source=state.player,target=target,instance=state.cardInUse})
        return true
    end
    if action.effect.op=='defectFinal'then
        return require('abyss_defect_final_cards').execute(M,state,action.effect,queue)
    end
    if action.effect.op=='colorless' then
        require('abyss_colorless_cards').apply(M,state,{effect=action.effect,source=state.player})
        return true
    end
    local effect=action.effect
    if effect.op=='giantHeadSlow'then require('abyss_giant_head').applySlow(Actors,state,effect);return true end
    local build=require('abyss_build_actions')
    if effect.op=='pileChoice' then
        local result,why=require('abyss_pile_choice').begin(state,effect.mode,effect.value,state.combatGeneration or 0)
        assert(result,why);return result
    elseif effect.op=='orbStart' then
        local prepared=copy(effect.action)
        if prepared.targetId then
            for _,enemy in ipairs(state.enemies) do if enemy.id==prepared.targetId then prepared.target=enemy;break end end
            prepared.targetId=nil
        end
        require('abyss_orbs').resolve(state,prepared,M);return true
    elseif effect.op=='turnPoison' then
        for _,enemy in ipairs(state.enemies) do if enemy.id==effect.targetId and Actors.isActive(enemy) then
            local value=enemy.statuses.poison~=nil and effect.value or effect.newPowerAmount
            Actors.applyPower(state,enemy,'poison',value,state.player,nil,effect.poisonBonus);break
        end end
        return true
    elseif effect.op=='removeStatus' or effect.op=='reduceStatus' or effect.op=='removeFlowPower' or effect.op=='reduceFlowPower' then
        local target=state.player
        if effect.targetId and effect.targetId~=target.id then
            target=nil
            for _,enemy in ipairs(state.enemies) do if enemy.id==effect.targetId then target=enemy;break end end
        end
        if target and target.statuses[effect.status]~=nil then
            if effect.op=='reduceStatus' or effect.op=='reduceFlowPower' then
                local value=target.statuses[effect.status]-effect.value
                if value>0 then target.statuses[effect.status]=value;return true end
            end
            local removed=target.statuses[effect.status]
            require('abyss_power_schedule').remove(state,target,effect.status)
            target.statuses[effect.status]=nil
            event(state,'status_removed',{source=target.id,target=target.id,status=effect.status,amount=-removed})
        end
        return true
    elseif effect.op=='loseEnergy' then
        state.energy=math.max(0,state.energy-effect.value);return true
    elseif effect.op=='gainWatcherFlowPower' or effect.op=='applyWatcherFlowPower' or effect.op=='applyFlowStatus' then
        local target=state.player
        if effect.op~='gainWatcherFlowPower' then
            target=nil
            local id=effect.targetId or state.pendingPlay and state.pendingPlay.targetId
            for _,enemy in ipairs(state.enemies) do if enemy.id==id then target=enemy;break end end
        end
        if Actors.isActive(target) then
            if effect.op=='applyFlowStatus' then Actors.applyPower(state,target,effect.status,effect.value,state.player)
            elseif Actors.artifactBlocksPower(target,effect.status,effect.value) then Actors.tryBlockDebuff(state,target,effect.status)
            else
                local plan=require('abyss_watcher_flow_cards').applicationPlan(state,target,effect.status,effect.value)
                if Actors.applyPower(state,target,effect.status,plan.incoming,state.player) then
                    target.statuses[effect.status]=plan.after
                    state.events[#state.events].frame=Events.frame(state)
                end
            end
        end
        return true
    elseif effect.op=='wallop' then
        local target
        for _,enemy in ipairs(state.enemies) do if enemy.id==state.pendingPlay.targetId then target=enemy;break end end
        if Actors.isActive(target) then
            local reactions={}
            local lost=M.damage(state,state.player,target,effect.value,false,reactions,effect.normalAmount)
            if lost>0 then M.block(state,state.player,lost,true) end
            Actors.resolveDamageReactions(state,reactions,M.retaliate)
            queueCurlUp(state,queue)
        end
        return true
    elseif effect.op=='markLoseHp' or effect.op=='loseHp' and effect.targetId then
        for _,enemy in ipairs(state.enemies) do if enemy.id==effect.targetId and Actors.isActive(enemy) then
            local before=enemy.hp;Actors.loseHp(state,enemy,effect.value)
            EnemyAI.hpLost(state,enemy,before,true)
            break
        end end
        return true
    elseif effect.op=='requestDiscard' then
        local ok,reason=require('abyss_discard').begin(state,effect.value)
        assert(ok,reason)
        return state.pendingDiscard and 'pause' or true
    elseif effect.op=='discardTacticianEnergy' then
        state.energy=state.energy+effect.value
        event(state,'discard_energy',{uid=effect.uid,amount=effect.value});return true
    elseif effect.op=='randomManualDiscard' or effect.op=='discardSpecific' then
        local discard=require('abyss_discard')
        local uid=effect.op=='randomManualDiscard' and require('abyss_silent_tactics_cards').randomDiscardUid(state) or effect.uid
        if uid then
            local ok,why=discard.discardSpecific(state,uid,effect.incrementFirst==true,M)
            assert(ok,why)
        end
        return true
    elseif effect.op=='drawWithFollowup' then
        local drawn=M.draw(state,effect.value)
        if #drawn>0 and M.cardDefinition(state,drawn[1]).type=='skill' then
            queue.pushTop(state,{kind='effect',effect={op='block',value=effect.blockAmount,fixed=true}})
        end
        return true
    elseif effect.op=='skewerHits' then
        if effect.remaining>1 then
            queue.pushTop(state,{kind='effect',effect={op='skewerHits',value=effect.value,
                normalAmount=effect.normalAmount,remaining=effect.remaining-1}})
        end
        queue.pushTop(state,{kind='effect',effect={op='damage',value=effect.value,normalAmount=effect.normalAmount}})
        return true
    elseif effect.op=='reduceGlassKnife' then
        require('abyss_silent_tactics_cards').reduceGlassKnife(state,effect.uid,effect.value);return true
    elseif effect.op=='gainCardTriggerPower' then
        require('abyss_card_triggers').apply(state,effect.status,effect.value);return true
    elseif effect.op=='cardTriggerStorm' then
        for _,nextAction in ipairs(require('abyss_card_triggers').expandStorm(state,effect)) do queue.pushTop(state,nextAction) end
        return true
    elseif effect.op=='cardTriggerPoison' then
        require('abyss_card_triggers').resolveEnvenom(state,effect);return true
    elseif effect.op=='cardTriggerDamageAll' then
        require('abyss_card_triggers').resolveDamageAll(state,effect,M);return true
    elseif effect.op=='removeCardTriggerPower' then
        require('abyss_card_triggers').removePower(state,effect.status);return true
    elseif effect.op=='onUseReactions' then
        EnemyAI.afterCard(state,assert(state.pendingPlay).reactions);return true
    elseif effect.op=='capturedSharpHide' then
        M.capturedSharpHide(state,effect);return true
    elseif effect.op=='gainStrengthPower' then
        require('abyss_warrior_strength_cards').applyPower(state,effect.status,effect.value)
        return true
    elseif effect.op=='gainStatusPower' then
        require('abyss_warrior_status_cards').applyPower(state,effect.status,effect.value);return true
    elseif effect.op=='exhaustRandomAny' then
        return require('abyss_warrior_status_cards').exhaustRandomAny(state,queue)
    elseif effect.op=='removeStatusPower' then
        require('abyss_power_schedule').remove(state,state.player,effect.status)
        state.player.statuses[effect.status]=nil;return true
    elseif effect.op=='evokeOrb' or effect.op=='evokeWithoutRemovingOrb' then
        local orbs=require('abyss_orbs')
        local prepared=orbs.prepareEvoke(state,effect.op=='evokeOrb',true)
        orbs.resolve(state,prepared,M)
        return true
    elseif effect.op=='applyLockOn' or effect.op=='removeBlock' then
        local context=assert(state.pendingPlay)
        local target
        for _,enemy in ipairs(state.enemies) do if enemy.id==(effect.targetId or context.targetId) then target=enemy;break end end
        if Actors.isActive(target) then
            if effect.op=='applyLockOn' then require('abyss_defect_engine_cards').applyLockOn(state,target,effect.value)
            else target.block=0 end
        end
        return true
    elseif effect.op=='spotWeakness' then
        local context=assert(state.pendingPlay)
        for _,target in ipairs(state.enemies) do
            if target.id==context.targetId and build.isAttacking(target) then
                queue.pushBottom(state,{kind='effect',effect={op='gainStatus',status='strength',value=effect.value}})
            end
        end
        return true
    elseif effect.op=='makeTempCardInHand' or effect.op=='makeTempCard' then
        build.makeCard(state,effect);return true
    elseif effect.op=='nextEnergy' then
        build.applyNextEnergy(state,effect.value,effect.status);return true
    elseif effect.op=='nextBlock' then
        require('abyss_silent_attack_cards').applyNextBlock(state,effect.value);return true
    elseif effect.op=='heelHook' then
        local context=assert(state.pendingPlay)
        local target
        for _,enemy in ipairs(state.enemies) do if enemy.id==context.targetId then target=enemy end end
        if target and (target.statuses.weak or 0)>0 then
            queue.pushBottom(state,{kind='effect',effect={op='energy',value=1}})
            queue.pushBottom(state,{kind='effect',effect={op='draw',value=1}})
        end
        queue.pushTop(state,{kind='effect',effect={op='damage',value=effect.value,normalAmount=effect.normalAmount}})
        return true
    elseif effect.op=='removeNextEnergy' then
        state.player.statuses[effect.status]=nil;return true
    elseif effect.op=='postDrawPoison' then
        require('abyss_poison').postDraw(state,M);return true
    elseif effect.op=='voidEnergy' then
        state.energy=math.max(0,state.energy-effect.value);return true
    elseif effect.op=='xBlockRounds' then
        M.block(state,state.player,effect.value,true)
        if effect.remaining>1 then
            queue.pushTop(state,{kind='effect',effect={op='xBlockRounds',value=effect.value,remaining=effect.remaining-1}})
        end
        return true
    elseif effect.op=='previousCardType' or effect.op=='halt' or effect.op=='drawToHandSize' then
        local actions=require('abyss_watcher_attack_cards').planEffect(state,effect)
        for i=#actions,1,-1 do queue.pushTop(state,actions[i]) end
        return true
    elseif effect.op=='combustDamage' or effect.op=='statusFireDamage' then
        local owner={hp=1,statuses={}}
        for _,enemy in ipairs(state.enemies) do
            if Actors.isActive(enemy) then M.damage(state,owner,enemy,effect.value,true) end
        end
        return true
    elseif effect.op=='scry' then
        return require("abyss_scry").begin(state,effect.value,queue)
    elseif effect.op=="calculatedGamble" then
        local actions=require("abyss_silent_discard_cards").gambleActions(state)
        for i=#actions,1,-1 do queue.pushTop(state,actions[i]) end
        return true
    elseif effect.op=="discardReflexDraw" then
        M.draw(state,effect.value)
        event(state,"discard_draw",{uid=effect.uid,amount=effect.value})
        return true
    elseif effect.op == "handChoice" then
        local result, reason=require("abyss_hand_choice").begin(state,effect.mode,effect.value,queue)
        assert(result,reason)
        return result
    elseif effect.op == "resolveCurlUp" then
        for _,enemy in ipairs(state.enemies) do
            if enemy.id==effect.targetId then Actors.resolveCurlUp(state,enemy,effect.value);break end
        end
        return true
    elseif effect.op == "applyMantra" then
        local ok,reason=require("abyss_mantra").apply(state,effect.value,queue,effect.nullSource)
        assert(ok,reason);return true
    elseif effect.op == "removeMantra" then
        return require("abyss_mantra").remove(state)
    elseif effect.op == "heal" then
        if effect.relic then
            return CardActions.apply(M,state,{effect=effect,source=state.player})
        end
        -- A source-verified Reaper continuation, not a public card effect ABI.
        local value=effect.value
        assert(type(value)=="number" and value%1==0 and value>=0 and value<=2147483647,"invalid heal amount")
        local player=state.player
        local before=player.hp
        player.hp=math.min(player.maxHp,player.hp+0.0+value)
        event(state,"heal",{source=player.id,target=player.id,amount=player.hp-before})
        return true
    elseif effect.op=="effectBatch" then
        local context=assert(state.pendingPlay,"missing pending batch play")
        local target
        for _,enemy in ipairs(state.enemies) do if enemy.id==context.targetId then target=enemy;break end end
        M.applyEffects(state,effect.effects,state.player,target,state.cardInUse)
        queueCurlUp(state,queue);queueStanceGains(state,queue)
        return state.pendingDiscard and 'pause' or true
    elseif effect.op=="exhaustHand" then
        local instance=findInstance(state,effect.uid)
        assert(instance,"missing queued exhaust card")
        return require("abyss_exhaust").move(state,instance,"hand",queue,{onExhaustRelics=state.onExhaustRelics or {}})
    elseif effect.op=="restoreRetained" then
        local cards=state.retainedCards or {}
        local retained=require("abyss_retained_cards")
        for _,instance in ipairs(cards) do
            local _,intent=retained.onRetained(state,instance)
            state.hand[#state.hand+1]=instance
            instance.retain=nil
            if type(intent)=="table" then queue.pushBottom(state,{kind="effect",effect=intent}) end
        end
        state.retainedCards=nil
        if #cards>0 then event(state,"retain",{count=#cards}) end
        return true
    elseif effect.op=="discardEndHand" then
        while #state.hand>0 do
            local instance=table.remove(state.hand)
            local card=M.cardDefinition(state,instance)
            assert(not card.ethereal and not card.selfRetain and not instance.retain,"unprocessed end-turn card")
            state.discard[#state.discard+1]=instance
            if (state.player.statuses.corruption or 0)~=0 then require("abyss_corruption").onDrawOrDiscard(state) end
            require("abyss_silent_discard_cards").rememberDiscard(state,true)
        end
        return true
    elseif effect.op=="reduceRetainedCost" then
        local instance=findInstance(state,effect.uid)
        assert(instance,"retained cost card left hand")
        require("abyss_retained_cards").reduceBaseCost(state,instance)
        event(state,"retained_cost",{uid=instance.uid,cardId=instance.cardId})
        return true
    end
    local context=state.pendingPlay or {}
    local target
    for _,enemy in ipairs(state.enemies) do if enemy.id==context.targetId then target=enemy;break end end
    if effect.targetId then
        for _,enemy in ipairs(state.enemies) do if enemy.id==effect.targetId then target=enemy;break end end
    end
    local flow=require('abyss_flow_actions')
    local classPlan=flow.plan(state,effect,{target=target,uid=context.uid,instance=state.cardInUse,
        energyOnUse=context.energyOnUse,cardDefinition=M.cardDefinition})
    if classPlan then flow.enqueue(state,classPlan,queue);return true end
    local utility=require('abyss_defect_utility_cards')
    local plan=utility.planEffect and utility.planEffect(state,effect,{target=target,
        energyOnUse=context.energyOnUse,cardsPlayedBefore=math.max(0,#(state.cardsPlayedThisTurn or {})-1)})
    if plan then
        if plan.consumeAllEnergy and not context.freeToPlayOnce then state.energy=0 end
        for i=#plan.top,1,-1 do queue.pushTop(state,{kind='effect',effect=plan.top[i]}) end
        for _,e in ipairs(plan.bottom) do queue.pushBottom(state,{kind='effect',effect=e}) end
        return true
    end
    if effect.op == "whirlwind" then
        local rounds=context.energyOnUse
        assert(type(rounds)=="number" and rounds%1==0 and rounds>=0 and rounds<=2147483647,"invalid X snapshot")
        if rounds>0 then
            queue.pushBottom(state,{kind="effect",effect={op="whirlwindRounds",remaining=rounds,matrix=effect.matrix}})
            if not context.freeToPlayOnce then state.energy=0 end
        end
    elseif effect.op == "whirlwindRounds" then
        normalMatrix(state,effect.matrix)
        if effect.remaining>1 and not M.outcome(state) then
            queue.pushTop(state,{kind="effect",effect={op="whirlwindRounds",remaining=effect.remaining-1,matrix=effect.matrix}})
        end
    elseif effect.op == "reaperDamage" then
        local dealt=normalMatrix(state,effect.matrix)
        queueCurlUp(state,queue)
        if dealt>0 then queue.pushBottom(state,{kind="effect",effect={op="heal",value=dealt}}) end
    else
        M.applyEffects(state,{effect},state.player,target,state.cardInUse)
    end
    queueCurlUp(state,queue)
    queueStanceGains(state,queue)
    return true
end
-- Potion actions have no played card. Transfer the remaining player BOT
-- effects (onUsePotion hooks) ahead of the stance actions they will generate.
-- The caller's enclosing Run.usePotion snapshot owns this entire transaction.
function M.resolvePotionActions(state,effects)
    assert(not state.actionQueue and not state.pendingPlay,'potion action queue is busy')
    local actions={}
    for _,effect in ipairs(effects)do actions[#actions+1]={kind='effect',effect=effect}end
    for _,item in ipairs(state.cardActions or {})do
        assert(item.source==state.player and not item.target and not item.instance,'unsupported potion action owner')
        actions[#actions+1]={kind='effect',effect=item.effect}
    end
    state.cardActions=nil
    local queue=require('abyss_action_queue');queue.start(state,actions)
    local result=queue.run(state,queuedHandlers)
    assert(result==true or result=='pause'and state.pendingPotionChoice,'potion action cannot pause')
end
function M.choosePotionStance(state,selected,token,generation)
    local queue=require('abyss_action_queue')
    local ok,why=require('abyss_potion_stance').choose(state,selected,token,generation,queue)
    if not ok then return false,why end
    assert(queue.resume(state,queuedHandlers)==true,'potion continuation cannot pause')
    drainNative(state);finish(state)
    return true
end
queuedHandlers.useCard = function(state, _action, queue)
    local context,instance=assert(state.pendingPlay,"missing pending play"),state.cardInUse
    assert(instance and instance.uid==context.uid,"missing using card")
    -- A lethal on-use retaliation stops before the source UseCard disposal.
    -- Preserve the original cardInUse identity on the death screen.
    if state.player.hp<=0 then return true end
    RelicHooks.afterCard(state)
    if not context.purge then instance.freeToPlayOnce=nil end
    local rebound=require('abyss_defect_final_cards').afterUse(state,{type=context.cardType},context.purge,context.exhaust)
    require('abyss_giant_head').afterUse(state,context,CardActions.enqueueReaction,instance)
    if context.cardType~="power" and not context.purge then
        if context.exhaust then
            require("abyss_exhaust").move(state,instance,"using",queue,{onExhaustRelics=state.onExhaustRelics or {}})
        else
            local destination=require('abyss_watcher_flow_cards').disposalPlan(state,instance,false)
            if rebound then state.draw[#state.draw+1]=instance
            elseif destination then
                if #state.draw>0 then table.insert(state.draw,SourceRandom.randomInt(state.cardRandomRng,#state.draw-1)+1,instance)
                else state.draw[#state.draw+1]=instance end
            else
                state.discard[#state.discard+1]=instance
                if (state.player.statuses.corruption or 0)~=0 then require("abyss_corruption").onDrawOrDiscard(state) end
            end
        end
    end
    if context.cardType~='power' and not context.purge and instance.dontTriggerOnUseCard~=nil then
        instance.dontTriggerOnUseCard=false
    end
    state.cardInUse=nil
    -- Keep the outer resolution flag until all queued tails drain. Curl Up is
    -- represented as an explicit BOTTOM action, not flushed at every hit.
    queueCurlUp(state,queue)
    return true
end
function M.finishEarlyTurn(state)
    if not state.endTurnAfterCard or state.drainingCardActions or state.pendingChoice
        or state.actionQueue or state.pendingPlay or state.cardActions then return end
    state.endTurnAfterCard=nil
    if not finish(state) then local ok,why=M.endTurn(state);assert(ok,why)end
end
local function finishQueuedPlay(state)
    if state.startTurnPending and not state.pendingPlay then
        state.startTurnPending=nil;drainNative(state)
        if not finish(state) then event(state,'player_turn',state.turn)end
        return
    end
    local context = assert(state.pendingPlay, "missing pending play")
    assert(not state.cardInUse or state.player.hp <= 0, "undisposed queued card")
    state.resolvingCard = context.previous
    state.pendingPlay = nil
    if state.endTurnAfterCard then
        require('abyss_watcher_final_cards').cancelAutomatic(M,state)
        if state.drainingCardActions then return end
        drainNative(state)
        M.finishEarlyTurn(state)
        return
    end
    drainNative(state)
    finish(state)
end
function M.chooseDiscard(state,uids,token)
    local discard=require('abyss_discard')
    if not state.actionQueue then
        local restore=require('abyss_snapshot').capture(state)
        local called,ok,reason=pcall(function()local accepted,why=discard.choose(state,uids,token,M);if accepted then drainNative(state);finish(state)end;return accepted,why end)
        if not called then restore();error(ok,0)end;return ok,reason
    end
    if not (state.pendingPlay or state.startTurnPending) or not state.pendingDiscard then return false,'no_pending_discard' end
    local restore=require('abyss_snapshot').capture(state)
    local called,ok,reason=pcall(function()
        local accepted,why=discard.choose(state,uids,token,M)
        if not accepted then return false,why end
        local result=require('abyss_action_queue').resume(state,queuedHandlers)
        if result~='pause' then
            if state.startTurnPending then state.startTurnPending=nil;drainNative(state);finish(state)else finishQueuedPlay(state)end
        end
        return true
    end)
    if not called then restore();error(ok,0) end
    return ok,reason
end
function M.choosePile(state,uids,token,generation)
    if not state.pendingPlay or not state.pendingPileChoice or not state.actionQueue then return false,'no_pending_pile_choice' end
    if generation~=(state.combatGeneration or 0) then return false,'stale_pile_choice_generation' end
    local restore=require('abyss_snapshot').capture(state)
    local called,ok,reason=pcall(function()
        local accepted,why=require('abyss_pile_choice').choose(state,uids,token,generation,M)
        if not accepted then return false,why end
        local result=require('abyss_action_queue').resume(state,queuedHandlers)
        if result~='pause' then finishQueuedPlay(state) end
        return true
    end)
    if not called then restore();error(ok,0) end
    return ok,reason
end
local function queueUseCopies(state,instance,card,targetIndex,energyOnUse,purge)
    local final=require('abyss_defect_final_cards');final.onUse(state,card)
    if purge then return end
    for _,id in ipairs(Actors.powerSequence(state.player,{'double_tap','duplication','echo_form','amplify'}))do
        local trigger
        if id=='double_tap'or id=='duplication'then
            trigger=id=='duplication'or card.type=='attack'
            if trigger then state.player.statuses[id]=state.player.statuses[id]-1 end
        else trigger=final.copyTrigger(state,id,card)end
        if trigger then
            M.queueCard(state,CardActions.sameInstance(M,state,instance),{targetIndex=targetIndex,
                energyOnUse=energyOnUse,purge=true,exhaustCards=false})
        end
    end
end
local function beginQueuedPlay(state, uid, targetIndex, instance, position, card, automatic)
    local previous = state.resolvingCard
    state.resolvingCard = true
    local reactions = EnemyAI.cardReactions(state, card)
    local enemyUse={}
    if not card.dontTriggerOnUseCard then
        local sharp={};for _,reaction in ipairs(reactions) do sharp[reaction.source]=reaction.amount end
        for _,enemy in ipairs(state.enemies) do
            local filter={choked=true,curiosity=true,sharp_hide=(enemy.statuses.sharp_hide or 0)>0}
            for _,entry in ipairs(require('abyss_power_schedule').list(enemy,filter)) do
                local curiosity=Awakened.useEffect(enemy,card,entry)
                if curiosity then enemyUse[#enemyUse+1]={kind='effect',effect=curiosity}
                elseif entry.id=='choked' and Actors.isActive(enemy) then
                    enemyUse[#enemyUse+1]={kind='effect',effect={op='loseHp',targetId=enemy.id,value=entry.amount,sourceNull=true}}
                elseif entry.id=='sharp_hide' and sharp[enemy.id] then
                    enemyUse[#enemyUse+1]={kind='effect',effect={op='capturedSharpHide',sourceId=enemy.id,value=sharp[enemy.id]}}
                end
            end
        end
    end
    state.cardsPlayedThisTurn=state.cardsPlayedThisTurn or {}
    state.cardsPlayedThisCombat=state.cardsPlayedThisCombat or {}
    state.cardsPlayedThisTurn[#state.cardsPlayedThisTurn+1]={type=card.type,cardId=card.id}
    state.cardsPlayedThisCombat[#state.cardsPlayedThisCombat+1]={type=card.type,cardId=card.id}
    -- X actions read the card's explicit free flag, not Swivel's FreeAttackPower.
    local freeToPlayOnce=automatic~=nil or instance.freeToPlayOnce==true
    local energyOnUse=automatic and automatic.energyOnUse or state.energy
    if energyOnUse==nil then energyOnUse=state.energy end
    require('abyss_silent_final_cards').onUse(M,state,card,instance,targetIndex,energyOnUse,automatic and automatic.purge)
    require('abyss_watcher_final_cards').used(state,card,automatic and automatic.purge)
    if not automatic then state.energy=state.energy-paidCost(state,card) end
    if position then table.remove(state.hand, position) end
    if not (automatic and automatic.purge)then instance.freeToPlayOnce=nil end
    state.cardInUse = instance
    local target = state.enemies[targetIndex]
    state.pendingPlay = {uid=uid, cardType=card.type, exhaust=require("abyss_exhaust").shouldExhaust(state,card),
        targetId=target and target.id, reactions=reactions, previous=previous, energyOnUse=energyOnUse,
        purge=automatic and automatic.purge or nil,freeToPlayOnce=freeToPlayOnce}
    state.pendingPlay.dontTriggerOnUseCard=card.dontTriggerOnUseCard
    if automatic and automatic.exhaustCards then state.pendingPlay.exhaust=true end
    event(state, "play", {uid=uid,cardId=instance.cardId,target=targetIndex})
    RelicHooks.onUseCard(state,card)
    local actions = {}
    local triggerPlan=require('abyss_card_triggers').prepareUse(state,card)
    local colorlessTail=require('abyss_colorless_cards').onUse(state,card)
    local triggerActive=#triggerPlan.top+#triggerPlan.beforeUse+#triggerPlan.afterUse>0
        or (state.player.statuses.envenom or 0)>0
    local advanced=Effects.requiresQueue(card.effects) or card.experimental==true or require('abyss_hp_loss').requiresQueue(state) or triggerActive
    local effects=require('abyss_defect_final_cards').prepareEffects(state,copy(card.effects))
    for _,effect in ipairs(effects)do
        if (effect.op=='applyStatus' or effect.op=='applyStatusAll') and effect.status=='poison'
            or effect.op=='cripplingPoison' then effect.poisonBonus=Actors.poisonBonus(state,target,state.player) end
        if effect.op=='playTop'then
            local pool={};for i,enemy in ipairs(state.enemies)do if Actors.isActive(enemy)then pool[#pool+1]=i end end
            if #pool>0 then effect.targetIndex=pool[M.cardRandom(state,#pool)]end
        end
    end
    if not advanced then
        actions[1]={kind="effect",effect={op="effectBatch",effects=effects}}
    else
    for _, effect in ipairs(effects) do
      for _,prepared in ipairs(require('abyss_watcher_attack_cards').prepareEffect(state,effect)) do
        local queued=copy(prepared)
        queued=require('abyss_silent_final_cards').prepare(M,state,queued)
        if queued.op=='damage' or queued.op=='heelHook' or queued.op=='watcherFinalLessonLearned' then
            queued.normalAmount=M.attackAmount(state,state.player,target,queued.value)
        elseif queued.op=='damageAll' then
            queued.normalAmounts={}
            for _,enemy in ipairs(state.enemies) do queued.normalAmounts[enemy.id]=M.attackAmount(state,state.player,enemy,queued.value) end
        elseif (queued.op=='block' and not queued.fixed) or queued.op=='nextBlock' then
            if queued.op=='block' then queued.blockCallbackAmount=Actors.blockFloat(state,state.player,queued.value)end
            queued.value=M.blockAmount(state,state.player,queued.value);queued.fixed=true
            if queued.op=='nextBlock' then queued.fixed=nil end
        elseif queued.op=='conditional' then
            for _,nested in ipairs(queued['then']) do
                if nested.op=='damage' then nested.normalAmount=M.attackAmount(state,state.player,target,nested.value) end
            end
        end
        local utility=require('abyss_defect_utility_cards')
        if utility.prepareEffect then queued=utility.prepareEffect(state,queued,target) end
        queued=require('abyss_flow_actions').prepare(state,queued,target,{instance=instance,uid=uid})
        if queued.op=="gainExhaustPower" and queued.status=="corruption" then require("abyss_corruption").prepare(state) end
        if queued.op=="gainMantra" then queued=require("abyss_mantra").prepareGain(state,queued.value) end
        if queued.op=="whirlwind" or queued.op=="reaperDamage" then
            queued.matrix={}
            for _,enemy in ipairs(state.enemies) do
                queued.matrix[#queued.matrix+1]={targetId=enemy.id,amount=M.attackAmount(state,state.player,enemy,queued.value)}
            end
        end
        if queued.op=='damage' and (queued.times or 1)>1 then
            local count=queued.times;queued.times=nil
            for _=1,count do actions[#actions+1]={kind='effect',effect=copy(queued)} end
        else actions[#actions+1]={kind="effect",effect=queued} end
      end
    end
    end
    for _,action in ipairs(triggerPlan.beforeUse) do actions[#actions+1]=action end
    local vigor=require('abyss_watcher_flow_cards').planUseCard(state,card)
    for _,effect in ipairs(vigor.bottom) do actions[#actions+1]={kind='effect',effect=effect} end
    for _,action in ipairs(enemyUse) do actions[#actions+1]=action end
    if #enemyUse==0 and not card.dontTriggerOnUseCard then
        actions[#actions+1]={kind='effect',effect={op='onUseReactions'}}
    end
    actions[#actions + 1] = {kind="useCard"}
    if colorlessTail then actions[#actions+1]={kind='effect',effect=colorlessTail} end
    for _,action in ipairs(triggerPlan.afterUse) do actions[#actions+1]=action end
    queueUseCopies(state,instance,card,targetIndex,energyOnUse,automatic and automatic.purge)
    local queue = require("abyss_action_queue")
    queue.start(state, actions)
    for _,action in ipairs(triggerPlan.top) do queue.pushTop(state,action) end
    local result = queue.run(state, queuedHandlers)
    if result ~= "pause" then finishQueuedPlay(state) end
    return true
end

local function queueNativePlay(state, uid, targetIndex, instance, card, free, forceExhaust, purge, top, energyOnUse)
    state.resolvingCard = true
    state.cardInUse=instance
    state.cardsPlayedThisTurn=state.cardsPlayedThisTurn or {};state.cardsPlayedThisCombat=state.cardsPlayedThisCombat or {}
    state.cardsPlayedThisTurn[#state.cardsPlayedThisTurn+1]={type=card.type,cardId=card.id}
    state.cardsPlayedThisCombat[#state.cardsPlayedThisCombat+1]={type=card.type,cardId=card.id}
    local reactions = EnemyAI.cardReactions(state, card)
    local x=energyOnUse or state.energy
    require('abyss_silent_final_cards').onUse(M,state,card,instance,targetIndex,x,purge)
    require('abyss_watcher_final_cards').used(state,card,purge)
    local colorlessTail=require('abyss_colorless_cards').onUse(state,card)
    -- Native already dispatches Rage's Block below. Only that hook is skipped;
    -- foreign After Image/Thousand Cuts/Heat Sinks/Storm keep their semantics.
    local triggerPlan=require('abyss_card_triggers').prepareUse(state,card,true)
    if not free and not instance.freeToPlayOnce then state.energy=state.energy-(card.costMode=="all_energy" and state.energy or card.cost) end
    if not purge then instance.freeToPlayOnce=nil end
    event(state, "play", { uid = uid, cardId = instance.cardId, target = targetIndex })
    RelicHooks.onUseCard(state,card)
    local items={}
    for i,effect in ipairs(card.effects) do
        if not (effect.targetGroup and card.effects[i-1] and card.effects[i-1].targetGroup) then
            local e=copy(effect)
            if (e.op=='applyStatus' or e.op=='applyStatusAll') and e.status=='poison'
                or e.op=='cripplingPoison' then e.poisonBonus=Actors.poisonBonus(state,state.enemies[targetIndex],state.player) end
            e=require('abyss_silent_final_cards').prepare(M,state,e)
            if e.op=='colorless' and e.kind=='transmutation' then e.energyOnUse=x end
            if e.op=='silentFinal' and e.kind=='doppelganger'then e.energyOnUse=x end
            if e.op=='colorless' and (e.kind=='greed' or e.kind=='ritual') then
                e.resolved={};for _,enemy in ipairs(state.enemies)do e.resolved[enemy.id]=Actors.attackAmount(state,state.player,enemy,e.damage or e.value)end
            end
            if e.op=='originalV4' then e.paidEnergy=free and 0 or (card.costMode=='all_energy' and x or card.cost) end
            if e.op=="playTop" then
                local pool={}; for j,enemy in ipairs(state.enemies) do if Actors.isActive(enemy) then pool[#pool+1]=j end end
                if #pool>0 then e.targetIndex=pool[M.cardRandom(state,#pool)] end
            end
            if e.op=="damage" or e.op=="damageAll" or e.op=="fiendFire" or e.op=="feed"
                or e.op=="reaper" or e.op=="damageRandom" or e.op=="damageEqualToBlock" then
                e.resolved={}
                for _,enemy in ipairs(state.enemies) do
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
    if coreOnly and not require('abyss_hp_loss').requiresQueue(state) then
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
    for _,a in ipairs(triggerPlan.beforeUse)do items[#items+1]={op='silentFinal',kind='trigger',action=a.effect}end
    if not card.dontTriggerOnUseCard then for _,enemy in ipairs(state.enemies)do
        for _,entry in ipairs(require('abyss_power_schedule').list(enemy,{choked=true,curiosity=true}))do
            local curiosity=Awakened.useEffect(enemy,card,entry)
            if curiosity then items[#items+1]=curiosity
            elseif entry.id=='choked'and Actors.isActive(enemy)then
                items[#items+1]={op='silentFinal',kind='choke',targetId=enemy.id,value=entry.amount}
            end
        end
    end end
    -- Each captured Sharp Hide is a separate retained DAMAGE action. Its TOP
    -- HP-loss callbacks must run before the following UseCardAction/disposal.
    for _,reaction in ipairs(reactions)do
        items[#items+1]={op='capturedSharpHide',sourceId=reaction.source,value=reaction.amount}
    end
    -- Leave non-array reactions (Hex, etc.) on their original disposal path.
    for i=#reactions,1,-1 do reactions[i]=nil end
    local exhaust=card.exhaust or forceExhaust or card.type=="skill" and (state.player.statuses.corruption or 0)>0
    items[#items+1]={op="dispose",exhaust=exhaust,purge=purge,cardType=card.type,reactions=reactions,
        dontTriggerOnUseCard=card.dontTriggerOnUseCard}
    if colorlessTail then items[#items+1]=colorlessTail end
    for _,a in ipairs(triggerPlan.afterUse)do items[#items+1]={op='silentFinal',kind='trigger',action=a.effect}end
    queueUseCopies(state,instance,card,targetIndex,x,purge)
    if top then
        for i=#items,1,-1 do CardActions.enqueue(state,items[i],state.player,state.enemies[targetIndex],instance,true) end
    else for _,e in ipairs(items) do CardActions.enqueue(state,e,state.player,state.enemies[targetIndex],instance) end end
    for _,a in ipairs(triggerPlan.top)do CardActions.enqueue(state,{op='silentFinal',kind='trigger',action=a.effect},state.player,nil,instance,true)end
    -- AbstractPlayer.useCard invokes these hand callbacks after use and the
    -- UseCardAction constructor (including Enrage's TOP Strength). Each Pain
    -- then adds LoseHP to TOP, above both those reactions and card effects.
    for _,held in ipairs(state.hand) do
        if held.cardId=='pain' and held~=instance then
            CardActions.enqueue(state,{op='loseHp',value=M.cardDefinition(state,held).onOtherCardHpLoss},state.player,nil,nil,true)
        end
    end
end

function M.capturedSharpHide(state,effect)
    EnemyAI.afterCard(state,{{source=effect.sourceId,amount=effect.value}})
end

function M.staticRetaliation(state,effect)
    for _,enemy in ipairs(state.enemies)do if enemy.id==effect.targetId then
        M.retaliate(state,state.player,enemy,effect.value);return true
    end end
    return true -- The captured target has already left the monster group.
end

function M.disposeCard(state,item)
    local e,instance=item.effect,item.instance
    EnemyAI.afterCard(state,e.reactions)
    -- Sharp Hide's onUseCard queues damage before UseCardAction. A lethal
    -- reaction opens the death screen before the physical card can leave limbo.
    if state.player.hp<=0 then return end
    RelicHooks.afterCard(state)
    local rebound=require('abyss_defect_final_cards').afterUse(state,{type=e.cardType},e.purge,e.exhaust)
    require('abyss_giant_head').afterUse(state,e,CardActions.enqueueReaction,instance)
    if state.cardInUse==instance then state.cardInUse=nil end
    -- A used Power leaves the combat piles; it is not an exhausted card.
    -- The Power destination takes precedence over exhaust-on-use, while an
    -- unplayed Power still follows the ordinary endTurn hand lifecycle.
    if e.cardType ~= "power" and not e.purge then
        if e.exhaust then CardActions.exhaust(M,state,instance)
        elseif rebound then state.draw[#state.draw+1]=instance
        else state.discard[#state.discard+1]=instance end
        if (state.player.statuses.corruption or 0)~=0 then require('abyss_corruption').onDrawOrDiscard(state) end
        if (state.player.statuses.accuracy or 0)>0 then require('abyss_shivs').onDrawOrDiscard(state) end
    end
    if e.cardType~='power' and not e.purge and instance.dontTriggerOnUseCard~=nil then
        instance.dontTriggerOnUseCard=false
    end
end

local function resolveNativePlay(state,uid,targetIndex,instance,position,card)
    table.remove(state.hand,position)
    queueNativePlay(state,uid,targetIndex,instance,card)
    CardActions.drain(M,state)
    if not state.pendingChoice then Actors.flushCurlUp(state) end
    finish(state)
    return true
end

function M.chooseCard(state,token,uid)
    local restore=require("abyss_snapshot").capture(state)
    local called,ok,reason=pcall(function()
        if state.actionQueue and state.pendingChoice and state.pendingChoice.op=='discover'then
            local accepted,why=require('abyss_potion_discovery').choose(M,state,token,uid,CardActions)
            if not accepted then return false,why end
            local result=require('abyss_action_queue').resume(state,queuedHandlers)
            if result~='pause'then finishQueuedPlay(state)end
            return true
        end
        if state.pendingChoice and state.pendingChoice.op=='watcher_final' then
            local accepted,why=require('abyss_watcher_final_cards').choose(M,state,token,uid)
            if not accepted then return false,why end
            local result=require('abyss_action_queue').resume(state,queuedHandlers)
            if result~='pause' then finishQueuedPlay(state)end
            return true
        end
        return CardActions.choose(M,state,token,uid)
    end)
    if not called then restore(); error(ok,0) end
    if ok and not state.pendingChoice then Actors.flushCurlUp(state); finish(state) end
    return ok,reason
end

function M.resolveQueuedCard(state,e)
    if e.randomTarget then
        local live={};for i,enemy in ipairs(state.enemies)do if Actors.isActive(enemy)then live[#live+1]=i end end
        e.targetIndex=#live>0 and live[M.cardRandom(state,#live)]or nil
    end
    local target=state.enemies[e.targetIndex]
    local c=e.card
    local d=M.cardDefinition(state,c)
    local forceExhaust=e.exhaustCards
    if forceExhaust==nil then forceExhaust=e.autoplay end
    local function rejected()
        if e.purge then return end
        if d.exhaust or forceExhaust or d.type=='skill' and (state.player.statuses.corruption or 0)>0 then
            CardActions.exhaust(M,state,c)
        elseif d.type~='power' then state.discard[#state.discard+1]=c end
    end
    -- A queued targeted card whose original target died is removed from limbo;
    -- it does not retarget, execute, or emit a real exhaust event.
    if d.target=="ENEMY" and (not target or not Actors.isActive(target)) then rejected();return end
    local invalid=d.cost==-2 or Curses.limitsPlay(state) or d.type=="attack" and (state.player.statuses.entangled or 0)>0
    if d.condition=="only_attacks_in_hand" then
        for _,held in ipairs(state.hand) do if state.catalog.cards[held.cardId].type~="attack" then invalid=true end end
    end
    if d.originalV4 then
        local accepted=require('abyss_original_v4').preflight(state,d,e.targetIndex)
        if not accepted then invalid=true end
    end
    if invalid then
        rejected()
        return
    end
    if not nativeDefinition(state,d) or Effects.requiresQueue(d.effects) then
        beginQueuedPlay(state,c.uid,e.targetIndex,c,nil,d,{purge=e.purge,exhaustCards=forceExhaust,
            energyOnUse=e.energyOnUse})
    else queueNativePlay(state,c.uid,e.targetIndex,c,d,true,forceExhaust,e.purge,true,e.energyOnUse) end
end

-- Callers own physical/stat-equivalent/same-instance identity construction.
-- The descriptor contains only data; target and energy may be captured at use.
function M.queueCard(state,instance,options)
    options=options or {}
    assert(type(instance)=='table'and state.catalog.cards[instance.cardId],'unknown queued card')
    local entry={card=instance,autoplay=true,targetIndex=options.targetIndex,randomTarget=options.randomTarget,
        exhaustCards=options.exhaustCards,purge=options.purge,energyOnUse=options.energyOnUse}
    state.queuedCards=state.queuedCards or {}
    if options.append then state.queuedCards[#state.queuedCards+1]=entry else table.insert(state.queuedCards,1,entry)end
    return entry
end

function M.autoplayTop(state,targetIndex,exhaustCards,append)
    if #state.draw==0 then
        if #state.discard==0 then return end
        state.draw,state.discard=state.discard,{}; shuffle(state,state.draw); event(state,"reshuffle")
    end
    local c=table.remove(state.draw)
    -- Like the original cardQueue, activation waits until all actions from the
    -- current card (including its disposal and exhaust callbacks) have drained.
    state.queuedCards=state.queuedCards or {}
    local queued={card=c,autoplay=true,targetIndex=targetIndex,exhaustCards=exhaustCards,energyOnUse=state.energy}
    if append then state.queuedCards[#state.queuedCards+1]=queued else table.insert(state.queuedCards,1,queued) end
end

function M.play(state, uid, targetIndex, commandId, rollbackOwner)
    if state.originalV4 and commandId~=nil then
        if type(commandId)~='string' or commandId=='' then return false,'invalid_command_id' end
        local replay,why=require('abyss_original_v4').replay(state,commandId,uid,targetIndex)
        if replay~=nil then return replay,why end
    end
    local ok, reason = M.canPlay(state, uid, targetIndex)
    if not ok then return false, reason end -- validate before changing any state/RNG
    local instance, position = findInstance(state, uid)
    local card = M.cardDefinition(state, instance)
    -- Run.play already captured this exact battle inside the complete Run.
    -- Bare Combat.play and invalid/expired/cross-battle tokens retain their
    -- original independent rollback; no mutable graph edge is omitted.
    local inherited=rollbackOwner and require('abyss_snapshot').ownedRestore(rollbackOwner,state)
    local nativeOnly=false
    for _,effect in ipairs(card.effects) do
        if CardActions.supports(effect.op) and not require('abyss_build_actions').ops[effect.op]
            and not require('abyss_flow_actions').ops[effect.op] or effect.times=='X' then nativeOnly=true end
    end
    if nativeDefinition(state,card) and (not state.experimentalMechanics or nativeOnly or card.silentFinalCard or card.runNativeABI) then
        local restore=inherited or require('abyss_snapshot').capture(state)
        local called,result=pcall(resolveNativePlay,state,uid,targetIndex,instance,position,card)
        if not called then restore();error(result,0) end
        if result and state.originalV4 then require('abyss_original_v4').record(state,commandId,uid,targetIndex) end
        return result
    end
    local hooks=(state.player.statuses.feel_no_pain or 0)>0 or (state.player.statuses.dark_embrace or 0)>0
    local corrupted=card.type=="skill" and (state.player.statuses.corruption or 0)~=0
    local trigger=false
    for _,id in ipairs({'after_image','thousand_cuts','envenom','rage','heat_sinks','storm'}) do
        if (state.player.statuses[id] or 0)>0 then trigger=true end
    end
    for _,enemy in ipairs(state.enemies) do if enemy.statuses.choked~=nil or enemy.statuses.slow~=nil then trigger=true end end
    -- Void's draw callback queues LoseEnergy behind the using card. Keep a
    -- native Draw action's tail alive until after on-use retaliation/disposal.
    local drawHooks=false
    local autoplayHook=false
    for _,effect in ipairs(card.effects)do if effect.op=='playTop'then autoplayHook=true end end
    if state.catalog.cards.void then
        for _,effect in ipairs(card.effects) do if effect.op=='draw' or effect.op=='requestDiscard' then drawHooks=true end end
    end
    if (state.player.statuses.evolve or 0)>0 or (state.player.statuses.fire_breathing or 0)>0 then
        for _,effect in ipairs(card.effects) do if effect.op=='draw' or effect.op=='requestDiscard' then drawHooks=true end end
    end
    local queued = Effects.requiresQueue(card.effects) or card.experimental==true or require('abyss_hp_loss').requiresQueue(state) or card.type=='skill'and (state.player.statuses.burst or 0)>0
        or require('abyss_defect_final_cards').needsQueue(state)
        or state.player.stance~=nil
        or drawHooks or autoplayHook or trigger or corrupted or hooks and require("abyss_exhaust").shouldExhaust(state,card)
    local restore = inherited or (queued and require("abyss_snapshot").capture(state) or savePlayState(state,instance))
    local resolver = queued and beginQueuedPlay or resolvePlay
    local called, result = pcall(resolver, state, uid, targetIndex, instance, position, card)
    if not called then
        restore()
        error(result, 0) -- preserve the rule error, including non-string errors
    end
    return result
end

function M.chooseScry(state, uids, token)
    if not (state.pendingPlay or state.startTurnPending) or not state.pendingScry or not state.actionQueue then
        return false, "no_pending_scry"
    end
    local restore = require("abyss_snapshot").capture(state)
    local called, ok, reason = pcall(function()
        local selected, refusal = require("abyss_scry").choose(state, uids, token)
        if not selected then return false, refusal end
        local result = require("abyss_action_queue").resume(state, queuedHandlers)
        if result ~= "pause" then finishQueuedPlay(state) end
        return true
    end)
    if not called then restore(); error(ok, 0) end
    return ok, reason
end

function M.chooseHand(state,uids,token)
    if not state.pendingPlay or not state.pendingHandChoice or not state.actionQueue then return false,"no_pending_hand_choice" end
    local restore=require("abyss_snapshot").capture(state)
    local called,ok,reason=pcall(function()
        local selected,refusal=require("abyss_hand_choice").choose(state,uids,token)
        if not selected then return false,refusal end
        local result=require("abyss_action_queue").resume(state,queuedHandlers)
        if result~="pause" then finishQueuedPlay(state) end
        return true
    end)
    if not called then restore();error(ok,0) end
    return ok,reason
end

function M.intent(state, enemyIndex)
    local enemy = state.enemies[enemyIndex]
    if not Actors.isPresent(enemy) then return nil end
    return copy(enemy.intents[enemy.intentIndex]) -- UI cannot mutate the queued intent
end

local function startNativePlayerTurn(state, beforeOpeningDraw)
    if finish(state) then return end
    state.turn = state.turn + 1
    state.phase = "player"
    state.cardsPlayedThisTurn={}
    if state.originalV4 then Actors.resetBlock(state,state.player) else Actors.startTurn(state,state.player) end
    if finish(state) then return end
    state.player.noDraw = false
    state.energy = 0
    local originalExtra=0
    if state.originalV4 then
        originalExtra=require('abyss_original_v4').startTurn(state)
        Actors.startTurnEffects(state,state.player)
        if finish(state)then return end
    end
    -- Only Combat.new supplies this one-shot callback. Do not store it in state:
    -- snapshots and subsequent turns contain data only.
    if beforeOpeningDraw then
        local ok, reason = beforeOpeningDraw(state)
        if not ok then return false, reason end
        if state.energy + 0.0 + state.rules.player.energyPerTurn > 2147483647 then return false, "effect_overflow" end
    end
    RelicHooks.atTurnStart(state)
    if state.energy+0.0+state.rules.player.energyPerTurn>2147483647 then return false,'effect_overflow' end
    state.energy = state.energy + state.rules.player.energyPerTurn
    for _,id in ipairs({"rage","flame_barrier"}) do
        require('abyss_power_schedule').remove(state,state.player,id)
        state.player.statuses[id]=nil
    end
    state.player.statuses.double_tap=nil -- Double Tap has no scheduled Power membership.
    local p=state.player
    require('abyss_colorless_cards').startTurn(state)
    require('abyss_silent_final_cards').startTurn(state,false)
    for _,id in ipairs(Actors.powerSequence(p,{'demon_form','berserk'})) do
        CardActions.enqueue(state,id=='demon_form' and {op="gainStatus",status="strength",value=p.statuses[id]}
            or {op="energy",value=p.statuses[id]})
    end
    -- The source queues ordinary draw and post-draw Powers before executing
    -- DrawCardAction. Draw hooks append behind those already queued actions.
    CardActions.enqueue(state,{op='draw',value=state.rules.player.drawPerTurn+originalExtra})
    if state.turn==1 and state.openingInnateExtra then
        CardActions.enqueue(state,{op='draw',value=state.openingInnateExtra});state.openingInnateExtra=nil
    end
    RelicHooks.enqueuePostDraw(state)
    require('abyss_silent_final_cards').startTurn(state,true)
    if (p.statuses.brutality or 0)>0 then
        CardActions.enqueue(state,{op="draw",value=p.statuses.brutality})
        CardActions.enqueue(state,{op="loseHp",value=p.statuses.brutality})
    end
    CardActions.drain(M,state)
    if finish(state) then return end
    event(state, "player_turn", state.turn)
    return true
end


function M.startPlayerTurn(state, beforeOpeningDraw)
    if not state.experimentalMechanics then return startNativePlayerTurn(state,beforeOpeningDraw) end
    if finish(state) then return end
    state.turn=state.turn+1;state.phase='player';state.cardsPlayedThisTurn={}
    require('abyss_silent_discard_cards').beginTurn(state)
    Actors.startTurn(state,state.player)
    if finish(state) then return end
    state.player.noDraw=false;state.energy=0
    if beforeOpeningDraw then
        local ok,why=beforeOpeningDraw(state)
        if not ok then return false,why end
    end
    local turns=require('abyss_turn_powers')
    require('abyss_colorless_cards').startTurn(state,true)
    require('abyss_defect_final_cards').startTurn(state)
    local actions={}
    if state.player.stance=='Divinity' then actions[1]={kind='effect',effect={op='changeStance',stance='Neutral'}} end
    for _,action in ipairs(RelicHooks.prepareTurnStart(state)) do actions[#actions+1]=action end
    for _,action in ipairs(turns.prepareStart(state)) do actions[#actions+1]=action end
    if state.energy+0.0+state.rules.player.energyPerTurn>2147483647 then return false,'effect_overflow' end
    state.energy=state.energy+state.rules.player.energyPerTurn
    RelicHooks.atTurnStart(state)
    for _,action in ipairs(turns.onEnergyRecharge(state)) do actions[#actions+1]=action end
    actions[#actions+1]={kind='effect',effect={op='draw',value=require('abyss_defect_final_cards').drawCount(state,state.rules.player.drawPerTurn)}}
    for _,action in ipairs(turns.preparePostDraw(state)) do actions[#actions+1]=action end
    if (state.player.statuses.foresight or 0)>0 and #state.draw==0 then M.shuffleDiscardIntoDraw(state)end
    local queue=require('abyss_action_queue');queue.start(state,actions)
    state.startTurnPending=true
    if queue.run(state,queuedHandlers)=='pause' then return true end
    state.startTurnPending=nil
    drainNative(state)
    if finish(state) then return true end
    event(state,'player_turn',state.turn)
    return true
end

-- AbstractMonster.changeState defaults to no-op. Only this existing enemy
-- handles ARMOR_BREAK; it is independent of the current actor's life state.
function M.changeMonsterState(state,enemy,name)
    if name=='ARMOR_BREAK' and enemy.ai and enemy.ai.policy=='parasite'then
        for i,intent in ipairs(enemy.intents)do if intent.id=='stunned'then enemy.intentIndex=i;break end end
        event(state,'enemy_interrupt',{enemy=enemy.id,id='stunned'})
    end
end
function M.enemyActionRetained(effect)
    return effect.stage=='payload' and Effects.allowedAfterVictory(effect.payload)
end
function M.resolveEnemyAction(state,effect,enemy)
    local stage=effect.stage
    if stage=='awakenedRebirth'then
        return Awakened.rebirth(state,enemy,CardActions.enqueueReaction)
    elseif stage=='payload'then
        return resolveEffects(state,{effect.payload},enemy,state.player,nil,true,true)
    elseif stage=='effectsComplete'then
        -- Keep existing Guardian/AI completion at the original whole-intent
        -- boundary, not between the newly separated DamageActions.
        EnemyAI.afterEffects(state,enemy);EnemyAI.flush(state,enemy)
    elseif stage=='split'then splitEnemy(state,enemy)
    elseif stage=='escape'then assert(M.escapeEnemy(state,enemy),'invalid escape')
    elseif stage=='v4Complete'then require('abyss_original_v4').endEnemyAction(M,state)
    elseif stage=='duringTurn'then
        require('abyss_act3_powers').duringTurn(M,state,enemy)
    elseif stage=='ownerEnd'then
        if Actors.isActive(enemy)then
            Actors.endTurn(state,enemy)
            if effect.advanced and not Awakened.owns(enemy)then
                local deferred=enemy.ai and enemy.ai.kind=='act3'and enemy.ai.policy=='transient'
                local powers=deferred and {} or require('abyss_silent_tactics_cards').planHook(state,'shackled','owner_turn_end',enemy)
                for i=#powers,1,-1 do
                    CardActions.enqueue(state,{op='enemyAction',stage='endPower',payload=powers[i]},enemy,nil,nil,true)
                end
            end
        end
    elseif stage=='endPower'then
        local power=effect.payload
        if power.op=='applyStatus'then
            Actors.applyPower(state,enemy,power.status,power.value,state.player)
        else
            assert(power.op=='removeStatus','unknown enemy owner-end Power')
            require('abyss_power_schedule').remove(state,enemy,power.status)
            enemy.statuses[power.status]=nil
        end
    elseif stage=='roll'then
        local captured
        for _,intent in ipairs(enemy.intents)do if intent.id==effect.intentId then captured=intent;break end end
        EnemyAI.afterAction(state,enemy,aiRandom,assert(captured,'missing queued enemy intent'))
        require('abyss_act3_powers').afterTurn(M,state,enemy)
    else error('unknown queued enemy action')end
end
local function queueEnemyTurn(state,enemy,intent,advanced)
    local function append(stage,payload)
        CardActions.enqueue(state,{op='enemyAction',stage=stage,payload=payload,intentId=intent.id,advanced=advanced},enemy)
    end
    if Awakened.owns(enemy)and intent.id=='rebirth'then append('awakenedRebirth')
    elseif intent.kind=='split'then append('split')
    elseif intent.kind=='escape'then append('escape')
    else
        for _,effect in ipairs(intent.effects)do
            local count=(effect.op=='damage' or effect.op=='damageAll') and (effect.times or 1) or 1
            for _=1,count do
                local payload=copy(effect)
                if effect.op=='damage' or effect.op=='damageAll'then payload.times=nil end
                append('payload',payload)
            end
        end
        append('effectsComplete')
    end
    if state.originalV4 then append('v4Complete')end
    append('duringTurn');append('ownerEnd');append('roll')
    -- All original actions exist before any BOTTOM damage callback can append.
    -- This deliberately does not activate the advanced actionQueue.
    CardActions.drain(M,state)
    if state.originalV4 and state.originalV4.enemyAction then
        assert(M.outcome(state),'unfinished V4 enemy action')
        require('abyss_original_v4').endEnemyAction(M,state)
    end
end
local function platedGroupEnd(state)
    for _,enemy in ipairs(state.enemies)do
        PlatedArmor.preEndCards(state,enemy,CardActions.enqueueReaction)
        Awakened.ownerEnd(Actors,state,enemy,CardActions.enqueueReaction)
    end
    CardActions.drain(M,state)
end

local function advancedTurnCleanup(state)
    if state.catalog.cards.evolve or state.catalog.cards.claw or state.catalog.cards.blur or state.catalog.cards.wallop then return true end
    local powers=state.player and state.player.statuses or {}
    if (powers.corruption or 0)~=0 or (powers.feel_no_pain or 0)>0 or (powers.dark_embrace or 0)>0 then return true end
    for _,id in ipairs({'combust','brutality','berserk','rage','energized','energized_blue','next_turn_block'}) do
        if powers[id]~=nil then return true end
    end
    for _,instance in ipairs(state.hand or {}) do
        local card=state.catalog.cards[instance.cardId]
        if card and (card.id=='burn' or card.selfRetain or card.ethereal or instance.upgraded and card.upgrade
            and (card.upgrade.selfRetain or card.upgrade.ethereal)) then return true end
    end
    return false
end
local function ordinaryOwnerEnd(state)
    local actions=require('abyss_end_turn_powers').prepare(state,M,require('abyss_act3_powers'))
    if #actions==0 then return true end
    local queue=require('abyss_action_queue');queue.start(state,actions)
    local result=queue.run(state,queuedHandlers)
    if result~='pause'then drainNative(state)end
    return result
end
local function preCardPowers(state)
    local powers=require('abyss_end_turn_powers')
    local actions=powers.preparePreCards(state)
    if #actions>0 then
        local queue=require('abyss_action_queue');queue.start(state,actions)
        local handlers={allow=queuedHandlers.allow,useCard=queuedHandlers.useCard}
        handlers.effect=function(s,action,q)
            local result=queuedHandlers.effect(s,action,q)
            powers.transferNative(s,q)
            return result
        end
        assert(queue.run(state,handlers)==true,'unexpected pre-card selection')
    end
end
local function discardOwnerEnd(state)
    local retained,remaining={},{}
    for _,instance in ipairs(state.hand)do
        local card=M.cardDefinition(state,instance)
        local selected=instance.finalRetain or instance.silentRetainTurn==state.turn
        instance.finalRetain=nil
        if (card.selfRetain or selected or instance.retain)and not card.ethereal then retained[#retained+1]=instance
        else remaining[#remaining+1]=instance end
    end
    state.hand=remaining;state.retainedCards=retained
    require('abyss_end_turn_powers').prepareExhaust(state)
    local actions={}
    for _,instance in ipairs(state.hand)do
        if M.cardDefinition(state,instance).ethereal then actions[#actions+1]={kind='effect',effect={op='exhaustHand',uid=instance.uid}}end
    end
    actions[#actions+1]={kind='effect',effect={op='discardEndHand'}}
    actions[#actions+1]={kind='effect',effect={op='restoreRetained'}}
    local queue=require('abyss_action_queue');queue.start(state,actions)
    assert(queue.run(state,queuedHandlers)==true,'unexpected end-turn selection')
    drainNative(state)
end
local function endExperimentalTurn(state)
    if state.pendingChoice or state.cardActions then return false,'card_choice_pending' end
    if state.pendingPlay or state.pendingScry or state.pendingHandChoice or state.actionQueue then return false, "selection_pending" end
    if state.pendingDiscard then return false, "discard_choice_pending" end
    if state.phase ~= "player" then return false, "not_player_turn" end
    if not state.silentRetainResume then
    for _,pile in ipairs({state.hand,state.draw,state.discard}) do for _,c in ipairs(pile) do c.costForTurn=nil end end
    local resetCosts=(state.player.statuses.corruption or 0)~=0
    for _,pile in ipairs({state.hand,state.draw,state.discard}) do
        for _,instance in ipairs(pile) do if instance.turnCost~=nil then resetCosts=true end end
    end
    if resetCosts then require("abyss_corruption").resetEndTurn(state) end
    preCardPowers(state)
    if finish(state)then return true end
    -- Regret snapshots every copy's amount before the end-turn card queue runs.
    -- Auto-use is not a player play: no energy, play hooks or attack modifiers.
    local handSize, regrets = #state.hand, {}
    for _, instance in ipairs(state.hand) do
        if instance.cardId == "regret" or instance.cardId=='burn' then regrets[#regrets + 1] = instance.uid end
    end
    for _, uid in ipairs(regrets) do
        local instance, position = findInstance(state, uid)
        table.remove(state.hand, position)
        state.cardInUse = instance
        if instance.cardId=='burn' then
            local def=M.cardDefinition(state,instance)
            M.damage(state,state.player,state.player,def.burnDamage,true)
        else M.applyEffects(state, {{op="loseHp", value=handSize}}, state.player, state.player) end
        -- Death opens the source death screen before UseCardAction can discard.
        -- Keep the current UID in cardInUse; later cards and cleanup never run.
        if finish(state) then return true end
        state.discard[#state.discard + 1] = instance
        if (state.player.statuses.corruption or 0)~=0 then require("abyss_corruption").onDrawOrDiscard(state) end
        state.cardInUse = nil
    end
    if ordinaryOwnerEnd(state)=='pause'then return true end
    if finish(state)then return true end
    -- No Draw's end-turn RemovePower is ahead of DiscardAtEndOfTurn.
    -- Regret death above stops before this action; surviving ethereal exhaust
    -- can subsequently trigger Dark Embrace draws before the enemy turn.
    if state.player.noDraw then
        state.player.noDraw=false
        event(state,"no_draw_removed",{target=state.player.id})
    end
    end
    state.silentRetainResume=nil
    discardOwnerEnd(state)
    if finish(state) then return true end
    if state.skipMonsterTurn then
        state.skipMonsterTurn=nil
        M.startPlayerTurn(state)
        return true
    end
    state.phase = "enemy"
    event(state, "enemy_turn")
    -- The group pre-turn hook clears every monster's old Block before its
    -- queued start powers resolve. Drain supported start powers before moves,
    -- so ally Block granted during a move survives later teammates' actions.
    for _, enemy in ipairs(state.enemies) do if Actors.isActive(enemy) then Actors.resetBlock(state, enemy) end end
    for _, enemy in ipairs(state.enemies) do
        if Actors.isActive(enemy) then
            local choke=require('abyss_silent_tactics_cards').planHook(state,'choked','owner_turn_start',enemy)
            if #choke>0 then
                local actions={};for _,effect in ipairs(choke) do actions[#actions+1]={kind='effect',effect=effect} end
                local queue=require('abyss_action_queue');queue.start(state,actions)
                assert(queue.run(state,queuedHandlers)==true,'unexpected enemy start selection')
            end
            local before = enemy.hp
            Actors.startTurnEffects(state, enemy)
            EnemyAI.hpLost(state, enemy, before) -- poison is direct HP loss
            EnemyAI.flush(state)
            drainNative(state)
            if finish(state) then return true end
        end
    end
    local actionQueue = {}
    for i, enemy in ipairs(state.enemies) do actionQueue[i] = enemy end
    for _, enemy in ipairs(actionQueue) do
        if Actors.isPresent(enemy) then
            local intent = enemy.intents[enemy.intentIndex]
            event(state, "intent", { enemy = enemy.id, id = intent.id })
            EnemyAI.beforeAction(state, enemy, aiRandom, intent)
            -- takeTurn has already queued this enemy's action payload.
            if enemy.ai and enemy.ai.kind == "looter"
                and (intent.id == enemy.ai.mugIntent or intent.id == enemy.ai.lungeIntent) then
                M.stealGold(state, enemy, enemy.ai.stealAmount)
            end
            queueEnemyTurn(state,enemy,intent,true)
            if finish(state) then return true end
        end
    end
    platedGroupEnd(state)
    if finish(state)then return true end
    for _,enemy in ipairs(state.enemies)do require('abyss_act3_powers').ownerEnd(Actors,state,enemy)end
    -- Duration powers belong to the shared round boundary, after all actions.
    -- A new monster-sourced power can suppress its first reduction.
    state.keepBlockOnNextStart=state.player.statuses.blur~=nil or nil
    local blur=require('abyss_silent_tactics_cards').planHook(state,'blur','round_end')
    if #blur>0 then
        local actions={};for _,effect in ipairs(blur) do actions[#actions+1]={kind='effect',effect=effect} end
        local queue=require('abyss_action_queue');queue.start(state,actions)
        assert(queue.run(state,queuedHandlers)==true,'unexpected Blur selection')
    end
    require('abyss_watcher_final_cards').endRound(state)
    Actors.endRound(state, state.player)
    for _, enemy in ipairs(state.enemies) do
        if Actors.isActive(enemy) then Actors.endRound(state, enemy) end
    end
    EnemyAI.endRound(state)
    require('abyss_defect_engine_cards').endRound(state)
    require('abyss_defect_final_cards').endRound(state)
    M.startPlayerTurn(state)
    return true
end

local function nativeEthereal(state)
    local endingHand={};for i,c in ipairs(state.hand)do endingHand[i]=c end
    for _,instance in ipairs(endingHand)do
        if M.cardDefinition(state,instance).ethereal then CardActions.exhaust(M,state,instance,state.hand)end
    end
    CardActions.drain(M,state)
    return finish(state)
end
local function endNativeTurn(state)
    if state.phase ~= "player" then return false, "not_player_turn" end
    if state.pendingChoice or state.cardActions then return false,"card_choice_pending" end
    local resumingRetain=state.silentRetainResume
    if not resumingRetain then
    if state.originalV4 then require('abyss_original_v4').endPhase(M,state);if finish(state)then return true end end
    if state.originalV4 then RelicHooks.onPlayerEndTurn(state)end
    -- AbstractRoom.endTurn resets these three piles before queued end-turn
    -- cleanup; exhaust is deliberately excluded. Exhume can recover a card
    -- that kept a temporary cost while it was out of those piles.
    for _,pile in ipairs({state.hand,state.draw,state.discard}) do
        for _,c in ipairs(pile) do c.costForTurn=nil end
    end
    if state.originalV4 then
    PlatedArmor.preEndCards(state,state.player,CardActions.enqueueReaction)
    CardActions.drain(M,state)
    if finish(state)then return true end
    else preCardPowers(state);if finish(state)then return true end end
    end
    local function cleanupPlayerEnd()
    if not resumingRetain then
    -- Regret snapshots every copy's amount before the end-turn card queue runs.
    -- Auto-use is not a player play: no energy, play hooks or attack modifiers.
    local handSize, endCards = #state.hand, {}
    for _, instance in ipairs(state.hand) do
        if Curses.endTurnCard(instance.cardId) or instance.cardId=="burn" then endCards[#endCards+1]=instance.uid end
    end
    for _, uid in ipairs(endCards) do
        local instance, position = findInstance(state, uid)
        table.remove(state.hand, position)
        state.cardInUse = instance
        if instance.cardId=="regret" then
            M.applyEffects(state,{{op="loseHp",value=handSize}},state.player,state.player)
        elseif instance.cardId=='doubt' or instance.cardId=='shame' then
            -- Both constructors explicitly pass isSourceMonster=true even
            -- though ApplyPowerAction's source is the player. This preserves
            -- the first round tick; Artifact still gates each application.
            Actors.applyPower(state,state.player,instance.cardId=='doubt' and 'weak' or 'frail',M.cardDefinition(state,instance).endTurnStatusAmount,state.player,true)
        else M.damage(state,state.player,state.player,M.cardDefinition(state,instance).endTurnDamage,true) end
        CardActions.drain(M,state)
        -- Death opens the source death screen before UseCardAction can discard.
        -- Keep the current UID in cardInUse; later cards and cleanup never run.
        if finish(state) then return true end
        state.discard[#state.discard + 1] = instance
        state.cardInUse = nil
    end
    if state.originalV4 then
        local p=state.player
        if (p.statuses.combust or 0)>0 then
            CardActions.enqueue(state,{op='loseHp',value=p.combustHpLoss})
            CardActions.enqueue(state,{op='damageAll',value=p.statuses.combust,fixed=true})
        end
        CardActions.drain(M,state)
        if finish(state)then return true end
        for _,id in ipairs({'rage','double_tap'})do
            local amount=p.statuses[id]or 0
            if amount>0 then p.statuses[id]=nil;event(state,'status',{source=p.id,target=p.id,status=id,amount=-amount})end
        end
    else
        if ordinaryOwnerEnd(state)=='pause'then return true end
        if finish(state)then return true end
    end
    if state.originalV4 and nativeEthereal(state)then return true end
    if state.originalV4 and (state.player.statuses.well_laid_plans or 0)>0 then
        Actors.endTurn(state,state.player);CardActions.drain(M,state)
        if finish(state)then return true end
        state.silentOwnerEndResolved=true
    end
    end
    state.silentRetainResume=nil
    if state.originalV4 and require('abyss_silent_final_cards').beginRetain(state)then return true end
    if state.originalV4 then
        local retained={}
        for _,instance in ipairs(state.hand)do
            local definition=M.cardDefinition(state,instance)
            if instance.silentRetainTurn==state.turn and not definition.ethereal then retained[#retained+1]=instance
            else state.discard[#state.discard+1]=instance end
        end
        state.hand=retained
    else discardOwnerEnd(state)end
    if state.originalV4 and not state.silentOwnerEndResolved then Actors.endTurn(state,state.player)end
    state.silentOwnerEndResolved=nil
    CardActions.drain(M,state)
    if finish(state) then return true end
    end
    if not state.originalV4 and cleanupPlayerEnd() then return true end
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
            drainNative(state)
            if finish(state) then return true end
        end
    end
    local actionQueue = {}
    for i, enemy in ipairs(state.enemies) do actionQueue[i] = enemy end
    for _, enemy in ipairs(actionQueue) do
        if Actors.isPresent(enemy) then
            local intent = enemy.intents[enemy.intentIndex]
            event(state, "intent", { enemy = enemy.id, id = intent.id })
            EnemyAI.beforeAction(state, enemy, aiRandom, intent)
            -- takeTurn has already queued this enemy's action payload.
            if enemy.ai and enemy.ai.kind == "looter"
                and (intent.id == enemy.ai.mugIntent or intent.id == enemy.ai.lungeIntent) then
                M.stealGold(state, enemy, enemy.ai.stealAmount)
            end
            if state.originalV4 then require('abyss_original_v4').beginEnemyAction(state,enemy,intent) end
            queueEnemyTurn(state,enemy,intent,false)
            if finish(state) then return true end
        end
    end
    platedGroupEnd(state)
    if finish(state)then return true end
    if state.originalV4 then
        if cleanupPlayerEnd() then return true end
        require('abyss_original_v4').cleanup(state)
    end
    -- Duration powers belong to the shared round boundary, after all actions.
    -- A new monster-sourced power can suppress its first reduction.
    for _,enemy in ipairs(state.enemies)do require('abyss_act3_powers').ownerEnd(Actors,state,enemy)end
    Actors.endRound(state, state.player)
    for _, enemy in ipairs(state.enemies) do
        if Actors.isActive(enemy) then Actors.endRound(state, enemy) end
    end
    EnemyAI.endRound(state)
    M.startPlayerTurn(state)
    return true
end


-- Advanced cleanup can invoke several card/power hooks. Keep end-turn errors
-- atomic just like a paused play, including costs reset before queued actions.
function M.endTurn(state)
    if state.pendingPotionChoice then return false,'potion_choice_pending'end
    if not state.originalV4 and state.silentRetainResume and state.actionQueue and state.actionQueue.paused
        and state.actionQueue.current.effect.op=='ownerEndRetain'then
        if state.pendingChoice then return false,'card_choice_pending'end
        for _,card in ipairs(state.hand)do
            if card.silentRetainTurn==state.turn and not M.cardDefinition(state,card).ethereal then card.retain=true end
        end
        local result=require('abyss_action_queue').resume(state,queuedHandlers)
        if result=='pause'or finish(state)then return true end
    end
    if state.originalV4 or advancedTurnCleanup(state)or require('abyss_act3_powers').active(state)
        or Awakened.active(state) or require('abyss_giant_head').active(state)
        or require('abyss_end_turn_powers').needed(state,require('abyss_act3_powers'))then
        local restore=require('abyss_snapshot').capture(state)
        local resolver=(state.originalV4 or not state.experimentalMechanics)and endNativeTurn or endExperimentalTurn
        local called,ok,reason=pcall(resolver,state)
        if not called then restore();error(ok,0)end
        return ok,reason
    end
    if not state.experimentalMechanics then return endNativeTurn(state) end
    if not advancedTurnCleanup(state) then return endExperimentalTurn(state) end
    local restore=require("abyss_snapshot").capture(state)
    local called,ok,reason=pcall(endExperimentalTurn,state)
    if not called then restore();error(ok,0) end
    return ok,reason
end

function M.new(data, options)
    local originalData=data
    data=require('abyss_colorless_cards').withCards(data)
    -- Registration owns fresh, detached pools when it returns a new bundle.
    -- Reuse that private copy; registered caller bundles still need a copy.
    local sourcePools=data~=originalData and data.cards.sourcePools or copy(data.cards.sourcePools)
    -- Existing definitions remain caller-owned. Newly registered definitions
    -- already have private graphs and can be adopted without copying twice.
    local catalogData=data~=originalData and originalData or data
    local cardCatalog,statusCatalog=index(copy(catalogData.cards.cards)),index(copy(catalogData.statuses.statuses))
    if data~=originalData then
        for _,definition in ipairs(data.cards.cards)do
            if not cardCatalog[definition.id]then cardCatalog[definition.id]=definition end
        end
        for _,definition in ipairs(data.statuses.statuses)do
            if not statusCatalog[definition.id]then statusCatalog[definition.id]=definition end
        end
    end
    options = options or {}
    if data.runCardCatalog then
        -- Only default scalar options. Formation callbacks and roomStreams
        -- must keep the same source owner while constructors spend its RNG.
        local configured={}
        for key,value in pairs(options)do configured[key]=value end
        options=configured
        if options.enableStances==nil then options.enableStances=true end
        if options.orbSlots==nil then options.orbSlots=data.runCardCharacter=='defect'and 3 or 0 end
    end
    if options.sourceEncounter ~= nil then
        assert(Formation.supports(options.sourceEncounter), "unknown source formation")
        assert(options.enemies == nil, "source formation cannot mix with explicit enemies")
        assert(type(options.encounterBoundary) == "table", "source formation needs explicit boundaries")
    end
    assert(type(options.seed or 1) == "number" and (options.seed or 1) % 1 == 0, "seed must be an integer")
    local rules = copy(data.rules)
    rules.player.maxHp=options.maxHp or rules.player.maxHp
    local hp = options.hp or rules.player.maxHp
    assert(hp > 0 and hp <= rules.player.maxHp and hp % 1 == 0, "invalid starting hp")
    local gold = options.gold == nil and rules.player.startingGold or options.gold
    assert(goldInteger(gold), "invalid starting gold")
    local state = { stolenGoldReward = 0, mugged = false, rules = rules,sourcePools=sourcePools,experimentalCharacter=data.experimentalCharacter, catalog = { cards = cardCatalog, enemies = index(copy(data.enemies.enemies)),
              statuses = statusCatalog,potions=index(data.potions and data.potions.potions or {}) },
        seed = (options.seed or 1) % 65536, turn = 0, energy = 0, phase = "setup", nextUid = 1, nextEnemyId = 1,
        player = { id = "player", gold = gold, hp = hp, maxHp = rules.player.maxHp, block = 0, statuses = {} },
        enemies = {}, draw = {}, hand = {}, discard = {}, exhaust = {}, events = {} }
    if data.originalV4Role then require('abyss_original_v4').init(state,data.originalV4Role,copy(data.originalV4Rules)) end
    require('abyss_act1_bosses').register(state.catalog,copy)
    require('abyss_act3_bosses').register(state.catalog,copy)
    for _,enemy in ipairs(require('abyss_act2_enemies').enemies)do
        assert(not state.catalog.enemies[enemy.id],'duplicate Act2 enemy')
        state.catalog.enemies[enemy.id]=copy(enemy)
    end
    for _,status in ipairs(require('abyss_act2_enemies').statuses)do
        assert(not state.catalog.statuses[status.id],'duplicate Act2 status')
        state.catalog.statuses[status.id]=copy(status)
    end
    for _,enemy in ipairs(require('abyss_act3_enemies').enemies)do
        assert(not state.catalog.enemies[enemy.id],'duplicate Act3 enemy')
        state.catalog.enemies[enemy.id]=copy(enemy)
    end
    for _,status in ipairs(require('abyss_act3_enemies').statuses)do
        assert(not state.catalog.statuses[status.id],'duplicate Act3 status')
        state.catalog.statuses[status.id]=copy(status)
    end
    -- Helper opt-in is independent of character selection: mixed native cards
    -- must still run the experimental on-use/draw hooks they were prepared with.
    for key,value in pairs(data) do
        if type(key)=='string' and key:match('^experimental') and value then state.experimentalMechanics=true end
    end
    for _,card in ipairs(data.cards.cards) do
        if (card.type=='attack' or card.type=='skill' or card.type=='power') and card.target==nil then
            state.experimentalMechanics=true
        end
    end
    if data.cards.sourcePools then state.cardRandomRng=SourceRandom.fromSeed(options.cardRandomSeed or string.format('%.0f',options.seed or 1)) end
    if options.shuffleSeed then state.shuffleRng=SourceRandom.fromSeed(options.shuffleSeed) end
    if options.roomStreams then
        assert(type(options.roomSeed)=='string','source room needs raw room seed')
        state.roomSeed=options.roomSeed
        state.monsterHpRng=SourceRandom.cloneState(options.roomStreams.monsterHpRng)
        state.aiRng=SourceRandom.cloneState(options.roomStreams.aiRng)
        -- Shuffle is consumed by initial setup and DrawCardAction below.
        -- cardRandomRng remains an explicit boundary for its separate migration.
        state.shuffleRng=SourceRandom.cloneState(options.roomStreams.shuffleRng)
        state.cardRandomRng=SourceRandom.cloneState(options.roomStreams.cardRandomRng)
    end
    if not state.cardRandomRng and options.cardRandomSeed ~= nil then
        assert(type(options.cardRandomSeed)=="string","card random seed must be a raw source string")
        state.cardRandomRng=SourceRandom.fromSeed(options.cardRandomSeed)
    end
    -- Opt-in development mechanics; ordinary Ironclad construction is unchanged.
    assert(options.enableStances == nil or type(options.enableStances) == "boolean", "invalid stance option")
    if options.enableStances then
        state.experimentalMechanics=true
        require("abyss_stances").reset(state)
    end
    if options.orbSlots ~= nil then
        state.experimentalMechanics=true
        if not state.cardRandomRng then
            assert(type(options.orbRandomSeed) == "string", "orb combat needs an explicit card random seed or room stream")
            state.cardRandomRng = SourceRandom.fromSeed(options.orbRandomSeed)
        end
        require("abyss_orbs").init(state, options.orbSlots)
    end
    Actors.bindStatuses(state.player, state.catalog.statuses)
    local deck = options.deck or data.cards.starter_deck.cards
    -- Removing the final permanent card is legal; draw already handles empty piles.
    assert(type(deck) == "table", "invalid deck")
    for _, value in ipairs(deck) do
        local id = type(value) == "table" and value.cardId or value
        assert(state.catalog.cards[id], "unknown deck card: " .. tostring(id))
        local uid=state.nextUid
        if state.originalV4 and type(value)=='table' and value.uid~=nil then
            assert(type(value.uid)=='number' and value.uid>0 and value.uid%1==0 and value.uid<9007199254740991,'invalid permanent card UID')
            uid=value.uid
            for _,existing in ipairs(state.draw)do assert(existing.uid~=uid,'duplicate permanent card UID')end
        end
        state.draw[#state.draw + 1] = { uid = uid, uuid=uid, cardId = id, upgraded = type(value) == "table" and value.upgraded == true,
            upgrades=type(value)=='table' and value.upgrades or nil,deckUid=type(value)=='table' and value.uid or nil,
            misc=type(value)=='table' and value.misc or nil }
        state.nextUid = math.max(state.nextUid,uid)+1
    end
    if options.sourceEncounter ~= nil then
        local callbacks, constructors = options.encounterBoundary, 0
        state.enemies = Formation.assemble(options.sourceEncounter, {
            misc = callbacks.misc, visualFloat = callbacks.visualFloat,
            construct = function(id, x, y)
                constructors = constructors + 1
                local actor = makeEnemy(state, id, constructors)
                actor.sourcePosition = {x = x, y = y}
                return actor
            end,
        })
        state.sourceEncounter = options.sourceEncounter
        -- Only selected actors receive live slot IDs and opening/pre-battle AI.
        -- Discarded candidates already spent constructor HP/Bite draws above.
        for i, enemy in ipairs(state.enemies) do enemy.id = enemy.definitionId .. "_" .. i end
        state.nextEnemyId = #state.enemies + 1
    else
        local enemyIds = options.enemies or { "cultist" }
        assert(#enemyIds > 0, "empty encounter")
        for i, id in ipairs(enemyIds) do
            state.enemies[#state.enemies + 1] = makeEnemy(state, id, i)
            state.nextEnemyId = i + 1
        end
    end
    for _, enemy in ipairs(state.enemies) do EnemyAI.initialize(state, enemy, aiRandom) end
    shuffle(state, state.draw)
    local openingDraw
    state.draw,openingDraw=require("abyss_opening_hand").stage(state.draw,state.catalog.cards,rules.player.drawPerTurn)
    -- MonsterRoom initializes all actors first; preBattlePrep shuffles the
    -- deck before calling the group's pre-battle powers in encounter order.
    for _, enemy in ipairs(state.enemies) do EnemyAI.preBattle(state, enemy, hpRandom) end
    state.cardRng=options.cardRng and SourceRandom.cloneState(options.cardRng) or SourceRandom.fromSeed(options.cardSeed or string.format('%.0f',options.seed or 1))
    require('abyss_writhing_mass').bindMaster(state,options.masterDeck,options.nextMasterDeckUid)
    local misc=options.roomStreams and options.roomStreams.miscRng or options.miscRng
    if misc then state.miscRng=SourceRandom.cloneState(misc)end
    if options.beforeFirstTurn then
        local ok, reason = options.beforeFirstTurn(state)
        if not ok then return nil, reason end
    end
    if openingDraw>0 then M.draw(state,openingDraw) end
    local ok, reason = M.startPlayerTurn(state, options.beforeOpeningDraw)
    if ok == false then return nil, reason end
    return state
end

return M
