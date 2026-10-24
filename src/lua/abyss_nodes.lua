-- Seven node flows over the existing same-run state. Adapters must navigate via enter/available.
-- Battle commands/reward selection remain Run commands, followed by completeCombat.
-- Combat relic effects and persistence restoration belong to their owning modules.
local Run = require("abyss_run")
local Map = require("abyss_map")
local Combat = require("abyss_combat")
local Effects = require("abyss_effects")
local Unknown = require("abyss_unknown")
local EventPool = require("abyss_event_pool")
local EventRandom = require("abyss_sts_random")
local Inventory = require("abyss_inventory")
local Shop = require("abyss_shop")
local M = {}
local battleKinds = { combat = true, elite = true, boss = true }

local function find(entries, id, field)
    for i, entry in ipairs(entries) do if entry[field or "id"] == id then return entry, i end end
end

local function owns(entries, id)
    for _, owned in ipairs(entries) do if owned == id then return true end end
    return false
end

local function playable(card)
    return card.type ~= "status" and card.type ~= "curse"
        and not card.condition and not card.costMode and Effects.supported(card.effects)
end

local function upgradeable(run, instance)
    if instance.upgraded then return false end
    local definition = find(run.data.cards.cards, instance.cardId)
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

local function unownedRelics(run)
    local result = {}
    for _, relic in ipairs(run.data.relics.relics) do
        if relic.rarity ~= "starter" and relic.rarity ~= "boss" and relic.rarity ~= "shop"
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
        for k,v in pairs(Shop.prepare(run)) do flow[k]=v end
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
        local relics = unownedRelics(run)
        flow.reward = #relics > 0 and { relicId = relics[Combat.random(random, #relics)] }
            or { gold = run.data.rules.rewards.normalGold }
    elseif node.type == "event" then
        local id=node.eventId or run.data.rules.events.encounterId
        flow.event = { id = id }
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
    if run.runSeed~=map.runSeed or run.phase ~= "map" or (run.nodeFlow and not run.nodeFlow.complete)
        or not matchingMap(run.nodeFlow, map) then return {} end
    return Map.available(map)
end

