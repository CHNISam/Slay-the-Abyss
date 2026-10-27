-- Same-run ownership across Map.restore; not exit/resume storage or rule-parity evidence.
-- A real first battle and public node commands create every pending transaction.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Run, Nodes, Map = require("abyss_run"), require("abyss_nodes"), require("abyss_map")
local Combat, data = require("abyss_combat"), require("abyss_data")
local count, rejectedSnapshots = 0, 0
local function equal(a, b, message)
    assert(a == b, (message or "different values") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}; if seen[value] then return seen[value] end
    local result = {}; seen[value] = result
    for key, item in pairs(value) do result[key] = copy(item, seen) end
    return result
end
-- Preserve values and alias topology, including hostile cyclic snapshot inputs.
local function same(a, b, forward, backward)
    if a == b then return end
    equal(type(a), type(b))
    if type(a) ~= "table" then equal(a, b); return end
    forward, backward = forward or {}, backward or {}
    if forward[a] then equal(forward[a], b); return end
    assert(not backward[b], "unexpected alias")
    forward[a], backward[b] = b, a
    for key, value in pairs(a) do same(value, b[key], forward, backward) end
    for key in pairs(b) do assert(a[key] ~= nil, "unexpected key " .. tostring(key)) end
end
local function test(name, fn)
    fn(); count = count + 1; print("ok inventory_restore " .. count .. " - " .. name)
end
local function refuse(run, map, command, reason)
    local before, flow, deck, relics, potions = copy({run, map}), run.nodeFlow, run.deck, run.relics, run.potions
    local ok, actual = command()
    equal(ok, false); equal(actual, reason); same({run, map}, before)
    equal(run.nodeFlow, flow); equal(run.deck, deck); equal(run.relics, relics); equal(run.potions, potions)
end
local function enter(run, map, id, kind)
    local found
    for _, node in ipairs(Nodes.available(run, map)) do if node.id == id then found = node end end
    assert(found, "route fixture unavailable: " .. id); equal(found.type, kind)
    assert(Nodes.enter(run, map, id))
end
local function finishBattle(run)
    for _ = 1, 200 do
        if run.phase ~= "combat" then break end
        local target
        for index, enemy in ipairs(run.combat.enemies) do if enemy.hp > 0 then target = index; break end end
        local selected
        for _, card in ipairs(run.combat.hand) do
            if Combat.canPlay(run.combat, card.uid, target) then
                selected = card
                if Combat.cardDefinition(run.combat, card).type == "attack" then break end
            end
        end
        if selected then assert(Run.play(run, selected.uid, target)) else assert(Run.endTurn(run)) end
    end
    equal(run.phase, "reward"); equal(run.lastResult.outcome, "victory")
end
local Routes=dofile('tests/lua/support/map_routes.lua')
-- Complete intervening source rooms through public commands. This preserves the
-- ownership fixture without assuming the old generator's adjacent shop rooms.
-- Independent MawBank/Ectoplasm source oracle, not a call to the hook under test.
local function sourceRoomEntryGold(run)
    local maw, ectoplasm = false, false
    for _, id in ipairs(run.relics) do
        maw = maw or id == "maw_bank" or id == "MawBank"
        ectoplasm = ectoplasm or id == "ectoplasm" or id == "Ectoplasm"
    end
    local disabled = run.relicCounters and run.relicCounters.maw_bank == -2
    return maw and not disabled and not ectoplasm and 12 or 0
