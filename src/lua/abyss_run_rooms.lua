-- Rooms responsibility for the same-run API.
local Combat = require("abyss_combat")
local Inventory = require("abyss_inventory")
local EventRandom = require("abyss_sts_random")
local RunSeed = require("abyss_run_seed")
local EncounterQueue = require("abyss_encounter_queue")
local RoomEncounters = require("abyss_room_encounters")
local EventCombat=require('abyss_event_combat')
local Acts = require('abyss_acts')

local M = {}

function M.install(Run, shared)
    local find=shared.find
    local function encounterEnemies(run, encounter, sourceRoom)
        -- Source-ordered group assembly uses the current misc stream (MonsterHelper,
        -- fixed 319009d). Keep this separate from Combat's HP/AI/shuffle stream and
        -- publish neither the choice nor its RNG state until all setup succeeds.
        local enemies, nextMiscRng = encounter.enemies
        if not sourceRoom and encounter.enemiesOnTrue then
            nextMiscRng = EventRandom.cloneState(run.miscRng)
            if EventRandom.randomBoolean(nextMiscRng) then enemies = encounter.enemiesOnTrue end
        elseif not sourceRoom and encounter.lousePool then
            nextMiscRng = EventRandom.cloneState(run.miscRng)
            enemies = {}
            for slot = 1, encounter.louseCount do
                -- Each source getLouse call is independent: true red, false green.
                -- Keep candidates for every slot; repeated colors are legal.
                enemies[slot] = encounter.lousePool[EventRandom.randomBoolean(nextMiscRng) and 1 or 2]
            end
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
        return enemies, nextMiscRng
    end

    local function configureSourceRoom(encounter, sourceRoom, options)
        if sourceRoom then
            options.roomSeed,options.roomStreams=sourceRoom.seed,sourceRoom
            options.emeraldBoost=sourceRoom.emeraldBoost
            if sourceRoom.preparedEncounter then
                options.enemies,options.sourceEncounter=nil,nil
                options.preparedEncounter=sourceRoom.preparedEncounter
            elseif encounter.sourceEncounter then
                options.enemies=nil;options.sourceEncounter=encounter.sourceEncounter
                options.encounterBoundary={
                    misc={boolean=function()return EventRandom.randomBoolean(sourceRoom.miscRng)end,
                        integer=function(lo,hi)return EventRandom.randomIntBetween(sourceRoom.miscRng,lo,hi)end},
                    -- Cosmetic-only independent stream; not a replay of global
                    -- libGDX MathUtils animation/offset entropy. Never spends misc.
                    visualFloat=function(lo,hi)return EventRandom.randomFloatBetween(sourceRoom.visualRng,lo,hi)end}
            end
        end
    end

    local function configureEncounterOptions(run, encounter, sourceRoom, options)
        if run.character and not run.characterProfile.originalV4 then
            options.cardRandomSeed=run.runSeed
            options.enableStances=true
            options.orbSlots=math.max(run.character=='defect'and 3 or 0,run.masterMaxOrbs or 0)
            -- Normal rooms supply the exact room stream; explicit replay battles
            -- use an explicitly named independent stream, never the legacy LCG.
            options.orbRandomSeed = run.runSeed
        end
        configureSourceRoom(encounter,sourceRoom,options)
    end

    local function validateEncounter(run, encounter, sourceRoom)
        if run.phase ~= "map" then return false, "not_on_map" end
        if not encounter then return false, "unknown_encounter" end
        local generation = run.combatGeneration or 0
        if type(generation) ~= "number" or generation % 1 ~= 0 or generation < 0 or generation >= 2147483647 then
            return false, "invalid_combat_generation"
        end
        if not sourceRoom and (run.floor < encounter.minFloor or run.floor > encounter.maxFloor) then return false, "wrong_floor" end
        return true,generation
    end

    local function startEncounter(run, encounter, sourceRoom)
        local valid,generation=validateEncounter(run,encounter,sourceRoom)
        if not valid then return false,generation end
        local opening, reason = Inventory.opening(run.data.relics.relics, run.relics,
            run.relicCounters,{tier=encounter.tier})
        if not opening then return false, reason end
        local bonus
        bonus, reason = Inventory.energyBonus(run.data.relics.relics, run.relics, encounter.tier)
        if not bonus then return false, reason end
        local combatData = {}
        for key, value in pairs(run.data) do combatData[key] = value end
        combatData.rules = Combat.copy(run.data.rules)
        combatData.rules.player.drawPerTurn=combatData.rules.player.drawPerTurn+require('abyss_boss_relics').drawBonus(run)
        combatData.rules.player.energyPerTurn = combatData.rules.player.energyPerTurn + 0.0 + bonus
        if combatData.rules.player.energyPerTurn > 2147483647 then return false, "invalid_relic_energy" end
        local enemies, nextMiscRng = encounterEnemies(run, encounter, sourceRoom)
        local battle
        local options={cardRandomSeed=RunSeed.forFloor(run.runSeed,run.floor),shuffleSeed=RunSeed.forFloor(run.runSeed,run.floor),seed=run.seed,hp=run.hp,maxHp=run.maxHp,gold=run.gold,deck=run.deck,enemies=enemies,
            masterDeck=run.deck,nextMasterDeckUid=run.nextDeckUid,miscRng=nextMiscRng or run.miscRng,cardRng=run.cardRng,
            beforeOpeningDraw=function(state)
                if opening.preDraw then
                    local ok, openingReason = Inventory.applyOpening(state,opening.preDraw)
                    if not ok then return false, openingReason end
                end
                return Inventory.applyOpening(state,opening.beforeDraw)
            end}
        options.beforeFirstTurn=function(state)
            state.potionRng=run.shopRng and EventRandom.cloneState(run.shopRng.potion)or EventRandom.fromSeed(run.runSeed)
            state.potionCharacter=require('abyss_potion_random').character(run)
            state.potionInventory=Combat.copy(run.potions)
            state.potionCapacity=run.potionSlots or run.data.rules.player.potionSlots
            if opening.preBattle then
                local ok,why=Inventory.applyOpening(state,opening.preBattle)
                if not ok then return false,why end
            end
            require('abyss_boss_relics').preBattle(state,run)
            return true
        end
        configureEncounterOptions(run, encounter, sourceRoom, options)
        battle, reason = Combat.new(combatData, options)
        if not battle then return false, reason end
        -- Queue-tail relics follow the ordinary draw, retaining their held order.
        local ok
        ok, reason = Inventory.applyOpening(battle, opening.afterDraw)
        if not ok then return false, reason end
        require('abyss_card_actions').drain(Combat,battle)
        run.combatGeneration = generation + 1
        battle.combatGeneration=run.combatGeneration
        run.combat, run.encounterId, run.encounterTier = battle, encounter.id, encounter.tier
        run.relicCounters=Combat.copy(battle.relicCounters)
        run.encounterSource,battle.encounterSource=encounter.source,encounter.source
        if nextMiscRng then run.miscRng = nextMiscRng end
        run.phase = "combat"
        run.eventCombat = nil
        run.emeraldCombat = nil
        run.pendingCombatRewards = nil
        return true
    end

    -- Explicit-ID development/replay entry; ordinary map rooms use startRoomCombat.
    -- Historical medium_slimes and fixed-color examples never enter the source pool.
    function Run.startCombat(run,encounterId)
        return startEncounter(run,find(run.data.enemies.encounters,encounterId))
    end

    function Run.roomStreams(run,floor)
        local seed=RunSeed.forFloor(run.runSeed,floor)
        return {seed=seed,monsterHpRng=EventRandom.fromSeed(seed),aiRng=EventRandom.fromSeed(seed),
            shuffleRng=EventRandom.fromSeed(seed),cardRandomRng=EventRandom.fromSeed(seed),
            miscRng=EventRandom.fromSeed(seed),visualRng=EventRandom.fromSeed(seed)}
    end

    function Run.prepareEventEncounter(run,source,floor,misc)
        return EventCombat.prepare(run,source,floor,Run.roomStreams,misc)
    end

    function Run.startEventCombat(run)
        return Run.transaction(run,function(staged)
            return EventCombat.start(staged,staged.nodeFlow,Run,startEncounter)
        end)
    end

    local function endingQualified(run)
        local keys=run.keys
        if run.campaign~=true or run.endingUnlocked~=true or type(keys)~='table' or getmetatable(keys)~=nil then return false end
        for key in pairs(keys)do if key~='ruby'and key~='emerald'and key~='sapphire'then return false end end
        return keys.ruby==true and keys.emerald==true and keys.sapphire==true
    end
    local function endingBoss(run)
        local boss=run.bossInitialization
        if type(boss)~='table'or getmetatable(boss)~=nil or boss.profile~='ending'
            or type(boss.bossList)~='table'or getmetatable(boss.bossList)~=nil or #boss.bossList~=3 then
            return false,'unsupported_boss_initialization'
        end
        for key,value in pairs(boss.bossList)do
            if type(key)~='number'or key%1~=0 or key<1 or key>3 or value~='The Heart'then return false,'unsupported_boss_initialization'end
        end
        return true
    end

    local function endingRoom(run,tier)
        if not endingQualified(run)then return false,'ending_keys_required'end
        if not(tier=='elite'and run.floor==54 or tier=='boss'and run.floor==55)then return false,'ending_room_unavailable'end
        local ok,queue=pcall(EncounterQueue.snapshot,run.encounters)
        if not ok or queue.act~=4 or queue.rawSeed~=run.runSeed or #queue.normal~=3
            or #queue.elite~=(tier=='elite'and 3 or 2)then return false,'encounter_act_mismatch'end
        return endingBoss(run)
    end

    local function resolveAct3Boss(run,tier)
        local encounter
        if run.floor~=50 or not run.bossInitialization or type(run.bossInitialization.bossList)~='table' then
            return nil,'unsupported_boss_initialization'
        end
        local resolved,reason=require('abyss_act3_bosses').resolve(run.bossInitialization.bossList[1],tier)
        if not resolved then return nil,reason or 'act_content_unavailable'end
        encounter=resolved
        return encounter
    end

    local function resolveAct2Boss(run,tier)
        local encounter
        if run.floor~=33 or not run.bossInitialization or type(run.bossInitialization.bossList)~='table' then
            return nil,'unsupported_boss_initialization'
        end
        encounter=require('abyss_act2_enemies').resolve(run.bossInitialization.bossList[1],tier)
        if not encounter then return nil,'act_content_unavailable' end
        return encounter
    end

    local function resolveBoss(run,tier,act)
        local encounter
        if act==4 then
            encounter=require('abyss_act4_enemies').resolve(run.bossInitialization.bossList[1],tier)
        elseif act==3 then
            return resolveAct3Boss(run,tier)
        elseif act==2 then
            return resolveAct2Boss(run,tier)
        elseif run.floor~=16 or not run.bossInitialization or type(run.bossInitialization.bossList)~='table'
            or (run.bossInitialization.profile~='guardian-unseen' and run.bossInitialization.profile~='source-history'
                and run.bossInitialization.profile~='source-unlocked') then
            return nil,'unsupported_boss_initialization'
        else
            encounter=require('abyss_act1_bosses').resolve(run.bossInitialization.bossList[1],tier)
            if not encounter then return nil,'act_content_unavailable' end
        end
        return encounter
    end

    local function resolveEncounter(run,tier,act)
        local encounter,nextQueue
        if tier=='boss' then
            local why
            encounter,why=resolveBoss(run,tier,act)
            if not encounter and act~=4 then return nil,nil,why,false end
        else
            local source,reason
            local valid
            valid,source,nextQueue,reason=pcall(EncounterQueue.consume,run.encounters,tier)
            if not valid then return nil,nil,'invalid_encounter_state',false end
            if not source then return nil,nil,reason,false end
            if act==4 then encounter,reason=require('abyss_act4_enemies').resolve(source,tier)
            elseif act==3 then encounter,reason=require('abyss_act3_enemies').resolve(source,tier)
            elseif act==2 then encounter,reason=require('abyss_act2_enemies').resolve(source,tier)
            else encounter,reason=RoomEncounters.resolve(source,tier) end
            if not encounter then return nil,nil,reason,false end
        end
        return encounter,nextQueue,nil,true
    end

    local function validateRoomBoundary(run, act)
        if type(run.roomGeneration)~='number' or run.roomGeneration%1~=0
            or run.roomGeneration<0 or run.roomGeneration>=2147483647 then return false,'invalid_room_generation' end
        if type(run.encounters)~='table' or run.encounters.rawSeed~=run.runSeed then return false,'run_seed_mismatch' end
        local chapter=Acts.get(act)
        local first,last=chapter.first,chapter.boss
        if type(run.floor)~='number' or run.floor%1~=0 or run.floor<first or run.floor>last then return false,'wrong_floor' end
        return true
    end

    local function validateRoom(run)
        if run.phase~='map' then return false,'not_on_map' end
        local act=run.act or 1
        if Acts.isCompetition(run) and act~=1 and act~=2 then return false,'competition_act_limit' end
        if act~=1 and act~=2 and act~=3 and act~=4 then return false,'act_content_unavailable' end
        local valid,why=validateRoomBoundary(run,act)
        if not valid then return false,why end
        return true,act
    end

    function Run.startRoomCombat(run,tier,emeraldBoost)
        local valid,act=validateRoom(run)
        if not valid then return false,act end
        if act==4 then
            local ready,why=endingRoom(run,tier);if not ready then return false,why end
            if emeraldBoost~=nil then return false,'invalid_emerald_combat_owner'end
        end
        local encounter,nextQueue,why,resolved=resolveEncounter(run,tier,act)
        if not resolved then return false,why end
        local staged={};for k,v in pairs(run)do staged[k]=v end
        local ready,room=pcall(Run.roomStreams,run,run.floor)
        if not ready then return false,'invalid_room_seed' end
        if emeraldBoost~=nil then
            if tier~='elite' then return false,'invalid_emerald_combat_owner'end
            room.emeraldBoost=Combat.copy(emeraldBoost)
        end
        local called,ok,reason=pcall(startEncounter,staged,encounter,room)
        if not called then return false,'combat_unavailable' end
        if not ok then return false,reason end
        staged.miscRng=room.miscRng
        for _,key in ipairs({'combat','combatGeneration','encounterId','encounterTier','encounterSource','phase','miscRng','relicCounters','eventCombat','emeraldCombat'})do run[key]=staged[key]end
        if nextQueue then run.encounters=nextQueue end
        run.roomGeneration=run.roomGeneration+1
        run.pendingCombatRewards=nil
        return true
    end

    -- Queue checkpoint boundary only, not exit/resume or a complete Run save file.
    function Run.snapshotEncounters(run)
        return {version=2,runSeed=run.runSeed,floor=run.floor,roomGeneration=run.roomGeneration,
            queue=EncounterQueue.snapshot(run.encounters)}
    end
    local function checkpointFields(snapshot)
        for k in pairs(snapshot)do if k~='version' and k~='runSeed' and k~='floor' and k~='roomGeneration' and k~='queue' then return false end end
        return true
    end

    local function validateCheckpoint(run, snapshot)
        if run.phase~='map' or (run.nodeFlow and not run.nodeFlow.complete) then return false,'node_pending' end
        if type(snapshot)~='table' or getmetatable(snapshot)~=nil then return false,'invalid_snapshot' end
        if not checkpointFields(snapshot) then return false,'invalid_snapshot' end
        if snapshot.version~=2 then return false,'invalid_snapshot' end
        if snapshot.runSeed~=run.runSeed then return false,'run_seed_mismatch' end
        if snapshot.floor~=run.floor then return false,'floor_mismatch' end
        if type(snapshot.roomGeneration)~='number' or snapshot.roomGeneration%1~=0
            or snapshot.roomGeneration<0 or snapshot.roomGeneration>2147483647
            or snapshot.roomGeneration~=run.roomGeneration then return false,'stale_encounter_checkpoint' end
        return true
    end

    function Run.restoreEncounters(run,snapshot)
        local valid,why=validateCheckpoint(run,snapshot)
        if not valid then return false,why end
        local ok,queue=pcall(EncounterQueue.restore,snapshot.queue)
        if not ok or queue.rawSeed~=run.runSeed then return false,'invalid_snapshot' end
        if (queue.act or 1)~=(run.act or 1) then return false,'encounter_act_mismatch' end
        -- A generation tag alone cannot authorize rewinding queue consumption.
        -- This API replaces a checkpoint at the current boundary, not Run progress.
        if type(run.encounters)~='table' or type(run.encounters.normal)~='table' or type(run.encounters.elite)~='table'
            or #queue.normal~=#run.encounters.normal or #queue.elite~=#run.encounters.elite then
            return false,'encounter_progress_mismatch'
        end
        run.encounters=queue
        return true
    end


    return {endingQualified=endingQualified, endingRoom=endingRoom}

end

return M
