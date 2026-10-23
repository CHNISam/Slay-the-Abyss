package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Run = require("abyss_combat"), require("abyss_run")
local data = require("abyss_data")

-- STS1 evidence: community decompilation, not an authenticated PC build or playtest.
-- Fixed source root: https://github.com/purewhitelove/ButterflyGame/tree/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码
-- cards/red/Carnage.java blob 14bb88f1823207254d84e932f9dc5bdad853169b: 2 cost, 20(+8) damage, ethereal retained on upgrade.
-- cards/red/GhostlyArmor.java blob f5e9b0354ebcd18235fb1505260865a8dbb9b9ac: 1 cost, 10(+3) block, ethereal retained on upgrade.
-- cards/AbstractCard.java blob 28010e74c3a9c7c97ca6cd3fd0654a451735172b: end-turn ethereal targets the hand.
-- actions/utility/ExhaustAllEtherealAction.java blob c475ce1427a0283e80289e616de4c4329b2e0605: generic hand-only scan, enqueued by Ghostly Armor's end-turn hook.
-- actions/utility/UseCardAction.java blob 3069a750b5c07b1a1c8aebfcf021984cad9a8a5a: ethereal alone does not exhaust a played card.
-- cards/red/Impervious.java blob af9cc28aff132cf34f2dd85a53c7d11e3f51f306: exhaust-on-use, not ethereal; 2 cost, 30(+10) block.
-- cards/CardGroup.java blob c68b25ad094b8cc04a0e380db8e67a1fb1f3bfe4: combat deck is initialized from a copy of masterDeck.
-- Tests deliberately do not assert shuffled exhaust order, unimplemented exhaust
-- powers/relics, original RNG parity, or Dazed/Sentry/Artifact behavior.
local count, failed = 0, 0
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function same(actual, expected)
    if type(expected) ~= "table" then equal(actual, expected); return end
    equal(type(actual), "table")
    for k, v in pairs(expected) do same(actual[k], v) end
    for k in pairs(actual) do assert(expected[k] ~= nil, "unexpected key: " .. tostring(k)) end
end
local function test(name, fn)
    count = count + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " ethereal_card_lifecycle " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local function copies(pile, card)
    local n = 0
    for _, instance in ipairs(pile) do if instance == card then n = n + 1 end end
    return n
end
local function onlyIn(state, card, destination)
    for _, name in ipairs({"hand", "draw", "discard", "exhaust"}) do
        equal(copies(state[name], card), name == destination and 1 or 0, "card in " .. name)
    end
end
local function battle(id, upgraded)
    local s = Combat.new(data, {seed=42, deck={{cardId=id, upgraded=upgraded}}, enemies={"cultist"}})
    return s, s.hand[1]
end

