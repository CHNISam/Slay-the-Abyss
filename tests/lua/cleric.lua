-- Original-game event options, not a full original unknown-room/event-pool sampler.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Nodes, Run, Map = require("abyss_nodes"), require("abyss_run"), require("abyss_map")
local Combat, data = require("abyss_combat"), require("abyss_data")
local count = 0
local function equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function same(a, b)
    equal(type(a), type(b))
    if type(a) ~= "table" then equal(a, b); return end
    for key, value in pairs(a) do same(value, b[key]) end
    for key in pairs(b) do assert(a[key] ~= nil, "unexpected field " .. tostring(key)) end
end
local function test(name, fn) fn(); count = count + 1; print("ok cleric " .. count .. " - " .. name) end
local function before(source)
    if not source then
        source = Combat.copy(data); source.rules.events.encounterId = "cleric"
    end
    local run, map = Run.new(source or data, 42), Map.generate(source or data, 42)
    while true do
        local available = Map.available(map); assert(#available > 0)
        for _, node in ipairs(available) do if node.type == "event" then return run, map, node end end
        assert(Map.choose(map, available[1].id))
    end
end
local function entered(source)
    local run, map, node = before(source)
    assert(Nodes.enter(run, map, node.id)); return run, map
end
local function rejected(run, map, command, reason)
    local oldRun, oldMap = Combat.copy(run), Map.snapshot(map)
    local ok, actual = command(); equal(ok, false)
    if reason then equal(actual, reason) end
    same(run, oldRun); same(map, oldMap)
end

test("Cleric only enters at the sourced 35-gold threshold without consuming RNG", function()
    local run, map, node = before()
    run.gold = 34
    rejected(run, map, function() return Nodes.enter(run, map, node.id) end, "event_unavailable")
    run.gold = 35; local seed = run.seed
    assert(Nodes.enter(run, map, node.id)); equal(run.seed, seed)
    local view = Nodes.view(run, map).node.event
    equal(view.id, "cleric"); equal(view.healCost, 35); equal(view.removeCost, 50)
    equal(view.gold, nil); equal(view.potionId, nil)
end)

test("healing costs 35 once, floors 25 percent max HP and caps the actual recovery", function()
    local run, map = entered()
    run.maxHp, run.hp, run.gold = 83, 20, 35
    local view = Nodes.view(run, map).node.event
    equal(view.heal, 20)
    view.healCost, view.heal = 0, 900
    assert(Nodes.chooseEvent(run, "heal")); equal(run.hp, 40); equal(run.gold, 0)
    equal(run.phase, "map"); equal(run.nodeFlow.eventChoice, "heal")
    rejected(run, map, function() return Nodes.chooseEvent(run, "heal") end, "no_pending_node")
    local capped = entered(); capped.hp, capped.gold = capped.maxHp - 1, 35
    assert(Nodes.chooseEvent(capped, "heal")); equal(capped.hp, capped.maxHp); equal(capped.gold, 0)
end)

test("failed healing preserves the leave option and never fabricates gold or potion rewards", function()
    local run, map = entered(); run.gold = 34
    rejected(run, map, function() return Nodes.chooseEvent(run, "heal") end, "insufficient_gold")
    for _, choice in ipairs({"gold", "potion", "fake", false, {}}) do
        rejected(run, map, function() return Nodes.chooseEvent(run, choice) end, "invalid_event_choice")
    end
    local old = Combat.copy(run)
    assert(Nodes.chooseEvent(run, "leave")); equal(run.phase, "map")
    equal(run.hp, old.hp); equal(run.gold, old.gold); same(run.deck, old.deck)
    same(run.potions, old.potions); same(run.relics, old.relics); equal(run.seed, old.seed)
    rejected(run, map, function() return Nodes.chooseEvent(run, "leave") end, "no_pending_node")
end)

test("Purify costs 50 and removes only the selected UID without raising shop prices", function()
    local run, map = entered(); run.gold = 50; run.shopRemoveCount = 2
    local first, second, uid, nextUid = run.deck[1].uid, run.deck[2].uid, run.deck[3].uid, run.nextDeckUid
    run.deck[3].upgraded = true
    rejected(run, map, function() return Nodes.purifyEvent(run, -1) end, "invalid_card")
    assert(Nodes.purifyEvent(run, uid)); equal(run.gold, 0); equal(#run.deck, 9)
    equal(run.deck[1].uid, first); equal(run.deck[2].uid, second)
    for _, instance in ipairs(run.deck) do assert(instance.uid ~= uid) end
    equal(run.nextDeckUid, nextUid); equal(run.shopRemoveCount, 2)
    equal(run.nodeFlow.eventChoice, "purify"); equal(run.nodeFlow.removalUsed, nil)
    rejected(run, map, function() return Nodes.purifyEvent(run, second) end, "no_pending_node")
end)

test("Purify refusals leave all resources and the pending event intact", function()
    local run, map = entered(); run.gold = 49
    rejected(run, map, function() return Nodes.purifyEvent(run, run.deck[1].uid) end, "insufficient_gold")
    for _, uid in ipairs({false, {}, "1", 0, -1, 1.5, math.huge, 0/0}) do
        rejected(run, map, function() return Nodes.purifyEvent(run, uid) end, "invalid_card")
    end
    rejected(run, map, function() return Nodes.purifyEvent(run) end, "invalid_card")
    while #run.deck > 1 do table.remove(run.deck) end
    run.gold = 50
    rejected(run, map, function() return Nodes.purifyEvent(run, run.deck[1].uid) end, "last_card")
    assert(Nodes.chooseEvent(run, "leave"))
end)

test("event amounts come from validated rules and all commands respect the active node", function()
    local source = Combat.copy(data)
    source.rules.events.encounterId = "cleric"
    source.rules.events.cleric = { minGold = 7, healCost = 7, healPercent = 17, removeCost = 9 }
    local run, map = entered(source); run.hp, run.gold = 1, 7
    local heal = math.floor(run.maxHp * 17 / 100)
    equal(Nodes.view(run, map).node.event.heal, heal)
    assert(Nodes.chooseEvent(run, "heal")); equal(run.hp, 1 + heal); equal(run.gold, 0)
    local other, otherMap, node = before(source)
    rejected(other, otherMap, function() return Nodes.purifyEvent(other, other.deck[1].uid) end, "no_pending_node")
    assert(Nodes.enter(other, otherMap, node.id)); other.gold = 9
    assert(Nodes.purifyEvent(other, other.deck[1].uid)); equal(other.gold, 0)
end)

test("explicit Purifier is available with zero gold and either source option remains safe", function()
    for _, choice in ipairs({"leave", "pray"}) do
        local source = Combat.copy(data); source.rules.player.startingGold = 0
        source.rules.events.encounterId='purifier'
        local run, map, node = before(source)
        local seed = run.seed
        assert(Nodes.enter(run, map, node.id)); equal(run.seed, seed)
        local view = Nodes.view(run, map).node.event
        equal(view.id, "purifier"); equal(view.removeCost, 0)
        equal(view.heal, nil); equal(view.healCost, nil)
        rejected(run, map, function() return Nodes.chooseEvent(run, "heal") end, "invalid_event_choice")
        rejected(run, map, function() return Nodes.chooseEvent(run, "purify", run.deck[1].uid) end, "invalid_event_choice")
        local size, nextUid = #run.deck, run.nextDeckUid
        assert(Nodes.chooseEvent(run, choice, run.deck[2].uid)); equal(run.phase, "map")
        equal(run.gold, 0); equal(run.nextDeckUid, nextUid)
        equal(#run.deck, size - (choice == "pray" and 1 or 0)); equal(run.shopRemoveCount or 0, 0)
        equal(#Nodes.available(run, map) > 0, true)
        rejected(run, map, function() return Nodes.purifyEvent(run, run.deck[1].uid) end, "no_pending_node")
    end
end)

test("low-gold consecutive explicit Purifier nodes retain their leave exit", function()
    local source = Combat.copy(data); source.rules.player.startingGold = 0
    local run, map = Run.new(source, 42), Map.generate(source, 42)
    -- Routing fixture makes the next two layers unknowns; it does not assert original map probabilities.
    for _, node in ipairs(map.nodes) do if node.floor <= 2 then node.type, node.encounterId, node.eventId = "event", nil, 'purifier' end end
    for _ = 1, 2 do
        local available = Nodes.available(run, map); assert(#available > 0)
        for _, node in ipairs(available) do equal(node.type, "event") end
        assert(Nodes.enter(run, map, available[1].id)); equal(run.nodeFlow.event.id, "purifier")
        assert(Nodes.chooseEvent(run, "leave")); equal(run.gold, 0)
    end
    equal(run.floor, 2); assert(#Nodes.available(run, map) > 0)
end)

print("LUA_CLERIC_PASS " .. count)
