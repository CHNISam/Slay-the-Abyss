-- Fixed-source behavior: inherited init and each completed takeTurn queue one
-- primary AI roll, even though Cultist chooses Ritual then fixed attacks.
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
        local result = old(state, maximum) -- preserve the real RNG side effect
        if endpoint ~= nil and maximum == 100 then return endpoint + 1 end
        return result
    end
    local ok, err = pcall(fn, calls)
    Combat.random = old
    assert(ok, err)
end
local function battle(enemies, deck)
    return Combat.new(data, {seed=42, enemies=enemies or {"cultist"}, deck=deck or {"defend"}})
end
local function callsEqual(calls, expected)
    eq(#calls, #expected, "random request count")
    for i, n in ipairs(expected) do eq(calls[i], n, "request " .. i) end
end
local function clear(t) for i = #t, 1, -1 do t[i] = nil end end

for _, roll in ipairs({0, 99}) do
    test("primary endpoint " .. roll .. " is consumed at opening, Ritual and Strike", function()
        observe(function(calls)
            local s = battle()
            callsEqual(calls, {7,100})
            eq(s.enemies[1].hp, 54); eq(Combat.intent(s,1).id, "cultist_2")
            assert(Combat.endTurn(s)); callsEqual(calls, {7,100,100})
            eq(s.player.hp,80); eq(s.enemies[1].statuses.ritual,3)
            eq(s.enemies[1].statuses.strength or 0,0)
            assert(Combat.endTurn(s)); callsEqual(calls, {7,100,100,100})
            eq(s.player.hp,74); eq(Combat.intent(s,1).id,"cultist_1")
            eq(s.enemies[1].statuses.strength,3)
        end, roll)
    end)
end

test("real project seed advances for each fixed move", function()
    local s = battle()
    -- Hand-calculated project LCG from seed 42, not original STS1 RNG vectors.
    eq(s.seed,42944); assert(Combat.endTurn(s)); eq(s.seed,26841)
    assert(Combat.endTurn(s)); eq(s.seed,6182)
    local other = battle(); eq(other.seed,42944); eq(other.enemies[1].hp,54)
end)

test("opening roll precedes actual deck shuffle without changing card identity", function()
    observe(function(calls)
        local s = battle(nil, {"strike","defend","bash","anger"})
        callsEqual(calls,{7,100,4,3,2}); eq(s.seed,50871)
        for i, uid in ipairs({2,3,4,1}) do eq(s.hand[i].uid,uid,"drawn UID "..i) end
    end)
end)

test("multiple Cultists retain independent opening rolls and Ritual timing", function()
    observe(function(calls)
        local s = battle({"cultist","cultist"})
        callsEqual(calls,{7,7,100,100})
        assert(Combat.endTurn(s)); callsEqual(calls,{7,7,100,100,100,100})
        eq(s.player.hp,80)
        for _, e in ipairs(s.enemies) do eq(e.statuses.ritual,3); eq(e.statuses.strength or 0,0) end
        assert(Combat.endTurn(s)); callsEqual(calls,{7,7,100,100,100,100,100,100})
        eq(s.player.hp,68)
        for _, e in ipairs(s.enemies) do eq(e.statuses.strength,3) end
    end)
end)

test("five live actions each roll while damage stays 0,6,9,12,15", function()
    observe(function(calls)
        local s = battle(); clear(calls)
        for turn, damage in ipairs({0,6,9,12,15}) do
            local hp = s.player.hp
            assert(Combat.endTurn(s)); eq(hp-s.player.hp,damage,"turn "..turn)
            eq(#calls,turn,"one post-action roll per turn"); eq(calls[turn],100)
            eq(s.enemies[1].statuses.strength or 0,(turn-1)*3)
        end
    end)
end)

test("dead Cultist consumes its queued roll before the surviving teammate", function()
    observe(function(calls)
        local s = battle({"cultist","sneaky_gremlin"})
        assert(Combat.endTurn(s)); clear(calls)
        s.enemies[1].hp=1; Combat.addStatus(s.player,"thorns",1)
        local hp=s.player.hp
        assert(Combat.endTurn(s)); callsEqual(calls,{100})
        eq(s.enemies[1].hp,0); eq(s.enemies[1].statuses.strength or 0,0)
        eq(hp-s.player.hp,15); eq(s.phase,"player"); eq(Combat.intent(s,1),nil)
        clear(calls); assert(Combat.endTurn(s)); callsEqual(calls,{})
    end)
end)

test("queued dead-owner roll changes the next teammate's actual selection", function()
    -- Real Rake -> Stab history avoids Blue's separate no-three-identical rule.
    local original, openingRoll = Combat.random, 1
    Combat.random=function(state,maximum)
        local result=original(state,maximum)
        return maximum==100 and openingRoll or result
    end
    local s
    local prepared, preparationError=pcall(function()
        s=battle({"cultist","blue_slaver"})
        eq(Combat.intent(s,2).id,"blue_slaver_2")
        openingRoll=100; assert(Combat.endTurn(s))
        eq(Combat.intent(s,2).id,"blue_slaver_1")
    end)
    Combat.random=original; assert(prepared,preparationError)
    s.enemies[1].hp=1; Combat.addStatus(s.player,"thorns",1)
    Combat.addStatus(s.player,"barricade",1); s.player.block=100
    -- The dead Cultist must consume 0, leaving 99 for Blue's next move.
    local old, consumed = Combat.random, 0
    Combat.random=function(state,maximum)
        eq(maximum,100); old(state,maximum); consumed=consumed+1
        return ({1,100})[consumed] or error("unexpected extra roll")
    end
    local ok, err=pcall(Combat.endTurn,s); Combat.random=old; assert(ok,err)
    eq(consumed,2); eq(s.enemies[1].hp,0)
    eq(Combat.intent(s,2).id,"blue_slaver_1")
end)

test("lethal poison before takeTurn never queues a Cultist roll", function()
    observe(function(calls)
        local s=battle({"cultist","sneaky_gremlin"}); clear(calls)
        s.enemies[1].hp=1; Combat.addStatus(s.enemies[1],"poison",1)
        assert(Combat.endTurn(s)); callsEqual(calls,{})
        eq(s.enemies[1].hp,0); eq(s.enemies[1].statuses.ritual,nil); eq(s.player.hp,71)
    end)
end)

test("last enemy retaliation death clears its queued roll", function()
    observe(function(calls)
        local s=battle(); assert(Combat.endTurn(s)); clear(calls)
        s.enemies[1].hp=1; Combat.addStatus(s.player,"thorns",1)
        assert(Combat.endTurn(s)); callsEqual(calls,{})
        eq(s.phase,"victory"); eq(s.player.hp,74)
    end)
end)

test("player card kill before takeTurn has no post-action roll", function()
    observe(function(calls)
        local s=battle({"cultist","sneaky_gremlin"},{"strike"}); clear(calls)
        s.enemies[1].hp=1; assert(Combat.play(s,s.hand[1].uid,1))
        callsEqual(calls,{}); assert(Combat.endTurn(s)); callsEqual(calls,{})
        eq(s.enemies[1].hp,0); eq(s.player.hp,71)
    end)
end)

test("intent previews and rejected requests never consume a roll", function()
    observe(function(calls)
        local s=battle(nil,{"strike"}); local seed,events=s.seed,#s.events
        clear(calls)
        for _=1,3 do
            local intent=Combat.intent(s,1); intent.id="changed"
            eq(Combat.intent(s,1).id,"cultist_2")
            local ok,reason=Combat.play(s,s.hand[1].uid,99)
            eq(ok,false); eq(reason,"invalid_target")
        end
        callsEqual(calls,{}); eq(s.seed,seed); eq(#s.events,events)
    end)
end)

test("failed card restores existing seed and Cultist bookkeeping in place", function()
    observe(function(calls)
        local s=battle(nil,{"strike"}); assert(Combat.endTurn(s)); clear(calls)
        local e,hand,events=s.enemies[1],s.hand,s.events
        local hp,seed=e.hp,s.seed
        s.catalog.cards.strike.effects={{op="damage",value=6},{op="gainStatus",status="strength",value=2147483647}}
        s.player.statuses.strength=1
        eq(pcall(Combat.play,s,hand[1].uid,1),false)
        eq(s.enemies[1],e); eq(s.hand,hand); eq(s.events,events)
        eq(e.hp,hp); eq(s.seed,seed); eq(e.aiPhase,"attacking")
        eq(e.statuses.ritual,3); eq(e.ritualSkipRound,false); callsEqual(calls,{})
    end)
end)

test("real Run encounter and endTurn dispatch the Cultist roll policy", function()
    observe(function(calls)
        local run=Run.new(data,42)
        run.deck={{uid=1,cardId="defend",upgraded=false}}
        assert(Run.startCombat(run,"cultist_solo")); callsEqual(calls,{7,100})
        eq(run.combat.seed,42944); eq(run.phase,"combat")
        assert(Run.endTurn(run)); callsEqual(calls,{7,100,100})
        eq(run.combat.seed,26841); eq(run.combat.player.hp,80)
        assert(Run.endTurn(run)); callsEqual(calls,{7,100,100,100})
        eq(run.combat.player.hp,74); eq(run.combat.enemies[1].statuses.strength,3)
    end)
end)

print("CULTIST_ROLLS "..passed.." passed; "..failed.." failed")
assert(failed==0,"Cultist roll failures: "..failed)
