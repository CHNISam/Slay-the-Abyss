package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Effects = require("abyss_effects")
local data = require("abyss_data")
local count, failed = 0, 0
local function equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function same(a, b)
    equal(type(a), type(b))
    if type(a) ~= "table" then equal(a, b); return end
    for k, v in pairs(a) do same(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil, "unexpected field " .. tostring(k)) end
end
local function test(name, fn)
    count = count + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " hp_loss " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local ids = { "bloodletting", "hemokinesis", "offering" }
local function battle(id, upgraded, hp)
    local deck = { { cardId = id, upgraded = upgraded } }
    -- Enough real cards for Offering+, with no duplicated instance UIDs.
    for _ = 1, 12 do deck[#deck + 1] = "defend" end
    local state = Combat.new(data, { seed = 42, hp = hp, deck = deck })
    for i, card in ipairs(state.draw) do
        if card.cardId == id then state.draw[i], state.hand[1] = state.hand[1], card; break end
    end
    local chosen
    for _, card in ipairs(state.hand) do if card.cardId == id then chosen = card end end
    assert(chosen)
    return state, chosen
end
local function refused(state, uid, target, reason)
    local before = Combat.copy(state)
    local ok, actual = Combat.play(state, uid, target)
    equal(ok, false); equal(actual, reason); same(state, before)
end
for _, id in ipairs(ids) do
for _, upgraded in ipairs({ false, true }) do
    local label = id .. (upgraded and "+" or "")
    test(label .. " pays exact HP before ordinary follow-on effects and preserves catalog", function()
        local state, instance = battle(id, upgraded)
        local definition = Combat.cardDefinition(state, instance)
        local hp, energy, hand, draw = state.player.hp, state.energy, #state.hand, #state.draw
        local enemyHp, catalog = state.enemies[1].hp, Combat.copy(state.catalog)
        assert(Effects.supported(definition.effects))
        assert(Combat.play(state, instance.uid, 1))
        equal(state.player.hp, hp - definition.effects[1].value)
        equal(state.energy, energy - definition.cost + (id == "hemokinesis" and 0 or definition.effects[2].value))
        equal(state.enemies[1].hp, enemyHp - (id == "hemokinesis" and definition.effects[2].value or 0))
        local draws = id == "offering" and definition.effects[3].value or 0
        equal(#state.hand, hand - 1 + draws); equal(#state.draw, draw - draws)
        equal(#state.exhaust, id == "offering" and 1 or 0)
        equal(#state.discard, id == "offering" and 0 or 1)
        local pile = id == "offering" and state.exhaust or state.discard
        equal(pile[1].uid, instance.uid); same(state.catalog, catalog)
        refused(state, instance.uid, 1, "card_not_in_hand")
    end)
    for _, hp in ipairs({ 1, id == "offering" and 6 or id == "hemokinesis" and 2 or 3 }) do
    test(label .. " lethal HP payment at " .. hp .. " stops every later effect", function()
        local state, instance = battle(id, upgraded, hp)
        local definition = Combat.cardDefinition(state, instance)
        local energy, hand, draw, enemyHp = state.energy, #state.hand, #state.draw, state.enemies[1].hp
        local events = #state.events
        assert(Combat.play(state, instance.uid, 1))
        equal(state.player.hp, 0); equal(state.phase, "defeat")
        equal(state.energy, energy - definition.cost)
        equal(#state.hand, hand - 1); equal(#state.draw, draw); equal(state.enemies[1].hp, enemyHp)
        equal(#state.events, events + 3) -- play + explicit HP payment + defeat; no attack/status tick
        equal(state.events[events + 2].kind, "hp_loss")
        equal(state.events[events + 2].detail.amount, hp)
        equal(state.events[events + 2].frame.player.hp, 0)
        equal(state.events[#state.events].kind, "defeat")
        equal(#state.exhaust,0);equal(#state.discard,0);equal(state.cardInUse,instance)
        refused(state, instance.uid, 1, "not_player_turn")
    end)
    end
end
end

test("HP loss bypasses block, strength, weak, vulnerable and self thorns", function()
    for _, id in ipairs(ids) do
        local state, instance = battle(id, false)
        state.player.block = 50
        Combat.addStatus(state.player, "strength", 8)
        Combat.addStatus(state.player, "weak", 2)
        Combat.addStatus(state.player, "vulnerable", 2)
        Combat.addStatus(state.player, "thorns", 7)
        local hp, loss = state.player.hp, Combat.cardDefinition(state, instance).effects[1].value
        assert(Combat.play(state, instance.uid, 1))
        equal(state.player.hp, hp - loss); equal(state.player.block, 50)
        for _, event in ipairs(state.events) do assert(event.kind ~= "status_damage") end
    end
end)

test("only the later actual attack triggers enemy thorns", function()
    for _, id in ipairs(ids) do
        local state, instance = battle(id, false)
        Combat.addStatus(state.enemies[1], "thorns", 4)
        local hp, loss = state.player.hp, Combat.cardDefinition(state, instance).effects[1].value
        assert(Combat.play(state, instance.uid, 1))
        equal(state.player.hp, hp - loss - (id == "hemokinesis" and 4 or 0))
    end
end)

test("energy and target validation reject before any HP or state mutation", function()
    local state, instance = battle("hemokinesis", false)
    state.energy = 0
    refused(state, instance.uid, 1, "insufficient_energy")
    state.energy = 3
    refused(state, instance.uid, nil, "invalid_target")
    refused(state, instance.uid, 99, "invalid_target")
    state.enemies[1].hp = 0
    refused(state, instance.uid, 1, "invalid_target")
end)

test("Run defeat from real HP-pay cards preserves gold and deck and emits no rewards or healing", function()
    for _, id in ipairs(ids) do
        local run = Run.new(data, 42)
        -- Focused lethal fixture; reward acquisition is exercised independently below.
        run.deck = { { uid = 1, cardId = id, upgraded = false } }
        run.hp = 1
        local gold, deck = run.gold, Combat.copy(run.deck)
        assert(Run.startCombat(run, "cultist_solo"))
        assert(Run.play(run, run.combat.hand[1].uid, 1))
        equal(run.phase, "defeat"); equal(run.hp, 0); equal(run.gold, gold)
        equal(run.rewards, nil); equal(#Run.rewardOptions(run), 0); same(run.deck, deck)
        equal(run.lastResult.outcome, "defeat")
        equal(Run.finishCombat(run), false); equal(Run.claimCardReward(run, 1), false)
    end
end)

test("Offering respects an existing draw lock but still pays HP and exhausts", function()
    local state, instance = battle("offering", true)
    state.player.noDraw = true
    local hp, energy, hand, draw = state.player.hp, state.energy, #state.hand, #state.draw
    assert(Combat.play(state, instance.uid))
    equal(state.player.hp, hp - 6); equal(state.energy, energy + 2)
    equal(#state.hand, hand - 1); equal(#state.draw, draw)
    equal(#state.exhaust, 1); equal(state.exhaust[1].uid, instance.uid)
end)

test("unrelated unsupported effects remain rejected without mutating state", function()
    local state = Combat.new(data, { deck = { "true_grit" } })
    state.catalog.cards.true_grit.effects={{op="unsupported_test_action"}}
    local before = Combat.copy(state)
    local ok, reason = Combat.play(state, state.hand[1].uid)
    equal(ok, false); assert(reason:find("unsupported_effect:", 1, true)); same(state, before)
end)

local function win(seed)
    local run = Run.new(data, seed)
    assert(Run.startCombat(run, "cultist_solo"))
    for _ = 1, 100 do
        if run.phase ~= "combat" then break end
        for _ = 1, 10 do
            if run.phase ~= "combat" then break end
            local chosen
            for _, card in ipairs(run.combat.hand) do
                if Combat.canPlay(run.combat, card.uid, 1) then
                    if not chosen or Combat.cardDefinition(run.combat, card).type == "attack" then chosen = card end
                end
            end
            if not chosen then break end
            assert(Run.play(run, chosen.uid, 1))
        end
        if run.phase == "combat" then assert(Run.endTurn(run)) end
    end
    return run
end
for _, id in ipairs(ids) do
test(id .. " is acquired in real starter victory rewards and played next battle", function()
    local selected, choice
    for seed = 1, 128 do
        local run = win(seed)
        for i, cardId in ipairs(Run.rewardOptions(run)) do
            if cardId == id then selected, choice = run, i; break end
        end
        if selected then break end
    end
    assert(selected, id .. " never offered")
    local oldDeck = Combat.copy(selected.deck)
    assert(Run.claimCardReward(selected, choice)); dofile('tests/lua/support/finish_combat_rewards.lua')(selected)
    equal(#selected.deck, #oldDeck + 1)
    for i, card in ipairs(oldDeck) do same(selected.deck[i], card) end
    equal(selected.deck[#selected.deck].cardId, id)
    assert(Run.startCombat(selected, "cultist_solo"))
    for _ = 1, 20 do
        assert(selected.phase == "combat", "battle ended before acquired card could play")
        for _, instance in ipairs(selected.combat.hand) do
            if instance.cardId == id then
                local hp = selected.combat.player.hp
                local definition = Combat.cardDefinition(selected.combat, instance)
                assert(Run.play(selected, instance.uid, 1))
                equal(selected.combat.player.hp, hp - definition.effects[1].value)
                equal(#selected.deck, #oldDeck + 1)
                return
            end
        end
        assert(Run.endTurn(selected))
    end
    error("acquired card never drawn")
end)
end
assert(failed == 0, tostring(failed) .. " hp_loss tests failed")
print("LUA_HP_LOSS_PASS " .. count)
