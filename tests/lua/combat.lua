package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local data = require("abyss_data")
local count = 0
local function equal(actual, expected, name)
    assert(actual == expected, (name or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, run)
    run()
    count = count + 1
    print("ok " .. count .. " - " .. name)
end
local function battle(deck, enemies, hp)
    return Combat.new(data, { deck = deck, enemies = enemies or { "jaw_worm" }, hp = hp, seed = 42 })
end
local function uid(state, id)
    for _, c in ipairs(state.hand) do if c.cardId == id then return c.uid end end
    error("missing hand card " .. id)
end
local function pileCount(s) return #s.hand + #s.draw + #s.discard + #s.exhaust end

test("starter deck draws five with refreshed three energy", function()
    local s = Combat.new(data, { seed = 1 })
    equal(#s.hand, 5); equal(#s.draw, 5); equal(s.energy, 3); equal(s.turn, 1)
    equal(pileCount(s), 10); equal(s.phase, "player")
end)

test("same seed gives identical shuffle and independent states", function()
    local a, b = Combat.new(data, { seed = 313 }), Combat.new(data, { seed = 313 })
    for i, c in ipairs(a.hand) do equal(c.uid, b.hand[i].uid) end
    a.player.hp = 3
    equal(b.player.hp, data.rules.player.maxHp)
    a.catalog.cards.strike.effects[1].value = 999
    equal(b.catalog.cards.strike.effects[1].value, 6)
    equal(data.cards.cards[1].effects[1].value, 6)
end)

test("strike spends energy and damage crosses enemy block", function()
    local s = battle({ "strike" })
    s.enemies[1].block = 4
    local hp = s.enemies[1].hp
    assert(Combat.play(s, uid(s, "strike"), 1))
    equal(s.energy, 2); equal(s.enemies[1].hp, hp - 2); equal(s.enemies[1].block, 0)
    equal(#s.hand, 0); equal(#s.discard, 1)
end)

test("defend absorbs enemy attack then clears at next own turn", function()
    local s = battle({ "defend" })
    assert(Combat.play(s, uid(s, "defend")))
    equal(s.player.block, 5)
    assert(Combat.endTurn(s))
    equal(s.player.hp, s.player.maxHp - 6) -- jaw's displayed attack 11, blocked 5
    equal(s.player.block, 0); equal(s.energy, 3); equal(s.turn, 2)
end)

test("invalid target and insufficient energy do not mutate state or RNG", function()
    local s = battle({ "bash" })
    local card = uid(s, "bash")
    local seed, events = s.seed, #s.events
    local ok, reason = Combat.play(s, card, 99)
    equal(ok, false); equal(reason, "invalid_target"); equal(s.energy, 3)
    equal(#s.hand, 1); equal(s.seed, seed); equal(#s.events, events)
    s.energy = 1
    ok, reason = Combat.play(s, card, 1)
    equal(ok, false); equal(reason, "insufficient_energy"); equal(s.energy, 1)
    equal(#s.discard, 0); equal(s.seed, seed)
end)

test("played card cannot be replayed by stale uid", function()
    local s = battle({ "strike" })
    local card = uid(s, "strike")
    assert(Combat.play(s, card, 1))
    equal(Combat.play(s, card, 1), false); equal(s.energy, 2)
end)

test("draw and discard recycle without dropping or duplicating instances", function()
    local s = battle({ "defend", "defend", "strike" })
    for _ = 1, 5 do
        equal(pileCount(s), 3)
        assert(Combat.endTurn(s))
        equal(#s.hand, 3); equal(#s.draw, 0); equal(#s.discard, 0)
    end
    local seen = {}
    for _, c in ipairs(s.hand) do assert(not seen[c.uid]); seen[c.uid] = true end
end)

test("draw stops at capacity without consuming remaining cards", function()
    local deck = {}
    for i = 1, 15 do deck[i] = "strike" end
    local s = battle(deck)
    Combat.draw(s, 20)
    equal(#s.hand, 10); equal(pileCount(s), 15)
    equal(#s.draw, 5); equal(#s.discard, 0)
    for _, event in ipairs(s.events) do assert(event.kind ~= "reshuffle", "full hand must not cause reshuffle") end
end)

test("intent copy is immutable to UI and executed before advancing", function()
    local s = battle({ "defend" })
    local intent = Combat.intent(s, 1)
    equal(intent.effects[1].value, 11)
    intent.effects[1].value = 999
    s.seed = 0 -- explicit project roll 49 selects Thrash; not an STS1 seed oracle
    assert(Combat.endTurn(s))
    equal(s.player.hp, s.player.maxHp - 11)
    equal(Combat.intent(s, 1).id, "jaw_worm_2")
    assert(Combat.endTurn(s))
    equal(s.enemies[1].block, 5)
    equal(s.player.hp, s.player.maxHp - 18)
end)

test("dead enemies skip queued attacks and victory refuses further commands", function()
    local s = battle({ "strike" }, { "jaw_worm" })
    s.enemies[1].hp = 1
    assert(Combat.play(s, uid(s, "strike"), 1))
    equal(s.phase, "victory"); equal(Combat.endTurn(s), false)
    equal(s.player.hp, s.player.maxHp)
end)

test("defeat stops remaining enemy intents and blocks player actions", function()
    local s = battle({ "strike" }, { "jaw_worm", "jaw_worm" }, 1)
    assert(Combat.endTurn(s))
    equal(s.phase, "defeat"); equal(s.enemies[2].intentIndex, 1)
    equal(Combat.endTurn(s), false); equal(Combat.play(s, 1, 1), false)
end)

test("bash debuff affects next attacks with final rounding", function()
    local s = battle({ "bash", "strike" })
    local hp = s.enemies[1].hp
    assert(Combat.play(s, uid(s, "bash"), 1))
    assert(Combat.play(s, uid(s, "strike"), 1))
    equal(s.enemies[1].hp, hp - 8 - 9)
end)

test("upgraded card inherits unchanged fields without mutating catalog", function()
    local s = battle({ { cardId = "strike", upgraded = true } })
    local hp = s.enemies[1].hp
    assert(Combat.play(s, uid(s, "strike"), 1))
    equal(s.enemies[1].hp, hp - 9); equal(s.energy, 2)
    equal(data.cards.cards[1].effects[1].value, 6)
end)

test("unknown or advanced effects fail before spending energy", function()
    local s = battle({ "demon_form" })
    local hp, seed = s.player.hp, s.seed
    equal(Combat.play(s, uid(s, "demon_form"), 1), false)
    equal(s.energy, 3); equal(s.player.hp, hp); equal(s.seed, seed)
end)

test("invalid starting snapshots fail rather than fabricate cards", function()
    equal(pcall(Combat.new, data, { deck = "invalid" }), false)
    equal(pcall(Combat.new, data, { deck = { "unknown" } }), false)
    equal(pcall(Combat.new, data, { hp = 0 }), false)
    equal(pcall(Combat.new, data, { seed = 0.5 }), false)
end)


local function drawBattle(handSize, drawSize, discardSize)
    local deck = {}
    for i = 1, handSize + drawSize + discardSize do deck[i] = "strike" end
    if #deck == 0 then deck[1] = "strike" end
    local s = battle(deck)
    local cards = {}
    for _, pile in ipairs({s.hand, s.draw}) do
        for _, card in ipairs(pile) do cards[#cards + 1] = card end
    end
    s.hand, s.draw, s.discard = {}, {}, {}
    local n = 0
    for _, entry in ipairs({{s.hand, handSize}, {s.draw, drawSize}, {s.discard, discardSize}}) do
        for _ = 1, entry[2] do n = n + 1; entry[1][#entry[1] + 1] = cards[n] end
    end
    return s
end

local function unchangedDraw(s, request)
    local hand, draw, discard, exhaust, events = s.hand, s.draw, s.discard, s.exhaust, s.events
    local before = {}
    for _, pile in ipairs({hand, draw, discard, exhaust, events}) do
        before[pile] = {}
        for i, item in ipairs(pile) do before[pile][i] = {item, item.uid} end
    end
    local seed, nextUid = s.seed, s.nextUid
    Combat.draw(s, request)
    equal(s.hand, hand); equal(s.draw, draw); equal(s.discard, discard)
    equal(s.exhaust, exhaust); equal(s.events, events)
    equal(s.seed, seed); equal(s.nextUid, nextUid)
    for pile, entries in pairs(before) do
        equal(#pile, #entries)
        for i, entry in ipairs(entries) do equal(pile[i], entry[1]); equal(pile[i].uid, entry[2]) end
    end
end

test("full hand preserves all pile objects cards UID RNG and events", function()
    unchangedDraw(drawBattle(10, 5, 2), 3)
end)

test("full hand with empty draw must not reshuffle discard", function()
    unchangedDraw(drawBattle(10, 0, 4), 3)
end)

test("last hand slot consumes only one card before stopping", function()
    local s = drawBattle(9, 2, 3)
    local nextCard, remaining = s.draw[2], s.draw[1]
    local draw, discard, seed, events = s.draw, s.discard, s.seed, #s.events
    Combat.draw(s, 4)
    equal(#s.hand, 10); equal(s.hand[10], nextCard); equal(#s.draw, 1); equal(s.draw[1], remaining)
    equal(s.draw, draw); equal(s.discard, discard); equal(#s.discard, 3)
    equal(s.seed, seed); equal(#s.events, events)
end)

test("filling last slot does not reshuffle after draw becomes empty", function()
    local s = drawBattle(9, 1, 3)
    local seed, events, discard = s.seed, #s.events, s.discard
    Combat.draw(s, 4)
    equal(#s.hand, 10); equal(#s.draw, 0); equal(s.discard, discard); equal(#s.discard, 3)
    equal(s.seed, seed); equal(#s.events, events)
end)

test("draw can cross one necessary reshuffle and stops at capacity", function()
    local s = drawBattle(8, 1, 4)
    local first, oldDiscard, seen = s.draw[1], s.discard, {}
    for _, pile in ipairs({s.hand, s.draw, s.discard}) do
        for _, c in ipairs(pile) do seen[c.uid] = c end
    end
    local seed, events = s.seed, #s.events
    local expected = {seed=seed}
    for size = 4, 2, -1 do Combat.random(expected, size) end
    Combat.draw(s, 20)
    equal(s.hand[9], first); equal(#s.hand, 10); equal(s.draw, oldDiscard); equal(#s.draw, 3)
    equal(#s.discard, 0); equal(s.seed, expected.seed); equal(#s.events, events + 1)
    equal(s.events[#s.events].kind, "reshuffle")
    for _, pile in ipairs({s.hand, s.draw, s.discard}) do
        for _, c in ipairs(pile) do equal(seen[c.uid], c); seen[c.uid] = nil end
    end
    equal(next(seen), nil)
end)

test("empty piles and nonpositive draw leave state untouched", function()
    unchangedDraw(drawBattle(3, 0, 0), 10)
    unchangedDraw(drawBattle(9, 0, 4), 0)
    unchangedDraw(drawBattle(9, 0, 4), -1)
end)

test("no draw prevents movement even when a slot and reshuffle are available", function()
    local s = drawBattle(9, 0, 4)
    s.player.noDraw = true
    unchangedDraw(s, 5)
end)

test("real upgraded pommel strike via Run uses the slot freed by playing", function()
    local Run = require("abyss_run")
    local run = Run.new(data, 42)
    run.deck = {}
    for i = 1, 15 do
        run.deck[i] = {uid=i, cardId=i == 1 and "pommel_strike" or "strike", upgraded=i == 1}
    end
    assert(Run.startCombat(run, "cultist_solo"))
    local s = run.combat
    local played
    for _, pile in ipairs({s.hand, s.draw}) do
        for i, c in ipairs(pile) do
            if c.cardId == "pommel_strike" then played = table.remove(pile, i); break end
        end
        if played then break end
    end
    s.hand[#s.hand + 1] = assert(played)
    Combat.draw(s, 10 - #s.hand)
    equal(#s.hand, 10)
    local top, seed, events, draw = s.draw[#s.draw], s.seed, #s.events, s.draw
    assert(Run.play(run, played.uid, 1))
    equal(#s.hand, 10); equal(s.hand[10], top); equal(#s.draw, 4); equal(s.draw, draw)
    equal(#s.discard, 1); equal(s.discard[1], played); equal(s.seed, seed)
    equal(#s.events, events + 2); equal(s.events[events + 1].kind, "play")
    equal(s.events[events + 2].kind, "damage")
    equal(#run.deck, 15); equal(run.deck[1].cardId, "pommel_strike")
end)

print("LUA_COMBAT_PASS " .. count)