end
local function reach(run,map,kind)
    local path=Routes.to(map,function(node)return node.type==kind end)
    local expectedGold=0
    for i=1,#path-1 do
        local id=path[i];local node
        for _,n in ipairs(Nodes.available(run,map))do if n.id==id then node=n end end
        expectedGold=expectedGold+sourceRoomEntryGold(run)
        assert(node);assert(Nodes.enter(run,map,id))
        if run.phase=='combat'then
            finishBattle(run)
            local beforeReward=run.gold
            assert(Run.claimCardReward(run,0))
            if run.phase=='reward' then
                if run.rewards.potion and not run.rewards.potion.resolved then assert(Run.skipPotionReward(run))end
                assert(Run.leaveCombatRewards(run))
            end
            expectedGold=expectedGold+run.gold-beforeReward
            assert(Nodes.completeCombat(run,map))
        elseif node.type=='event'then assert(Nodes.chooseEvent(run,'leave'))
        elseif node.type=='shop'then assert(Nodes.leaveShop(run))
        elseif node.type=='camp'then
            local uid
            for j=#run.deck,1,-1 do local card=run.deck[j];if card.uid~=2 and not card.upgraded then uid=card.uid;break end end
            assert(uid and Nodes.upgrade(run,uid))
        elseif node.type=='treasure'then
            expectedGold=expectedGold+(Nodes.view(run,map).node.reward.gold or 0);assert(Nodes.claimTreasure(run))
        else error('unexpected intermediate room '..node.type)end
    end
    return path[#path],expectedGold
end
local function rewardPending()
    local source = copy(data)
    -- Funding + explicit event fixture: unchanged source pools, combat stats and item effects.
    source.rules.player.startingGold = 1000
    source.rules.events.encounterId='purifier' -- restoration ownership is independent of unknown-room sampling
    local run, map = Run.new(source, 36), Map.generate(source, 36)
    assert(Run.obtainPotion(run, "fire_potion"))
    assert(Run.obtainPotion(run, "energy_potion"))
    assert(Run.obtainPotion(run, "regen_potion"))
    enter(run, map, Map.available(map)[1].id, "combat")
    assert(Run.usePotion(run, 2))
    finishBattle(run)
    same(run.potions, {[1] = "fire_potion", [3] = "regen_potion"})
    return run, map
end
local stockByRun=setmetatable({},{__mode="k"})
local function atShop()
    local run, map = rewardPending()
    assert(Run.claimCardReward(run, 1)); dofile('tests/lua/support/finish_combat_rewards.lua')(run); assert(Nodes.completeCombat(run, map))
    local shop=reach(run,map,'shop')
    local previous = Map.snapshot(map)
    -- Explicit merchant-stream fixture, not natural seed-36 campaign stock.
    -- Seed 21 selects the purchased Stone from the complete, unfiltered relic
    -- pool; card, combat, map and potion streams retain their actual history.
    run.shopRng.merchant = require("abyss_sts_random").fromSeed("21")
    enter(run, map, shop, "shop")
    equal(run.nodeFlow.cards[1].id, "iron_wave", "purchase card fixture")
    equal(run.nodeFlow.relics[1].id, "oddly_smooth_stone", "purchase relic fixture")
    return run, map, previous
end
local function offer(list, id)
    for _, item in ipairs(list) do if item.id == id then return item end end
    error("missing offer " .. id)
end

test("restoring during reward keeps the same pending owner and grants exactly one permanent UID", function()
    local run, map = rewardPending()
    local flow, deck, relics, potions, battle = run.nodeFlow, run.deck, run.relics, run.potions, run.combat
    local before, snapshot = copy(run), Map.snapshot(map)
    local restored = assert(Map.restore(run.data, snapshot))
    same(run, before); equal(run.combat, battle)
    equal(#Nodes.available(run, restored), 0)
    refuse(run, restored, function() return Nodes.completeCombat(run, restored) end, "reward_pending")
    local cardId = Run.rewardOptions(run)[1]
    assert(Run.claimCardReward(run, 1))
    equal(run.deck, deck); equal(run.relics, relics); equal(run.potions, potions); equal(run.nodeFlow, flow)
    equal(#run.deck, 11); equal(run.deck[11].uid, 11); equal(run.deck[11].cardId, cardId)
    equal(run.nextDeckUid, 12); equal(#Nodes.available(run, restored), 0)
    refuse(run, restored, function() return Run.claimCardReward(run, 1) end, "no_pending_reward")
    dofile('tests/lua/support/finish_combat_rewards.lua')(run)
    assert(Nodes.completeCombat(run, restored))
    local nextRoom=Nodes.available(run,restored)[1]
    enter(run, restored, nextRoom.id, nextRoom.type)
    equal(map.floor, 1); equal(snapshot.floor, 1); equal(restored.floor, 2)
    same(run.potions, {[1] = "fire_potion", [3] = "regen_potion"})
end)

test("invalid restored snapshots leave a purchased shop and its valid continuation untouched", function()
    local run, map = atShop()
    local shelf=Nodes.view(run,map).node
    local boughtCard=assert(shelf.cards[1]).id
    local boughtRelic
    for _,item in ipairs(shelf.relics)do if not item.unavailable then boughtRelic=item.id;break end end
    assert(boughtRelic,'the frozen shop must contain an implemented relic')
    assert(Nodes.buyCard(run,boughtCard));assert(Nodes.buyRelic(run,boughtRelic))
    local valid = Map.snapshot(map)
    local changes = {
        {"forged stock", function(s) s.nodeFlow = copy(run.nodeFlow) end},
        {"duplicate path", function(s) s.path[#s.path + 1] = s.path[#s.path] end},
        {"sparse path", function(s) s.path[2] = nil end},
        {"wrong current room", function(s) s.currentNodeId = "f4_l2" end},
        {"inventory in graph", function(s) s.nodes[1].potions = run.potions end},
        {"cyclic graph", function(s) s.nodes[1].nextIds = s end},
        {"cyclic path", function(s) s.path[1] = s.path end},
        {"aliased unequal nodes", function(s) s.nodes[2] = s.nodes[1] end},
    }
    for _, change in ipairs(changes) do
        local bad = Map.snapshot(map); change[2](bad)
        local before, identities = copy({run, map, bad}), {bad.nodes, bad.path, run.nodeFlow, run.deck, run.potions}
        local ok, restored, reason = pcall(Map.restore, run.data, bad)
        assert(ok and restored == nil and type(reason) == "string", change[1] .. " was not safely rejected")
        same({run, map, bad}, before)
        equal(bad.nodes, identities[1]); equal(bad.path, identities[2]); equal(run.nodeFlow, identities[3])
        equal(run.deck, identities[4]); equal(run.potions, identities[5]); rejectedSnapshots = rejectedSnapshots + 1
    end
    local restored = assert(Map.restore(run.data, valid))
    equal(#Nodes.available(run, restored), 0)
    refuse(run, restored, function() return Nodes.buyCard(run, boughtCard) end, "item_unavailable")
    refuse(run, restored, function() return Nodes.buyRelic(run, boughtRelic) end, "item_unavailable")
    assert(Nodes.leaveShop(run)); enter(run, restored, reach(run,restored,'shop'), "shop")
    for _, item in ipairs(Nodes.view(run, restored).node.relics) do assert(item.id ~= boughtRelic) end
    equal(run.deck[12].cardId, boughtCard); equal(run.deck[12].uid, 12); equal(run.nextDeckUid, 13)
    same(run.potions, {[1] = "fire_potion", [3] = "regen_potion"})
end)

test("valid but stale restored progress cannot reenter a completed purchase or spend inventory", function()
    local run, map, previous = atShop()
    local view = Nodes.view(run, map).node
    local price = offer(view.cards, stockByRun[run].card).price + offer(view.relics, stockByRun[run].relic).price
    local gold = run.gold
    assert(Nodes.buyCard(run, stockByRun[run].card)); assert(Nodes.buyRelic(run, stockByRun[run].relic))
    equal(run.gold, gold - price); assert(Nodes.leaveShop(run))
    local current = assert(Map.restore(run.data, Map.snapshot(map)))
    local stale = assert(Map.restore(run.data, previous))
    equal(#Nodes.available(run, stale), 0)
    refuse(run, stale, function() return Nodes.enter(run, stale, run.nodeFlow.id) end, "map_mismatch")
    refuse(run, current, function() return Nodes.buyRelic(run, stockByRun[run].relic) end, "no_pending_node")
    local shop,earned=reach(run,current,'shop')
    enter(run, current, shop, "shop")
    equal(run.gold, gold - price + earned); equal(run.nextDeckUid, 13)
    local ok, slot = Run.obtainPotion(run, "block_potion"); equal(ok, true); equal(slot, 2)
    same(run.potions, {"fire_potion", "block_potion", "regen_potion"})
end)

test("restored route preserves removed and upgraded permanent UIDs and relics into the next battle", function()
    local run, map = atShop()
    assert(Nodes.buyCard(run, stockByRun[run].card)); assert(Nodes.buyRelic(run, stockByRun[run].relic))
    assert(Run.obtainRelic(run,'oddly_smooth_stone')) -- retain the exact cross-room Dexterity hook assertion
    assert(Nodes.removeCard(run, 1)); assert(Nodes.leaveShop(run))
    map = assert(Map.restore(run.data, Map.snapshot(map)))
    enter(run, map, reach(run,map,'shop'), "shop"); assert(Nodes.leaveShop(run))
    enter(run, map, reach(run,map,'camp'), "camp")
    map = assert(Map.restore(run.data, Map.snapshot(map)))
    assert(Nodes.upgrade(run, 2))
    enter(run, map, reach(run,map,'treasure'), "treasure")
    local relic = Nodes.view(run, map).node.reward.relicId
    assert(relic and relic ~= stockByRun[run].relic and relic ~= "oddly_smooth_stone" and relic ~= "burning_blood")
    assert(Nodes.claimTreasure(run))
    map = assert(Map.restore(run.data, Map.snapshot(map)))
    local elite=reach(run,map,'elite')
    -- Entering the next room may legitimately grant Maw Bank gold.
    local deck, owned, hp, gold, nextUid = copy(run.deck), copy(run.relics), run.hp, run.gold + sourceRoomEntryGold(run), run.nextDeckUid
    enter(run, map, elite, "elite")
    equal(run.hp, hp); equal(run.combat.player.hp, hp); equal(run.gold, gold); equal(run.nextDeckUid, nextUid)
    same(run.deck, deck); same(run.relics, owned)
    same(run.potions, {[1] = "fire_potion", [3] = "regen_potion"})
    equal(run.combat.player.statuses.dexterity, 1)
    local permanent = {}; for _, card in ipairs(run.deck) do permanent[card.uid] = card end
    equal(permanent[1], nil); equal(permanent[2].upgraded, true); equal(permanent[12].cardId, stockByRun[run].card)
    -- Combat allocates its own transient UIDs; persistent ownership is the
    -- unchanged Run deck plus one independent battle instance per card/upgrade.
    local expected, actual, battleUids, cards = {}, {}, {}, 0
    local function key(card) return card.cardId .. ":" .. tostring(card.upgraded) end
    for _, card in ipairs(run.deck) do expected[key(card)] = (expected[key(card)] or 0) + 1 end
    for _, pile in ipairs({run.combat.hand, run.combat.draw, run.combat.discard, run.combat.exhaust}) do
        for _, card in ipairs(pile) do
            assert(not battleUids[card.uid], "duplicate transient UID"); battleUids[card.uid] = true
            for _, original in ipairs(run.deck) do assert(card ~= original, "combat instance aliases permanent deck") end
            actual[key(card)] = (actual[key(card)] or 0) + 1
            cards = cards + 1
        end
    end
    equal(cards, 11); same(actual, expected)
end)

test("equal-valued snapshot aliases are normalized instead of becoming shared live edges", function()
    local map = Map.generate(data, 36)
    local snapshot = Map.snapshot(map)
    local camps={};for i,node in ipairs(map.nodes)do if node.floor==15 then camps[#camps+1]=i end end
    local a,b=assert(camps[1]),assert(camps[2])
    -- Connected camp nodes lead to the same Boss; an input alias has equal values.
    snapshot.nodes[b].nextIds = snapshot.nodes[a].nextIds
    local before = copy(snapshot)
    local restored = assert(Map.restore(data, snapshot))
    same(snapshot, before)
    assert(restored.nodes[a].nextIds ~= restored.nodes[b].nextIds, "restored edges still alias")
    assert(restored.nodes[a].nextIds ~= snapshot.nodes[a].nextIds, "restored edge aliases snapshot")
    restored.nodes[a].nextIds[1] = "changed"
    equal(restored.nodes[b].nextIds[1], "f16_l4")
    equal(snapshot.nodes[a].nextIds[1], "f16_l4"); equal(map.nodes[a].nextIds[1], "f16_l4")
end)

print("LUA_INVENTORY_RESTORE_PASS " .. count .. " rejected_snapshots=" .. rejectedSnapshots)