for _, fixture in ipairs({
    {id="carnage", cost=2, damage={20,28}, block={0,0}},
    {id="ghostly_armor", cost=1, damage={0,0}, block={10,13}},
}) do
for _, upgraded in ipairs({false, true}) do
    local name, n = fixture.id .. (upgraded and "+" or ""), upgraded and 2 or 1
    test(name .. " left in hand exhausts without executing its effect", function()
        local s, card = battle(fixture.id, upgraded)
        local hp, catalog = s.enemies[1].hp, Combat.copy(s.catalog)
        assert(Combat.endTurn(s))
        onlyIn(s, card, "exhaust")
        equal(s.turn, 2); equal(s.phase, "player"); equal(s.enemies[1].hp, hp)
        equal(s.player.hp, 80); equal(s.player.block, 0); equal(s.energy, 3)
        for _, event in ipairs(s.events) do
            assert(event.kind ~= "play", "unplayed card executed")
            -- Next-turn block reset would hide an erroneously executed Ghostly
            -- Armor effect; inspect the actual intermediate combat event too.
            assert(not (event.kind == "block" and event.detail.source == "player"), "unplayed card granted block")
        end
        same(s.catalog, catalog)
        assert(Combat.endTurn(s)); onlyIn(s, card, "exhaust")
        local ok, reason = Combat.play(s, card.uid, 1)
        equal(ok, false); equal(reason, "card_not_in_hand")
    end)
    test(name .. " played card discards and redraws, then exhausts only if left unplayed", function()
        local s, card = battle(fixture.id, upgraded)
        local hp = s.enemies[1].hp
        assert(Combat.play(s, card.uid, 1))
        equal(s.energy, 3 - fixture.cost); equal(s.enemies[1].hp, hp - fixture.damage[n])
        equal(s.player.block, fixture.block[n]); onlyIn(s, card, "discard")
        assert(Combat.endTurn(s)); onlyIn(s, card, "hand")
        equal(card.upgraded, upgraded)
        assert(Combat.endTurn(s)); onlyIn(s, card, "exhaust")
    end)
    test(name .. " failed energy payment leaves the card eligible for end-turn exhaustion", function()
        local s, card = battle(fixture.id, upgraded)
        s.energy = fixture.cost - 1 -- explicit inability-to-pay boundary fixture
        local before = Combat.copy(s)
        local ok, reason = Combat.play(s, card.uid, 1)
        equal(ok, false); equal(reason, "insufficient_energy"); same(s, before)
        assert(Combat.endTurn(s)); onlyIn(s, card, "exhaust")
    end)
    test(name .. " end-turn exhaustion does not sweep copies outside the hand", function()
        local deck = {}
        for _ = 1, 3 do deck[#deck+1] = {cardId=fixture.id, upgraded=upgraded} end
        local s = Combat.new(data, {seed=42, deck=deck, enemies={"cultist"}})
        local held, inDraw, discarded = s.hand[1], table.remove(s.hand, 3), table.remove(s.hand, 2)
        -- Controlled pile placement, not a claim of a particular shuffle order.
        s.draw[1], s.discard[1] = inDraw, discarded
        assert(Combat.endTurn(s))
        onlyIn(s, held, "exhaust"); onlyIn(s, inDraw, "hand"); onlyIn(s, discarded, "hand")
        equal(#s.exhaust, 1); equal(#s.hand, 2)
    end)
    test(name .. " combat exhaustion preserves the permanent instance and next battle", function()
        local run = Run.new(data, 42)
        -- A small constructed-deck fixture. Enemy/card values stay original;
        -- acquisition coverage belongs to card_pool.lua, not this fixture.
        run.deck = {
            {uid=1, cardId=fixture.id, upgraded=upgraded},
            {uid=2, cardId="bludgeon", upgraded=false},
            {uid=3, cardId="bludgeon", upgraded=false},
        }
        run.nextDeckUid = 4
        local permanent, before = run.deck[1], Combat.copy(run.deck)
        assert(Run.startCombat(run, "cultist_solo"))
        local exhausted
        for _, card in ipairs(run.combat.hand) do if card.cardId == fixture.id then exhausted = card end end
        assert(exhausted); assert(exhausted ~= permanent)
        assert(Run.endTurn(run)); onlyIn(run.combat, exhausted, "exhaust")
        for _ = 1, 2 do
            local attack = run.combat.hand[1]
            equal(attack.cardId, "bludgeon"); assert(Run.play(run, attack.uid, 1))
            if run.phase == "combat" then assert(Run.endTurn(run)) end
        end
        equal(run.phase, "reward"); same(run.deck, before); equal(run.deck[1], permanent)
        assert(Run.claimCardReward(run, 0)); assert(Run.startCombat(run, "cultist_solo"))
        equal(#run.combat.exhaust, 0); equal(run.nextDeckUid, 4); same(run.deck, before)
        local found = 0
        for _, card in ipairs(run.combat.hand) do
            if card.cardId == fixture.id then
                found = found + 1; equal(card.upgraded, upgraded)
                assert(card ~= exhausted and card ~= permanent)
            end
        end
        equal(found, 1)
    end)
end
end

for _, upgraded in ipairs({false, true}) do
    local name = "impervious" .. (upgraded and "+" or "")
    test(name .. " exhaust-on-use does not exhaust an unplayed hand card", function()
        local s, card = battle("impervious", upgraded)
        assert(Combat.endTurn(s)); onlyIn(s, card, "hand")
        equal(s.player.block, 0); equal(#s.exhaust, 0)
    end)
    test(name .. " still exhausts when actually played", function()
        local s, card = battle("impervious", upgraded)
        assert(Combat.play(s, card.uid))
        equal(s.energy, 1); equal(s.player.block, upgraded and 40 or 30)
        onlyIn(s, card, "exhaust")
        assert(Combat.endTurn(s)); onlyIn(s, card, "exhaust")
    end)
end

test("mixed base and upgraded ethereal hand exhausts each UID once, not the ordinary Exhaust card", function()
    local s = Combat.new(data, {seed=42, deck={
        "carnage", {cardId="carnage",upgraded=true},
        "ghostly_armor", {cardId="ghostly_armor",upgraded=true}, "impervious",
    }, enemies={"cultist"}})
    local cards = {}; for _, card in ipairs(s.hand) do cards[#cards+1] = card end
    assert(Combat.endTurn(s)); equal(#s.exhaust, 4); equal(#s.hand, 1)
    for _, card in ipairs(cards) do onlyIn(s, card, card.cardId == "impervious" and "hand" or "exhaust") end
    assert(Combat.endTurn(s)); equal(#s.exhaust, 4); equal(#s.hand, 1)
    for _, card in ipairs(cards) do onlyIn(s, card, card.cardId == "impervious" and "hand" or "exhaust") end
end)

assert(failed == 0, failed .. "/" .. count .. " ethereal card lifecycle tests failed")
print("LUA_ETHEREAL_CARD_LIFECYCLE_PASS " .. count)
