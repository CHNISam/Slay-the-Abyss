package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Combat=require("abyss_combat")
local Run=require("abyss_run")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn) count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end;print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err))) end
local function battle(enemies,seed) return Combat.new(Data,{enemies=enemies or {"spike_slime_s"},deck={"defend"},seed=seed or 42}) end
local function controlled(roll,fn)
    local old=Combat.random;local calls={}
    Combat.random=function(s,n) calls[#calls+1]=n;return n==100 and roll+1 or 1 end
    local ok,err=pcall(fn,calls);Combat.random=old;assert(ok,err)
end

test("A0 small Spike Slime samples inclusive HP10–14 reproducibly",function()
    local def,seen
    seen={};for _,e in ipairs(Data.enemies.enemies) do if e.id=="spike_slime_s" then def=e end end
    assert(def.hpRange,"small Spike Slime HP range missing");eq(def.hpRange.min,10);eq(def.hpRange.max,14)
    for seed=0,127 do local e=battle(nil,seed).enemies[1];assert(e.hp>=10 and e.hp<=14);eq(e.maxHp,e.hp);eq(e.hp,battle(nil,seed).enemies[1].hp);seen[e.hp]=true end
    for hp=10,14 do assert(seen[hp],"missing HP "..hp) end
end)
test("single Tackle opening consumes one primary roll regardless of its value",function()
    for _,roll in ipairs({0,99}) do controlled(roll,function(calls)
        local s=battle();eq(Combat.intent(s,1).id,"spike_slime_s_1");eq(#calls,2);eq(calls[1],5);eq(calls[2],100)
    end) end
end)
test("each completed living Tackle repeats damage5 and consumes one primary roll",function()
    controlled(99,function(calls)
        local s=battle()
        for turn=1,10 do
            eq(Combat.intent(s,1).id,"spike_slime_s_1");assert(Combat.endTurn(s));eq(s.player.hp,80-5*turn);eq(#calls,2+turn);eq(calls[#calls],100)
        end
    end)
end)
test("full Block and zero damage still complete Tackle and its queued roll",function()
    controlled(0,function(calls)
        local s=battle();s.player.block=5;assert(Combat.endTurn(s));eq(s.player.hp,80);eq(#calls,3)
        Combat.addStatus(s.enemies[1],"strength",-5);assert(Combat.endTurn(s));eq(s.player.hp,80);eq(#calls,4)
    end)
end)
test("Tackle uses existing Strength Weak Vulnerable and Block arithmetic",function()
    local s=battle();Combat.addStatus(s.enemies[1],"strength",3);Combat.addStatus(s.enemies[1],"weak",1)
    Combat.addStatus(s.player,"vulnerable",2);s.player.block=4;assert(Combat.endTurn(s));eq(s.player.hp,75,"floor(8*.75*1.5)-4")
end)
test("multiple instances each resolve damage5 and retain their own sampled HP",function()
    controlled(0,function(calls)
        local s=battle({"spike_slime_s","spike_slime_s"});eq(#calls,4)
        assert(Combat.endTurn(s));eq(s.player.hp,70);eq(#calls,6);eq(s.enemies[1].hp,10);eq(s.enemies[2].hp,10)
    end)
end)
test("failed card transaction restores selected attack HP seed and event count",function()
    local s=battle();local e=s.enemies[1];local intent,hp,seed,n=e.intentIndex,e.hp,s.seed,#s.events
    s.catalog.cards.defend.effects={{op="draw",value=1},{op="gainStatus",status="missing",value=1}}
    assert(not pcall(Combat.play,s,s.hand[1].uid,1));eq(e.intentIndex,intent);eq(e.hp,hp);eq(s.seed,seed);eq(#s.events,n)
end)
test("real true-branch small_slimes Run resolves Spike S and Acid M source actions",function()
    controlled(0,function()
        local run=Run.new(Data,42)
        for _,e in ipairs(Data.enemies.encounters) do if e.id=="small_slimes" then run.floor=e.minFloor end end
        assert(Run.startCombat(run,"small_slimes"));eq(#run.combat.enemies,2)
        eq(run.combat.enemies[1].definitionId,"spike_slime_s");eq(run.combat.enemies[2].definitionId,"acid_slime_m")
        assert(Run.endTurn(run));eq(run.combat.player.hp,68,"Spike S Tackle5 + Acid M Spit7")
        eq(run.combat.enemies[1].intentIndex,1);eq(run.miscRng.counter,1)
    end)
end)
assert(failed==0,tostring(failed).." failed of "..count)
