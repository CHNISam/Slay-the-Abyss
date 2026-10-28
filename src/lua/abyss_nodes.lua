-- Seven node flows over the existing same-run state. Adapters must navigate via enter/available.
-- Battle commands/reward selection remain Run commands, followed by completeCombat.
-- Combat relic effects and persistence restoration belong to their owning modules.
local Run = require("abyss_run")
local Map = require("abyss_map")
local Combat = require("abyss_combat")
local Capability = require("abyss_card_capability")
local Unknown = require("abyss_unknown")
local EventPool = require("abyss_event_pool")
local EventRandom = require("abyss_sts_random")
local Inventory = require("abyss_inventory")
local Shop = require("abyss_shop")
local External=require('abyss_external_random')

local CardRandom = require("abyss_card_random")
local CardPool = require('abyss_card_pool')
local LivingWall = require('abyss_living_wall')
local Fountain = require('abyss_fountain')
local RelicHooks = require('abyss_relic_hooks')
local Act1Events = require('abyss_act1_events')
local Act2Events = require('abyss_act2_events')
local Act3Events = require('abyss_act3_events')
local Acts = require('abyss_acts')
local Treasure=require('abyss_treasure')
local Neow=require('abyss_neow')
local TreasureSource=require('abyss_treasure_source')
local EmeraldRewards=require('abyss_emerald_rewards')
local M = {}
local battleKinds = { combat = true, elite = true, boss = true }

local function find(entries, id, field)
    for i, entry in ipairs(entries) do if entry[field or "id"] == id then return entry, i end end
end

local function owns(entries, id)
    for _, owned in ipairs(entries) do if owned == id then return true end end
    return false
end

-- Both camp Recall and the linked chest choice consume the same existing
-- campaign/history input. Neither command creates or persists qualification.
local function endingKeyEligible(run,key)
    if run.campaign~=true then return false,'campaign_unavailable' end
    if run.act~=1 and run.act~=2 and run.act~=3 and run.act~=4 then return false,'invalid_act' end
    if run.endingUnlocked~=true then return false,'ending_history_required' end
    local keys=run.keys
    if type(keys)~='table' or getmetatable(keys)~=nil or type(keys.ruby)~='boolean'
        or type(keys.emerald)~='boolean' or type(keys.sapphire)~='boolean' then return false,'invalid_keys' end
    if keys[key] then return false,key..'_key_owned' end
    return true
end

local function playable(card)
    return card.type ~= "status" and card.type ~= "curse"
        and Capability.isImplemented(card)
end

local function upgradeable(run, instance)
    local definition = find(run.data.cards.cards, instance.cardId)
    if instance.upgraded and not (definition and definition.repeatable) then return false end
    if not definition or not definition.upgrade or not next(definition.upgrade) then return false end
    local upgraded = Combat.copy(definition)
    for key, value in pairs(definition.upgrade) do upgraded[key] = value end
    return playable(upgraded)
end

