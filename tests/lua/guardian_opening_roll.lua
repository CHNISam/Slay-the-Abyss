-- Guardian inherits one initialization roll; all later moves are direct sets.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Run, data = require("abyss_combat"), require("abyss_run"), require("abyss_data")
local passed, failed = 0, 0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn)
    local ok,err=pcall(fn)
    if ok then passed=passed+1 else failed=failed+1 end
    print((ok and "PASS " or "FAIL ")..name..(ok and "" or ": "..tostring(err)))
end
local function observe(fn,endpoint)
    local original,calls=Combat.random,{}
    Combat.random=function(state,maximum)
        calls[#calls+1]=maximum
        local result=original(state,maximum)
        return maximum==100 and endpoint~=nil and endpoint+1 or result
    end
    local ok,err=pcall(fn,calls)
    Combat.random=original
    assert(ok,err)
end
local function clear(t) for i=#t,1,-1 do t[i]=nil end end
local function ranges(calls,want)
    eq(#calls,#want,"random request count")
    for i,n in ipairs(want) do eq(calls[i],n,"random range "..i) end
end
local function battle(deck,enemies)
    return Combat.new(data,{seed=42,deck=deck or {"defend"},enemies=enemies or {"guardian"}})
end
local function id(s,n) return Combat.intent(s,n or 1).id end

for _,endpoint in ipairs({0,99}) do
    test("opening endpoint "..endpoint.." rolls once and preserves Charge and Mode Shift",function()
        observe(function(calls)
            local s=battle(); ranges(calls,{100}); eq(s.seed,22539)
            eq(s.enemies[1].hp,240); eq(s.enemies[1].block,0)
            eq(s.enemies[1].statuses.mode_shift,30); eq(id(s),"guardian_1")
            eq(s.player.hp,80)
        end,endpoint)
    end)
end

test("opening roll precedes real four-card shuffle",function()
    observe(function(calls)
        local s=battle({"strike","defend","bash","anger"})
        ranges(calls,{100,4,3,2}); eq(s.seed,6182)
        for i,uid in ipairs({1,4,3,2}) do eq(s.hand[i].uid,uid,"opening hand UID "..i) end
    end)
end)

test("offense cycle does not roll after Charge Bash Vent or Whirlwind",function()
    observe(function(calls)
        local s=battle(); clear(calls)
        for turn,want in ipairs({"guardian_2","guardian_4","guardian_3","guardian_1"}) do
            s.player.block=100 -- explicit survival fixture, not a full-run claim
            assert(Combat.endTurn(s)); eq(id(s),want); ranges(calls,{})
            if turn==1 then eq(s.enemies[1].block,9) end
            if turn==3 then eq(s.player.statuses.weak,2); eq(s.player.statuses.vulnerable,2) end
        end
        eq(s.player.hp,80)
    end)
end)

test("damage shift Close Up Roll Attack and Twin Slam do not roll",function()
    observe(function(calls)
        local s=battle(); clear(calls)
        Combat.damage(s,s.player,s.enemies[1],30,true)
        eq(id(s),"guardian_5"); eq(s.enemies[1].block,20); ranges(calls,{})
        for _,want in ipairs({"guardian_6","guardian_7","guardian_3"}) do
            assert(Combat.endTurn(s)); eq(id(s),want); ranges(calls,{})
        end
        eq(s.player.hp,55); eq(s.enemies[1].statuses.mode_shift,40)
        eq(s.enemies[1].statuses.sharp_hide,0)
    end)
end)

test("nonlethal poison shift never adds an AI roll",function()
    observe(function(calls)
        local s=battle(); clear(calls)
        Combat.addStatus(s.enemies[1],"poison",30)
        assert(Combat.endTurn(s)); ranges(calls,{})
        eq(id(s),"guardian_6"); eq(s.enemies[1].hp,210); eq(s.player.hp,80)
    end)
end)

test("retaliation-triggered mode shift does not invent a roll",function()
    observe(function(calls)
        local s=battle(); Combat.damage(s,s.player,s.enemies[1],29,true)
        assert(Combat.endTurn(s)); clear(calls); Combat.addStatus(s.player,"thorns",3)
        assert(Combat.endTurn(s)); ranges(calls,{})
        eq(id(s),"guardian_5"); eq(s.enemies[1].block,20)
        eq(s.enemies[1].hp,208); eq(s.player.hp,48)
    end)
end)

for _,withTeammate in ipairs({false,true}) do
    test("retaliation death has no queued roll, teammate="..tostring(withTeammate),function()
        observe(function(calls)
            local s=battle(nil,withTeammate and {"guardian","sneaky_gremlin"} or nil)
            assert(Combat.endTurn(s)); clear(calls)
            s.enemies[1].hp=1; Combat.addStatus(s.player,"thorns",1)
            assert(Combat.endTurn(s)); ranges(calls,{})
            eq(s.enemies[1].hp,0); eq(s.phase,withTeammate and "player" or "victory")
        end)
    end)
end

test("preview and invalid card input do not consume the opening roll again",function()
    observe(function(calls)
        local s=battle({"strike"}); clear(calls); local seed,eventCount=s.seed,#s.events
        for _=1,3 do
            local intent=Combat.intent(s,1); intent.kind="changed"
            eq(id(s),"guardian_1")
            local ok,reason=Combat.play(s,s.hand[1].uid,99)
            eq(ok,false); eq(reason,"invalid_target")
        end
        ranges(calls,{}); eq(s.seed,seed); eq(#s.events,eventCount)
    end)
end)

test("failed card restores mode shift and seed without an extra roll",function()
    observe(function(calls)
        local s=battle({"strike"}); local e=s.enemies[1]
        Combat.damage(s,s.player,e,25,true); clear(calls)
        local seed,eventCount,statuses=s.seed,#s.events,e.statuses
        s.catalog.cards.strike.effects={{op="damage",value=6},{op="gainStatus",status="strength",value=2147483647}}
        s.player.statuses.strength=1
        eq(pcall(Combat.play,s,s.hand[1].uid,1),false)
        ranges(calls,{}); eq(s.seed,seed); eq(#s.events,eventCount)
        eq(s.enemies[1],e); eq(e.statuses,statuses); eq(e.hp,215)
        eq(e.statuses.mode_shift,5); eq(e.block,0); eq(id(s),"guardian_1")
    end)
end)

test("two Guardian instances each consume an opening roll, not on one instance shifting",function()
    observe(function(calls)
        local s=battle(nil,{"guardian","guardian"}); ranges(calls,{100,100}); eq(s.seed,42944)
        clear(calls); Combat.damage(s,s.player,s.enemies[1],30,true)
        ranges(calls,{}); eq(id(s,1),"guardian_5"); eq(id(s,2),"guardian_1")
        assert(Combat.endTurn(s)); ranges(calls,{})
        eq(id(s,1),"guardian_6"); eq(id(s,2),"guardian_2")
    end)
end)

test("fresh combat initialization repeats one deterministic opening roll",function()
    observe(function(calls)
        local first=battle(); local second=battle()
        ranges(calls,{100,100}); eq(first.seed,22539); eq(second.seed,22539)
        eq(id(first),"guardian_1"); eq(id(second),"guardian_1")
    end)
end)

test("real Run boss entry rolls before starter shuffle; fire potion shift does not roll",function()
    local run=Run.new(data,42); run.floor=data.rules.map.bossFloor; run.potions={"fire_potion"}
    observe(function(calls)
        assert(Run.startCombat(run,"boss_guardian"))
        ranges(calls,{100}) -- shuffle now owns an independent source RNG
        eq(run.combat.shuffleRng.counter,1);eq(run.combat.cardRandomRng.counter,0)
        local s=run.combat; local seed=s.seed; clear(calls)
        Combat.damage(s,s.player,s.enemies[1],10,true)
        assert(Run.usePotion(run,1,1)); ranges(calls,{})
        eq(s.seed,seed); eq(id(s),"guardian_5"); eq(s.enemies[1].hp,210)
        eq(s.enemies[1].block,20); eq(run.potions[1],nil)
    end)
end)

print("guardian opening roll: "..passed.." passed, "..failed.." failed")
assert(failed==0,"Guardian opening roll failures")
