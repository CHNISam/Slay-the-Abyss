local sliceFirst,sliceLast,seedFirst,seedLast=...
sliceFirst,sliceLast=sliceFirst or 1,sliceLast or 1
seedFirst,seedLast=seedFirst or 0,seedLast or 127
local sliceRegistered,sliceExecuted=0,0
-- Fixed A0 mirror expectations, not generated from the production definition.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local data = require("abyss_data")
local count, failed = 0, 0
local function eq(a,b,label) assert(a == b, (label or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function test(name, fn)
 sliceRegistered=sliceRegistered+1
 if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end
 sliceExecuted=sliceExecuted+1

    count = count + 1
    local ok, err = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok " or "not ok ") .. count .. " - " .. name .. (ok and "" or ": " .. tostring(err)))
end
local function battle(seed, enemies)
    return Combat.new(data, {seed=seed or 42, enemies=enemies or {"sneaky_gremlin"}, deck={"strike"}})
end

test("A0 has one repeatable single-hit nine-damage attack and detached preview", function()
    local s = battle(); local intent = Combat.intent(s,1)
    eq(#s.enemies[1].intents,1); eq(intent.kind,"attack"); eq(#intent.effects,1)
    eq(intent.effects[1].op,"damage"); eq(intent.effects[1].value,9); eq(intent.effects[1].times or 1,1)
    intent.effects[1].value=99; eq(Combat.intent(s,1).effects[1].value,9)
end)

test("inclusive HP10 through14, maxHp, reproducible sampling and live state isolation", function()
    local seen = {}
    for seed=0,127 do
        local s, again = battle(seed), battle(seed); local e = s.enemies[1]
        assert(e.hp>=10 and e.hp<=14 and e.hp%1==0)
        eq(e.maxHp,e.hp); eq(again.enemies[1].hp,e.hp); eq(again.seed,s.seed)
        seen[e.hp]=true; e.hp=1; assert(again.enemies[1].hp>=10)
    end
    for hp=10,14 do assert(seen[hp],"missing HP " .. hp) end
end)

test("first and five subsequent rounds remain one nine-damage attack each", function()
    local s = battle(); local hp=s.enemies[1].hp
    for turn=1,6 do
        s.events={}; assert(Combat.endTurn(s)); eq(s.player.hp,80-turn*9)
        eq(s.enemies[1].hp,hp); eq(s.enemies[1].maxHp,hp)
        eq(Combat.intent(s,1).effects[1].value,9)
        local hits=0
        for _,event in ipairs(s.events) do
            if event.kind=="damage" and event.detail.source=="sneaky_gremlin_1" then hits=hits+1 end
        end
        eq(hits,1); eq(s.player.statuses.weak or 0,0); eq(s.player.statuses.frail or 0,0)
    end
end)

test("block absorbs nine without inventing a debuff", function()
    local s = battle(); s.player.block=9; assert(Combat.endTurn(s))
    eq(s.player.hp,80); eq(s.player.statuses.weak or 0,0)
end)

test("existing Strength Weak Vulnerable calculation remains in effect", function()
    local s = battle(); Combat.addStatus(s.enemies[1],"strength",3)
    Combat.addStatus(s.enemies[1],"weak",1); Combat.addStatus(s.player,"vulnerable",2)
    s.player.block=2; assert(Combat.endTurn(s)); eq(s.player.hp,69)
end)

test("two instances both attack; poison death suppresses only dead instance", function()
    local s = battle(42,{"sneaky_gremlin","sneaky_gremlin"})
    assert(Combat.endTurn(s)); eq(s.player.hp,62)
    Combat.addStatus(s.enemies[1],"poison",14); assert(Combat.endTurn(s))
    eq(s.enemies[1].hp,0); eq(s.player.hp,53)
end)

test("real player Strike uses sampled HP and preserves maxHp", function()
    local s=battle(); local hp=s.enemies[1].hp
    assert(Combat.play(s,s.hand[1].uid,1)); eq(s.enemies[1].hp,hp-6); eq(s.enemies[1].maxHp,hp)
end)

test("Run encounter entry samples the same inclusive HP range", function()
    local seen,present,absent={},0,0
    for seed=seedFirst,seedLast do
        local run=Run.new(data,seed); run.floor=5 -- host-entry fixture, not map traversal
        assert(Run.startCombat(run,"gremlin_gang")); local found
        for i,e in ipairs(run.combat.enemies) do
            if e.definitionId=="sneaky_gremlin" then
                found=true; assert(e.hp>=10 and e.hp<=14); eq(e.maxHp,e.hp); seen[e.hp]=true
                eq(Combat.intent(run.combat,i).effects[1].value,9)
            end
        end
        eq(#run.combat.enemies,4)
        if found then present=present+1 else absent=absent+1 end
    end
    -- Selection can omit Sneaky; retain the integration HP range/intent checks
    -- for every selected instance and prove all five HP values are exercised.
    assert(present>0 and absent>0, "must cover both selected and omitted Sneaky")
    for hp=10,14 do assert(seen[hp],"missing Run HP " .. hp) end
end)

assert(failed==0,tostring(failed) .. " Sneaky Gremlin groups failed")
print("Sneaky Gremlin: " .. count .. " groups passed")

assert(sliceRegistered==8,'all original cases must register')
assert(sliceExecuted==sliceLast-sliceFirst+1,'all selected cases must execute')
print('PR238_SLICE '..sliceFirst..' '..sliceLast..' '..sliceExecuted)
