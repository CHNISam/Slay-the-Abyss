-- Prepare, stage and commit room entry inside the caller-owned Run transaction.
local Run = require("abyss_run")
local Map = require("abyss_map")
local Combat = require("abyss_combat")

local Unknown = require("abyss_unknown")
local EventPool = require("abyss_event_pool")
local EventRandom = require("abyss_sts_random")
local Inventory = require("abyss_inventory")
local Shop = require("abyss_shop")

local CardRandom = require("abyss_card_random")

local Fountain = require('abyss_fountain')
local RelicHooks = require('abyss_relic_hooks')
local Act1Events = require('abyss_act1_events')
local Act2Events = require('abyss_act2_events')
local Act3Events = require('abyss_act3_events')
local Match=require('abyss_match_event')
local Acts = require('abyss_acts')
local Treasure=require('abyss_treasure')

local EmeraldRewards=require('abyss_emerald_rewards')
local Common=require('abyss_nodes_common')
local find,owns=Common.find,Common.owns
local endingKeyEligible=Common.endingKeyEligible

local matchingMap=Common.matchingMap

local battleKinds = { combat = true, elite = true, boss = true }

return function(M)
    local function unownedRelics(run,roomFloor)
        local result = {}
        for _, relic in ipairs(run.data.relics.relics) do
            if (relic.rarity=='common' or relic.rarity=='uncommon' or relic.rarity=='rare')
                and ((relic.id~='darkstone_periapt' and relic.sourceId~='Darkstone Periapt') or roomFloor<=48)
                and (relic.id~='toxic_egg' and relic.id~='molten_egg' or (roomFloor or run.floor or 1)<=48)
                and not owns(run.relics, relic.id) then result[#result + 1] = relic.id end
        end
        table.sort(result)
        return result
    end

    local function goldenAttack(run)
        for _,card in ipairs(run.deck) do
            local def=find(run.data.cards.cards,card.cardId)
            if def and def.type=='attack' then
                local effects=card.upgraded and def.upgrade and def.upgrade.effects or def.effects
                for _,effect in ipairs(effects) do
                    if (effect.op=='damage' or effect.op=='damageAll')
                        and (effect.value or 0)>=run.data.rules.events.golden_wing.attackThreshold then return true end
                end
            end
        end
        return false
    end

    local function prepareEvent(run,node,flow,miscRng)
        local id=node.eventId or run.data.rules.events.encounterId
        flow.event = { id = id }
        if id=='match_game' then
            local prepared,why=Match.prepare(run,flow.event,miscRng,node.floor)
            assert(prepared,why)
        end
        if Act1Events.ids[id] then Act1Events.prepare(run,flow.event,miscRng) end
        if Act2Events.ids[id] then Act2Events.prepare(run,flow.event) end
        if Act3Events.ids[id] then Act3Events.prepare(run,flow.event,miscRng) end
        if flow.event.constructorEncounter then
            local prepared,why=Run.prepareEventEncounter(run,flow.event.constructorEncounter,node.floor,miscRng)
            assert(prepared,why);flow.event.preparedCombat=prepared
        end
        if id=='goop' then
            local r=run.data.rules.events.goop
            flow.event.goldLoss=math.min(run.gold,EventRandom.randomIntBetween(miscRng,r.lossMin,r.lossMax))
        elseif id=='shining_light' then
            flow.event.damage=math.floor(EventRandom.float32(run.maxHp*EventRandom.float32(run.data.rules.events.shining_light.damagePercent/100))+.5)
        elseif id=='golden_wing' then flow.event.canAttack=goldenAttack(run) end
    end

    local function prepareBossReward(run,flow,random)
        local pool, choices = {}, {}
        for _, relic in ipairs(run.data.relics.relics) do
            if Inventory.bossEligible(relic, run.relics) then pool[#pool + 1] = relic.id end
        end
        table.sort(pool)
        for _ = 1, math.min(3, #pool) do
            choices[#choices + 1] = table.remove(pool, Combat.random(random, #pool))
        end
        flow.reward = { relics = choices }
    end

    local function prepare(run, node, miscRng)
        local flow = { id = node.id, floor = node.floor, type = node.type, roomKind = node.roomKind, complete = false,
            encounterId = node.encounterId }
        local random = { seed = run.seed }
        if node.type == "camp" then
            flow.upgradesLeft = run.data.rules.camp.upgradeCount
        elseif node.type == "shop" then
            for k,v in pairs(Shop.prepare(run,node.floor)) do flow[k]=v end
        elseif node.type=='treasure' and run.relicPool then
            local prepared,why=Treasure.create(run,{floor=node.floor,boss=node.roomKind=='boss_treasure'})
            assert(prepared,why)
            for _,key in ipairs({'treasureRng','relicPool','cardRng','relicCounters'})do run[key]=prepared[key]end
            flow.chest,flow.reward=prepared.chest,prepared.reward
        elseif node.roomKind == "boss_treasure" then
            prepareBossReward(run,flow,random)
        elseif node.type == "treasure" then
            local relics = unownedRelics(run,node.floor)
            flow.reward = #relics > 0 and { relicId = relics[Combat.random(random, #relics)] }
                or { gold = run.data.rules.rewards.normalGold }
            -- Preserve the legacy generation above. Only its actual base relic is
            -- linked; gold fallback and Boss chests never synthesize a free key.
            if flow.reward.relicId and endingKeyEligible(run,'sapphire') then
                flow.reward.sapphireKey={relicId=flow.reward.relicId}
            end
        elseif node.type == "event" then prepareEvent(run,node,flow,miscRng)
        end
        return flow, random.seed
    end

    function M.available(run, map)
        if (run.act or 1)~=(map.act or 1) or run.runSeed~=map.runSeed or run.phase ~= "map" or (run.nodeFlow and not run.nodeFlow.complete)
            or not matchingMap(run.nodeFlow, map) then return {} end
        return Map.available(map)
    end

    local function validateEntryIdentity(run,map)
        if (run.act or 1)~=(map.act or 1) or run.runSeed~=map.runSeed
            or not matchingMap(run.nodeFlow,map) then return false,'map_mismatch' end
        return true
    end

    local function validateRunEntry(run,map)
        if Acts.isCompetition(run) and run.act~=1 and run.act~=2 then return false,'competition_act_limit' end
        if run.nodeFlow and not run.nodeFlow.complete then return false,'node_pending' end
        if run.phase~='map' then return false,'not_on_map' end
        if type(run.roomGeneration)~='number' or run.roomGeneration%1~=0
            or run.roomGeneration<0 or run.roomGeneration>=2147483647 then return false,'invalid_room_generation' end
        return validateEntryIdentity(run,map)
    end

    local function entryNode(run,map,nodeId)
        local node=find(map.nodes,nodeId)
        if not node then return nil,'invalid_node' end
        if not find(Map.available(map),nodeId) then return nil,'node_unavailable' end
        if node.roomKind=='boss_treasure' and (node.floor~=Acts.get(run.act or 1).last
            or not run.nodeFlow or run.nodeFlow.type~='boss' or run.nodeFlow.result~='boss_victory') then
            return nil,'boss_treasure_unavailable'
        end
        return node
    end

    local function endingDoor(run)
        local keys=run.keys or {}
        return run.endingUnlocked==true and keys.ruby==true and keys.emerald==true and keys.sapphire==true
    end

    local function enterEnding(run,map,node)
        if run.campaign~=true or run.act~=3 or node.floor~=51 or not run.nodeFlow
            or run.nodeFlow.type~='boss' or run.nodeFlow.result~='boss_victory' then return false,'ending_unavailable' end
        assert(Map.choose(map,node.id))
        local door=endingDoor(run)
        run.floor,run.phase,run.pendingAct=51,door and 'act_transition' or 'victory',door and 4 or nil
        run.nodeFlow={id=node.id,floor=51,type='event',roomKind='ending',complete=true,
            mapSeed=map.seed,mapSignature=map.sourceSignature,result=door and 'ending_door' or 'normal_victory'}
        run.roomGeneration=run.roomGeneration+1
        run.pendingCombatRewards=nil
        return true
    end

    local function drawEvent(run,c)
        c.selectionRng=EventRandom.atCounter(run.eventSeed,c.nextEventRng.counter)
        local originalId,reason=EventPool.draw(c.nextUnknown.pools,{floor=c.node.floor,gold=run.gold,act=run.act or 1,
            hp=run.hp,relicCount=#run.relics,elapsedSeconds=run.elapsedSeconds,cursed=Fountain.isCursed(run)},c.selectionRng)
        if not originalId then return false,reason end
        c.node.eventId=EventPool.contentId[originalId]
        if not c.node.eventId then return false,'event_not_implemented' end
        c.node.originalEventId=originalId
        return true
    end

    local function resolveUnknown(run,c)
        local node=c.node
        if node.type~='event' or node.eventId or run.data.rules.events.encounterId then return true end
        c.nextUnknown=Combat.copy(run.unknown)
        c.nextEventRng=EventRandom.cloneState(run.eventRng)
        local kind=Unknown.advancePc(c.nextUnknown.chances,EventRandom.randomFloat(c.nextEventRng),{
            previousRoom=run.nodeFlow and run.nodeFlow.type,
            tinyChest=owns(run.relics,'tiny_chest'),juzu=owns(run.relics,'juzu_bracelet')})
        c.node=Combat.copy(node)
        c.node.type=kind=='monster' and 'combat' or kind
        if kind=='event' then return drawEvent(run,c) end
        return true
    end

    local legacyEvents={cleric=true,purifier=true,goop=true,upgrade_shrine=true,golden_wing=true,
        shining_light=true,golden_shrine=true,living_wall=true,fountain=true}
    local function validateEvent(run,node)
        if node.type~='event' then return true end
        local id=node.eventId or run.data.rules.events.encounterId
        if not legacyEvents[id] and not Act1Events.ids[id] and not Act2Events.ids[id]
            and not Act3Events.ids[id] and id~='match_game' then return false,'event_unavailable' end
        if Act3Events.ids[id] and run.act~=3 then return false,'event_unavailable' end
        if id=='cleric' and run.gold<run.data.rules.events.cleric.minGold then return false,'event_unavailable' end
        return true
    end

    local function prepareFlow(run,c)
        local ok,reason=resolveUnknown(run,c);if not ok then return false,reason end
        ok,reason=validateEvent(run,c.node);if not ok then return false,reason end
        RelicHooks.onEnterRoom(run,c.node.type,'entered')
        local prepared,flow,seed=pcall(prepare,run,c.node,c.nextMiscRng)
        if not prepared then return false,'node_content_unavailable' end
        if flow.type=='shop' and not pcall(CardRandom.snapshot,flow.cardRandom) then return false,'node_content_unavailable' end
        flow.sourceType=c.sourceType
        if c.selectionRng then
            flow.selectionRng=EventRandom.snapshot(c.selectionRng)
            flow.event.originalId=c.node.originalEventId
        end
        c.flow,c.seed=flow,seed
        return true
    end

    local function prepareEmerald(run,map,nodeId,c)
        if not c.node.hasEmeraldKey then return true end
        local boost,_,reason=Map.prepareEmeraldBoost(map,nodeId)
        if not boost then return false,reason end
        c.emeraldBoost=boost
        local context=Run.mapContext(run)
        if not context or not context.endingUnlocked or context.emeraldOwned or run.keys.emerald
            or run.endingUnlocked~=true then return false,'ending_history_required' end
        return true
    end

    local function stageCombat(run,c)
        if not battleKinds[c.node.type] then
            run.floor,run.phase,run.seed=c.node.floor,'node',c.seed
            return true
        end
        -- The destination floor and room stream stay private until setup succeeds.
        local stagedRun={}
        for key,value in pairs(run)do stagedRun[key]=value end
        stagedRun.floor,stagedRun.miscRng=c.node.floor,c.nextMiscRng
        local tier=c.node.type=='combat' and 'normal' or c.node.type
        local called,ok,reason=pcall(Run.startRoomCombat,stagedRun,tier,c.emeraldBoost and c.emeraldBoost.effect)
        if not called or not ok then return false,called and reason or 'combat_unavailable' end
        c.nextMiscRng=stagedRun.miscRng
        c.flow.encounterId,c.flow.encounterSource=stagedRun.encounterId,stagedRun.encounterSource
        c.stagedRun=stagedRun
        return true
    end

    local function commitEmerald(map,nodeId,c)
        if not c.emeraldBoost then return true end
        local ok,reason=Map.commitEmeraldBoost(map,nodeId,c.emeraldBoost)
        if not ok then return false,reason end
        local owner;owner,reason=EmeraldRewards.bind(c.stagedRun,c.emeraldBoost)
        if not owner then return false,reason end
        c.stagedRun.emeraldCombat=owner
        c.flow.emeraldBoost=Combat.copy(c.emeraldBoost)
        return true
    end

    local function commitCombat(run,stagedRun)
        if not stagedRun then run.roomGeneration=run.roomGeneration+1;return end
        run.floor,run.phase,run.combat=stagedRun.floor,stagedRun.phase,stagedRun.combat
        run.encounterId,run.encounterTier=stagedRun.encounterId,stagedRun.encounterTier
        run.encounterSource,run.encounters=stagedRun.encounterSource,stagedRun.encounters
        run.relicCounters=stagedRun.relicCounters
        run.eventCombat=stagedRun.eventCombat
        run.emeraldCombat=stagedRun.emeraldCombat
        run.combatGeneration=stagedRun.combatGeneration
        run.roomGeneration=stagedRun.roomGeneration
        run.combatGeneration=stagedRun.combatGeneration
    end

    local function commitRoom(run,map,c)
        commitCombat(run,c.stagedRun)
        local flow=c.flow
        flow.mapSeed,flow.mapSignature=map.seed,map.sourceSignature
        if c.nextUnknown then run.unknown,run.eventRng=c.nextUnknown,c.nextEventRng end
        run.miscRng=c.nextMiscRng
        run.nodeFlow=flow
        if not c.emeraldBoost then run.emeraldCombat=nil end
        if flow.type=='shop' then
            run.relicPool=flow.relicPool;flow.relicPool=nil
            run.shopRng=flow.shopRng
            CardRandom.commit(run,flow.cardRandom)
            flow.cardRandom=nil
        end
        -- Only successful entry expires the old room's unclaimed rewards.
        run.pendingCombatRewards=nil
        return true
    end

    local function enter(run,map,nodeId)
        local ok,reason=validateRunEntry(run,map);if not ok then return false,reason end
        local node;node,reason=entryNode(run,map,nodeId);if not node then return false,reason end
        if node.roomKind=='ending' then return enterEnding(run,map,node) end
        if not battleKinds[node.type] and node.type~='camp' and node.type~='shop'
            and node.type~='event' and node.type~='treasure' then return false,'unknown_node_type' end
        local sourceType=node.type
        RelicHooks.onEnterRoom(run,sourceType,'enter')
        local c={node=node,sourceType=sourceType,nextMiscRng=Run.roomStreams(run,node.floor).miscRng}
        ok,reason=prepareFlow(run,c);if not ok then return false,reason end
        ok,reason=prepareEmerald(run,map,nodeId,c);if not ok then return false,reason end
        ok,reason=stageCombat(run,c);if not ok then return false,reason end
        assert(Map.choose(map,nodeId))
        ok,reason=commitEmerald(map,nodeId,c);if not ok then return false,reason end
        return commitRoom(run,map,c)
    end

    return enter
end
