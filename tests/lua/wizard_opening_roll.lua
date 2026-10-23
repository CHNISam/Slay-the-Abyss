-- Source contract: AbstractMonster.init rolls once even when Wizard.getMove
-- ignores its result. Later Wizard takeTurn transitions never request a roll.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Run, data = require("abyss_combat"), require("abyss_run"), require("abyss_data")
local passed, failed = 0, 0
local function eq(a, b, label)
    assert(a == b, (label or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(err)))
end
local function observe(fn, endpoint)
    local old, calls = Combat.random, {}
    Combat.random = function(state, maximum)
        calls[#calls + 1] = maximum
        -- Observe the real seed mutation; only endpoint fixtures override the
        -- bounded result to prove the initial move does not depend on the roll.
        local result = old(state, maximum)
        if endpoint ~= nil and maximum == 100 then return endpoint + 1 end
        return result
    end
    local ok, err = pcall(fn, calls)
    Combat.random = old
    assert(ok, err)
end
local function battle(enemies, deck)
    return Combat.new(data, {seed = 42, enemies = enemies or {"wizard_gremlin"}, deck = deck or {"defend"}})
end
local function callsEqual(calls, expected)
    eq(#calls, #expected, "random request count")
    for i, n in ipairs(expected) do eq(calls[i], n, "request " .. i) end
end

for _, roll in ipairs({0, 99}) do
    test("opening primary endpoint " .. roll .. " is consumed before fixed Charge", function()
        observe(function(calls)
            local s = battle()
            callsEqual(calls, {5, 100})
            eq(s.enemies[1].hp, 25, "HP sample remains unchanged")
            eq(s.enemies[1].aiCharge, 1)
            eq(Combat.intent(s, 1).id, "wizard_gremlin_1")
            eq(#Combat.intent(s, 1).effects, 0)
            eq(s.player.hp, 80); eq(s.energy, 3)
        end, roll)
    end)
end

test("opening real project seed advances twice and is repeatable", function()
    local a, b = battle(), battle()
    -- Hand-calculated LCG sequence from 42: 22539 (HP), 42944 (AI).
    -- This is the project's stream contract, NOT an STS1 seed oracle.
    eq(a.seed, 42944); eq(b.seed, 42944)
    eq(a.enemies[1].hp, 25); eq(b.enemies[1].hp, 25)
    eq(a.hand[1].uid, 1); eq(b.hand[1].uid, 1)
end)

test("each Wizard owns one initial draw before the ordinary deck shuffle", function()
    observe(function(calls)
        local s = battle({"wizard_gremlin", "wizard_gremlin"}, {"strike", "defend", "bash", "anger"})
        callsEqual(calls, {5, 5, 100, 100, 4, 3, 2})
        for _, e in ipairs(s.enemies) do eq(e.aiCharge, 1); eq(e.intentIndex, 1) end
        eq(#s.hand, 4); eq(#s.draw, 0)
    end)
end)

test("opening roll changes subsequent actual shuffle without changing card identity", function()
    local s = battle(nil, {"strike", "defend", "bash", "anger"})
    -- Literal Fisher-Yates result for project requests 4,3,2 after 42944.
    -- Draw order is the reverse of the shuffled pile.
    eq(s.seed, 50871)
    for i, uid in ipairs({2, 3, 4, 1}) do eq(s.hand[i].uid, uid, "drawn UID " .. i) end
end)

test("eleven real turns preserve charge cadence without post-action draws", function()
    observe(function(calls)
        local s = battle()
        callsEqual(calls, {5, 100})
        for turn, damage in ipairs({0, 0, 25, 0, 0, 0, 25, 0, 0, 0, 25}) do
            local hp = s.player.hp
            assert(Combat.endTurn(s))
            eq(hp - s.player.hp, damage, "turn " .. turn)
            callsEqual(calls, {5, 100})
        end
        eq(s.player.hp, 5)
    end)
end)

test("mixed Fat and Wizard keep distinct post-action policies", function()
    observe(function(calls)
        local s = battle({"wizard_gremlin", "fat_gremlin"})
        callsEqual(calls, {5, 5, 100, 100})
        assert(Combat.endTurn(s))
        callsEqual(calls, {5, 5, 100, 100, 100})
        eq(s.player.hp, 76); eq(s.enemies[1].aiCharge, 2)
        eq(s.player.statuses.weak, 1)
    end)
end)

test("intent previews and refused plays do not repeat the opening roll", function()
    observe(function(calls)
        local s = battle(nil, {"strike"})
        local seed, events = s.seed, #s.events
        for _ = 1, 3 do
            eq(Combat.intent(s, 1).id, "wizard_gremlin_1")
            local ok, reason = Combat.play(s, s.hand[1].uid, 99)
            eq(ok, false); eq(reason, "invalid_target")
        end
        callsEqual(calls, {5, 100}); eq(s.seed, seed); eq(#s.events, events)
    end)
end)

test("poison death never starts another Wizard roll or charge", function()
    observe(function(calls)
        local s = battle({"wizard_gremlin", "wizard_gremlin"})
        s.enemies[1].hp = 1
        Combat.addStatus(s.enemies[1], "poison", 1)
        assert(Combat.endTurn(s))
        callsEqual(calls, {5, 5, 100, 100})
        eq(s.enemies[1].hp, 0); eq(s.enemies[1].aiCharge, 1)
        eq(s.enemies[2].aiCharge, 2); eq(s.phase, "player")
    end)
end)

test("thorns death has no queued roll while a teammate remains", function()
    observe(function(calls)
        local s = battle({"wizard_gremlin", "sneaky_gremlin"})
        assert(Combat.endTurn(s)); assert(Combat.endTurn(s))
        s.enemies[1].hp = 1
        Combat.addStatus(s.player, "thorns", 1)
        assert(Combat.endTurn(s))
        callsEqual(calls, {5, 5, 100, 100})
        eq(s.enemies[1].hp, 0); eq(s.enemies[1].aiCharge, 0)
        assert(s.enemies[2].hp > 0); eq(s.phase, "player")
    end)
end)

test("final thorns death ends combat without another draw", function()
    observe(function(calls)
        local s = battle()
        assert(Combat.endTurn(s)); assert(Combat.endTurn(s))
        s.enemies[1].hp = 1
        Combat.addStatus(s.player, "thorns", 1)
        assert(Combat.endTurn(s))
        callsEqual(calls, {5, 100}); eq(s.phase, "victory")
        eq(s.enemies[1].aiCharge, 0); eq(s.player.hp, 55)
    end)
end)

test("Run encounter constructor uses the same Wizard opening policy", function()
    observe(function(calls)
        local run = Run.new(data, 42)
        -- Existing five-enemy encounter is a project integration fixture, not
        -- a claim that this grouping or its shared RNG matches original STS1.
        run.floor = 5
        run.deck = {{uid=1, cardId="defend", upgraded=false}}
        assert(Run.startCombat(run, "gremlin_gang"))
        local primary = 0
        for _, n in ipairs(calls) do if n == 100 then primary = primary + 1 end end
        eq(primary, 3, "Fat, Sneaky, Wizard each have an opening primary draw")
        eq(run.phase, "combat"); eq(#run.combat.enemies, 5)
        eq(run.combat.enemies[4].definitionId, "wizard_gremlin")
        eq(Combat.intent(run.combat, 4).id, "wizard_gremlin_1")
    end)
end)

print("WIZARD_OPENING_ROLL " .. passed .. " passed; " .. failed .. " failed")
assert(failed == 0, "Wizard opening roll failures: " .. failed)
