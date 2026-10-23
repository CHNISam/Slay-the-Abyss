-- Seven node flows over the existing same-run state. Adapters must navigate via enter/available.
-- Battle commands/reward selection remain Run commands, followed by completeCombat.
-- Relic/potion runtime effects, persistence restoration and final Boss settlement belong to other modules.
local Run = require("abyss_run")
local Map = require("abyss_map")
local Combat = require("abyss_combat")
local Effects = require("abyss_effects")
local M = {}
local battleKinds = { combat = true, elite = true, boss = true }
local priceKeys = { common = "cardCommon", uncommon = "cardUncommon", rare = "cardRare" }

local function find(entries, id, field)
    for i, entry in ipairs(entries) do if entry[field or "id"] == id then return entry, i end end
end

local function owns(entries, id)
    for _, owned in ipairs(entries) do if owned == id then return true end end
    return false
end

local function playable(card)
    return not card.condition and not card.costMode and Effects.supported(card.effects)
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
        if relic.rarity ~= "starter" and not owns(run.relics, relic.id) then result[#result + 1] = relic.id end
    end
    table.sort(result)
    return result
end

local function prepare(run, node)
    local flow = { id = node.id, floor = node.floor, type = node.type, complete = false,
        encounterId = node.encounterId }
    local random = { seed = run.seed }
    if node.type == "camp" then
        flow.upgradesLeft = run.data.rules.camp.upgradeCount
    elseif node.type == "shop" then
        flow.cards, flow.relics = {}, {}
        for _, card in ipairs(run.data.cards.cards) do
            local key = priceKeys[card.rarity]
            if key and playable(card) then
                flow.cards[#flow.cards + 1] = { id = card.id, price = run.data.rules.shop[key], sold = false }
            end
        end
        for _, id in ipairs(unownedRelics(run)) do
            flow.relics[#flow.relics + 1] = { id = id, price = run.data.rules.shop.relic, sold = false }
        end
        table.sort(flow.cards, function(a, b) return a.id < b.id end)
    elseif node.type == "treasure" then
        local relics = unownedRelics(run)
        flow.reward = #relics > 0 and { relicId = relics[Combat.random(random, #relics)] }
            or { gold = run.data.rules.rewards.normalGold }
    elseif node.type == "event" then
        -- First-release minimal event: choose the existing ordinary gold reward OR a catalog potion.
        -- This is deliberately not a reproduction of any original-game event or new balance table.
        local potions = {}
        for _, potion in ipairs(run.data.potions.potions) do potions[#potions + 1] = potion.id end
        table.sort(potions)
        flow.event = { gold = run.data.rules.rewards.normalGold }
        if #potions > 0 then flow.event.potionId = potions[Combat.random(random, #potions)] end
    end
    return flow, random.seed
end

function M.available(run, map)
    if run.phase ~= "map" or (run.nodeFlow and not run.nodeFlow.complete)
        or not matchingMap(run.nodeFlow, map) then return {} end
    return Map.available(map)
end

function M.enter(run, map, nodeId)
    if run.nodeFlow and not run.nodeFlow.complete then return false, "node_pending" end
    if run.phase ~= "map" then return false, "not_on_map" end
    if not matchingMap(run.nodeFlow, map) then return false, "map_mismatch" end
    local node = find(map.nodes, nodeId)
    if not node then return false, "invalid_node" end
    if not find(Map.available(map), nodeId) then return false, "node_unavailable" end
    if not battleKinds[node.type] and node.type ~= "camp" and node.type ~= "shop"
        and node.type ~= "event" and node.type ~= "treasure" then return false, "unknown_node_type" end
    local flow, seed = prepare(run, node)
    if battleKinds[node.type] then
        -- startCombat validates the encounter using its new floor and constructs the battle before mutation.
        -- A failed setup must not consume a map choice, change the floor or create a node claim.
        local oldFloor = run.floor
        run.floor = node.floor
        local called, ok, reason = pcall(Run.startCombat, run, node.encounterId)
        if not called or not ok then
            run.floor = oldFloor
            return false, called and reason or "combat_unavailable"
        end
    else
        run.floor, run.phase, run.seed = node.floor, "node", seed
    end
    assert(Map.choose(map, nodeId)) -- already validated against the unchanged map above
    flow.mapSeed, flow.mapSignature = map.seed, map.sourceSignature
    run.nodeFlow = flow
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
            node.removePrice = run.data.rules.shop.removeCard
                + (run.shopRemoveCount or 0) * run.data.rules.shop.removeCardIncrement
            node.removeAvailable = not node.removalUsed
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

local function purchase(run, category, id)
    local flow, reason = pending(run, "shop"); if not flow then return false, reason end
    local offer = find(flow[category], id)
    if not offer or offer.sold or (category == "relics" and owns(run.relics, id)) then
        return false, "item_unavailable"
    end
    if run.gold < offer.price then return false, "insufficient_gold" end
    if category == "cards" then
        run.deck[#run.deck + 1] = { uid = run.nextDeckUid, cardId = id, upgraded = false }
        run.nextDeckUid = run.nextDeckUid + 1
    else run.relics[#run.relics + 1] = id end
    run.gold, offer.sold = run.gold - offer.price, true
    return true
end

function M.buyCard(run, id) return purchase(run, "cards", id) end
function M.buyRelic(run, id) return purchase(run, "relics", id) end

function M.removeCard(run, uid)
    local flow, reason = pending(run, "shop"); if not flow then return false, reason end
    -- The service is a one-use offer per shop; the price increase belongs to later shops.
    if flow.removalUsed then return false, "removal_unavailable" end
    local instance, position = find(run.deck, uid, "uid")
    if not instance then return false, "invalid_card" end
    if #run.deck <= 1 then return false, "last_card" end -- Combat.new requires a nonempty permanent deck.
    local price = run.data.rules.shop.removeCard
        + (run.shopRemoveCount or 0) * run.data.rules.shop.removeCardIncrement
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
    if flow.reward.relicId then
        if owns(run.relics, flow.reward.relicId) then return false, "relic_already_owned" end
        run.relics[#run.relics + 1] = flow.reward.relicId
    else run.gold = run.gold + flow.reward.gold end
    return complete(run)
end

function M.chooseEvent(run, choice)
    local flow, reason = pending(run, "event"); if not flow then return false, reason end
    if choice == "gold" then run.gold = run.gold + flow.event.gold
    elseif choice == "potion" and flow.event.potionId then
        if #run.potions >= run.data.rules.player.potionSlots then return false, "potion_slots_full" end
        run.potions[#run.potions + 1] = flow.event.potionId
    else return false, "invalid_event_choice" end
    flow.eventChoice = choice
    return complete(run)
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
