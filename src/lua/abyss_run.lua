-- Same-run deck and reward ownership. Platform/UI adapters issue these commands.
local Combat = require("abyss_combat")
local Inventory = require("abyss_inventory")
local EventRandom = require("abyss_sts_random")
local Unknown = require("abyss_unknown")
local EventPool = require("abyss_event_pool")
local PotionRewards = require("abyss_potion_rewards")
local CardPool = require("abyss_card_pool")
local GoldRewards = require("abyss_gold_rewards")
local RunSeed = require("abyss_run_seed")
local EncounterQueue = require("abyss_encounter_queue")
local RoomEncounters = require("abyss_room_encounters")
local CardRandom = require("abyss_card_random")
local M = {}

local function find(entries, id)
    for _, entry in ipairs(entries) do if entry.id == id then return entry end end
end

function M.new(data, seed)
    local eventSeed = RunSeed.normalize(seed)
    local cardOwner = CardRandom.new(eventSeed)
    local run = { version = data.rules.version, data = Combat.copy(data), seed = RunSeed.legacy(eventSeed),runSeed=eventSeed,
        eventSeed = eventSeed, eventRng = EventRandom.fromSeed(eventSeed), miscRng = EventRandom.fromSeed(eventSeed),
        treasureRng = EventRandom.fromSeed(eventSeed),
        cardRng = cardOwner.cardRng,cardRarityOffset=cardOwner.cardRarityOffset,
        encounters=EncounterQueue.new(eventSeed),roomGeneration=0,
        -- Launch supports the exact source !isBossSeen(GUARDIAN) branch. It
        -- duplicates Guardian and spends no monsterRng; no all-unlocked claim.
        bossInitialization={profile='guardian-unseen',bossList={'The Guardian','The Guardian'}},
        unknown = { chances = Unknown.newPc(), pools = EventPool.new(data.rules.events.poolMode or 'restricted-six') },
        phase = "map", floor = 1, hp = data.rules.player.maxHp, maxHp = data.rules.player.maxHp,
        elapsedSeconds = 0, victories = 0,
        gold = data.rules.player.startingGold, deck = {}, nextDeckUid = 1,
        relics = Combat.copy(data.rules.player.startingRelics), potions = {} }
    for _, id in ipairs(data.cards.starter_deck.cards) do
        run.deck[#run.deck + 1] = { uid = run.nextDeckUid, cardId = id, upgraded = false }
        run.nextDeckUid = run.nextDeckUid + 1
    end
    return run
end

local function startEncounter(run, encounter, sourceRoom)
    if run.phase ~= "map" then return false, "not_on_map" end
    if not encounter then return false, "unknown_encounter" end
    if not sourceRoom and (run.floor < encounter.minFloor or run.floor > encounter.maxFloor) then return false, "wrong_floor" end
    local opening, reason = Inventory.opening(run.data.relics.relics, run.relics)
    if not opening then return false, reason end
    local bonus
    bonus, reason = Inventory.energyBonus(run.data.relics.relics, run.relics, encounter.tier)
    if not bonus then return false, reason end
    local combatData = {}
    for key, value in pairs(run.data) do combatData[key] = value end
    combatData.rules = Combat.copy(run.data.rules)
    combatData.rules.player.energyPerTurn = combatData.rules.player.energyPerTurn + 0.0 + bonus
    if combatData.rules.player.energyPerTurn > 2147483647 then return false, "invalid_relic_energy" end
    -- Source-ordered group assembly uses the current misc stream (MonsterHelper,
    -- fixed 319009d). Keep this separate from Combat's HP/AI/shuffle stream and
    -- publish neither the choice nor its RNG state until all setup succeeds.
    local enemies, nextMiscRng = encounter.enemies
    if not sourceRoom and encounter.enemiesOnTrue then
        nextMiscRng = EventRandom.cloneState(run.miscRng)
        if EventRandom.randomBoolean(nextMiscRng) then enemies = encounter.enemiesOnTrue end
    elseif not sourceRoom and encounter.gremlinPool then
        nextMiscRng = EventRandom.cloneState(run.miscRng)
        local pool = Combat.copy(encounter.gremlinPool)
        enemies = {}
        for slot = 1, encounter.gremlinCount do
            -- Inclusive Java bound: 7, 6, 5, 4. Remove only this occurrence;
            -- duplicates carry weight, and draw order is construction order.
            enemies[slot] = table.remove(pool, EventRandom.randomInt(nextMiscRng, #pool - 1) + 1)
        end
    end
    local battle
    local options={seed=run.seed,hp=run.hp,maxHp=run.maxHp,gold=run.gold,deck=run.deck,enemies=enemies,
        cardRandomSeed=RunSeed.forFloor(run.runSeed,run.floor),shuffleSeed=RunSeed.forFloor(run.runSeed,run.floor),
        beforeOpeningDraw=function(state)return Inventory.applyOpening(state,opening.beforeDraw)end}
    if sourceRoom then
        options.roomSeed,options.roomStreams=sourceRoom.seed,sourceRoom
        if encounter.sourceEncounter then
            options.enemies=nil;options.sourceEncounter=encounter.sourceEncounter
            options.encounterBoundary={
                misc={boolean=function()return EventRandom.randomBoolean(sourceRoom.miscRng)end,
                    integer=function(lo,hi)return EventRandom.randomIntBetween(sourceRoom.miscRng,lo,hi)end},
                -- Cosmetic-only independent stream; not a replay of global
                -- libGDX MathUtils animation/offset entropy. Never spends misc.
                visualFloat=function(lo,hi)return EventRandom.randomFloatBetween(sourceRoom.visualRng,lo,hi)end}
        end
    end
    battle, reason = Combat.new(combatData, options)
    if not battle then return false, reason end
    -- Queue-tail relics follow the ordinary draw, retaining their held order.
    local ok
    ok, reason = Inventory.applyOpening(battle, opening.afterDraw)
    if not ok then return false, reason end
    run.combat, run.encounterId, run.encounterTier = battle, encounter.id, encounter.tier
    run.encounterSource,battle.encounterSource=encounter.source,encounter.source
    if nextMiscRng then run.miscRng = nextMiscRng end
    run.phase = "combat"
    run.pendingCombatRewards = nil
    return true
end

-- Explicit-ID development/replay entry; ordinary map rooms use startRoomCombat.
-- Historical medium_slimes and fixed-color examples never enter the source pool.
function M.startCombat(run,encounterId)
    return startEncounter(run,find(run.data.enemies.encounters,encounterId))
end

function M.roomStreams(run,floor)
    local seed=RunSeed.forFloor(run.runSeed,floor)
    return {seed=seed,monsterHpRng=EventRandom.fromSeed(seed),aiRng=EventRandom.fromSeed(seed),
        shuffleRng=EventRandom.fromSeed(seed),cardRandomRng=EventRandom.fromSeed(seed),
        miscRng=EventRandom.fromSeed(seed),visualRng=EventRandom.fromSeed(seed)}
end

function M.startRoomCombat(run,tier)
    if run.phase~='map' then return false,'not_on_map' end
    if type(run.roomGeneration)~='number' or run.roomGeneration%1~=0
        or run.roomGeneration<0 or run.roomGeneration>=2147483647 then return false,'invalid_room_generation' end
    if type(run.encounters)~='table' or run.encounters.rawSeed~=run.runSeed then return false,'run_seed_mismatch' end
    if type(run.floor)~='number' or run.floor%1~=0 or run.floor<1 or run.floor>16 then return false,'wrong_floor' end
    local encounter,nextQueue
    if tier=='boss' then
        if run.floor~=16 or not run.bossInitialization or run.bossInitialization.profile~='guardian-unseen' then
            return false,'unsupported_boss_initialization'
        end
        encounter={id='boss_guardian',tier='boss',source='The Guardian',enemies={'guardian'}}
    else
        local source,reason
        local valid
        valid,source,nextQueue,reason=pcall(EncounterQueue.consume,run.encounters,tier)
        if not valid then return false,'invalid_encounter_state' end
        if not source then return false,reason end
        encounter,reason=RoomEncounters.resolve(source,tier)
        if not encounter then return false,reason end
    end
    local staged={};for k,v in pairs(run)do staged[k]=v end
    local ready,room=pcall(M.roomStreams,run,run.floor)
    if not ready then return false,'invalid_room_seed' end
    local called,ok,reason=pcall(startEncounter,staged,encounter,room)
    if not called then return false,'combat_unavailable' end
    if not ok then return false,reason end
    staged.miscRng=room.miscRng
    for _,key in ipairs({'combat','encounterId','encounterTier','encounterSource','phase','miscRng'})do run[key]=staged[key]end
    if nextQueue then run.encounters=nextQueue end
    run.roomGeneration=run.roomGeneration+1
    run.pendingCombatRewards=nil
    return true
end

-- Queue checkpoint boundary only, not exit/resume or a complete Run save file.
function M.snapshotEncounters(run)
    return {version=2,runSeed=run.runSeed,floor=run.floor,roomGeneration=run.roomGeneration,
        queue=EncounterQueue.snapshot(run.encounters)}
end
function M.restoreEncounters(run,snapshot)
    if run.phase~='map' or (run.nodeFlow and not run.nodeFlow.complete) then return false,'node_pending' end
    if type(snapshot)~='table' or getmetatable(snapshot)~=nil then return false,'invalid_snapshot' end
    for k in pairs(snapshot)do if k~='version' and k~='runSeed' and k~='floor' and k~='roomGeneration' and k~='queue' then return false,'invalid_snapshot' end end
    if snapshot.version~=2 then return false,'invalid_snapshot' end
    if snapshot.runSeed~=run.runSeed then return false,'run_seed_mismatch' end
    if snapshot.floor~=run.floor then return false,'floor_mismatch' end
    if type(snapshot.roomGeneration)~='number' or snapshot.roomGeneration%1~=0
        or snapshot.roomGeneration<0 or snapshot.roomGeneration>2147483647
        or snapshot.roomGeneration~=run.roomGeneration then return false,'stale_encounter_checkpoint' end
    local ok,queue=pcall(EncounterQueue.restore,snapshot.queue)
    if not ok or queue.rawSeed~=run.runSeed then return false,'invalid_snapshot' end
    -- A generation tag alone cannot authorize rewinding queue consumption.
    -- This API replaces a checkpoint at the current boundary, not Run progress.
    if type(run.encounters)~='table' or type(run.encounters.normal)~='table' or type(run.encounters.elite)~='table'
        or #queue.normal~=#run.encounters.normal or #queue.elite~=#run.encounters.elite then
        return false,'encounter_progress_mismatch'
    end
    run.encounters=queue
    return true
end

local function finishCombat(run)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    local result = Combat.outcome(run.combat)
    if not result then return false, "battle_unfinished" end
    run.hp, run.seed, run.gold = run.combat.player.hp, run.combat.seed, run.combat.player.gold
    run.maxHp=run.combat.player.maxHp
    local allEscaped = Combat.allEnemiesEscaped(run.combat)
    run.lastResult = { outcome = result, turn = run.combat.turn, encounterId = run.encounterId, allEnemiesEscaped = allEscaped, mugged = run.combat.mugged }
    if result == "defeat" then
        run.phase, run.rewards = "defeat", nil
        return true
    end
    -- Combat-end relics apply once, before the reward transaction is offered.
    for _, id in ipairs(run.relics) do
        local relic = find(run.data.relics.relics, id)
        if relic and relic.trigger == "combat_end" then
            for _, effect in ipairs(relic.effects) do
                if effect.op == "heal" then run.hp = math.min(run.maxHp, run.hp + effect.value) end
            end
        end
    end
    local gold, goldStream, nextGoldRng
    if run.combat.roomSeed then
        gold, goldStream, nextGoldRng = GoldRewards.prepare(run.encounterTier, run, {allEscaped=allEscaped})
    else
        -- Historical explicit-ID fixtures retain their fixed reward contract;
        -- only the actual source-room path claims the source gold RNG boundary.
        gold = run.data.rules.rewards[run.encounterTier .. "Gold"]
        assert(type(gold) == "number", "unknown encounter reward tier")
        if allEscaped then gold = 0 end
    end
    local choices,nextCardRng,offset=CardPool.prepareRewards(run)
    run.cardRng,run.cardRarityOffset=nextCardRng,offset
    local potion,potionRng,potionModifier=PotionRewards.prepare(run,2,{allEscaped=allEscaped})
    PotionRewards.commit(run,potionRng,potionModifier)
    run.rewards, run.phase = { cards = choices, gold = gold, goldClaimed = gold == 0, potion = potion,
        cardResolved = false, manualContinue = true }, "reward"
    local stolen = run.combat.stolenGoldReward or 0
    if stolen > 0 then
        run.rewards.stolenGold = {type="STOLEN_GOLD", amount=stolen, claimed=false}
        run.rewards.cardResolved, run.rewards.manualContinue = false, true
    end
    run.victories = run.victories + 1
    if goldStream then run[goldStream] = nextGoldRng end
    return true
end

function M.finishCombat(run)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    if not run.combat.roomSeed then return finishCombat(run) end
    -- A formal reward is one transaction: invalid source RNG or a later potion
    -- failure must not publish healed HP, card/treasure progress or lastResult.
    local staged = {}
    for key, value in pairs(run) do staged[key] = value end
    staged.shopRng = run.shopRng and Combat.copy(run.shopRng)
    local ok, reason = finishCombat(staged)
    if not ok then return false, reason end
    for key in pairs(run) do run[key] = staged[key] end
    for key, value in pairs(staged) do run[key] = value end
    return true
end

function M.rewardOptions(run)
    if run.phase ~= "reward" or run.rewards.cardResolved then return {} end
    return Combat.copy(run.rewards.cards)
end

function M.claimCardReward(run, choice)
    if run.phase ~= "reward" or run.rewards.cardResolved then return false, "no_pending_reward" end
    if type(choice) ~= "number" or choice % 1 ~= 0 or choice < 0 or choice > #run.rewards.cards then
        return false, "invalid_reward_choice"
    end
    -- A card choice never owns the independent potion reward (RewardItem).
    if choice > 0 then
        run.deck[#run.deck + 1] = { uid = run.nextDeckUid, cardId = run.rewards.cards[choice], upgraded = false }
        run.nextDeckUid = run.nextDeckUid + 1
    end
    -- choice=0 is the internal explicit-abandon command retained for old
    -- non-UI drivers. PC Skip merely closes the picker and never calls this.
    run.rewards.cardResolved = true
    return true
end

local function validGold(n)
    return type(n) == "number" and n == n and n % 1 == 0 and n >= 0 and n <= 2147483647
end

-- RewardItem.GOLD: the victory creates an offer; clicking it grants the money.
function M.claimGoldReward(run)
    local rewards = run.phase == "reward" and run.rewards
    if not rewards or rewards.goldClaimed ~= false then return false, "no_pending_gold" end
    if not validGold(rewards.gold) or rewards.gold == 0 or not validGold(run.gold)
        or run.gold + 0.0 + rewards.gold > 2147483647 then return false, "invalid_gold_reward" end
    run.gold, rewards.goldClaimed = run.gold + rewards.gold, true
    return true
end

function M.claimStolenGoldReward(run)
    local rewards = run.phase == "reward" and run.rewards
    local item = type(rewards) == "table" and rewards.stolenGold
    if type(item) ~= "table" or rewards.manualContinue ~= true or item.type ~= "STOLEN_GOLD" or item.claimed ~= false then
        return false, "no_pending_stolen_gold"
    end
    if not validGold(item.amount) or item.amount == 0 or not validGold(run.gold)
        or run.gold + 0.0 + item.amount > 2147483647 then return false, "invalid_stolen_gold" end
    run.gold, item.claimed = run.gold + item.amount, true
    return true
end

function M.leaveCombatRewards(run)
    if run.phase ~= "reward" or not run.rewards or run.rewards.manualContinue ~= true then
        return false, "no_pending_reward"
    end
    -- Proceed opens the map without consuming unclaimed items. They remain
    -- accessible until a successful room transition commits.
    run.pendingCombatRewards = { rewards = run.rewards, combat = run.combat, flow = run.nodeFlow }
    run.phase, run.rewards, run.combat = "map", nil, nil
    return true
end

function M.reopenCombatRewards(run)
    local pending = run.pendingCombatRewards
    if run.phase ~= "map" or not pending or pending.flow ~= run.nodeFlow then return false, "no_pending_reward" end
    run.rewards, run.combat, run.phase = pending.rewards, pending.combat, "reward"
    run.pendingCombatRewards = nil
    return true
end

function M.claimPotionReward(run)
    if run.phase~='reward' then return false,'no_pending_reward' end
    local offer=run.rewards and run.rewards.potion
    if not offer or offer.resolved then return false,'no_pending_potion_reward' end
    for _, id in ipairs(run.relics) do
        local relic = find(run.data.relics.relics, id)
        if relic and relic.blocksPotions then
            offer.resolved, offer.result = true, 'blocked'
            return true, 'potion_blocked_by_sozu'
        end
    end
    if offer.unavailable then return false,'potion_content_unavailable' end
    local ok,slot=M.obtainPotion(run,offer.id)
    if not ok then return false,slot end
    offer.resolved,offer.result,offer.slot=true,'claimed',slot
    return true,slot
end

function M.skipPotionReward(run)
    if run.phase~='reward' then return false,'no_pending_reward' end
    local offer=run.rewards and run.rewards.potion
    if not offer or offer.resolved then return false,'no_pending_potion_reward' end
    offer.resolved,offer.result=true,'skipped'
    return true
end

function M.chooseCard(run,token,uid)
    if run.phase~="combat" then return false,"not_in_combat" end
    local ok,reason=Combat.chooseCard(run.combat,token,uid)
    if ok then
        run.gold=run.combat.player.gold
        if Combat.outcome(run.combat) then M.finishCombat(run) end
    end
    return ok,reason
end

function M.play(run, uid, targetIndex)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    local ok, reason = Combat.play(run.combat, uid, targetIndex)
    if ok then
        run.gold = run.combat.player.gold
        if Combat.outcome(run.combat) then M.finishCombat(run) end
    end
    return ok, reason
end

function M.endTurn(run)
    if run.phase ~= "combat" then return false, "not_in_combat" end
    local ok, reason = Combat.endTurn(run.combat)
    if ok then
        run.gold = run.combat.player.gold
        if Combat.outcome(run.combat) then M.finishCombat(run) end
    end
    return ok, reason
end

-- Inventory slots are physical positions, not a packed list. Acquiring a bottle
-- fills the leftmost vacancy; reward/shop adapters still own eligibility/payment.
function M.potionCount(run)
    local count = 0
    for slot = 1, run.data.rules.player.potionSlots do
        if run.potions[slot] then count = count + 1 end
    end
    return count
end

function M.obtainPotion(run, id)
    if not find(run.data.potions.potions, id) then return false, "unknown_potion" end
    for _, owned in ipairs(run.relics) do
        local relic = find(run.data.relics.relics, owned)
        if relic and relic.blocksPotions then return false, "potion_blocked_by_sozu" end
    end
    for slot = 1, run.data.rules.player.potionSlots do
        if not run.potions[slot] then
            run.potions[slot] = id
            return true, slot
        end
    end
    return false, "potion_slots_full"
end

-- Discard never executes a potion effect and does not require a player turn.
-- The original WeMeetAgain event veto is outside the supported event pool.
function M.discardPotion(run, slot)
    if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > run.data.rules.player.potionSlots then
        return false, "invalid_potion_slot"
    end
    local id = run.potions[slot]
    if not id then return false, "empty_potion_slot" end
    if not find(run.data.potions.potions, id) then return false, "unknown_potion" end
    -- Like usePotion, a destructive transaction expires old physical gestures,
    -- even if the same bottle ID is immediately acquired in the vacant slot.
    run.potions = Combat.copy(run.potions)
    run.potions[slot] = nil
    return true
end

local function potionCandidate(run, slot, targetIndex)
    if run.phase ~= "combat" then return nil, "not_in_combat" end
    if not run.combat or run.combat.phase ~= "player" then return nil, "not_player_turn" end
    if run.combat.pendingChoice or run.combat.cardActions then return nil,"card_choice_pending" end
    if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > run.data.rules.player.potionSlots then
        return nil, "invalid_potion_slot"
    end
    local id = run.potions[slot]
    if not id then return nil, "empty_potion_slot" end
    local potion = find(run.data.potions.potions, id)
    if not potion then return nil, "unknown_potion" end
    local candidate = Combat.copy(run.combat)
    local called, ok, reason = pcall(Inventory.apply, candidate, potion.effects, targetIndex)
    if not called then return nil, "potion_effect_failed" end
    if not ok then return nil, reason end
    return candidate
end

function M.usePotion(run, slot, targetIndex)
    local battle, reason = potionCandidate(run, slot, targetIndex)
    if not battle then return false, reason end
    require("abyss_events").emit(battle, "potion", { slot = slot, id = run.potions[slot], target = targetIndex })
    local outcome = Combat.outcome(battle)
    if outcome then
        battle.phase = outcome
        require("abyss_events").emit(battle, outcome, {allEnemiesEscaped=Combat.allEnemiesEscaped(battle), mugged=battle.mugged})
    end
    -- Stage the complete transaction, including rewards and their RNG, before committing.
    -- Persistent deck UIDs are owned by Run and are never regenerated from combat instances.
    local candidate = {}
    for key, value in pairs(run) do candidate[key] = value end
    candidate.combat, candidate.potions, candidate.gold = battle, Combat.copy(run.potions), battle.player.gold
    candidate.potions[slot] = nil
    if outcome then
        -- Reward preparation commits the continuous potion stream. Do not let
        -- an exception mutate a table still owned by the live run.
        candidate.shopRng = run.shopRng and Combat.copy(run.shopRng)
        local called, ok = pcall(M.finishCombat, candidate)
        if not called or not ok then return false, "potion_effect_failed" end
    end
    local root = run.combat
    for key in pairs(root) do root[key] = nil end
    for key, value in pairs(battle) do root[key] = value end
    candidate.combat = root
    for key, value in pairs(candidate) do run[key] = value end
    return true
end

-- Detached UI description. A targeted bottle is usable if at least one legal target exists;
-- usePotion still validates the selected target when the command arrives.
-- Indexed by physical slot, with nil vacancies; do not iterate/count with ipairs/#.
function M.potionView(run)
    local result = {}
    for slot = 1, run.data.rules.player.potionSlots do
        local id = run.potions[slot]
        if id then
            local potion = find(run.data.potions.potions, id)
            local needTarget = potion and potion.targetPolicy == "enemy_one" or false
            local candidate, reason
            if needTarget and run.combat then
                for index, enemy in ipairs(run.combat.enemies) do
                    if require("abyss_actor").isActive(enemy) then
                        candidate, reason = potionCandidate(run, slot, index)
                        if candidate then break end
                    end
                end
            end
            if not candidate and not reason then candidate, reason = potionCandidate(run, slot) end
            result[slot] = { slot = slot, id = id, name = potion and potion.name or id,
                targetPolicy = potion and potion.targetPolicy,
                effects = potion and Combat.copy(potion.effects) or {}, needTarget = needTarget,
                canUse = candidate ~= nil, reason = reason }
        end
    end
    return result
end

return M
