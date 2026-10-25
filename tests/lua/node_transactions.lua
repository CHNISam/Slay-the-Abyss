-- API transaction contracts only, not original-game economy or platform certification.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Nodes, Run, Map = require("abyss_nodes"), require("abyss_run"), require("abyss_map")
local Combat, data = require("abyss_combat"), require("abyss_data")
local count, refusals = 0, 0
local proofCase = ""
local function equal(a, b)
    if a ~= b then error("[ABYSS_ASSERT M3:" .. proofCase .. "] " .. tostring(a) .. " ~= " .. tostring(b)) end
end
local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}; if seen[value] then return seen[value] end
    local result = {}; seen[value] = result
    for key, item in pairs(value) do
        result[key] = type(item) == "table" and copy(item, seen) or item
    end
    return result
end
-- Check both values and alias topology, without recursing forever on shared/cyclic tables.
local function same(a, b, forward, backward)
    if a == b then return end
    equal(type(a), type(b))
    if type(a) ~= "table" then equal(a, b); return end
    forward, backward = forward or {}, backward or {}
    if forward[a] then equal(forward[a], b); return end
    assert(not backward[b], "unexpected alias")
    forward[a], backward[b] = b, a
    for key, value in pairs(a) do
        local other = b[key]
        if value ~= other then same(value, other, forward, backward) end
    end
    for key in pairs(b) do
        if a[key] == nil then error("missing key " .. tostring(key)) end
    end