local function upgradeCards(run)
    local result = {}
    for _, instance in ipairs(run.deck) do
        if upgradeable(run, instance) then result[#result + 1] = Combat.copy(instance) end
    end
    return result
end

local function healingPreview(run,amount)
    if require('abyss_potion_health').blocked(run.relics)then return 0 end
    return math.min(run.maxHp-run.hp,amount)
end

local function matchingMap(flow, map)
    return not flow or (flow.mapSeed == map.seed and flow.mapSignature == map.sourceSignature
        and flow.id == map.currentNodeId and flow.floor == map.floor)
end

local function pending(run, kind)
    local flow = run.nodeFlow
    if not flow or flow.complete then return nil, "no_pending_node" end
    if flow.type ~= kind or run.phase ~= "node" then return nil, "wrong_node_type" end
    return flow
end

local function complete(run, result)
    run.nodeFlow.complete, run.nodeFlow.result = true, result or "complete"
    run.phase = "map"
    return true, run.nodeFlow.result
end

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
        local pool, choices = {}, {}
        for _, relic in ipairs(run.data.relics.relics) do
            if Inventory.bossEligible(relic, run.relics) then pool[#pool + 1] = relic.id end
        end
        table.sort(pool)
        for _ = 1, math.min(3, #pool) do
            choices[#choices + 1] = table.remove(pool, Combat.random(random, #pool))
        end
        flow.reward = { relics = choices }
    elseif node.type == "treasure" then
        local relics = unownedRelics(run,node.floor)
        flow.reward = #relics > 0 and { relicId = relics[Combat.random(random, #relics)] }
            or { gold = run.data.rules.rewards.normalGold }
        -- Preserve the legacy generation above. Only its actual base relic is
        -- linked; gold fallback and Boss chests never synthesize a free key.
        if flow.reward.relicId and endingKeyEligible(run,'sapphire') then
            flow.reward.sapphireKey={relicId=flow.reward.relicId}
        end
    elseif node.type == "event" then
        local id=node.eventId or run.data.rules.events.encounterId
        flow.event = { id = id }
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
    return flow, random.seed
end

function M.available(run, map)
    if (run.act or 1)~=(map.act or 1) or run.runSeed~=map.runSeed or run.phase ~= "map" or (run.nodeFlow and not run.nodeFlow.complete)
        or not matchingMap(run.nodeFlow, map) then return {} end
    return Map.available(map)
end

local function enter(run, map, nodeId)
    if run.nodeFlow and not run.nodeFlow.complete then return false, "node_pending" end
    if run.phase ~= "map" then return false, "not_on_map" end
    if type(run.roomGeneration)~='number' or run.roomGeneration%1~=0
        or run.roomGeneration<0 or run.roomGeneration>=2147483647 then return false,'invalid_room_generation' end
    if (run.act or 1)~=(map.act or 1) or run.runSeed~=map.runSeed or not matchingMap(run.nodeFlow, map) then return false, "map_mismatch" end
    local node = find(map.nodes, nodeId)
    if not node then return false, "invalid_node" end
    if not find(Map.available(map), nodeId) then return false, "node_unavailable" end
    -- A Boss chest is earned only after that Boss's card reward is resolved.
    if node.roomKind == "boss_treasure" and (node.floor ~= Acts.get(run.act or 1).last
        or not run.nodeFlow or run.nodeFlow.type ~= "boss" or run.nodeFlow.result ~= "boss_victory") then
        return false, "boss_treasure_unavailable"
    end
    if node.roomKind=='ending' then
        if run.campaign~=true or run.act~=3 or node.floor~=51 or not run.nodeFlow
            or run.nodeFlow.type~='boss' or run.nodeFlow.result~='boss_victory' then return false,'ending_unavailable' end
        assert(Map.choose(map,nodeId))
        local keys=run.keys or {}
        local door=run.endingUnlocked==true and keys.ruby==true and keys.emerald==true and keys.sapphire==true
        run.floor,run.phase,run.pendingAct=51,door and 'act_transition' or 'victory',door and 4 or nil
        run.nodeFlow={id=node.id,floor=51,type='event',roomKind='ending',complete=true,
            mapSeed=map.seed,mapSignature=map.sourceSignature,result=door and 'ending_door' or 'normal_victory'}
        run.roomGeneration=run.roomGeneration+1
        run.pendingCombatRewards=nil
        return true
    end
    if not battleKinds[node.type] and node.type ~= "camp" and node.type ~= "shop"
        and node.type ~= "event" and node.type ~= "treasure" then return false, "unknown_node_type" end
    local sourceType=node.type
    -- Source onEnterRoom runs before an unknown room resolves or an event
    -- checks eligibility. justEnteredRoom uses its resolved room afterwards.
    RelicHooks.onEnterRoom(run,sourceType,'enter')
    local nextUnknown,nextEventRng,nextMiscRng
    -- nextRoomTransition reconstructs misc from raw run seed + destination
    -- floor for every room, before event constructors or encounter assembly.
    nextMiscRng=Run.roomStreams(run,node.floor).miscRng
    local selectionRng
    if node.type=='event' and not node.eventId and not run.data.rules.events.encounterId then
        nextUnknown=Combat.copy(run.unknown)
        nextEventRng=EventRandom.cloneState(run.eventRng)
        local kind=Unknown.advancePc(nextUnknown.chances,EventRandom.randomFloat(nextEventRng),{
            previousRoom=run.nodeFlow and run.nodeFlow.type,
            tinyChest=owns(run.relics,'tiny_chest'),juzu=owns(run.relics,'juzu_bracelet')})
        node=Combat.copy(node)
        node.type=kind=='monster' and 'combat' or kind
        if kind=='event' then
            selectionRng=EventRandom.atCounter(run.eventSeed,nextEventRng.counter)
            local originalId,reason=EventPool.draw(nextUnknown.pools,{floor=node.floor,gold=run.gold,act=run.act or 1,
                hp=run.hp,relicCount=#run.relics,elapsedSeconds=run.elapsedSeconds,cursed=Fountain.isCursed(run)},selectionRng)
            if not originalId then return false,reason end
            node.eventId=EventPool.contentId[originalId]
            if not node.eventId then return false,'event_not_implemented' end
            node.originalEventId=originalId
        end
    end
    if node.type == "event" then
        local id = node.eventId or run.data.rules.events.encounterId
        if id ~= "cleric" and id ~= "purifier" and id~='goop' and id~='upgrade_shrine'
            and id~='golden_wing' and id~='shining_light' and id~='golden_shrine' and id~='living_wall' and id~='fountain'
            and not Act1Events.ids[id] and not Act2Events.ids[id] and not Act3Events.ids[id] then return false, "event_unavailable" end
        if Act3Events.ids[id] and run.act~=3 then return false,'event_unavailable'end
        if id == "cleric" and run.gold < run.data.rules.events.cleric.minGold then
            return false, "event_unavailable"
        end
    end
    RelicHooks.onEnterRoom(run,node.type,'entered')
    local prepared,flow,seed=pcall(prepare,run,node,nextMiscRng)
    if not prepared then return false,'node_content_unavailable' end
    if flow.type=='shop' and not pcall(CardRandom.snapshot,flow.cardRandom) then
        return false,'node_content_unavailable'
    end
    flow.sourceType=sourceType
    if selectionRng then flow.selectionRng=EventRandom.snapshot(selectionRng);flow.event.originalId=node.originalEventId end
    local stagedRun,emeraldBoost
    if node.hasEmeraldKey then
        local preparedBoost,_,reason=Map.prepareEmeraldBoost(map,nodeId)
        if not preparedBoost then return false,reason end
        emeraldBoost=preparedBoost
        local context=Run.mapContext(run)
        if not context or not context.endingUnlocked or context.emeraldOwned or run.keys.emerald
            or run.endingUnlocked~=true then return false,'ending_history_required' end
    end
    if battleKinds[node.type] then
        -- Keep the new floor and room misc state private until real battle setup
        -- succeeds. startCombat may advance this stream when assembling a group;
        -- use that resulting state, not the pre-battle clone, at commit below.
        stagedRun = {}
        for key, value in pairs(run) do stagedRun[key] = value end
        stagedRun.floor, stagedRun.miscRng = node.floor, nextMiscRng
        local tier=node.type=='combat' and 'normal' or node.type
        local called, ok, reason = pcall(Run.startRoomCombat, stagedRun, tier,emeraldBoost and emeraldBoost.effect)
        if not called or not ok then
            return false, called and reason or "combat_unavailable"
        end
        nextMiscRng = stagedRun.miscRng
        flow.encounterId,flow.encounterSource=stagedRun.encounterId,stagedRun.encounterSource
    else
        run.floor, run.phase, run.seed = node.floor, "node", seed
    end
    assert(Map.choose(map, nodeId)) -- already validated against the unchanged map above
    if emeraldBoost then
        local ok,reason=Map.commitEmeraldBoost(map,nodeId,emeraldBoost)
        if not ok then return false,reason end
        local owner;owner,reason=EmeraldRewards.bind(stagedRun,emeraldBoost)
        if not owner then return false,reason end
        stagedRun.emeraldCombat=owner
        flow.emeraldBoost=Combat.copy(emeraldBoost)
    end
    if stagedRun then
        run.floor, run.phase, run.combat = stagedRun.floor, stagedRun.phase, stagedRun.combat
        run.encounterId, run.encounterTier = stagedRun.encounterId, stagedRun.encounterTier
        run.encounterSource,run.encounters=stagedRun.encounterSource,stagedRun.encounters
        run.relicCounters=stagedRun.relicCounters
        run.eventCombat=stagedRun.eventCombat
        run.emeraldCombat=stagedRun.emeraldCombat
        run.combatGeneration=stagedRun.combatGeneration
        run.roomGeneration=stagedRun.roomGeneration
        run.combatGeneration=stagedRun.combatGeneration
    else
        run.roomGeneration=run.roomGeneration+1
    end
    flow.mapSeed, flow.mapSignature = map.seed, map.sourceSignature
    if nextUnknown then run.unknown,run.eventRng=nextUnknown,nextEventRng end
    run.miscRng=nextMiscRng
    run.nodeFlow = flow
    if not emeraldBoost then run.emeraldCombat=nil end
    if flow.type == 'shop' then
        run.relicPool=flow.relicPool;flow.relicPool=nil
        run.shopRng=flow.shopRng
        CardRandom.commit(run,flow.cardRandom)
        flow.cardRandom=nil -- Only the Run owns the persistent card stream.
    end
    -- The old room's unclaimed rewards expire only after this entry succeeds.
    run.pendingCombatRewards = nil
    return true
end

local function validateEntryMap(run,map)
    if type(map)~='table' or getmetatable(map)~=nil then return false,'invalid_snapshot' end
    -- Chapter birth facts, not caller-supplied markers, decide whether this is
    -- a canonical map. Keep the old no-birth component API, but never let an
    -- Emerald contract manufacture its own context or downgrade a born map.
    local canonical=run.mapBirthAct~=nil or run.mapBirthContext~=nil
        or map.emeraldSelection~=nil or map.mapRng~=nil or map.emeraldBoost~=nil
    if not canonical and type(map.nodes)=='table' then
        for _,node in next,map.nodes do
            if type(node)=='table' and rawget(node,'hasEmeraldKey')~=nil then canonical=true;break end
        end
    end
    if canonical then
        local restored,reason=M.restoreMap(run,map)
        if not restored then return false,reason end
    end
    return true
end

function M.enter(run,map,nodeId)
    -- Validate the original graph/continuous stream before a copy can discard
    -- metatables and before room hooks, encounter consumption or battle setup.
    local valid,why=validateEntryMap(run,map)
    if not valid then return false,why end
    -- Map.choose and every entry hook stay private until battle setup and room
    -- preparation both succeed. Keep the public map/root/path owners stable.
    local stagedMap=Combat.copy(map)
    local ok,reason=Run.transaction(run,function(staged)return enter(staged,stagedMap,nodeId)end)
    if not ok then return false,reason end
    map.floor,map.currentNodeId=stagedMap.floor,stagedMap.currentNodeId
    if stagedMap.mapRng then
        map.mapRng,map.emeraldBoost=Combat.copy(stagedMap.mapRng),Combat.copy(stagedMap.emeraldBoost)
    end
    for i=#map.path,1,-1 do map.path[i]=nil end
    for i,id in ipairs(stagedMap.path)do map.path[i]=id end
    return true,reason
end

-- Opening is outside the map. It must not count as a visited room, spend an
-- event draw, or run room-entry relic hooks. Existing direct Run.new stays valid.
function M.beginNeow(run,map,history)
    if type(map)~='table' or type(map.path)~='table' or map.floor~=0 or map.currentNodeId~=nil or #map.path~=0 then return false,'neow_opening_unavailable' end
    return Run.transaction(run,function(staged)
        if staged.phase~='map' or staged.nodeFlow~=nil or staged.runSeed~=map.runSeed then return false,'neow_opening_unavailable' end
        local flow={type='event',roomKind='neow',mapSeed=map.seed,mapSignature=map.sourceSignature,floor=map.floor,event={id='neow'}}
        local ok,why=Neow.prepare(staged,flow.event,history);if not ok then return false,why end
        staged.nodeFlow,staged.phase,staged.floor=flow,'node',0
        staged.neowStatus='available'
        return true
    end)
end

function M.advanceAct(run,map)
    if (run.act or 1)~=(map.act or 1) or run.runSeed~=map.runSeed
        or not matchingMap(run.nodeFlow,map) then return false,'map_mismatch' end
    local nextMap
    local ok,reason=Run.transaction(run,function(staged)
        local advanced,why=Run.advanceAct(staged)
        if not advanced then return false,why end
        nextMap=Map.generate(staged.data,staged.runSeed,staged.act,assert(Run.mapContext(staged)))
        return true
    end)
    if not ok then return false,reason end
    for key in pairs(map)do map[key]=nil end
    for key,value in pairs(nextMap)do map[key]=value end
    return true
end

function M.restoreMap(run,snapshot)
    local context,reason=Run.mapContext(run)
    if not context then return nil,reason end
    if type(snapshot)~='table' or snapshot.runSeed~=run.runSeed or (snapshot.act or 1)~=(run.act or 1)then
        return nil,'map_mismatch'
    end
    return Map.restore(run.data,snapshot,context)
end

function M.endingProceedSource(run,map)
    local owner,flow=run.endingProceed,run.nodeFlow
    if run.phase~='ending_proceed' or run.act~=4 or run.floor~=55 or type(owner)~='table'
        or owner.version~=1 or owner.act~=4 or owner.floor~=55 or owner.runSeed~=run.runSeed
        or owner.encounterId~=run.encounterId or owner.combatGeneration~=run.combatGeneration
        or type(flow)~='table' or flow.type~='boss' or flow.complete~=false
        or flow.encounterId~=owner.encounterId or type(map)~='table' then return nil,'ending_proceed_source_mismatch' end
    local birth=Run.mapContext(run)
    if not birth or not birth.endingUnlocked or not birth.emeraldOwned then return nil,'ending_history_required' end
    local ok,restored=pcall(function()return M.restoreMap(run,map)end)
    if not ok or not restored or map.act~=4 or map.floor~=55 or not matchingMap(flow,map)
        or map.path[#map.path]~=flow.id then return nil,'map_mismatch' end
    local last=restored.nodes[#restored.nodes]
    if last.id~=flow.id or last.type~='boss' or last.floor~=55 then return nil,'map_mismatch' end
    return owner
end

function M.proceedEnding(run,map,expectedOwner)
    if expectedOwner==nil or not rawequal(expectedOwner,run.endingProceed) then return false,'ending_proceed_owner_mismatch' end
    local owner,reason=M.endingProceedSource(run,map)
    if not rawequal(owner,expectedOwner) then return false,reason or 'ending_proceed_owner_mismatch' end
    return Run.proceedEnding(run,expectedOwner)
end

function M.view(run, map)
    local available, mapView = M.available(run, map), Map.view(map)
    local enabled = #available > 0
    if not enabled then for _, node in ipairs(mapView.nodes) do node.available = false end end
    local node = run.nodeFlow and Combat.copy(run.nodeFlow) or nil
    if run.phase=='ending_proceed' then
        node=node or {id=map.currentNodeId,floor=55,complete=false}
        node.type,node.event,node.reward='ending_proceed',nil,nil
        node.canProceed=M.endingProceedSource(run,map)~=nil
        return {phase=run.phase,node=node,map=mapView,available={},navigationEnabled=false}
    end
    if node and not node.complete then
        node.purgeCards=LivingWall.purgeCards(run)
        if node.type == "camp" then
            node.upgradeCards = upgradeCards(run)
            node.heal = healingPreview(run,RelicHooks.campHealAmount(run,math.floor(run.maxHp * run.data.rules.camp.healPercent / 100)))
            node.dreamCatcher=RelicHooks.owns(run,'dream_catcher')
        elseif node.type == "shop" then
            node.removePrice = Shop.removePrice(run)
            node.removeAvailable = not node.removalUsed
        elseif node.type == "event" then
            local rules = run.data.rules.events[node.event.id] or {}
            node.event.removeCost = rules.removeCost or 0
            node.upgradeCards=upgradeCards(run)
            node.upgradesLeft=1
            if node.event.id=='living_wall' then node.event.purgeCards=LivingWall.purgeCards(run) end
            if node.event.id=='bonfire' then node.event.purgeCards=LivingWall.purgeCards(run) end
            if node.event.id=='transmogrifier' then node.event.purgeCards=LivingWall.purgeCards(run) end
            if node.event.id=='wheel' then node.event.purgeCards=LivingWall.purgeCards(run) end
            if Act2Events.ids[node.event.id] then Act2Events.view(run,node.event) end
            if node.event.id=='neow'then Neow.view(run,node.event)end
            if node.event.id == "cleric" then
                node.event.healCost = rules.healCost
                node.event.heal = healingPreview(run,math.floor(run.maxHp * rules.healPercent / 100))
            end
            node.event.options=M.eventOptions(run,node)
        end
    end
    return { phase = run.phase, node = node, map = mapView, available = available, navigationEnabled = enabled }
end

-- Recall uses the existing campaign/history gate. The camp UI consumes
-- this source token through its existing last-action footer.
local function campSource(run,map)
    local flow,reason=pending(run,'camp');if not flow then return nil,reason end
    if flow.campChoice~=nil or flow.restReward~=nil then return nil,'camp_choice_made' end
    if type(map)~='table' or type(map.nodes)~='table' or type(map.path)~='table'
        or type(run.runSeed)~='string' or type(flow.mapSeed)~='string' or flow.mapSeed~=run.runSeed
        or type(flow.floor)~='number' or flow.floor%1~=0 or flow.floor<1 or flow.floor>55
        or type(run.roomGeneration)~='number'
        or run.roomGeneration%1~=0 or run.roomGeneration<1 or run.roomGeneration>2147483647
        or type(flow.id)~='string' or type(flow.mapSignature)~='string' or flow.mapSignature==''
        or flow.complete~=false or run.floor~=flow.floor or run.runSeed~=map.runSeed
        or (run.act or 1)~=(map.act or 1) or map.path[#map.path]~=flow.id or not matchingMap(flow,map) then
        return nil,'camp_source_mismatch'
    end
    local node
    for _,entry in ipairs(map.nodes)do
        if type(entry)~='table' then return nil,'camp_source_mismatch' end
        if entry.id==flow.id then node=entry end
    end
    if not node or node.type~='camp' or node.floor~=flow.floor then return nil,'camp_source_mismatch' end
    return {id=flow.id,floor=flow.floor,act=run.act or 1,runSeed=run.runSeed,
        mapSeed=flow.mapSeed,mapSignature=flow.mapSignature,roomGeneration=run.roomGeneration}
end

local function recallEligible(run)
    return endingKeyEligible(run,'ruby')
end

function M.recallSource(run,map)
    local source,reason=campSource(run,map);if not source then return nil,reason end
    local eligible,why=recallEligible(run);if not eligible then return nil,why end
    return source
end

function M.recall(run,map,source)
    local current,reason=M.recallSource(run,map)
    if current then
        if type(source)~='table' or getmetatable(source)~=nil then reason='camp_source_mismatch'
        else
            for key,value in pairs(current)do
                if source[key]~=value then reason='camp_source_mismatch';break end
            end
        end
    end
    -- Preserve original-owner validation before graph copying, but pass a
    -- refused nested command through the existing transaction poison path.
    if not current or reason then return Run.transaction(run,function()return false,reason end)end
    return Run.transaction(run,function(staged)
        local accepted,detail=recallEligible(staged);if not accepted then return false,detail end
        -- No rest/forge hooks or random stream belongs to Recall. Resolve the
        -- room and its rewards, then grant only the Ruby key exactly once.
        staged.keys.ruby=true
        staged.nodeFlow.campChoice='recall'
        staged.nodeFlow.reward=nil
        return complete(staged,'recall')
    end)
end

function M.rest(run)
    return Run.transaction(run,function(staged)
        local flow,reason=pending(staged,'camp');if not flow then return false,reason end
        if flow.campChoice then return false,'camp_choice_made' end
        local healing=RelicHooks.campHealAmount(staged,math.floor(staged.maxHp*staged.data.rules.camp.healPercent/100))
        flow.restHealed=Run.heal(staged,healing)
        flow.campChoice='rest'
        flow.restReward=RelicHooks.onRest(staged,function(owner)
            -- RestRoom uses ordinary reward chances, independently of the
            -- previous encounter. Its persistent card RNG/offset still advance.
            local context={data=owner.data,cardRng=owner.cardRng,
                cardRarityOffset=owner.cardRarityOffset,encounterTier='normal'}
            local cards,rng,offset,upgrades=CardPool.prepareRewards(context)
            for _,id in ipairs(cards)do
                if not Capability.isImplemented(find(owner.data.cards.cards,id))then error('card_content_unavailable')end
            end
            owner.cardRng,owner.cardRarityOffset=rng,offset
            local reward={cards=cards,resolved=false,cardUpgrades=upgrades}
            RelicHooks.previewCardReward(owner,reward,true)
            return reward
        end)
        if flow.restReward then return true,'choose_rest_card' end
        return complete(staged)
    end)
end

function M.claimRestReward(run,choice)
    return Run.transaction(run,function(staged)
        local flow,reason=pending(staged,'camp');if not flow then return false,reason end
        local reward=flow.restReward
        if flow.campChoice~='rest' or not reward or reward.resolved then return false,'no_pending_reward' end
        if type(choice)~='number' or choice%1~=0 or choice<0 or choice>#reward.cards then return false,'invalid_reward_choice' end
        if choice>0 then
            local ok,why=Run.obtainCard(staged,reward.cards[choice],
                {upgraded=reward.cardUpgrades and reward.cardUpgrades[choice]==true});if not ok then return false,why end
        end
        reward.resolved,reward.choice=true,choice
        return complete(staged)
    end)
end

function M.upgrade(run, uid)
    local flow, reason = pending(run, "camp"); if not flow then return false, reason end
    if flow.campChoice and flow.campChoice ~= "upgrade" then return false, "camp_choice_made" end
    local instance = find(run.deck, uid, "uid")
    if not instance then return false, "invalid_card" end
    if flow.upgradesLeft <= 0 or not upgradeable(run, instance) then return false, "card_not_upgradeable" end
    instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1
    instance.upgraded, flow.campChoice = true, "upgrade"
    flow.upgradesLeft = flow.upgradesLeft - 1
    if flow.upgradesLeft == 0 or #upgradeCards(run) == 0 then return complete(run) end
    return true
end

local function purchaseCommand(run, category, reference, bySlot)
    local flow, reason = pending(run, "shop"); if not flow then return false, reason end
    local offer
    if bySlot or category=='potions' then offer=flow[category][reference]
    elseif category=='cards' then
        -- Courier may legitimately stock the same card at different prices.
        -- Keep the ID API only when it identifies exactly one shelf offer.
        for _, candidate in ipairs(flow.cards) do
            if candidate.id==reference then
                if offer then return false,'item_unavailable' end
                offer=candidate
            end
        end
    else offer=find(flow[category],reference) end
    local id=offer and offer.id
    if not offer or offer.sold or offer.unavailable or (category == "relics" and owns(run.relics, id)) then
        return false, "item_unavailable"
    end
    if run.gold < offer.price then return false, "insufficient_gold" end
    if category=='potions' then
        if Shop.owns(run,'sozu') then return false,'potions_blocked' end
        if Run.potionCount(run)>=Run.potionCapacity(run) then return false,'potion_slots_full' end
        if not find(run.data.potions.potions,offer.id) then return false,'unknown_potion' end
    end
    -- Run.transaction rolls back payment/equip if restock fails. Equip first:
    -- source StoreRelic.purchaseRelic observes its effects during Courier draw.
    run.gold = run.gold - offer.price
    RelicHooks.onSpendGold(run,'shop')
    if category == "cards" then
        local ok,why=Run.obtainCard(run,id,{upgraded=offer.upgraded,upgrades=offer.upgrades});if not ok then return false,why end
    elseif category=='potions' then
        local ok,why=Run.obtainPotion(run,offer.id);if not ok then return false,why end
    else
        local ok,why=Run.obtainRelic(run,id);if not ok then return false,why end
    end
    local stagedRun,stagedFlow={},Combat.copy(flow)
    for k,v in pairs(run)do stagedRun[k]=v end
    local called,transaction=pcall(Shop.afterPurchase,stagedRun,stagedFlow,category,stagedFlow[category][offer.slot])
    if not called then return false,'shop_content_unavailable' end
    flow.cards,flow.relics,flow.potions,flow.shopRng=stagedFlow.cards,stagedFlow.relics,stagedFlow.potions,stagedFlow.shopRng
    run.shopRng=flow.shopRng
    run.relicPool=stagedRun.relicPool
    run.cardRng,run.cardRarityOffset=stagedRun.cardRng,stagedRun.cardRarityOffset
    -- Commit session entropy only after all staged grants/hooks succeed.
    if transaction and not pcall(External.commit,transaction) then return false,'shop_content_unavailable' end
    return true
end

local function purchase(run,category,reference,bySlot)
    return Run.transaction(run,function(staged)return purchaseCommand(staged,category,reference,bySlot)end)
end

function M.buyCard(run, id) return purchase(run, "cards", id) end
function M.buyCardSlot(run, slot)
    if type(slot)~='number' or slot%1~=0 or slot<1 or slot>7 then return false,'item_unavailable' end
    return purchase(run,'cards',slot,true)
end
function M.buyRelic(run, id) return purchase(run, "relics", id) end
function M.buyPotion(run, slot)
    if type(slot)~='number' or slot%1~=0 or slot<1 or slot>3 then return false,'item_unavailable' end
    return purchase(run,'potions',slot)
end

local function removeCard(run, uid)
    local flow, reason = pending(run, "shop"); if not flow then return false, reason end
    -- The service is a one-use offer per shop; the price increase belongs to later shops.
    if flow.removalUsed then return false, "removal_unavailable" end
    local instance = find(run.deck, uid, "uid")
    if not instance then return false, "invalid_card" end
    if not find(LivingWall.purgeCards(run),uid,'uid') then return false,'card_not_purgeable' end
    local price = Shop.removePrice(run)
    if run.gold < price then return false, "insufficient_gold" end
    run.gold, run.shopRemoveCount = run.gold - price, (run.shopRemoveCount or 0) + 1
    RelicHooks.onSpendGold(run,'shop')
    local ok,why=Run.removeCard(run,uid);if not ok then return false,why end
    flow.removalUsed = true
    return true
end

function M.removeCard(run,uid)
    return Run.transaction(run,function(staged)return removeCard(staged,uid)end)
end

function M.leaveShop(run)
    local flow, reason = pending(run, "shop"); if not flow then return false, reason end
    return complete(run)
end

local function openSourceTreasure(run,flow)
    local prepared,why=Treasure.open(run,flow.chest,flow.reward)
    if not prepared then return false,why end
    for _,key in ipairs({'treasureRng','relicPool','cardRng','relicCounters'})do run[key]=prepared[key]end
    for _,id in ipairs(prepared.curseSourceIds)do
        local ok,reason=Run.obtainCard(run,id);if not ok then return false,reason end
    end
    flow.chest,flow.reward=prepared.chest,prepared.reward
    return true
end
function M.openTreasure(run)
    return Run.transaction(run,function(staged)
        local flow,why=pending(staged,'treasure');if not flow then return false,why end
        if not flow.chest then return false,'source_chest_required' end
        return openSourceTreasure(staged,flow)
    end)
end
function M.treasureRewardSource(run,slot)
    local flow,why=pending(run,'treasure');if not flow then return nil,why end
    if type(flow.chest)~='table' or getmetatable(flow.chest)~=nil or flow.chest.opened~=true then return nil,'chest_closed' end
    if run.floor~=flow.floor or type(flow.floor)~='number' or flow.floor%1~=0 or flow.floor<1 or flow.floor>55
        or type(flow.id)~='string' or flow.id=='' or type(run.runSeed)~='string' or flow.mapSeed~=run.runSeed
        or type(flow.mapSignature)~='string' or flow.mapSignature==''
        or type(run.roomGeneration)~='number' or run.roomGeneration%1~=0 or run.roomGeneration<1 or run.roomGeneration>2147483647
        or type(flow.reward)~='table' or getmetatable(flow.reward)~=nil
        or type(flow.reward.items)~='table' or getmetatable(flow.reward.items)~=nil or flow.complete~=false
        or type(slot)~='number' or slot%1~=0 or slot<1 then return nil,'treasure_source_mismatch' end
    for _,item in ipairs(flow.reward.items)do if item.slot==slot then
        if getmetatable(item)~=nil then return nil,'treasure_source_mismatch' end
        return {id=flow.id,floor=flow.floor,roomGeneration=run.roomGeneration,slot=slot,
            kind=item.kind,sourceId=item.sourceId or item.kind}
    end end
    return nil,'treasure_reward_unavailable'
end
local function takeSourceTreasure(run,flow,slot)
    local taken,why=Treasure.take(flow.reward,slot);if not taken then return false,why end
    local item=taken.item
    if item.kind=='relic' then
        local ok,reason=Run.obtainRelic(run,item.id);if not ok then return false,reason end
    elseif item.kind=='gold' then Run.gainGold(run,item.amount)
    else
        local eligible,reason=endingKeyEligible(run,'sapphire');if not eligible then return false,reason end
        run.keys.sapphire=true
    end
    flow.reward=taken.reward
    if item.kind=='sapphire' or item.origin=='base' then flow.treasureChoice=item.kind end
    return true,item.kind
end
function M.claimTreasureReward(run,token)
    -- Validate plain source owners before copying can erase a metatable.
    if type(token)~='table' or getmetatable(token)~=nil then
        return Run.transaction(run,function()return false,'treasure_source_mismatch'end)
    end
    local initial,reason=M.treasureRewardSource(run,token.slot)
    if not initial then return Run.transaction(run,function()return false,reason end)end
    return Run.transaction(run,function(staged)
        if type(token)~='table' or getmetatable(token)~=nil then return false,'treasure_source_mismatch' end
        local fields={id=true,floor=true,roomGeneration=true,slot=true,kind=true,sourceId=true}
        for key in pairs(token)do if not fields[key]then return false,'treasure_source_mismatch' end end
        local live,why=M.treasureRewardSource(staged,token.slot);if not live then return false,why end
        for key,value in pairs(live)do if token[key]~=value then return false,'treasure_source_mismatch' end end
        local flow=staged.nodeFlow
        if flow.roomKind=='boss_treasure' then return false,'boss_treasure_choice_required' end
        local ok,kind=takeSourceTreasure(staged,flow,token.slot);if not ok then return false,kind end
        if #flow.reward.items==0 then return complete(staged,kind) end
        return true,kind
    end)
end
function M.leaveTreasure(run)
    return Run.transaction(run,function(staged)
        local flow,why=pending(staged,'treasure');if not flow then return false,why end
        if flow.roomKind=='boss_treasure' then
            complete(staged,'boss_treasure_complete')
            if staged.campaign then staged.phase,staged.pendingAct='act_transition',(staged.act or 1)+1
            else staged.phase='victory' end
            return true,'boss_treasure_complete'
        end
        return complete(staged,'treasure_skipped')
    end)
end

local function claimTreasure(run)
    local flow, reason = pending(run, "treasure"); if not flow then return false, reason end
    if flow.roomKind == "boss_treasure" then return false, "boss_treasure_choice_required" end
    if flow.chest then
        if not flow.chest.opened then local ok,why=openSourceTreasure(run,flow);if not ok then return false,why end end
        local items=Combat.copy(flow.reward.items)
        for _,item in ipairs(items)do if item.kind~='sapphire' then
            local ok,why=takeSourceTreasure(run,flow,item.slot);if not ok then return false,why end
        end end
        return complete(run)
    end
    if flow.reward.relicId then
        if owns(run.relics, flow.reward.relicId) then return false, "relic_already_owned" end
        local ok,why=Run.obtainRelic(run,flow.reward.relicId);if not ok then return false,why end
        if flow.reward.sapphireKey then
            flow.reward.sapphireKey=nil
            flow.treasureChoice='relic'
        end
    else Run.gainGold(run,flow.reward.gold) end
    return complete(run)
end

function M.claimTreasure(run)
    return Run.transaction(run,claimTreasure)
end

-- This token follows Recall's existing map/room-generation ownership pattern.
-- The bounded current reward owner has one base relic, not a full PC chest
-- reward list: reject other shapes instead of sacrificing unrelated rewards.
function M.treasureSource(run,map)
    local flow,reason=pending(run,'treasure');if not flow then return nil,reason end
    if flow.roomKind=='boss_treasure' then return nil,'boss_treasure_choice_required' end
    local eligible,why=endingKeyEligible(run,'sapphire');if not eligible then return nil,why end
    local reward=flow.reward
    local modern
    if flow.chest then
        if type(flow.chest)~='table'or getmetatable(flow.chest)~=nil or flow.chest.opened~=true then return nil,'chest_closed'end
        modern,why=TreasureSource.pair(reward);if not modern then return nil,why end
        if modern.relicAvailable and not find(run.data.relics.relics,modern.relicId)then return nil,'treasure_choice_unavailable'end
        if owns(run.relics,modern.relicId) and modern.relicId~='circlet' and modern.relicId~='Circlet'then
            return nil,'treasure_choice_unavailable'
        end
    else
    if type(reward)~='table' or getmetatable(reward)~=nil or type(reward.relicId)~='string'
        or type(reward.sapphireKey)~='table' or getmetatable(reward.sapphireKey)~=nil
        or reward.sapphireKey.relicId~=reward.relicId or owns(run.relics,reward.relicId)
        or not find(run.data.relics.relics,reward.relicId) then return nil,'treasure_choice_unavailable' end
    for key in pairs(reward)do
        if key~='relicId' and key~='sapphireKey' then return nil,'treasure_reward_shape_unsupported' end
    end
    for key in pairs(reward.sapphireKey)do
        if key~='relicId' then return nil,'treasure_reward_shape_unsupported' end
    end
    end
    if type(map)~='table' or type(map.nodes)~='table' or type(map.path)~='table'
        or type(run.runSeed)~='string' or type(flow.mapSeed)~='string' or flow.mapSeed~=run.runSeed
        or type(flow.floor)~='number' or flow.floor%1~=0 or flow.floor<1 or flow.floor>55
        or type(run.roomGeneration)~='number' or run.roomGeneration%1~=0
        or run.roomGeneration<1 or run.roomGeneration>2147483647
        or type(flow.id)~='string' or type(flow.mapSignature)~='string' or flow.mapSignature==''
        or flow.complete~=false or flow.treasureChoice~=nil or run.floor~=flow.floor or run.runSeed~=map.runSeed
        or (run.act or 1)~=(map.act or 1) or map.path[#map.path]~=flow.id or not matchingMap(flow,map) then
        return nil,'treasure_source_mismatch'
    end
    local node
    for _,entry in ipairs(map.nodes)do
        if type(entry)~='table' then return nil,'treasure_source_mismatch' end
        if entry.id==flow.id then node=entry end
    end
    if not node or node.floor~=flow.floor or node.roomKind=='boss_treasure'
        or (node.type~='treasure' and not (node.type=='event' and flow.sourceType=='event')) then
        return nil,'treasure_source_mismatch'
    end
    local token={id=flow.id,floor=flow.floor,act=run.act or 1,runSeed=run.runSeed,
        mapSeed=flow.mapSeed,mapSignature=flow.mapSignature,roomGeneration=run.roomGeneration,relicId=reward.relicId}
    if modern then
        token.baseSlot,token.keySlot,token.itemsSignature=modern.baseSlot,modern.keySlot,modern.itemsSignature
    end
    return token
end

local function treasureChoiceSource(run,map,source,choice)
    local current,reason=M.treasureSource(run,map);if not current then return false,reason end
    if type(source)~='table' or getmetatable(source)~=nil then return false,'treasure_source_mismatch' end
    for key,value in pairs(current)do if source[key]~=value then return false,'treasure_source_mismatch' end end
    for key in pairs(source)do if current[key]==nil then return false,'treasure_source_mismatch'end end
    if choice~='relic' and choice~='sapphire' then return false,'invalid_treasure_choice' end
    return true
end

function M.chooseTreasure(run,map,source,choice)
    -- Validate plain owners before Run.transaction's graph copy can normalize
    -- their metatables. A nested preflight refusal must still poison its parent.
    local valid,reason=treasureChoiceSource(run,map,source,choice)
    if not valid then return Run.transaction(run,function()return false,reason end)end
    return Run.transaction(run,function(staged)
        local live,why=treasureChoiceSource(staged,map,source,choice);if not live then return false,why end
        local flow=staged.nodeFlow
        if flow.chest then
            local ok,kind=takeSourceTreasure(staged,flow,choice=='sapphire'and source.keySlot or source.baseSlot)
            if not ok then return false,kind end
            if #flow.reward.items==0 then return complete(staged,choice=='relic'and 'complete'or kind)end
            return true,kind
        end
        if choice=='relic' then return claimTreasure(staged) end
        -- The BLUE effect's gameplay result only changes this flag. Expire its
        -- linked relic in the same transaction; no obtain/equip or gold hook.
        staged.keys.sapphire=true
        staged.nodeFlow.reward.relicId=nil
        staged.nodeFlow.reward.sapphireKey=nil
        staged.nodeFlow.treasureChoice='sapphire'
        return complete(staged,'sapphire')
    end)
end

local function claimBossTreasure(run, choice)
    local flow, reason = pending(run, "treasure"); if not flow then return false, reason end
    if flow.roomKind ~= "boss_treasure" then return false, "wrong_node_type" end
    if type(choice) ~= "number" or choice % 1 ~= 0 or choice < 0 or choice > #flow.reward.relics then
        return false, "invalid_boss_relic_choice"
    end
    if flow.chest then
        if choice>0 then
            if not flow.chest.opened then local ok,why=openSourceTreasure(run,flow);if not ok then return false,why end end
            local item=flow.reward.items[choice]
            if not item or item.kind~='relic' then return false,'invalid_boss_relic_choice' end
            local ok,why=takeSourceTreasure(run,flow,item.slot);if not ok then return false,why end
            flow.chosenRelic=item.id
        end
    elseif choice > 0 then
        local id = flow.reward.relics[choice]
        local relic = find(run.data.relics.relics, id)
        if not relic or not Inventory.bossEligible(relic, run.relics) then return false, "boss_relic_unavailable" end
        local ok,why=Run.obtainRelic(run,id);if not ok then return false,why end
        flow.chosenRelic = id
    end
    complete(run, "boss_treasure_complete")
    if run.campaign then run.phase,run.pendingAct='act_transition',(run.act or 1)+1
    else run.phase = "victory" end
    return true, "boss_treasure_complete"
end

function M.claimBossTreasure(run,choice)
    return Run.transaction(run,function(staged)return claimBossTreasure(staged,choice)end)
end

function M.eventOptions(run,flow)
    local id,e=flow.event.id,flow.event
    if id=='neow'then return Neow.options(run,e)end
    if Act1Events.ids[id] then return Act1Events.options(run,e,upgradeCards) end
    if Act2Events.ids[id] then return Act2Events.options(run,e) end
    if Act3Events.ids[id] then return Act3Events.options(run,e) end
    local rows={}
    local function option(choice,title,description,enabled,picker)
        rows[#rows+1]={choice=choice,title=title,description=description,enabled=enabled~=false,picker=picker}
    end
    local upgrades=#upgradeCards(run)
    local deckOk=#LivingWall.purgeCards(run)>0
    if id=='living_wall' then
        option('forget','遗忘','移除一张卡牌',true,#LivingWall.purgeCards(run)>0 and 'living_forget' or nil)
        option('change','改变','将一张卡牌变换为随机的新卡牌',true,#LivingWall.purgeCards(run)>0 and 'living_change' or nil)
        option('grow','成长','升级一张卡牌',upgrades>0,#LivingWall.purgeCards(run)>0 and 'living_grow' or nil)
        return rows
    elseif id=='fountain' then
        option('cleanse','净化','移除牌组中所有可清除的诅咒。')
    elseif id=='cleric' then
        local r=run.data.rules.events.cleric
        local heal=healingPreview(run,math.floor(run.maxHp*r.healPercent/100))
        option('heal','治疗','支付 '..r.healCost..' 金币，回复 '..heal..' 点生命',run.gold>=r.healCost)
        option('purify','净化','支付 '..r.removeCost..' 金币，移除一张卡牌',run.gold>=r.removeCost and deckOk,'purify')
    elseif id=='purifier' then option('pray','祈祷','免费移除一张卡牌',deckOk,'purify')
    elseif id=='upgrade_shrine' then option('upgrade','升级',upgrades>0 and '免费升级一张卡牌' or '牌组没有可升级的卡牌',upgrades>0,'event_upgrade')
    elseif id=='golden_shrine' then
        local r=run.data.rules.events.golden_shrine
        local curse=find(run.data.cards.cards,r.curse)
        option('pray','领受馈赠','获得 '..r.gold..' 金币')
        option('desecrate','取走供物','获得 '..r.curseGold..' 金币，并将诅咒「'..(curse and curse.name or 'Regret')..'」加入牌组')
    elseif id=='goop' then
        local r=run.data.rules.events.goop
        option('gather','拾取金币','受到 '..r.damage..' 点伤害，获得 '..r.gold..' 金币')
        option('leave','离开','失去 '..e.goldLoss..' 金币');return rows
    elseif id=='shining_light' then option('accept','触碰光芒',upgrades>0 and ('受到 '..e.damage..' 点伤害，随机升级最多 '..run.data.rules.events.shining_light.upgradeCount..' 张卡牌') or '牌组没有可升级的卡牌',upgrades>0)
    elseif id=='golden_wing' then
        local r=run.data.rules.events.golden_wing
        if e.stage=='purge' then
            option('purge','移除卡牌','已支付 '..r.damage..' 点生命；选择一张卡牌移除',deckOk,'wing_purge');return rows
        end
        option('sacrifice','献出生命','受到 '..r.damage..' 点伤害，然后选择移除一张卡牌')
        option('take_gold','击碎雕像','获得 '..r.goldMin..'–'..r.goldMax..' 金币；需要基础伤害至少 '..r.attackThreshold..' 的攻击牌',e.canAttack)
    end
    option('leave','离开','什么也不会发生。')
    return rows
end

local function chooseEvent(run, choice, uid)
    local flow, reason = pending(run, "event"); if not flow then return false, reason end
    local id = flow.event.id
    if id=='neow'then
        local ok,status=Neow.choose(run,flow,choice,uid)
        if not ok or status~='complete'then return ok,status end
        flow.eventChoice=choice;run.neowStatus='complete'
        return complete(run)
    end
    local rules = run.data.rules.events[id] or {}
    if Act2Events.ids[id] then
        local ok,status=Act2Events.choose(run,flow,choice,uid,upgradeable)
        if ok and run.hp==0 then
            flow.eventChoice=choice;complete(run);run.phase='defeat';return true,'defeat'
        end
        if not ok or status~='complete' then return ok,status end
        flow.eventChoice=choice
        return complete(run)
    end
    if Act3Events.ids[id] then
        local ok,status=Act3Events.choose(run,flow,choice,uid)
        if ok and status=='event_combat'then return Run.startEventCombat(run)end
        if ok and run.hp==0 then
            flow.eventChoice=choice;complete(run);run.phase='defeat';return true,'defeat'
        end
        if not ok or status~='complete'then return ok,status end
        flow.eventChoice=choice;return complete(run)
    end
    if Act1Events.ids[id] then
        local ok,status=Act1Events.choose(run,flow,choice,uid,upgradeable,upgradeCards)
        if ok and status=='event_combat'then return Run.startEventCombat(run)end
        if ok and run.hp==0 then
            run.nodeFlow.eventChoice=choice
            complete(run);run.phase='defeat';return true,'defeat'
        end
        if not ok or status~='complete' then return ok,status end
        run.nodeFlow.eventChoice=choice
        return complete(run)
    end
    if id=='living_wall' then
        local ok,status=LivingWall.choose(run,flow,choice,uid,upgradeable,upgradeCards)
        if not ok or status=='choose_card' then return ok,status end
        flow.eventChoice=choice
        return complete(run)
    end
    if id=='fountain' and choice=='cleanse' then
        local ok,why=Fountain.cleanse(run,flow)
        if not ok then return false,why end
        flow.eventChoice=choice
        return complete(run)
    end
    if id=='golden_wing' and flow.event.stage=='purge' and choice~='purge' then return false,'invalid_event_choice' end
    local function damage(amount) local ok,why=Run.eventDamage(run,amount);assert(ok,why) end
    if choice == "heal" and id == "cleric" then
        if run.gold < rules.healCost then return false, "insufficient_gold" end
        run.gold = run.gold - rules.healCost
        Run.heal(run,math.floor(run.maxHp * rules.healPercent / 100))
    elseif (choice == "purify" and id == "cleric") or (choice == "pray" and id == "purifier") then
        local instance = find(run.deck, uid, "uid")
        if not instance then return false, "invalid_card" end
        if not find(LivingWall.purgeCards(run),uid,'uid') then return false,'card_not_purgeable' end
        if run.gold < rules.removeCost then return false, "insufficient_gold" end
        local ok,why=Run.removeCard(run,uid);if not ok then return false,why end
        run.gold = run.gold - rules.removeCost
    elseif choice=='pray' and id=='golden_shrine' then Run.gainGold(run,rules.gold)
    elseif choice=='desecrate' and id=='golden_shrine' then
        local curse=find(run.data.cards.cards,rules.curse)
        -- Preflight the sole supported curse ABI and permanent identity before paying gold.
        if not curse or curse.id~='regret' or curse.type~='curse' or curse.rarity~='curse'
            or curse.cost~=-2 or type(curse.effects)~='table' or next(curse.effects)~=nil
            or curse.upgrade~=nil or curse.condition~=nil or curse.costMode~=nil
            or curse.ethereal or curse.exhaust or curse.innate or curse.repeatable then
            return false,'event_content_unavailable'
        end
        local offer,why=Run.prepareCard(run,curse.id);if not offer then return false,why end
        Run.gainGold(run,rules.curseGold)
        local ok,obtained=Run.commitCard(run,offer);if not ok then return false,obtained end
        flow.event.obtainedCardUid=type(obtained)=='number' and obtained or nil
        flow.event.cursePrevented=obtained=='curse_blocked' or nil
    elseif choice=='gather' and id=='goop' then damage(rules.damage);Run.gainGold(run,rules.gold)
    elseif choice=='leave' and id=='goop' then run.gold=math.max(0,run.gold-flow.event.goldLoss)
    elseif choice=='upgrade' and id=='upgrade_shrine' then
        local instance=find(run.deck,uid,'uid')
        if not instance then return false,'invalid_card' end
        if not upgradeable(run,instance) then return false,'card_not_upgradeable' end
        instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1
        instance.upgraded=true;flow.event.upgradedUids={uid}
    elseif choice=='accept' and id=='shining_light' then
        local cards=upgradeCards(run)
        if #cards==0 then return false,'card_not_upgradeable' end
        local rng=EventRandom.cloneState(run.miscRng)
        EventRandom.shuffle(rng,cards)
        damage(flow.event.damage)
        flow.event.upgradedUids={}
        for i=1,math.min(rules.upgradeCount,#cards) do
            local instance=find(run.deck,cards[i].uid,'uid')
            instance.upgrades=(instance.upgrades or (instance.upgraded and 1 or 0))+1
            instance.upgraded=true
            flow.event.upgradedUids[#flow.event.upgradedUids+1]=cards[i].uid
        end
        run.miscRng=rng
    elseif choice=='sacrifice' and id=='golden_wing' then
        damage(rules.damage);flow.event.stage='purge'
        -- An empty purge group cannot keep the event waiting for a nonexistent UID.
        if run.hp>0 and #LivingWall.purgeCards(run)>0 then return true,'choose_purge' end
    elseif choice=='take_gold' and id=='golden_wing' then
        if not flow.event.canAttack then return false,'event_condition_unmet' end
        local rng=EventRandom.cloneState(run.miscRng)
        local gold=EventRandom.randomIntBetween(rng,rules.goldMin,rules.goldMax)
        Run.gainGold(run,gold);run.miscRng=rng
    elseif choice=='purge' and id=='golden_wing' and flow.event.stage=='purge' then
        local instance=find(run.deck,uid,'uid')
        if not instance then return false,'invalid_card' end
        if not find(LivingWall.purgeCards(run),uid,'uid') then return false,'card_not_purgeable' end
        local ok,why=Run.removeCard(run,uid);if not ok then return false,why end
    elseif choice ~= "leave" then return false, "invalid_event_choice" end
    flow.eventChoice = choice
    local ok,result=complete(run)
    if run.hp==0 then run.phase='defeat' end
    return ok,result
end

function M.chooseEvent(run,choice,uid)
    return Run.transaction(run,function(staged)return chooseEvent(staged,choice,uid)end)
end

function M.upgradeEvent(run,uid) return M.chooseEvent(run,'upgrade',uid) end
function M.chooseAct2EventCard(run,uid)
    local flow,reason=pending(run,'event');if not flow then return false,reason end
    if not Act2Events.ids[flow.event.id] or flow.event.stage~='choose_card' then return false,'invalid_event_choice' end
    return M.chooseEvent(run,flow.event.choice,uid)
end
function M.chooseAct1EventCard(run,uid)
    local flow,reason=pending(run,'event');if not flow then return false,reason end
    if not Act1Events.ids[flow.event.id] or flow.event.stage~='choose_card' then return false,'invalid_event_choice' end
    return M.chooseEvent(run,flow.event.choice,uid)
end
function M.chooseLivingWallCard(run,uid)
    local flow,reason=pending(run,'event');if not flow then return false,reason end
    if flow.event.id~='living_wall' or flow.event.stage~='choose_card' then return false,'invalid_event_choice' end
    return M.chooseEvent(run,flow.event.choice,uid)
end
function M.purgeWing(run,uid) return M.chooseEvent(run,'purge',uid) end

function M.purifyEvent(run, uid)
    local flow = run.nodeFlow
    return M.chooseEvent(run, flow and flow.event and flow.event.id == "purifier" and "pray" or "purify", uid)
end

function M.completeCombat(run, map)
    local flow = run.nodeFlow
    if not flow or flow.complete then return false, "no_pending_node" end
    if not battleKinds[flow.type] and not (flow.type=='event' and flow.eventCombat) then return false, "wrong_node_type" end
    if not matchingMap(flow, map) then return false, "map_mismatch" end
    if run.phase == "defeat" then return false, "run_defeated" end
    if run.phase == "reward" then return false, "reward_pending" end
    if run.phase=='map' and run.lastResult and run.lastResult.outcome=='escaped'
        and flow.type~='boss' and run.lastResult.encounterId==flow.encounterId then return complete(run,'escaped') end
    if run.phase ~= "map" or not run.lastResult or run.lastResult.outcome ~= "victory"
        or run.lastResult.encounterId ~= flow.encounterId then return false, "battle_unfinished" end
    return complete(run, flow.type == "boss" and "boss_victory" or "victory")
end

return M
