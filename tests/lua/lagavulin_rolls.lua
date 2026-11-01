-- Lagavulin's fixed intents still consume RollMove draws. Natural third sleep
-- uses SetMove instead; poisoning before takeTurn and queued death differ.
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
        local latest
        for i=#state.events,1,-1 do
            if state.events[i].kind=="intent" then latest=state.events[i].detail.enemy; break end
        end
        calls[#calls+1]={range=maximum,intentOwner=latest}
        local result=original(state,maximum)
        return maximum==100 and endpoint~=nil and endpoint+1 or result
    end
    local ok,err=pcall(fn,calls)
    Combat.random=original
    assert(ok,err)
end
local function clear(t) for i=#t,1,-1 do t[i]=nil end end
local function ranges(calls,want)
    eq(#calls,#want,"request count")
    for i,n in ipairs(want) do eq(calls[i].range,n,"request range "..i) end
end
local function battle(enemies,deck)
    return Combat.new(data,{seed=42,enemies=enemies or {"lagavulin"},deck=deck or {"defend"}})
end
local function wake(s)
    eq(Combat.damage(s,s.player,s.enemies[1],9,true),1)
    eq(Combat.intent(s,1).kind,"stunned")
end

for _,endpoint in ipairs({0,99}) do
    test("opening endpoint "..endpoint.." consumes primary roll without changing sleep",function()
        observe(function(calls)
            local s=battle(); ranges(calls,{3,100})
            eq(s.enemies[1].hp,109); eq(s.enemies[1].block,8)
            eq(Combat.intent(s,1).id,"lagavulin_1"); eq(s.player.hp,80)
        end,endpoint)
    end)
end

test("first two sleeps roll but natural third wake does not",function()
    observe(function(calls)
        local s=battle(); clear(calls)
        for turn,want in ipairs({1,2,2}) do
            assert(Combat.endTurn(s)); eq(#calls,want,"rolls after sleep "..turn)
            eq(s.player.hp,80); eq(s.enemies[1].block,turn<3 and 8 or 0)
            eq(Combat.intent(s,1).kind,turn<3 and "sleep" or "attack")
        end
        ranges(calls,{100,100})
    end)
end)

test("awake attacks and debuff each roll without changing 18,18,0 cycle",function()
    observe(function(calls)
        local s=battle(); for _=1,3 do assert(Combat.endTurn(s)) end
        clear(calls)
        for turn,damage in ipairs({18,18,0,18}) do
            local hp=s.player.hp; assert(Combat.endTurn(s))
            eq(hp-s.player.hp,damage); eq(#calls,turn)
            eq(calls[turn].range,100); eq(calls[turn].intentOwner,"lagavulin_1")
        end
        eq(s.player.statuses.dexterity,-1); eq(s.player.statuses.strength,-1)
        eq(s.enemies[1].block,0)
    end)
end)

for _,sleepCount in ipairs({0,2}) do
    test("damage wake after "..sleepCount.." sleeps rolls on stun, not on damage",function()
        observe(function(calls)
            local s=battle(); for _=1,sleepCount do assert(Combat.endTurn(s)) end
            clear(calls); wake(s); ranges(calls,{})
            assert(Combat.endTurn(s)); ranges(calls,{100})
            eq(s.player.hp,80); eq(Combat.intent(s,1).id,"lagavulin_2")
            assert(Combat.endTurn(s)); ranges(calls,{100,100}); eq(s.player.hp,62)
        end)
    end)
end

test("nonlethal poison wakes then consumes exactly one stun roll",function()
    observe(function(calls)
        local s=battle(); clear(calls); Combat.addStatus(s.enemies[1],"poison",2)
        assert(Combat.endTurn(s)); ranges(calls,{100})
        eq(s.enemies[1].hp,107); eq(s.enemies[1].block,0)
        eq(s.player.hp,80); eq(Combat.intent(s,1).id,"lagavulin_2")
    end)
end)

test("lethal poison before takeTurn does not consume a roll",function()
    observe(function(calls)
        local s=battle({"lagavulin","sneaky_gremlin"}); clear(calls)
        s.enemies[1].hp=1; Combat.addStatus(s.enemies[1],"poison",1)
        assert(Combat.endTurn(s)); ranges(calls,{})
        eq(s.enemies[1].hp,0); eq(s.player.hp,71); eq(s.phase,"player")
    end)
end)

test("retaliation death retains already queued roll while a teammate lives",function()
    observe(function(calls)
        local s=battle({"lagavulin","cultist"}); wake(s); assert(Combat.endTurn(s))
        clear(calls); s.enemies[1].hp=1; Combat.addStatus(s.player,"thorns",1)
        assert(Combat.endTurn(s)); ranges(calls,{100,100})
        eq(calls[1].intentOwner,"lagavulin_1"); eq(calls[2].intentOwner,"cultist_2")
        eq(s.enemies[1].hp,0); eq(s.player.hp,56); eq(s.phase,"player")
        clear(calls); assert(Combat.endTurn(s)); ranges(calls,{100})
        eq(calls[1].intentOwner,"cultist_2")
    end)
end)

test("last enemy retaliation death clears queued roll",function()
    observe(function(calls)
        local s=battle(); wake(s); assert(Combat.endTurn(s)); clear(calls)
        s.enemies[1].hp=1; Combat.addStatus(s.player,"thorns",1)
        assert(Combat.endTurn(s)); ranges(calls,{})
        eq(s.phase,"victory"); eq(s.player.hp,62)
    end)
end)

test("player card kill before takeTurn never queues a roll",function()
    observe(function(calls)
        local s=battle({"lagavulin","sneaky_gremlin"},{"strike"}); clear(calls)
        s.enemies[1].hp=1; s.enemies[1].block=0
        assert(Combat.play(s,s.hand[1].uid,1)); ranges(calls,{})
        assert(Combat.endTurn(s)); ranges(calls,{})
        eq(s.enemies[1].hp,0); eq(s.player.hp,71)
    end)
end)

test("two Lagavulins preserve independent sleep and stunned roll schedules",function()
    observe(function(calls)
        local s=battle({"lagavulin","lagavulin"}); ranges(calls,{3,3,100,100})
        assert(Combat.endTurn(s)); assert(Combat.endTurn(s)); clear(calls); wake(s)
        assert(Combat.endTurn(s)); ranges(calls,{100})
        eq(calls[1].intentOwner,"lagavulin_1")
        eq(Combat.intent(s,1).kind,"attack"); eq(Combat.intent(s,2).kind,"attack")
        eq(s.player.hp,80)
    end)
end)

test("real project seed changes on rolls but not natural wake",function()
    local s=battle(); eq(s.seed,42944)
    assert(Combat.endTurn(s)); eq(s.seed,26841)
    assert(Combat.endTurn(s)); eq(s.seed,6182)
    assert(Combat.endTurn(s)); eq(s.seed,6182)
    assert(Combat.endTurn(s)); eq(s.seed,50871)
end)

test("opening roll occurs before shuffle and preserves card instances",function()
    observe(function(calls)
        local s=battle(nil,{"strike","defend","bash","anger"})
        ranges(calls,{3,100,4,3,2}); eq(s.seed,50871)
        for i,uid in ipairs({2,3,4,1}) do eq(s.hand[i].uid,uid) end
    end)
end)

test("preview and refused card input do not consume rolls",function()
    observe(function(calls)
        local s=battle(nil,{"strike"}); clear(calls); local seed,eventCount=s.seed,#s.events
        for _=1,3 do
            local intent=Combat.intent(s,1); intent.kind="changed"
            eq(Combat.intent(s,1).kind,"sleep")
            local ok,reason=Combat.play(s,s.hand[1].uid,99)
            eq(ok,false); eq(reason,"invalid_target")
        end
        ranges(calls,{}); eq(s.seed,seed); eq(#s.events,eventCount)
    end)
end)

test("failed card restores damage wake without a hidden roll",function()
    observe(function(calls)
        local s=battle(nil,{"strike"}); clear(calls)
        local e,seed,events=s.enemies[1],s.seed,s.events
        s.catalog.cards.strike.effects={{op="damage",value=9},{op="gainStatus",status="strength",value=2147483647}}
        s.player.statuses.strength=1
        eq(pcall(Combat.play,s,s.hand[1].uid,1),false)
        eq(s.enemies[1],e); eq(s.events,events); eq(s.seed,seed); eq(e.hp,109); eq(e.block,8)
        eq(Combat.intent(s,1).kind,"sleep"); ranges(calls,{})
    end)
end)

test("real Run elite entry and fire-potion wake use the same roll schedule",function()
    observe(function(calls)
        local run=Run.new(data,42); run.floor=6; run.deck={{uid=1,cardId="defend",upgraded=false}}
        run.potions={"fire_potion"}; assert(Run.startCombat(run,"elite_lagavulin"))
        ranges(calls,{3,100}); eq(run.combat.seed,42944)
        assert(Run.usePotion(run,1,1)); ranges(calls,{3,100})
        eq(Combat.intent(run.combat,1).kind,"stunned")
        assert(Run.endTurn(run)); ranges(calls,{3,100,100})
        eq(run.combat.seed,26841); eq(run.combat.player.hp,80)
        eq(Combat.intent(run.combat,1).kind,"attack")
    end)
end)

print("lagavulin rolls: "..passed.." passed, "..failed.." failed")
assert(failed==0,"Lagavulin roll regressions")