end
local function test(name, fn) proofCase = name; fn(); count = count + 1; print("ok node transactions " .. count .. " - " .. name) end
local function rejected(run, map, fn, before)
    before = before or copy({run = run, map = map})
    local ok, reason = fn()
    equal(ok, false); assert(type(reason) == "string" and #reason > 0)
    same({run = run, map = map}, before)
    refusals = refusals + 1
end
-- Navigation-only fixture: stage preceding map choices, then enter through public Nodes.
-- Does not claim a played route or verify original map/economy values.
local function entered(kind)
    local run, map = Run.new(data, 42), Map.generate(data, 42)
    while true do
        local choices = Map.available(map); assert(#choices > 0)
        for _, node in ipairs(choices) do
            if node.type == kind then assert(Nodes.enter(run, map, node.id)); return run, map end
        end
        assert(Map.choose(map, choices[1].id))
    end
end
local function commands(run)
    return {
        camp = { function() return Nodes.rest(run) end, function() return Nodes.upgrade(run, run.deck[1].uid) end },
        shop = { function() return Nodes.buyCard(run, "anger") end, function() return Nodes.buyRelic(run, "vajra") end,
            function() return Nodes.removeCard(run, run.deck[1].uid) end, function() return Nodes.leaveShop(run) end },
        treasure = { function() return Nodes.claimTreasure(run) end },
        event = { function() return Nodes.chooseEvent(run, "heal") end, function() return Nodes.purifyEvent(run, run.deck[1].uid) end }
    }
end
local function rejectOtherNodes(run, map, active)
    -- No successful commands in this batch: one frozen snapshot, checked after every refusal.
    local before = copy({run = run, map = map})
    for kind, list in pairs(commands(run)) do
        if kind ~= active then for _, command in ipairs(list) do rejected(run, map, command, before) end end
    end
end

for _, kind in ipairs({"camp", "shop", "treasure", "event", "combat", "elite", "boss"}) do
    test(kind .. " refuses foreign node commands without spending resources or changing UID/RNG", function()
        local run, map = entered(kind)
        rejectOtherNodes(run, map, kind)
        rejected(run, map, function() return Run.claimCardReward(run, 0) end)
        if kind == "camp" then assert(Nodes.rest(run))
        elseif kind == "shop" then assert(Nodes.leaveShop(run))
        elseif kind == "treasure" then assert(Nodes.claimTreasure(run))
        elseif kind == "event" then assert(Nodes.chooseEvent(run, "leave"))
        else assert(Run.endTurn(run)); return end
        -- Stale callbacks after completion must not consume another transaction.
        rejectOtherNodes(run, map, nil)
        assert(#Nodes.available(run, map) > 0)
    end)
end

local invalidIds = { false, true, {}, "", "missing", -1, 0, 1.5, math.huge, 0/0 }
for _, kind in ipairs({"shop", "camp"}) do
    test(kind .. " incomplete and malformed commands preserve the pending valid choice", function()
        local run, map = entered(kind)
        local functions = kind == "shop" and {Nodes.buyCard, Nodes.buyRelic, Nodes.removeCard} or {Nodes.upgrade}
        local before = copy({run = run, map = map})
        for _, command in ipairs(functions) do
            rejected(run, map, function() return command(run) end, before)
            for _, id in ipairs(invalidIds) do rejected(run, map, function() return command(run, id) end, before) end
        end
        if kind == "camp" then
            assert(Nodes.upgrade(run, run.deck[1].uid)); equal(run.deck[1].upgraded, true)
        else
            local offer = Nodes.view(run, map).node.cards[1]
            -- Funding fixture only; assertions compare the actual offer, not a balance constant.
            run.gold = offer.price
            local uid, size = run.nextDeckUid, #run.deck
            assert(Nodes.buyCard(run, offer.id)); equal(run.gold, 0)
            equal(#run.deck, size + 1); equal(run.deck[#run.deck].uid, uid)
            equal(run.nextDeckUid, uid + 1)
            assert(Nodes.leaveShop(run))
        end
    end)
end

test("shop and camp views are detached even for nested offers, card instances and navigation", function()
    for _, kind in ipairs({"shop", "camp"}) do
        local run, map = entered(kind)
        local before = copy({run = run, map = map})
        local view = Nodes.view(run, map)
        view.node.complete = true
        if kind == "shop" then
            view.node.cards[1].price = -1; view.node.cards[1].sold = true
            view.node.relics[1].id = "forged"
            view.node.cards[#view.node.cards + 1] = {id = "forged", price = 0}
        else view.node.upgradeCards[1].uid = -1; view.node.upgradeCards[1].upgraded = true end
        view.map.nodes[1].nextIds[1] = "forged"; view.map.path[1] = "forged"
        same({run = run, map = map}, before)
        if kind == "shop" then assert(Nodes.leaveShop(run)) else assert(Nodes.upgrade(run, run.deck[1].uid)) end
        before = copy({run = run, map = map})
        local choices = Nodes.available(run, map); assert(#choices > 0)
        local id = choices[1].id
        choices[1].id = "forged"; choices[1].nextIds[1] = "forged"
        same({run = run, map = map}, before)
        assert(Nodes.enter(run, map, id))
    end
end)

test("real battle reward rejects stale node and malformed reward commands before a valid claim", function()
    local run, map = entered("combat")
    -- Original catalog and starter deck, no enemy HP/resource edits.
    for _ = 1, 100 do
        if run.phase ~= "combat" then break end
        local target
        for i, enemy in ipairs(run.combat.enemies) do if enemy.hp > 0 then target = i; break end end
        local chosen
        for _, card in ipairs(run.combat.hand) do
            if Combat.canPlay(run.combat, card.uid, target) then
                chosen = card
                if Combat.cardDefinition(run.combat, card).type == "attack" then break end
            end
        end
        if chosen then assert(Run.play(run, chosen.uid, target)) else assert(Run.endTurn(run)) end
    end
    equal(run.phase, "reward")
    rejectOtherNodes(run, map, nil)
    local before = copy({run = run, map = map})
    rejected(run, map, function() return Nodes.completeCombat(run, map) end, before)
    rejected(run, map, function() return Run.claimCardReward(run) end, before)
    for _, choice in ipairs({false, true, {}, "1", -1, 1.5, math.huge, 0/0}) do
        rejected(run, map, function() return Run.claimCardReward(run, choice) end, before)
    end
    rejected(run, map, function() return Run.claimCardReward(run, #run.rewards.cards + 1) end, before)
    local options = Run.rewardOptions(run)
    local id, uid, size = options[1], run.nextDeckUid, #run.deck
    options[1] = "forged"
    equal(Run.rewardOptions(run)[1], id)
    assert(Run.claimCardReward(run, 1)); dofile('tests/lua/support/finish_combat_rewards.lua')(run)
    equal(#run.deck, size + 1); equal(run.deck[#run.deck].cardId, id)
    equal(run.deck[#run.deck].uid, uid); equal(run.nextDeckUid, uid + 1)
    rejected(run, map, function() return Run.claimCardReward(run, 1) end)
    assert(Nodes.completeCombat(run, map))
    local nextNode = Nodes.available(run, map)[1]; assert(nextNode)
    assert(Nodes.enter(run, map, nextNode.id))
end)

print("LUA_NODE_TRANSACTIONS_PASS " .. count .. " refusals=" .. refusals)
