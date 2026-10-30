package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Run = require("abyss_run")
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
    print((ok and "ok" or "not ok") .. " draw_lock " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local function uid(s, id)
    for _, card in ipairs(s.hand) do if card.cardId == id then return card.uid end end
    error("missing " .. id)
end
-- Arrange only card zones, retaining real catalog definitions and unique instances.
local function battle(upgraded, hand, draw, discard)
    local deck = {}
    for _, zone in ipairs({hand, draw or {}, discard or {}}) do
        for _, id in ipairs(zone) do deck[#deck + 1] = {cardId = id, upgraded = id == "battle_trance" and upgraded or false} end
    end
    local s = Combat.new(data, {seed = 42, deck = deck})
    local instances = {}
    for _, zone in ipairs({s.hand, s.draw}) do for _, card in ipairs(zone) do instances[card.uid] = card end end
    s.hand, s.draw, s.discard = {}, {}, {}
    local nextId = 1
    for i, zone in ipairs({hand, draw or {}, discard or {}}) do
        local destination = ({s.hand, s.draw, s.discard})[i]
        for _ in ipairs(zone) do destination[#destination + 1] = instances[nextId]; nextId = nextId + 1 end
    end
    return s
end
local function inventory(s)
    local result = {}
    for _, zone in ipairs({s.hand, s.draw, s.discard, s.exhaust}) do
        for _, card in ipairs(zone) do assert(not result[card.uid], "duplicate uid"); result[card.uid] = Combat.copy(card) end
    end
    return result
end
local function refused(s, card, reason)
    local before = Combat.copy(s)
    local ok, actual = Combat.play(s, card)
    equal(ok, false); equal(actual, reason); same(s, before)
end
for _, upgraded in ipairs({false, true}) do
    local label, n = upgraded and "upgraded" or "normal", upgraded and 4 or 3
    test(label .. " draws catalog amount before locking, costs zero and preserves enemy/catalog", function()
        local s = battle(upgraded, {"battle_trance"}, {"strike", "defend", "strike", "defend", "strike"})
        local card = s.hand[1]
        local definition = Combat.cardDefinition(s, card)
        equal(definition.cost, 0); equal(definition.effects[1].op, "draw"); equal(definition.effects[1].value, n)
        equal(definition.effects[2].op, "noDrawThisTurn")
        local enemies, catalog, cards = Combat.copy(s.enemies), Combat.copy(s.catalog), inventory(s)
        local energy = s.energy
        equal(s.player.noDraw, false)
        assert(Combat.play(s, card.uid))
        equal(#s.hand, n); equal(#s.draw, 5 - n); equal(s.energy, energy)
        equal(s.player.noDraw, true); equal(#s.discard, 1); equal(s.discard[1].uid, card.uid)
        same(s.enemies, enemies); same(s.catalog, catalog); same(inventory(s), cards)
        local locked = Combat.copy(s)
        Combat.draw(s, 99); same(s, locked)
        refused(s, card.uid, "card_not_in_hand")
    end)
    test(label .. " empty deck still locks and discards exactly once", function()
        local s = battle(upgraded, {"battle_trance"})
        assert(Combat.play(s, s.hand[1].uid)); equal(#s.hand, 0); equal(#s.discard, 1)
        equal(s.player.noDraw, true); Combat.draw(s, 5); equal(#s.hand, 0)
    end)
    test(label .. " full hand draws only into the played slot then locks", function()
        local hand = {"battle_trance"}
        for _ = 1, 9 do hand[#hand + 1] = "defend" end
        local s = battle(upgraded, hand, {"strike", "strike", "strike", "strike", "strike"})
        local cards = inventory(s)
        assert(Combat.play(s, uid(s, "battle_trance")))
        equal(#s.hand, 10); equal(#s.draw, 4); equal(#s.discard, 1)
        equal(s.player.noDraw, true); same(inventory(s), cards)
    end)
    test(label .. " reshuffles prior discard without drawing played card", function()
        local s = battle(upgraded, {"battle_trance"}, {"strike"}, {"defend", "defend", "defend", "defend"})
        local played, cards, events = s.hand[1].uid, inventory(s), #s.events
        assert(Combat.play(s, played)); equal(#s.hand, n); equal(#s.draw, 5 - n)
        equal(#s.discard, 1); equal(s.discard[1].uid, played); equal(#s.events, events + 3)
        -- NoDraw's successful Power action has its own detached callback boundary
        -- after drawing; the reshuffle still happens before the lock is applied.
        local play, reshuffle, locked = s.events[events + 1], s.events[events + 2], s.events[events + 3]
        equal(play.kind, "play"); equal(reshuffle.kind, "reshuffle")
        equal(reshuffle.frame.player.noDraw, false)
        equal(locked.kind, "source_intent_powers"); equal(locked.frame.player.noDraw, true)
        same(locked.sourceIntentPowers, {origin = "ApplyPowerAction.NoDraw", scope = "all-monsters", timing = "action-boundary"})
        same(inventory(s), cards)
        for _, card in ipairs(s.hand) do assert(card.uid ~= played) end
    end)
    test(label .. " repeated zero-cost copies discard normally but cannot draw again", function()
        local s = battle(upgraded, {"battle_trance", "battle_trance"}, {"strike", "defend", "strike", "defend", "strike"})
        local first, second, energy = s.hand[1].uid, s.hand[2].uid, s.energy
        assert(Combat.play(s, first)); equal(#s.hand, n + 1)
        local draw, seed = Combat.copy(s.draw), s.seed
        assert(Combat.play(s, second)); equal(#s.hand, n); equal(#s.discard, 2)
        same(s.draw, draw); equal(s.seed, seed); equal(s.energy, energy)
        refused(s, second, "card_not_in_hand")
    end)
end
for _, id in ipairs({"shrug_it_off", "pommel_strike"}) do
    test(id .. " draws before lock; other effects still work after lock", function()
        local s = battle(false, {id, "battle_trance", id}, {"strike", "defend", "strike", "defend", "strike", "defend"})
        local before = #s.hand
        assert(Combat.play(s, uid(s, id), 1)); equal(#s.hand, before)
        assert(Combat.play(s, uid(s, "battle_trance")))
        local hand, draw, hp, block, energy = #s.hand, Combat.copy(s.draw), s.enemies[1].hp, s.player.block, s.energy
        assert(Combat.play(s, uid(s, id), 1)); equal(#s.hand, hand - 1); same(s.draw, draw); equal(s.energy, energy - 1)
        if id == "shrug_it_off" then equal(s.player.block, block + 8) else equal(s.enemies[1].hp, hp - 9) end
    end)
end
test("next player turn resets lock and energy, processes enemy intent and preserves all cards", function()
    local s = battle(false, {"battle_trance", "defend"}, {"strike", "defend", "strike", "defend", "strike", "defend", "strike", "defend"})
    local cards = inventory(s)
    assert(Combat.play(s, uid(s, "battle_trance"))); assert(Combat.play(s, uid(s, "defend")))
    equal(s.energy, 2); equal(s.player.noDraw, true)
    local hp = s.player.hp
    assert(Combat.endTurn(s))
    equal(s.player.hp, hp) -- Cultist's opening Ritual deals no damage.
    equal(s.turn, 2); equal(s.phase, "player"); equal(s.player.noDraw, false)
    equal(s.energy, s.rules.player.energyPerTurn); equal(#s.hand, s.rules.player.drawPerTurn)
    equal(Combat.intent(s,1).kind, "attack"); equal(s.enemies[1].noDraw, nil)
    same(inventory(s), cards)
    local hand = #s.hand; Combat.draw(s, 1); equal(#s.hand, hand + 1)
end)
test("invalid UID and non-player turn leave complete state unchanged", function()
    local s = battle(false, {"battle_trance"}, {"strike"})
    refused(s, -1, "card_not_in_hand")
    s.phase = "enemy"; refused(s, s.hand[1].uid, "not_player_turn")
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

test("real starter victory awards trance and next battle uses it without state edits", function()
    local selected, choice
    for _,seed in ipairs({dofile("tests/lua/support/first_reward_seed.lua")(data,"battle_trance")}) do
        local run = win(seed)
        for i, id in ipairs(Run.rewardOptions(run)) do
            if id == "battle_trance" then selected, choice = run, i; break end
        end
        if selected then break end
    end
    assert(selected, "battle_trance never offered in real victory rewards")
    local oldDeck = Combat.copy(selected.deck)
    assert(Run.claimCardReward(selected, choice)); dofile("tests/lua/support/finish_combat_rewards.lua")(selected)
    equal(#selected.deck, #oldDeck + 1)
    for i, card in ipairs(oldDeck) do same(selected.deck[i], card) end
    equal(selected.deck[#selected.deck].cardId, "battle_trance")
    local before = Combat.copy(selected)
    equal(Run.claimCardReward(selected, choice), false); same(selected, before)
    dofile('tests/lua/support/finish_combat_rewards.lua')(selected)
    assert(Run.startCombat(selected, "cultist_solo"))
    equal(selected.combat.player.noDraw, false)
    for _ = 1, 10 do
        assert(selected.phase == "combat", "battle ended before trance was played")
        for _, card in ipairs(selected.combat.hand) do
            if card.cardId == "battle_trance" then
                local hand, energy, cards = #selected.combat.hand, selected.combat.energy, inventory(selected.combat)
                assert(Run.play(selected, card.uid))
                equal(#selected.combat.hand, hand - 1 + 3)
                equal(selected.combat.player.noDraw, true); equal(selected.combat.energy, energy)
                same(inventory(selected.combat), cards)
                equal(#selected.deck, #oldDeck + 1)
                for _, persistent in ipairs(selected.deck) do equal(persistent.noDraw, nil) end
                equal(selected.noDraw, nil)
                return
            end
        end
        assert(Run.endTurn(selected))
    end
    error("reward card was not played")
end)
assert(failed == 0, tostring(failed) .. " draw_lock tests failed")
print("LUA_DRAW_LOCK_PASS " .. count)
