package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Run = require("abyss_combat"), require("abyss_run")
local Events, data = require("abyss_events"), require("abyss_data")

-- TASK-16.1.1: source-backed destination only, not all Power/exhaust hooks.
-- Fixed community mirror fc379c875c11e008e9c10548ac8e394c301c532f:
-- UseCardAction.java 3069a750b5c07b1a1c8aebfcf021984cad9a8a5a returns from
-- its POWER branch before normal discard/exhaust; CardGroup.java
-- c68b25ad094b8cc04a0e380db8e67a1fb1f3bfe4 keeps empower separate from exhaust.
local count, failed = 0, 0
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function test(name, fn)
    count = count + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " power_card_lifecycle " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local function location(state, card, destination)
    for _, name in ipairs({"hand", "draw", "discard", "exhaust"}) do
        local found = 0
        for _, instance in ipairs(state[name]) do if instance.uid == card.uid then found = found + 1 end end
        equal(found, name == destination and 1 or 0, "card in " .. name)
    end
end
local function battle(id, upgraded)
    local s = Combat.new(data, {seed=42, deck={{cardId=id, upgraded=upgraded}}, enemies={"cultist"}})
    return s, s.hand[1]
end
local function find(pile, id)
    for _, card in ipairs(pile) do if card.cardId == id then return card end end
end

for _, fixture in ipairs({
    {id="inflame", cost={1,1}, status="strength", amount={2,3}},
    {id="barricade", cost={3,2}, status="barricade", amount={1,1}},
}) do
for _, upgraded in ipairs({false, true}) do
    local name, n = fixture.id .. (upgraded and "+" or ""), upgraded and 2 or 1
    test(name .. " leaves combat piles after one successful use, without becoming exhausted", function()
        local s, card = battle(fixture.id, upgraded)
        local seed, energy, events = s.seed, s.energy, #s.events
        assert(Combat.play(s, card.uid))
        location(s, card, nil); equal(#s.exhaust, 0); equal(#s.discard, 0)
        equal(s.player.statuses[fixture.status], fixture.amount[n])
        equal(s.energy, energy - fixture.cost[n]); equal(s.seed, seed)
        equal(#s.events, events + 2); equal(s.events[events + 1].kind, "play")
        equal(s.events[events + 2].kind, "status")
        location(Events.frame(s), card, nil)
        local ok, reason = Combat.play(s, card.uid)
        equal(ok, false); equal(reason, "card_not_in_hand"); equal(#s.events, events + 2)
        assert(Combat.endTurn(s)); location(s, card, nil); equal(#s.hand, 0)
        equal(s.player.statuses[fixture.status], fixture.amount[n])
    end)
    test(name .. " left unplayed is discarded and can be drawn next turn", function()
        local s, card = battle(fixture.id, upgraded)
        assert(Combat.endTurn(s))
        location(s, card, "hand"); equal(#s.exhaust, 0)
        equal(s.player.statuses[fixture.status], nil)
        assert(Combat.play(s, card.uid)); location(s, card, nil)
    end)
    test(name .. " rejected for energy remains in hand without applying its power", function()
        local s, card = battle(fixture.id, upgraded)
        s.energy = fixture.cost[n] - 1 -- exact insufficient-energy boundary
        local events, seed = #s.events, s.seed
        local ok, reason = Combat.play(s, card.uid)
        equal(ok, false); equal(reason, "insufficient_energy")
        location(s, card, "hand"); equal(#s.events, events); equal(s.seed, seed)
        equal(s.player.statuses[fixture.status], nil)
    end)
    test(name .. " leaves its permanent deck card intact for the next encounter", function()
        local run = Run.new(data, 42)
        -- Constructed legal-card deck, not a natural acquisition/balance claim.
        run.deck = {{uid=1,cardId=fixture.id,upgraded=upgraded},
            {uid=2,cardId="bludgeon",upgraded=false},{uid=3,cardId="bludgeon",upgraded=false}}
        run.nextDeckUid = 4
        local permanent = run.deck[1]
        assert(Run.startCombat(run, "cultist_solo"))
        local used = assert(find(run.combat.hand, fixture.id))
        assert(used ~= permanent); assert(Run.play(run, used.uid))
        location(run.combat, used, nil)
        for _ = 1, 2 do
            assert(Run.endTurn(run))
            assert(Run.play(run, assert(find(run.combat.hand, "bludgeon")).uid, 1))
        end
        equal(run.phase, "reward"); equal(#run.deck, 3); equal(run.deck[1], permanent)
        equal(permanent.upgraded, upgraded); equal(run.nextDeckUid, 4)
        assert(Run.claimCardReward(run, 0)); assert(Run.startCombat(run, "cultist_solo"))
        local fresh = assert(find(run.combat.hand, fixture.id))
        assert(fresh ~= used and fresh ~= permanent); equal(fresh.upgraded, upgraded)
        equal(#run.combat.exhaust, 0); equal(run.combat.player.statuses[fixture.status], nil)
    end)
end
end

test("Power destination precedes an exhaust-on-use flag", function()
    local s, card = battle("inflame", false)
    s.catalog.cards.inflame.exhaust = true -- controlled flag precedence, not a new playable card
    assert(Combat.play(s, card.uid)); location(s, card, nil)
    equal(s.player.statuses.strength, 2)
end)

test("ordinary Exhaust cards still enter the exhaust pile", function()
    local s, card = battle("impervious", false)
    assert(Combat.play(s, card.uid)); location(s, card, "exhaust")
    equal(s.player.block, 30); equal(s.energy, 1)
end)

test("native battle counter distinguishes used Power from true Exhaust cards", function()
    local F = dofile("tests/lua/support/game_ui_fixture.lua")
    local ui, root = F.fixture()
    assert(ui:start())
    ui.run.deck = {{uid=1,cardId="inflame",upgraded=false},{uid=2,cardId="impervious",upgraded=false}}
    ui.run.nextDeckUid = 3
    assert(Run.startCombat(ui.run, "cultist_solo")); ui:refresh()
    local panel = root:GetChild("battlePanel")
    local function play(id)
        local slot
        for i, card in ipairs(ui.run.combat.hand) do if card.cardId == id then slot = i end end
        assert(slot); F.click(root, "battlePanel", "card" .. slot); F.click(root, "battlePanel", "playArea")
    end
    play("inflame"); equal(panel:GetChild("exhaust").text, "0")
    equal(panel:GetChild("discard").text, "0"); equal(ui.run.combat.player.statuses.strength, 2)
    play("impervious"); equal(panel:GetChild("exhaust").text, "1")
    equal(ui.run.combat.player.block, 30)
end)

assert(failed == 0, failed .. "/" .. count .. " power card lifecycle tests failed")
print("LUA_POWER_CARD_LIFECYCLE_PASS " .. count)
