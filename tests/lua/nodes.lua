package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local loaded, Nodes = pcall(require, "abyss_nodes")
assert(loaded, "TASK-13 requires abyss_nodes node flow service")
local Run, Map = require("abyss_run"), require("abyss_map")
local Combat, Effects = require("abyss_combat"), require("abyss_effects")
local data = require("abyss_data")
local count = 0
local function equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function same(a, b)
    equal(type(a), type(b))
    if type(a) ~= "table" then equal(a, b); return end
    for k, v in pairs(a) do same(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil, "unexpected key " .. tostring(k)) end
end
local function test(name, fn) fn(); count = count + 1; print("ok nodes " .. count .. " - " .. name) end
local function rejected(run, map, fn, reason)
    local beforeRun, beforeMap = Combat.copy(run), Map.snapshot(map)
    local ok, actual = fn(); equal(ok, false)
    if reason then equal(actual, reason) end
    same(run, beforeRun); same(map, beforeMap)
end
-- Stage preceding navigation with the real map API; each test enters its target via Nodes.
local function before(kind, source, seed, minimumFloor)
    local run, map = Run.new(source or data, seed or 42), Map.generate(source or data, seed or 42)
    while true do
        local available = Map.available(map)
        for _, node in ipairs(available) do
            if node.type == kind and node.floor >= (minimumFloor or 1) then return run, map, node end
        end
        assert(#available > 0, "fixture route must reach " .. kind)
        assert(Map.choose(map, available[1].id))
    end
end
local function entered(kind, source, seed, minimumFloor)
    local run, map, node = before(kind, source, seed, minimumFloor)
    assert(Nodes.enter(run, map, node.id)); return run, map, node
end
local function easyData()
    local source = Combat.copy(data)
    for _, enemy in ipairs(source.enemies.enemies) do enemy.hp, enemy.hpRange = 1, nil end -- explicit one-HP navigation fixture
    return source
end
local function finishBattle(run)
    for _ = 1, 100 do
        if run.phase ~= "combat" then break end
        local target
        for i, enemy in ipairs(run.combat.enemies) do if enemy.hp > 0 then target = i; break end end
        local chosen
        for _, card in ipairs(run.combat.hand) do
            if Combat.canPlay(run.combat, card.uid, target) then chosen = card
                if Combat.cardDefinition(run.combat, card).type == "attack" then break end
            end
        end
        if chosen then assert(Run.play(run, chosen.uid, target)) else assert(Run.endTurn(run)) end
    end
    equal(run.phase, "reward")
end

test("legal map selection starts the matching source queue tier or Guardian", function()
    for _, kind in ipairs({ "combat", "elite", "boss" }) do
        local run, map, node = entered(kind)
        equal(map.currentNodeId, node.id); equal(run.floor, node.floor)
        equal(run.phase, "combat"); equal(run.encounterTier,kind=='combat' and 'normal' or kind)
        equal(run.nodeFlow.encounterId,run.encounterId);assert(run.encounterSource)
        equal(#Nodes.available(run, map), 0)
        rejected(run, map, function() return Nodes.enter(run, map, Map.available(map)[1] and Map.available(map)[1].id) end)
        rejected(run, map, function() return Nodes.completeCombat(run, map) end, "battle_unfinished")
    end
end)

test("invalid selection and failed combat setup leave the map and run unchanged", function()
    local run, map = Run.new(data, 3), Map.generate(data, 3)
    rejected(run, map, function() return Nodes.enter(run, map, "f15_l2") end, "node_unavailable")
    rejected(run, map, function() return Nodes.enter(run, map, "missing") end, "invalid_node")
    run.relics={'missing'}
    rejected(run, map, function() return Nodes.enter(run, map, Map.available(map)[1].id) end, "unknown_relic")
end)

test("an ordinary treasure cannot impersonate the earned Boss chest", function()
    local run, map, node = before("treasure")
    -- Map.available returns detached descriptions; mark the actual source node.
    for _, original in ipairs(map.nodes) do
        if original.id == node.id then original.roomKind = "boss_treasure" end
    end
    rejected(run, map, function() return Nodes.enter(run, map, node.id) end, "boss_treasure_unavailable")
end)

test("camp healing uses current rules, caps hp and consumes the single choice", function()
    local source = Combat.copy(data); source.rules.camp.healPercent = 17
    local run, map = entered("camp", source)
    run.hp = 20
    assert(Nodes.rest(run)); equal(run.hp, 20 + math.floor(run.maxHp * 17 / 100))
    equal(run.phase, "map"); assert(#Nodes.available(run, map) > 0)
    rejected(run, map, function() return Nodes.rest(run) end)
    rejected(run, map, function() return Nodes.upgrade(run, run.deck[1].uid) end)
    local capped = entered("camp"); capped.hp = capped.maxHp - 1
    assert(Nodes.rest(capped)); equal(capped.hp, capped.maxHp)
end)

test("camp upgrades the permanent uid once and the next battle uses upgraded effects", function()
    local run, map = entered("camp", nil, 42, 14)
    local uid = run.deck[1].uid
    rejected(run, map, function() return Nodes.upgrade(run, -1) end, "invalid_card")
    assert(Nodes.upgrade(run, uid)); equal(run.deck[1].upgraded, true); equal(run.phase, "map")
    local nextNode = Nodes.available(run, map)[1]; assert(Nodes.enter(run, map, nextNode.id))
    local found
    for _, pile in ipairs({ run.combat.hand, run.combat.draw }) do
        for _, card in ipairs(pile) do if card.cardId == "strike" and card.upgraded then found = card end end
    end
    assert(found); equal(Combat.cardDefinition(run.combat, found).effects[1].value, data.cards.cards[1].upgrade.effects[1].value)
end)

test("camp reads upgradeCount and rejects an already upgraded or unsupported choice", function()
    local source = Combat.copy(data); source.rules.camp.upgradeCount = 2
    local run, map = entered("camp", source)
    assert(Nodes.upgrade(run, run.deck[1].uid)); equal(run.phase, "node")
    rejected(run, map, function() return Nodes.rest(run) end, "camp_choice_made")
    rejected(run, map, function() return Nodes.upgrade(run, run.deck[1].uid) end, "card_not_upgradeable")
    assert(Nodes.upgrade(run, run.deck[2].uid)); equal(run.phase, "map")
    local unsupported = Combat.copy(data)
    unsupported.cards.cards[1].upgrade.effects = { { op = "heal", value = 6 } }
    local other, otherMap = entered("camp", unsupported)
    rejected(other, otherMap, function() return Nodes.upgrade(other, other.deck[1].uid) end, "card_not_upgradeable")
end)

test("shop offers only playable cards and purchases unique permanent cards atomically", function()
    local run, map = entered("shop")
    local view = Nodes.view(run, map)
    assert(#view.node.cards > 0)
    for _, offer in ipairs(view.node.cards) do
        if not offer.unavailable then
        local definition
        for _, card in ipairs(run.data.cards.cards) do if card.id == offer.id then definition = card end end
        assert(Effects.supported(definition.effects)); assert(not definition.condition and not definition.costMode)
        assert(definition.rarity ~= "basic" and definition.rarity ~= "special")
        end
    end
    local offer = view.node.cards[1]
    run.gold = offer.price - 1
    rejected(run, map, function() return Nodes.buyCard(run, offer.id) end, "insufficient_gold")
    rejected(run, map, function() return Nodes.buyCard(run, "strike") end, "item_unavailable")
    run.gold = offer.price
    local size, uid = #run.deck, run.nextDeckUid
    assert(Nodes.buyCard(run, offer.id)); equal(run.gold, 0); equal(#run.deck, size + 1)
    equal(run.deck[#run.deck].uid, uid); equal(run.deck[#run.deck].cardId, offer.id)
    equal(run.nextDeckUid, uid + 1)
    rejected(run, map, function() return Nodes.buyCard(run, offer.id) end, "item_unavailable")
    equal(run.phase, "node"); assert(Nodes.leaveShop(run)); equal(run.phase, "map")
    rejected(run, map, function() return Nodes.leaveShop(run) end)
end)

test("shop relic stock excludes owned items and writes inventory after payment", function()
    local run, map = entered("shop")
    local offers = Nodes.view(run, map).node.relics; assert(#offers > 0)
    for _, offer in ipairs(offers) do assert(offer.id ~= "burning_blood") end
    local offer = offers[3]; run.gold = offer.price - 1
    rejected(run, map, function() return Nodes.buyRelic(run, offer.id) end, "insufficient_gold")
    run.gold = offer.price
    assert(Nodes.buyRelic(run, offer.id)); equal(run.gold, 0); equal(run.relics[#run.relics], offer.id)
    rejected(run, map, function() return Nodes.buyRelic(run, offer.id) end, "item_unavailable")
end)

test("shop deletion targets uid, charges once, and reserves the increase for the next shop", function()
    local run, map = entered("shop")
    local price = data.rules.shop.removeCard
    run.gold = price - 1
    rejected(run, map, function() return Nodes.removeCard(run, run.deck[1].uid) end, "insufficient_gold")
    rejected(run, map, function() return Nodes.removeCard(run, -1) end, "invalid_card")
    run.gold = price
    local uid, otherUid = run.deck[1].uid, run.deck[2].uid
    assert(Nodes.removeCard(run, uid)); equal(#run.deck, 9); equal(run.deck[1].uid, otherUid); equal(run.gold, 0)
    equal(Nodes.view(run, map).node.removePrice, price + data.rules.shop.removeCardIncrement)
    equal(Nodes.view(run, map).node.removeAvailable, false)
    run.gold = 10000
    rejected(run, map, function() return Nodes.removeCard(run, uid) end, "removal_unavailable")
    rejected(run, map, function() return Nodes.removeCard(run, otherUid) end, "removal_unavailable")
    equal(run.shopRemoveCount, 1)
    -- The exhausted service does not close the shop or disable independent purchases.
    local offer = run.nodeFlow.cards[1]
    assert(Nodes.buyCard(run, offer.id)); assert(Nodes.leaveShop(run))
end)

test("invalid UID does not consume the last-card shop service", function()
    local run, map = entered("shop")
    while #run.deck > 1 do table.remove(run.deck) end
    run.gold = 10000
    rejected(run, map, function() return Nodes.removeCard(run, -1) end, "invalid_card")
    equal(Nodes.view(run, map).node.removeAvailable, true)
    local offer = run.nodeFlow.cards[1]
    assert(Nodes.buyCard(run, offer.id))
    assert(Nodes.removeCard(run, run.deck[1].uid))
end)

test("shop service view is read-only and a new run does not inherit its use or price", function()
    local run, map = entered("shop")
    local view = Nodes.view(run, map).node
    equal(view.removeAvailable, true)
    view.removeAvailable, view.removalUsed = false, true
    equal(Nodes.view(run, map).node.removeAvailable, true)
    run.gold = view.removePrice
    assert(Nodes.removeCard(run, run.deck[1].uid))
    view = Nodes.view(run, map).node
    view.removeAvailable, view.removalUsed = true, false
    rejected(run, map, function() return Nodes.removeCard(run, run.deck[1].uid) end, "removal_unavailable")
    local restarted, restartedMap = entered("shop")
    local fresh = Nodes.view(restarted, restartedMap).node
    equal(fresh.removeAvailable, true); equal(fresh.removePrice, data.rules.shop.removeCard)
    equal(restarted.shopRemoveCount or 0, 0)
end)

test("treasure is deterministic, grants an unowned relic once, and copies its view", function()
    local a, map = entered("treasure", nil, 18)
    local b, otherMap = entered("treasure", nil, 18)
    local view = Nodes.view(a, map); same(view.node.reward, Nodes.view(b, otherMap).node.reward)
    local id = view.node.reward.relicId; assert(id and id ~= "burning_blood")
    view.node.reward.relicId = "fake"
    equal(Nodes.view(a, map).node.reward.relicId, id)
    assert(Nodes.claimTreasure(a)); equal(a.relics[#a.relics], id); equal(a.phase, "map")
    rejected(a, map, function() return Nodes.claimTreasure(a) end)
end)

test("treasure with all relics owned uses the existing normal gold reward", function()
    local run, map, node = before("treasure")
    run.relics = {}; for _, relic in ipairs(data.relics.relics) do run.relics[#run.relics + 1] = relic.id end
    assert(Nodes.enter(run, map, node.id)); local gold = run.gold
    assert(Nodes.claimTreasure(run)); equal(run.gold, gold + data.rules.rewards.normalGold)
end)

test("Cleric replaces fabricated gold and potion rewards with a one-time sourced service", function()
    local source = Combat.copy(data); source.rules.events.encounterId = "cleric"
    local run, map = entered("event", source)
    local gold, hp = run.gold, run.hp
    rejected(run, map, function() return Nodes.chooseEvent(run, "fake") end, "invalid_event_choice")
    rejected(run, map, function() return Nodes.chooseEvent(run, "gold") end, "invalid_event_choice")
    rejected(run, map, function() return Nodes.chooseEvent(run, "potion") end, "invalid_event_choice")
    assert(Nodes.chooseEvent(run, "heal")); equal(run.gold, gold - data.rules.events.cleric.healCost)
    equal(run.hp, hp)
    equal(#run.potions, 0); equal(run.phase, "map")
    rejected(run, map, function() return Nodes.chooseEvent(run, "heal") end)
end)

test("full potion inventory is unchanged when leaving Cleric", function()
    local run, map = entered("event")
    for _ = 1, data.rules.player.potionSlots do run.potions[#run.potions + 1] = "fire_potion" end
    local potions, gold = Combat.copy(run.potions), run.gold
    assert(Nodes.chooseEvent(run, "leave")); equal(run.phase, "map")
    same(run.potions, potions); equal(run.gold, gold)
end)

test("battle node stays locked through card reward and completes only once", function()
    local run, map = entered("combat", easyData())
    finishBattle(run)
    rejected(run, map, function() return Nodes.completeCombat(run, map) end, "reward_pending")
    equal(#Nodes.available(run, map), 0)
    assert(Run.claimCardReward(run, 1)); dofile('tests/lua/support/finish_combat_rewards.lua')(run); equal(#Nodes.available(run, map), 0)
    assert(Nodes.completeCombat(run, map)); assert(#Nodes.available(run, map) > 0)
    rejected(run, map, function() return Nodes.completeCombat(run, map) end, "no_pending_node")
end)

test("real starter wins a map-dispatched encounter without combat or content state edits", function()
    local run, map = Run.new(data, 42), Map.generate(data, 42)
    local selected=Map.available(map)[1]
    equal(require('abyss_encounter_queue').peek(run.encounters,'normal'),'Cultist')
    assert(Nodes.enter(run, map, selected.id)); finishBattle(run)
    assert(run.hp > 0); equal(run.lastResult.outcome, "victory"); equal(#run.deck, 10)
    assert(Run.claimCardReward(run, 1)); dofile('tests/lua/support/finish_combat_rewards.lua')(run); assert(Nodes.completeCombat(run, map))
    equal(#run.deck, 11); assert(#Nodes.available(run, map) > 0)
end)

test("completed flows cannot be attached to a different map or mutated through views", function()
    local run, map = entered("camp")
    local view = Nodes.view(run, map)
    view.node.upgradesLeft = 100; view.node.upgradeCards[1].upgraded = true
    view.map.nodes[1].type = "fake"
    equal(run.nodeFlow.upgradesLeft, data.rules.camp.upgradeCount)
    equal(run.deck[1].upgraded, false); assert(map.nodes[1].type ~= "fake")
    assert(Nodes.rest(run))
    local otherMap = Map.generate(data, 43)
    equal(#Nodes.available(run, otherMap), 0)
    rejected(run, otherMap, function() return Nodes.enter(run, otherMap, Map.available(otherMap)[1].id) end, "map_mismatch")
end)

test("shops keep configured deletion increments and purchases across independently sampled nodes", function()
    local source = easyData()
    source.rules.player.startingGold = 10000
    source.rules.shop = { cardCommon = 13, cardUncommon = 17, cardRare = 19, relic = 23,
        removeCard = 29, removeCardIncrement = 31 }
    local run, map, shops = Run.new(source, 1), Map.generate(source, 1), 0
    local route=dofile('tests/lua/support/map_routes.lua').best(map,function(n)return n.type=='shop'and 1 or 0 end)
    local relicId, cardId
    while shops < 2 do
        local node = dofile('tests/lua/support/map_routes.lua').at(map,route[#map.path+1])
        assert(Nodes.enter(run, map, node.id))
        if run.phase == "combat" then
            finishBattle(run); assert(Run.claimCardReward(run, 0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run); assert(Nodes.completeCombat(run, map))
        elseif node.type == "camp" then assert(Nodes.rest(run))
        elseif node.type == "treasure" then assert(Nodes.claimTreasure(run))
        elseif node.type == "event" then assert(Nodes.chooseEvent(run, "leave"))
        elseif node.type == "shop" then
            shops = shops + 1
            local view = Nodes.view(run, map).node
            equal(view.removePrice, require('abyss_shop').removePrice(run))
            equal(view.removeAvailable, true)
            if shops == 1 then
                cardId = view.cards[1].id
                local gold, price = run.gold, view.cards[1].price
                assert(Nodes.buyCard(run, cardId)); equal(run.gold, gold - price)
                for _,o in ipairs(view.relics) do
                    if not o.unavailable and o.id~='courier' and o.id~='membership_card' and o.id~='smiling_mask' then
                        relicId=o.id;gold=run.gold;assert(Nodes.buyRelic(run,relicId));equal(run.gold,gold-o.price);break
                    end
                end
            else
                for _, offer in ipairs(view.relics) do assert(offer.id ~= relicId) end
                local available
                for _,o in ipairs(view.cards) do if not o.unavailable then available=o;break end end
                assert(available and Nodes.buyCard(run,available.id)) -- new independently sampled stock
            end
            local gold = run.gold
            assert(Nodes.removeCard(run, run.deck[1].uid)); equal(run.gold, gold - view.removePrice)
            equal(Nodes.view(run, map).node.removeAvailable, false)
            rejected(run, map, function() return Nodes.removeCard(run, run.deck[1].uid) end, "removal_unavailable")
            assert(Nodes.leaveShop(run))
        end
    end
    equal(run.shopRemoveCount, 2)
end)

test("lost battle never completes or unlocks a node", function()
    local run, map, node = before("combat"); run.hp = 1
    assert(Nodes.enter(run, map, node.id))
    for _=1,3 do if run.phase=='combat'then assert(Run.endTurn(run))end end
    equal(run.phase, "defeat") -- Cultist's first source move is Ritual, then Attack.
    rejected(run, map, function() return Nodes.completeCombat(run, map) end, "run_defeated")
    equal(#Nodes.available(run, map), 0)
end)

test("existing node flows reach Boss16 and expose the separate pending Boss treasure entrance", function()
    local run, map = Run.new(easyData(), 42), Map.generate(easyData(), 42)
    local seen = {}
    while map.floor < data.rules.map.bossFloor do
        local node = Nodes.available(run, map)[1]; seen[node.type] = true
        assert(Nodes.enter(run, map, node.id)); equal(#Nodes.available(run, map), 0)
        if run.phase == "combat" then
            finishBattle(run)
            -- This one-HP navigation fixture declines bottles explicitly; the
            -- normal-data resource route exercises acquisition and full belts.
            if run.rewards.potion then assert(Run.skipPotionReward(run)) end
            assert(Run.claimCardReward(run, 0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run)
            local ok, result = Nodes.completeCombat(run, map); assert(ok)
            if node.type == "boss" then equal(result, "boss_victory") end
        elseif node.type == "camp" then assert(Nodes.rest(run))
        elseif node.type == "shop" then assert(Nodes.leaveShop(run))
        elseif node.type == "treasure" then assert(Nodes.claimTreasure(run))
        elseif node.type == "event" then assert(Nodes.chooseEvent(run, "leave")) end
    end
    equal(#map.path, data.rules.map.bossFloor)
    for _, kind in ipairs({"combat", "treasure", "camp", "boss"}) do assert(seen[kind], "missing mandatory " .. kind) end
    equal(run.nodeFlow.result, "boss_victory")
    local nextRoom = Map.available(map)
    equal(#nextRoom, 1); equal(nextRoom[1].roomKind, "boss_treasure")
    equal(nextRoom[1].floor, data.rules.map.bossTreasureFloor)
end)

print("LUA_NODES_PASS " .. count)