function M.enter(run, map, nodeId)
    if run.nodeFlow and not run.nodeFlow.complete then return false, "node_pending" end
    if run.phase ~= "map" then return false, "not_on_map" end
    if type(run.roomGeneration)~='number' or run.roomGeneration%1~=0
        or run.roomGeneration<0 or run.roomGeneration>=2147483647 then return false,'invalid_room_generation' end
    if run.runSeed~=map.runSeed or not matchingMap(run.nodeFlow, map) then return false, "map_mismatch" end
    local node = find(map.nodes, nodeId)
    if not node then return false, "invalid_node" end
    if not find(Map.available(map), nodeId) then return false, "node_unavailable" end
    -- A Boss chest is earned only after that Boss's card reward is resolved.
    if node.roomKind == "boss_treasure" and (node.floor ~= run.data.rules.map.bossTreasureFloor
        or not run.nodeFlow or run.nodeFlow.type ~= "boss" or run.nodeFlow.result ~= "boss_victory") then
        return false, "boss_treasure_unavailable"
    end
    if not battleKinds[node.type] and node.type ~= "camp" and node.type ~= "shop"
        and node.type ~= "event" and node.type ~= "treasure" then return false, "unknown_node_type" end
    local sourceType=node.type
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
            local originalId,reason=EventPool.draw(nextUnknown.pools,{floor=node.floor,gold=run.gold,act=1,
                hp=run.hp,relicCount=#run.relics,elapsedSeconds=run.elapsedSeconds,cursed=false},selectionRng)
            if not originalId then return false,reason end
            node.eventId=EventPool.contentId[originalId]
            if not node.eventId then return false,'event_not_implemented' end
            node.originalEventId=originalId
        end
    end
    if node.type == "event" then
        local id = node.eventId or run.data.rules.events.encounterId
        if id ~= "cleric" and id ~= "purifier" and id~='goop' and id~='upgrade_shrine'
            and id~='golden_wing' and id~='shining_light' and id~='golden_shrine' then return false, "event_unavailable" end
        if id == "cleric" and run.gold < run.data.rules.events.cleric.minGold then
            return false, "event_unavailable"
        end
    end
    local flow, seed = prepare(run, node,nextMiscRng)
    flow.sourceType=sourceType
    if selectionRng then flow.selectionRng=EventRandom.snapshot(selectionRng);flow.event.originalId=node.originalEventId end
    local stagedRun
    if battleKinds[node.type] then
        -- Keep the new floor and room misc state private until real battle setup
        -- succeeds. startCombat may advance this stream when assembling a group;
        -- use that resulting state, not the pre-battle clone, at commit below.
        stagedRun = {}
        for key, value in pairs(run) do stagedRun[key] = value end
        stagedRun.floor, stagedRun.miscRng = node.floor, nextMiscRng
        local tier=node.type=='combat' and 'normal' or node.type
        local called, ok, reason = pcall(Run.startRoomCombat, stagedRun, tier)
        if not called or not ok then
            return false, called and reason or "combat_unavailable"
        end
        nextMiscRng = stagedRun.miscRng
        flow.encounterId,flow.encounterSource=stagedRun.encounterId,stagedRun.encounterSource
    else
        run.floor, run.phase, run.seed = node.floor, "node", seed
    end
    assert(Map.choose(map, nodeId)) -- already validated against the unchanged map above
    if stagedRun then
        run.floor, run.phase, run.combat = stagedRun.floor, stagedRun.phase, stagedRun.combat
        run.encounterId, run.encounterTier = stagedRun.encounterId, stagedRun.encounterTier
        run.encounterSource,run.encounters=stagedRun.encounterSource,stagedRun.encounters
        run.roomGeneration=stagedRun.roomGeneration
    else
        run.roomGeneration=run.roomGeneration+1
    end
    flow.mapSeed, flow.mapSignature = map.seed, map.sourceSignature
    if nextUnknown then run.unknown,run.eventRng=nextUnknown,nextEventRng end
    run.miscRng=nextMiscRng
    run.nodeFlow = flow
    if flow.type == 'shop' then run.shopRng=flow.shopRng end
    -- The old room's unclaimed rewards expire only after this entry succeeds.
    run.pendingCombatRewards = nil
    return true
end

function M.view(run, map)
    local available, mapView = M.available(run, map), Map.view(map)
    local enabled = #available > 0
    if not enabled then for _, node in ipairs(mapView.nodes) do node.available = false end end
    local node = run.nodeFlow and Combat.copy(run.nodeFlow) or nil
    if node and not node.complete then
        if node.type == "camp" then
            node.upgradeCards = upgradeCards(run)
            node.heal = math.min(run.maxHp - run.hp, math.floor(run.maxHp * run.data.rules.camp.healPercent / 100))
        elseif node.type == "shop" then
            node.removePrice = Shop.removePrice(run)
            node.removeAvailable = not node.removalUsed
        elseif node.type == "event" then
            local rules = run.data.rules.events[node.event.id] or {}
            node.event.removeCost = rules.removeCost or 0
            node.upgradeCards=upgradeCards(run)
            node.upgradesLeft=1
            if node.event.id == "cleric" then
                node.event.healCost = rules.healCost
                node.event.heal = math.min(run.maxHp - run.hp, math.floor(run.maxHp * rules.healPercent / 100))
            end
            node.event.options=M.eventOptions(run,node)
        end
    end
    return { phase = run.phase, node = node, map = mapView, available = available, navigationEnabled = enabled }
end

function M.rest(run)
    local flow, reason = pending(run, "camp"); if not flow then return false, reason end
    if flow.campChoice then return false, "camp_choice_made" end
    local healing = math.floor(run.maxHp * run.data.rules.camp.healPercent / 100)
    run.hp = math.min(run.maxHp, run.hp + healing)
    flow.campChoice = "rest"
    return complete(run)
end

function M.upgrade(run, uid)
    local flow, reason = pending(run, "camp"); if not flow then return false, reason end
    if flow.campChoice and flow.campChoice ~= "upgrade" then return false, "camp_choice_made" end
    local instance = find(run.deck, uid, "uid")
    if not instance then return false, "invalid_card" end
    if flow.upgradesLeft <= 0 or not upgradeable(run, instance) then return false, "card_not_upgradeable" end
    instance.upgraded, flow.campChoice = true, "upgrade"
    flow.upgradesLeft = flow.upgradesLeft - 1
    if flow.upgradesLeft == 0 or #upgradeCards(run) == 0 then return complete(run) end
    return true
end

local function purchase(run, category, reference, bySlot)
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
        if Run.potionCount(run)>=run.data.rules.player.potionSlots then return false,'potion_slots_full' end
        if not find(run.data.potions.potions,offer.id) then return false,'unknown_potion' end
    end
    -- Stage discounts and restock before charging or granting anything. An
    -- invalid stream/content adapter must not leave half a purchase committed.
    local stagedRun,stagedFlow={},Combat.copy(flow)
    for k,v in pairs(run) do stagedRun[k]=v end
    if category=='relics' then
        stagedRun.relics=Combat.copy(run.relics)
        stagedRun.relics[#stagedRun.relics+1]=id
    end
    local called=pcall(Shop.afterPurchase,stagedRun,stagedFlow,category,stagedFlow[category][offer.slot])
    if not called then return false,'shop_content_unavailable' end
    if category == "cards" then
        run.deck[#run.deck + 1] = { uid = run.nextDeckUid, cardId = id, upgraded = false }
        run.nextDeckUid = run.nextDeckUid + 1
    elseif category=='potions' then
        local ok,why=Run.obtainPotion(run,offer.id);if not ok then return false,why end
    else run.relics[#run.relics + 1] = id end
    run.gold = run.gold - offer.price
    flow.cards,flow.relics,flow.potions,flow.shopRng=stagedFlow.cards,stagedFlow.relics,stagedFlow.potions,stagedFlow.shopRng
    run.shopRng=flow.shopRng
    return true
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

function M.removeCard(run, uid)
    local flow, reason = pending(run, "shop"); if not flow then return false, reason end
    -- The service is a one-use offer per shop; the price increase belongs to later shops.
    if flow.removalUsed then return false, "removal_unavailable" end
    local instance, position = find(run.deck, uid, "uid")
    if not instance then return false, "invalid_card" end
    local price = Shop.removePrice(run)
    if run.gold < price then return false, "insufficient_gold" end
    table.remove(run.deck, position)
    run.gold, run.shopRemoveCount = run.gold - price, (run.shopRemoveCount or 0) + 1
    flow.removalUsed = true
    return true
end

function M.leaveShop(run)
    local flow, reason = pending(run, "shop"); if not flow then return false, reason end
    return complete(run)
end

function M.claimTreasure(run)
    local flow, reason = pending(run, "treasure"); if not flow then return false, reason end
    if flow.roomKind == "boss_treasure" then return false, "boss_treasure_choice_required" end
    if flow.reward.relicId then
        if owns(run.relics, flow.reward.relicId) then return false, "relic_already_owned" end
        run.relics[#run.relics + 1] = flow.reward.relicId
    else run.gold = run.gold + flow.reward.gold end
    return complete(run)
end

function M.claimBossTreasure(run, choice)
    local flow, reason = pending(run, "treasure"); if not flow then return false, reason end
    if flow.roomKind ~= "boss_treasure" then return false, "wrong_node_type" end
    if type(choice) ~= "number" or choice % 1 ~= 0 or choice < 0 or choice > #flow.reward.relics then
        return false, "invalid_boss_relic_choice"
    end
    if choice > 0 then
        local id = flow.reward.relics[choice]
        local relic = find(run.data.relics.relics, id)
        if not relic or not Inventory.bossEligible(relic, run.relics) then return false, "boss_relic_unavailable" end
        -- Preflight finishes before removing the starter. Replacement keeps its
        -- held position, so no later hook order changes with Black Blood.
        local position
        if relic.replaces then
            for i, owned in ipairs(run.relics) do if owned == relic.replaces then position = i; break end end
        end
        if position then run.relics[position] = id else run.relics[#run.relics + 1] = id end
        flow.chosenRelic = id
    end
    complete(run, "boss_treasure_complete")
    run.phase = "victory"
    return true, "boss_treasure_complete"
end

function M.eventOptions(run,flow)
    local id,e=flow.event.id,flow.event
    local rows={}
    local function option(choice,title,description,enabled,picker)
        rows[#rows+1]={choice=choice,title=title,description=description,enabled=enabled~=false,picker=picker}
    end
    local upgrades=#upgradeCards(run)
    local deckOk=#run.deck>0
    if id=='cleric' then
        local r=run.data.rules.events.cleric
        local heal=math.min(run.maxHp-run.hp,math.floor(run.maxHp*r.healPercent/100))
        option('heal','治疗','支付 '..r.healCost..' 金币，回复 '..heal..' 点生命',run.gold>=r.healCost)
        option('purify','净化','支付 '..r.removeCost..' 金币，移除一张卡牌',run.gold>=r.removeCost and deckOk,'purify')
    elseif id=='purifier' then option('pray','祈祷','免费移除一张卡牌',deckOk,'purify')
    elseif id=='upgrade_shrine' then option('upgrade','升级',upgrades>0 and '免费升级一张卡牌' or '牌组没有可升级的卡牌',upgrades>0,'event_upgrade')
    elseif id=='golden_shrine' then
        local r=run.data.rules.events.golden_shrine
        local curse=find(run.data.cards.cards,r.curse)
        option('pray','领受馈赠','获得 '..r.gold..' 金币')
        option('desecrate','取走供物','获得 '..r.curseGold..' 金币，并将诅咒「'..(curse and curse.name or '余悔')..'」加入牌组')
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

function M.chooseEvent(run, choice, uid)
    local flow, reason = pending(run, "event"); if not flow then return false, reason end
    local id = flow.event.id
    local rules = run.data.rules.events[id] or {}
    if id=='golden_wing' and flow.event.stage=='purge' and choice~='purge' then return false,'invalid_event_choice' end
    local function damage(amount) run.hp=math.max(0,run.hp-amount) end
    if choice == "heal" and id == "cleric" then
        if run.gold < rules.healCost then return false, "insufficient_gold" end
        run.gold = run.gold - rules.healCost
        run.hp = math.min(run.maxHp, run.hp + math.floor(run.maxHp * rules.healPercent / 100))
    elseif (choice == "purify" and id == "cleric") or (choice == "pray" and id == "purifier") then
        local instance, position = find(run.deck, uid, "uid")
        if not instance then return false, "invalid_card" end
        if run.gold < rules.removeCost then return false, "insufficient_gold" end
        table.remove(run.deck, position)
        run.gold = run.gold - rules.removeCost
    elseif choice=='pray' and id=='golden_shrine' then run.gold=run.gold+0.0+rules.gold
    elseif choice=='desecrate' and id=='golden_shrine' then
        local curse=find(run.data.cards.cards,rules.curse)
        -- Preflight the sole supported curse ABI and permanent identity before paying gold.
        if not curse or curse.id~='regret' or curse.type~='curse' or curse.rarity~='curse'
            or curse.cost~=-2 or type(curse.effects)~='table' or next(curse.effects)~=nil
            or curse.upgrade~=nil or curse.condition~=nil or curse.costMode~=nil
            or curse.ethereal or curse.exhaust or curse.innate or curse.repeatable then
            return false,'event_content_unavailable'
        end
        local uid=run.nextDeckUid
        if type(uid)~='number' or uid%1~=0 or uid<1 or uid>=9007199254740991.0
            or find(run.deck,uid,'uid') then return false,'invalid_deck_uid' end
        run.deck[#run.deck+1]={uid=uid,cardId=curse.id,upgraded=false}
        run.nextDeckUid=uid+1.0
        run.gold=run.gold+0.0+rules.curseGold
        flow.event.obtainedCardUid=uid
    elseif choice=='gather' and id=='goop' then damage(rules.damage);run.gold=run.gold+rules.gold
    elseif choice=='leave' and id=='goop' then run.gold=math.max(0,run.gold-flow.event.goldLoss)
    elseif choice=='upgrade' and id=='upgrade_shrine' then
        local instance=find(run.deck,uid,'uid')
        if not instance then return false,'invalid_card' end
        if not upgradeable(run,instance) then return false,'card_not_upgradeable' end
        instance.upgraded=true;flow.event.upgradedUids={uid}
    elseif choice=='accept' and id=='shining_light' then
        local cards=upgradeCards(run)
        if #cards==0 then return false,'card_not_upgradeable' end
        local rng=EventRandom.cloneState(run.miscRng)
        EventRandom.shuffle(rng,cards)
        damage(flow.event.damage)
        flow.event.upgradedUids={}
        for i=1,math.min(rules.upgradeCount,#cards) do
            find(run.deck,cards[i].uid,'uid').upgraded=true
            flow.event.upgradedUids[#flow.event.upgradedUids+1]=cards[i].uid
        end
        run.miscRng=rng
    elseif choice=='sacrifice' and id=='golden_wing' then
        damage(rules.damage);flow.event.stage='purge'
        -- An empty purge group cannot keep the event waiting for a nonexistent UID.
        if run.hp>0 and #run.deck>0 then return true,'choose_purge' end
    elseif choice=='take_gold' and id=='golden_wing' then
        if not flow.event.canAttack then return false,'event_condition_unmet' end
        local rng=EventRandom.cloneState(run.miscRng)
        local gold=EventRandom.randomIntBetween(rng,rules.goldMin,rules.goldMax)
        run.gold,run.miscRng=run.gold+gold,rng
    elseif choice=='purge' and id=='golden_wing' and flow.event.stage=='purge' then
        local instance,position=find(run.deck,uid,'uid')
        if not instance then return false,'invalid_card' end
        table.remove(run.deck,position)
    elseif choice ~= "leave" then return false, "invalid_event_choice" end
    flow.eventChoice = choice
    local ok,result=complete(run)
    if run.hp==0 then run.phase='defeat' end
    return ok,result
end

function M.upgradeEvent(run,uid) return M.chooseEvent(run,'upgrade',uid) end
function M.purgeWing(run,uid) return M.chooseEvent(run,'purge',uid) end

function M.purifyEvent(run, uid)
    local flow = run.nodeFlow
    return M.chooseEvent(run, flow and flow.event and flow.event.id == "purifier" and "pray" or "purify", uid)
end

function M.completeCombat(run, map)
    local flow = run.nodeFlow
    if not flow or flow.complete then return false, "no_pending_node" end
    if not battleKinds[flow.type] then return false, "wrong_node_type" end
    if not matchingMap(flow, map) then return false, "map_mismatch" end
    if run.phase == "defeat" then return false, "run_defeated" end
    if run.phase == "reward" then return false, "reward_pending" end
    if run.phase ~= "map" or not run.lastResult or run.lastResult.outcome ~= "victory"
        or run.lastResult.encounterId ~= flow.encounterId then return false, "battle_unfinished" end
    return complete(run, flow.type == "boss" and "boss_victory" or "victory")
end

return M
