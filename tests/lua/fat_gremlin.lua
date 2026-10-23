-- Fixed-source A0 expectations; these numbers do not read the enemy definition.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local data = require("abyss_data")
local count, failed = 0, 0
local function eq(a, b, label) assert(a == b, (label or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function test(name, fn)
    count = count + 1
    local ok, err = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok " or "not ok ") .. count .. " - " .. name .. (ok and "" or ": " .. tostring(err)))
end
local function battle(seed, enemies)
    return Combat.new(data, {seed = seed or 42, enemies = enemies or {"fat_gremlin"}, deck = {"strike"}})
end

test("one repeatable attack contains damage then Weak, with no A17 Frail", function()
    local s = battle(); local e = s.enemies[1]; local intent = Combat.intent(s, 1)
    eq(#e.intents, 1); eq(intent.kind, "attack"); eq(#intent.effects, 2)
    eq(intent.effects[1].op, "damage"); eq(intent.effects[1].value, 4)
    eq(intent.effects[2].op, "applyStatus"); eq(intent.effects[2].status, "weak"); eq(intent.effects[2].value, 1)
    intent.effects[2].value = 99
    eq(Combat.intent(s, 1).effects[2].value, 1, "detached preview")
end)

test("first attack deals four and leaves one Weak for the next player turn", function()
    local s = battle(); s.events = {}; assert(Combat.endTurn(s))
    eq(s.player.hp, 76); eq(s.player.statuses.weak, 1); eq(s.player.statuses.frail or 0, 0)
    local damageIndex, weakIndex
    for i, e in ipairs(s.events) do
        if e.kind == "damage" and e.detail.source == "fat_gremlin_1" then damageIndex = i end
        if e.kind == "status" and e.detail.status == "weak" then weakIndex = i end
    end
    assert(damageIndex and weakIndex and damageIndex < weakIndex, "damage event must precede Weak")
end)

test("five consecutive actions each attack and reapply Weak", function()
    local s = battle()
    for turn = 1, 5 do
        eq(Combat.intent(s, 1).kind, "attack"); assert(Combat.endTurn(s))
        eq(s.player.hp, 80 - turn * 4); eq(s.player.statuses.weak, 1)
    end
end)

test("fully blocked attack still applies Weak", function()
    local s = battle(); s.player.block = 4; assert(Combat.endTurn(s))
    eq(s.player.hp, 80); eq(s.player.statuses.weak, 1)
end)

test("zero-damage attack still applies Weak and its duration expires at player turn end", function()
    local s = battle(); Combat.addStatus(s.enemies[1], "strength", -4)
    assert(Combat.endTurn(s)); eq(s.player.hp, 80); eq(s.player.statuses.weak, 1)
    -- Remove the target before the next enemy action so reapplication cannot mask decay.
    Combat.addStatus(s.enemies[1], "poison", 17)
    assert(Combat.endTurn(s)); eq(s.player.statuses.weak, 0); eq(s.phase, "victory")
end)

test("existing Strength Weak and Vulnerable modifiers affect damage, not debuff amount", function()
    local s = battle(); local e = s.enemies[1]
    Combat.addStatus(e, "strength", 2); Combat.addStatus(e, "weak", 1)
    Combat.addStatus(s.player, "vulnerable", 2); s.player.block = 2
    assert(Combat.endTurn(s))
    eq(s.player.hp, 76, "floor((4+2)*.75*1.5)-2"); eq(s.player.statuses.weak, 1)
end)

test("next player Strike is weakened through the real play entry point", function()
    local s = battle(); assert(Combat.endTurn(s)); local before = s.enemies[1].hp
    assert(Combat.play(s, s.hand[1].uid, 1)); eq(before - s.enemies[1].hp, 4)
end)

test("HP samples cover inclusive 13 through 17 with matching maxHp and repeatability", function()
    local seen = {}
    for seed = 0, 127 do
        local s, repeatState = battle(seed), battle(seed)
        local e = s.enemies[1]
        assert(e.hp >= 13 and e.hp <= 17 and e.hp % 1 == 0)
        eq(e.maxHp, e.hp); eq(repeatState.enemies[1].hp, e.hp); eq(repeatState.seed, s.seed)
        seen[e.hp] = true
    end
    for hp = 13, 17 do assert(seen[hp], "missing HP sample " .. hp) end
end)

test("two living instances both attack and stack Weak in the same round", function()
    local s = battle(42, {"fat_gremlin", "fat_gremlin"})
    assert(Combat.endTurn(s)); eq(s.player.hp, 72); eq(s.player.statuses.weak, 2)
    assert(Combat.endTurn(s)); eq(s.player.hp, 64); eq(s.player.statuses.weak, 3)
end)

test("poison-killed instance cannot attack or apply Weak while teammate survives", function()
    local s = battle(42, {"fat_gremlin", "sneaky_gremlin"})
    Combat.addStatus(s.enemies[1], "poison", 17); assert(Combat.endTurn(s))
    eq(s.enemies[1].hp, 0); eq(s.player.hp, 71); eq(s.player.statuses.weak or 0, 0)
end)

test("Run host entry at floor 5 reaches combined attack with original encounter data", function()
    local run = Run.new(data, 42)
    run.floor = 5 -- isolated host-entry fixture, not a completed map route
    assert(Run.startCombat(run, "gremlin_gang"))
    local found
    for i, e in ipairs(run.combat.enemies) do if e.definitionId == "fat_gremlin" then found = i end end
    assert(found); eq(#Combat.intent(run.combat, found).effects, 2)
    assert(Run.endTurn(run)); eq(run.combat.player.statuses.weak, 1)
end)

assert(failed == 0, tostring(failed) .. " Fat Gremlin groups failed")
print("Fat Gremlin: " .. count .. " groups passed")
