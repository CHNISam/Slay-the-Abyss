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

test("draw at capacity discards overflow, finite request cannot loop", function()
    local deck = {}
    for i = 1, 15 do deck[i] = "strike" end
    local s = battle(deck)
    Combat.draw(s, 20)
    equal(#s.hand, 10); equal(pileCount(s), 15)
end)

test("intent copy is immutable to UI and executed before advancing", function()
    local s = battle({ "defend" })
    local intent = Combat.intent(s, 1)
    equal(intent.effects[1].value, 11)
    intent.effects[1].value = 999
    assert(Combat.endTurn(s))
    equal(s.player.hp, s.player.maxHp - 11)
    equal(Combat.intent(s, 1).kind, "defend")
    assert(Combat.endTurn(s))
    equal(s.enemies[1].block, 6)
    equal(Combat.intent(s, 1).kind, "buff")
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
    local s = battle({ "offering" })
    local hp, seed = s.player.hp, s.seed
    equal(Combat.play(s, uid(s, "offering"), 1), false)
    equal(s.energy, 3); equal(s.player.hp, hp); equal(s.seed, seed)
end)

test("invalid starting snapshots fail rather than fabricate cards", function()
    equal(pcall(Combat.new, data, { deck = {} }), false)
    equal(pcall(Combat.new, data, { deck = { "unknown" } }), false)
    equal(pcall(Combat.new, data, { hp = 0 }), false)
    equal(pcall(Combat.new, data, { seed = 0.5 }), false)
end)

print("LUA_COMBAT_PASS " .. count)
