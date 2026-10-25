package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Run, Combat = require("abyss_run"), require("abyss_combat")
local Nodes, Map = require("abyss_nodes"), require("abyss_map")
local data = require("abyss_data")
local count = 0
local function equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function same(a, b)
    equal(type(a), type(b))
    if type(a) ~= "table" then equal(a, b); return end
    for k, v in pairs(a) do same(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil, "unexpected key " .. tostring(k)) end
end
local function test(name, fn) fn(); count = count + 1; print("ok inventory " .. count .. " - " .. name) end
local function battle(potions, source)
    local run = Run.new(source or data, 42)
    run.potions = potions or {}
    assert(Run.startCombat(run, "cultist_solo"))
    return run
end
local function rejected(run, slot, target, reason)
    local before, root = Combat.copy(run), run.combat
    local ok, actual = Run.usePotion(run, slot, target)
    equal(ok, false); equal(actual, reason); same(run, before); equal(run.combat, root)
end
local function definition(entries, id)
    for _, entry in ipairs(entries) do if entry.id == id then return entry end end
    error("missing definition " .. id)
end

test("all six opening relics use current data and retain their effects after owner-turn reset", function()
    local source = Combat.copy(data)
    definition(source.relics.relics, "anchor").effects[1].value = 13
    definition(source.relics.relics, "bag_of_preparation").effects[1].value = 3
    definition(source.relics.relics, "lantern").effects[1].value = 2
    local run = Run.new(source, 42)
    for _, relic in ipairs(source.relics.relics) do
        if relic.trigger == "combat_start" then run.relics[#run.relics + 1] = relic.id end
    end
    assert(Run.startCombat(run, "cultist_solo"))
    equal(run.combat.player.block, 13); equal(#run.combat.hand, 8); equal(run.combat.energy, 5)
    equal(run.combat.player.statuses.strength, 1); equal(run.combat.player.statuses.dexterity, 1)
    equal(run.combat.player.statuses.thorns, 3)
    assert(Run.endTurn(run)); equal(run.combat.energy, 3); equal(run.combat.player.block, 0)
end)

test("fire ignores attack modifiers and thorns while respecting enemy block", function()
    local run = battle({ "fire_potion" })
    local root, enemy = run.combat, run.combat.enemies[1]
    Combat.addStatus(root.player, "strength", 100); Combat.addStatus(root.player, "weak", 2)
    Combat.addStatus(enemy, "vulnerable", 2); Combat.addStatus(enemy, "thorns", 100)
    enemy.block = 7
    local hp, playerHp, seed, uid = enemy.hp, root.player.hp, root.seed, run.nextDeckUid
    assert(Run.usePotion(run, 1, 1)); equal(run.combat, root)
    equal(root.enemies[1].hp, hp - 13); equal(root.enemies[1].block, 0)
    equal(root.player.hp, playerHp); equal(root.seed, seed); equal(run.nextDeckUid, uid); equal(#run.potions, 0)
    rejected(run, 1, 1, "empty_potion_slot")
end)

test("block potion is fixed and all self potions consume exactly one matching slot", function()
    for _, id in ipairs({ "block_potion", "strength_potion", "dexterity_potion", "energy_potion", "regen_potion" }) do
        local run = battle({ "fire_potion", id, "poison_potion" })
        Combat.addStatus(run.combat.player, "dexterity", 100); Combat.addStatus(run.combat.player, "frail", 2)
        local before = Combat.copy(run.combat)
        assert(Run.usePotion(run, 2))
        same(run.potions, { [1] = "fire_potion", [3] = "poison_potion" })
        if id == "block_potion" then equal(run.combat.player.block, 12)
        elseif id == "energy_potion" then equal(run.combat.energy, before.energy + 2)
        elseif id == "strength_potion" then equal(run.combat.player.statuses.strength, 2)
        elseif id == "dexterity_potion" then equal(run.combat.player.statuses.dexterity, 102)
        elseif id == "regen_potion" then equal(run.combat.player.statuses.regen, 5) end
    end
end)

test("production block potion reaches the cap without changing fixed amount or consumption", function()
    for _, block in ipairs({ 988, 998, 999 }) do
        local run = battle({ "block_potion" })
        run.combat.player.block = block
        Combat.addStatus(run.combat.player, "dexterity", -100)
        Combat.addStatus(run.combat.player, "frail", 2)
        assert(Run.usePotion(run, 1)); equal(run.combat.player.block, 999)
        equal(#run.potions, 0)
    end
end)

test("poison and regeneration use actor timing and current data values", function()
    local source = Combat.copy(data)
    definition(source.potions.potions, "poison_potion").effects[1].value = 7
    definition(source.potions.potions, "regen_potion").effects[1].value = 4
    local run = battle({ "poison_potion", "regen_potion" }, source)
    run.combat.player.hp = 50
    local enemyHp = run.combat.enemies[1].hp
    assert(Run.usePotion(run, 1, 1)); equal(run.combat.enemies[1].statuses.poison, 7)
    equal(run.combat.enemies[1].hp, enemyHp)
    assert(Run.usePotion(run, 2)); assert(Run.endTurn(run))
    equal(run.combat.enemies[1].hp, enemyHp - 7); equal(run.combat.enemies[1].statuses.poison, 6)
    equal(run.combat.player.hp, 54); equal(run.combat.player.statuses.regen, 3) -- Ritual opening has no attack.
end)

test("invalid slots phases and targets preserve every run field and RNG", function()
    local run = battle({ "fire_potion", "poison_potion" })
    for _, slot in ipairs({ 0, -1, 0.5, 4, "1", false, {}, math.huge, 0/0 }) do
        rejected(run, slot, 1, "invalid_potion_slot")
    end
    rejected(run, nil, 1, "invalid_potion_slot")
    rejected(run, 3, 1, "empty_potion_slot")
    for _, target in ipairs({ 0, -1, 0.5, 2, "1", false, {} }) do rejected(run, 1, target, "invalid_target") end
    rejected(run, 2, nil, "invalid_target")
    run.combat.enemies[1].hp = 0; rejected(run, 1, 1, "invalid_target")
    run.combat.enemies[1].hp = 50; run.combat.phase = "enemy"
    rejected(run, 1, 1, "not_player_turn")
    run.phase = "map"; rejected(run, 1, 1, "not_in_combat")
end)

test("unknown definitions effects statuses and arithmetic overflow are atomic", function()
    local run = battle({ "fake" }); rejected(run, 1, 1, "unknown_potion")
    run.potions[1] = "strength_potion"
    local potion = definition(run.data.potions.potions, "strength_potion")
    potion.effects = { { op = "energy", value = 2 }, { op = "fake", value = 1 } }
    rejected(run, 1, nil, "unsupported_effect:fake")
    potion.effects[2] = { op = "gainStatus", status = "fake", value = 1 }
    rejected(run, 1, nil, "unknown_status:fake")
    potion.effects[2] = { op = "gainStatus", status = "strength", value = 2 }
    run.combat.player.statuses.strength = 2147483647
    rejected(run, 1, nil, "effect_overflow")
    potion.effects = { { op = "energy", value = 2 } }; run.combat.energy = 2147483647
    rejected(run, 1, nil, "effect_overflow")
    potion.effects = { { op = "block", value = 12 } }; run.combat.player.block = 2147483647
    rejected(run, 1, nil, "effect_overflow")
    potion.effects = { { op = "draw", value = 2 }, { op = "gainStatus", status = "strength", value = 2 } }
    run.combat.draw = {}; run.combat.discard = run.combat.hand; run.combat.hand = {}
    rejected(run, 1, nil, "effect_overflow") -- earlier draw would reshuffle and advance RNG on a naive implementation
    potion.effects = { { op = "energy", value = math.huge } }
    rejected(run, 1, nil, "invalid_effect_value")
end)

test("potion view is detached and enables targeted bottles only for a live target", function()
    local run = battle({ "fire_potion", "energy_potion", "fake" })
    local before = Combat.copy(run)
    local view = Run.potionView(run)
    equal(#view, 3); equal(view[1].slot, 1); equal(view[1].id, "fire_potion")
    equal(view[1].name, "火焰药水"); equal(view[1].needTarget, true); equal(view[1].canUse, true)
    equal(view[2].needTarget, false); equal(view[2].canUse, true)
    equal(view[3].canUse, false); equal(view[3].reason, "unknown_potion")
    view[1].effects[1].value = 999; view[1].id = "fake"; same(run, before)
    run.combat.enemies[1].hp = 0
    equal(Run.potionView(run)[1].canUse, false); equal(Run.potionView(run)[1].reason, "invalid_target")
    run.phase = "reward"; equal(Run.potionView(run)[2].reason, "not_in_combat")
end)

test("potion finalization failure preserves complete state and original references", function()
    for _, mode in ipairs({"throw", "false"}) do
        local run = battle({ "fire_potion" })
        run.combat.player.hp = 40; run.combat.enemies[1].hp = 20
        local before, root, saved = Combat.copy(run), run.combat, {}
        local function remember(value)
            if type(value) ~= "table" or saved[value] then return end
            local values = {}; saved[value] = values
            for key, item in pairs(value) do values[key] = item; remember(item) end
        end
        remember(run)
        local original = Run.finishCombat
        Run.finishCombat = function(candidate)
            assert(original(candidate)) -- stage real HP/gold/rewards/RNG first
            if mode == "throw" then error("fixture finalization fault") end
            return false
        end
        local called, ok, reason = pcall(Run.usePotion, run, 1, 1)
        Run.finishCombat = original -- restore the stub before any assertion can fail
        assert(called and ok == false and reason == "potion_effect_failed", "[ABYSS_ASSERT M4:finalization atomic]")
        same(run, before); equal(run.combat, root)
        for object, values in pairs(saved) do
            for key, value in pairs(values) do equal(object[key], value) end
            for key, value in pairs(object) do equal(value, values[key]) end
        end
        assert(Run.usePotion(run, 1, 1)); equal(run.phase, "reward")
        local gold = run.gold
        equal(Run.finishCombat(run), false); equal(run.gold, gold)
    end
end)

test("last-enemy potion kill finishes normally and awards gold and end healing once", function()
    local run = battle({ "fire_potion" })
    run.combat.player.hp = 40; run.combat.enemies[1].hp = 20
    local gold, root = run.gold, run.combat
    assert(Run.usePotion(run, 1, 1)); equal(run.combat, root); equal(root.phase, "victory")
    equal(run.phase, "reward"); equal(run.hp, 46); equal(run.gold, gold)
    assert(Run.claimGoldReward(run)); equal(run.gold, gold + data.rules.rewards.normalGold)
    equal(#Run.rewardOptions(run), data.rules.rewards.cardChoices)
    rejected(run, 1, 1, "not_in_combat"); equal(Run.finishCombat(run), false)
    equal(run.hp, 46); equal(run.gold, gold + data.rules.rewards.normalGold)
end)

local function finishBattle(run)
    for _ = 1, 200 do
        if run.phase ~= "combat" then break end
        local target
        for index, enemy in ipairs(run.combat.enemies) do if enemy.hp > 0 then target = index; break end end
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
end

test("legacy six-opening fixture keeps resources across two original-enemy battles and the acquired relic persists into the next battle", function()
    local source = Combat.copy(data)
    -- This historical six-opening transaction fixture deliberately isolates its
    -- Anchor chest. Full-pool order/probability and the added persistent hooks
    -- have independent suites; their newly added definitions must not silently
    -- turn this fixed-relic fixture into a different acquisition assertion.
    local legacyRelics={}
    for _,relic in ipairs(source.relics.relics)do
        if relic.trigger~='hooks' then legacyRelics[#legacyRelics+1]=relic end
    end
    source.relics.relics=legacyRelics
    source.rules.player.startingGold = 1000 -- isolate shop affordability, retaining original enemies/cards/combat values
    source.rules.events.encounterId='purifier' -- explicit content fixture; unknown RNG has its own route tests
    -- A real connected source-map route reaches events/shop/camp/chest before
    -- its second battle. No room symbols or edges are replaced by the fixture.
    local route={'f1_l4','f2_l5','f3_l5','f4_l5','f5_l4','f6_l4','f7_l3','f8_l2','f9_l2','f10_l2'}
    local run, map = Run.new(source, 70), Map.generate(source, 70)
    for _, relic in ipairs(source.relics.relics) do
        if relic.trigger == "combat_start" and relic.id ~= "anchor" then run.relics[#run.relics + 1] = relic.id end
    end
    run.potions = { "strength_potion", "regen_potion" }
    run.hp = 70
    local Routes=dofile('tests/lua/support/map_routes.lua')
    local first = Routes.at(map,route[1])
    assert(Nodes.enter(run, map, first.id)); equal(run.combat.player.block, 0)
    equal(#run.combat.hand, 7); equal(run.combat.energy, 4)
    assert(Run.usePotion(run, 1)); equal(run.combat.player.statuses.strength, 3)
    finishBattle(run)
    local quotedGold=run.rewards.gold
    assert(quotedGold>=10 and quotedGold<=20 and not run.rewards.goldClaimed)
    equal(run.gold,1000)
    assert(Run.claimGoldReward(run))
    local hp, gold = run.hp, run.gold
    equal(gold, 1000 + quotedGold)
    assert(not Run.claimGoldReward(run));equal(run.gold,gold)
    local rewardId = Run.rewardOptions(run)[1]
    assert(Run.claimCardReward(run, 1)); assert(Run.leaveCombatRewards(run)); assert(Nodes.completeCombat(run, map))
    equal(#run.deck, 11); equal(run.deck[11].uid, 11); equal(run.nextDeckUid, 12)
    local acquired, visitedEvent, boughtCard, spent, nextBattleType = false, false, false, 0, nil
    local acquiredId,boughtCardId
    while true do
        local node = Routes.at(map,route[#map.path+1])
        assert(Nodes.enter(run, map, node.id))
        if run.phase == "combat" then nextBattleType = node.type break
        elseif node.type == "treasure" then
            local reward = Nodes.view(run, map).node.reward
            if reward.relicId then acquiredId=reward.relicId; acquired = true
            else gold = gold + reward.gold end
            assert(Nodes.claimTreasure(run))
        elseif node.type == "event" then
            visitedEvent = true
            assert(Nodes.chooseEvent(run, "leave"))
        elseif node.type == "shop" then
            local view = Nodes.view(run, map).node
            for _, offer in ipairs(view.cards) do
                if not offer.unavailable and not boughtCard then
                    assert(Nodes.buyCard(run, offer.id)); spent = spent + offer.price; boughtCard = true; boughtCardId=offer.id
                end
            end
            assert(Nodes.leaveShop(run))
        elseif node.type=='camp' then
            local before=run.hp;local uid
            for _,card in ipairs(run.deck)do if not card.upgraded then uid=card.uid;break end end
            assert(uid and Nodes.upgrade(run,uid));equal(run.hp,before)
        else error("unexpected fixture node " .. node.type) end
    end
    assert(acquired and visitedEvent and boughtCard)
    equal(run.combat.player.hp, hp); equal(run.hp, hp); equal(run.gold, gold - spent)
    same(run.potions, { [2] = "regen_potion" })
    equal(#run.deck, 12); equal(run.deck[11].cardId, rewardId); equal(run.deck[12].uid, 12);equal(run.deck[12].cardId,boughtCardId); equal(run.nextDeckUid, 13)
    assert(acquiredId);local owned=false;for _,id in ipairs(run.relics)do if id==acquiredId then owned=true end end;assert(owned)
    equal(run.combat.player.block, acquiredId=="anchor" and 10 or 0); equal(run.combat.energy, 4); equal(#run.combat.hand, 7)
    equal(run.combat.player.statuses.strength, 1); equal(run.combat.player.statuses.dexterity, 1)
    equal(run.combat.player.statuses.thorns, 3); equal(run.combat.player.statuses.regen, nil)
    assert(Run.usePotion(run, 2)); equal(run.combat.player.statuses.regen, 5)
    finishBattle(run)
    local expectedReward=run.rewards.gold
    local minimum,maximum=nextBattleType=='elite' and 25 or 10,nextBattleType=='elite' and 35 or 20
    assert(expectedReward>=minimum and expectedReward<=maximum and not run.rewards.goldClaimed)
    equal(run.gold,gold-spent)
    assert(Run.claimGoldReward(run))
    equal(run.gold, gold - spent + expectedReward)
    assert(not Run.claimGoldReward(run));equal(run.gold,gold-spent+expectedReward)
    assert(Run.claimCardReward(run, 0)); assert(Run.leaveCombatRewards(run)); assert(Nodes.completeCombat(run, map))
    same(run.potions, {}); equal(run.nextDeckUid, 13)
end)

test("death followed by Run.new resets all same-run resources without sharing catalogs", function()
    local old = Run.new(data, 19)
    old.hp, old.gold = 1, 1000
    old.potions, old.relics = { "fire_potion" }, { "burning_blood", "vajra" }
    old.deck[1].upgraded = true
    old.deck[#old.deck + 1] = { uid = old.nextDeckUid, cardId = "cleave", upgraded = true }
    old.nextDeckUid = old.nextDeckUid + 1
    assert(Run.startCombat(old, "cultist_solo")); assert(Run.endTurn(old)); assert(Run.endTurn(old)); equal(old.phase, "defeat")
    rejected(old, 1, 1, "not_in_combat")
    local before = Combat.copy(old)
    local fresh = Run.new(data, 19)
    equal(fresh.phase, "map"); equal(fresh.hp, data.rules.player.maxHp)
    equal(fresh.gold, data.rules.player.startingGold); equal(#fresh.deck, 10); equal(fresh.nextDeckUid, 11)
    equal(fresh.deck[1].upgraded, false); same(fresh.relics, data.rules.player.startingRelics); same(fresh.potions, {})
    equal(fresh.combat, nil); equal(fresh.nodeFlow, nil); equal(fresh.lastResult, nil)
    definition(fresh.data.potions.potions, "fire_potion").effects[1].value = 1
    same(old, before); equal(definition(data.potions.potions, "fire_potion").effects[1].value, 20)
end)

print("LUA_INVENTORY_PASS " .. count)
