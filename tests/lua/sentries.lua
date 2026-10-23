package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local C=require("abyss_combat")
local Run=require("abyss_run")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn) count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end;print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err))) end
local function battle(ids,deck,seed) return C.new(Data,{enemies=ids or {"sentry","sentry","sentry"},deck=deck or {"defend"},seed=seed or 42}) end
local function dazed(s)
    local n=0;for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust}) do for _,card in ipairs(pile) do if card.cardId=="dazed" then n=n+1 end end end;return n
end
local function controlled(roll,fn)
    local old=C.random;local rolls=0
    C.random=function(s,n) if n==100 then rolls=rolls+1;return roll+1 end;return 1 end
    local ok,err=pcall(fn,function()return rolls end);C.random=old;assert(ok,err)
end

test("all three A0 Sentries sample HP38–42 and start with Artifact1",function()
    local seen={};local def
    for _,e in ipairs(Data.enemies.enemies) do if e.id=="sentry" then def=e end end
    assert(def.hpRange,"Sentry HP range missing");eq(def.hpRange.min,38);eq(def.hpRange.max,42)
    for seed=0,63 do for _,e in ipairs(battle(nil,nil,seed).enemies) do
        assert(e.hp>=38 and e.hp<=42);eq(e.maxHp,e.hp);eq(e.statuses.artifact,1);seen[e.hp]=true
    end end
    for hp=38,42 do assert(seen[hp],"missing HP "..hp) end
end)
test("outer Bolt2 Dazed and middle Beam9 are source-specific opening intents",function()
    local s=battle();eq(C.intent(s,1).id,"sentry_2");eq(C.intent(s,2).id,"sentry_1");eq(C.intent(s,3).id,"sentry_2")
    local bolt=C.intent(s,1);eq(bolt.kind,"debuff");eq(#bolt.effects,1);eq(bolt.effects[1].op,"makeTempCardInDiscard");eq(bolt.effects[1].card,"dazed");eq(bolt.effects[1].value,2)
    eq(C.intent(s,2).effects[1].value,9);bolt.effects[1].value=99;eq(C.intent(s,1).effects[1].value,2)
end)
test("initial parity is the whole monster-list slot, not the Sentry-only ordinal",function()
    local s=battle({"cultist","sentry","sentry"})
    eq(C.intent(s,2).id,"sentry_1");eq(C.intent(s,3).id,"sentry_2")
end)
test("three natural rounds alternate actual Bolt and Beam effects without fake Weak",function()
    local s=battle()
    for turn,expected in ipairs({{71,4},{53,6},{44,10}}) do
        assert(C.endTurn(s));eq(s.player.hp,expected[1]);eq(dazed(s),expected[2]);eq(s.player.statuses.weak or 0,0)
        for i,e in ipairs(s.enemies) do eq(e.statuses.artifact,1);eq(C.intent(s,i).id,(i%2==1)==(turn%2==0) and "sentry_2" or "sentry_1") end
    end
end)
test("Artifact does not block generated status cards",function()
    local s=battle();C.addStatus(s.player,"artifact",1);assert(C.endTurn(s));eq(dazed(s),4);eq(s.player.statuses.artifact,1)
end)
test("ignored primary roll consumes once per initial and completed Sentry action",function()
    for _,roll in ipairs({0,99}) do controlled(roll,function(rolls)
        local s=battle();eq(rolls(),3);assert(C.endTurn(s));eq(rolls(),6);assert(C.endTurn(s));eq(rolls(),9)
    end) end
end)
test("Beam killed by Thorns keeps its queued roll but never acts on later turns",function()
    controlled(99,function(rolls)
        local s=battle();s.enemies[2].hp=1;C.addStatus(s.player,"thorns",1)
        assert(C.endTurn(s));eq(s.enemies[2].hp,0);eq(s.player.hp,71);eq(dazed(s),4);eq(rolls(),6)
        assert(C.endTurn(s));eq(s.player.hp,53);eq(dazed(s),4);eq(rolls(),8)
    end)
end)
test("poison setup before action suppresses only that Sentry's Bolt and roll",function()
    controlled(0,function(rolls)
        local s=battle();C.addStatus(s.enemies[1],"poison",99)
        assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(s.player.hp,71);eq(dazed(s),2);eq(rolls(),5)
    end)
end)
test("real elite_sentries Run entry retains three actors and the staggered first round",function()
    local run=Run.new(Data,42)
    for _,e in ipairs(Data.enemies.encounters) do if e.id=="elite_sentries" then run.floor=e.minFloor end end
    assert(Run.startCombat(run,"elite_sentries"));eq(#run.combat.enemies,3)
    assert(Run.endTurn(run));eq(run.combat.player.hp,71);eq(dazed(run.combat),4)
end)
assert(failed==0,tostring(failed).." failed of "..count)
