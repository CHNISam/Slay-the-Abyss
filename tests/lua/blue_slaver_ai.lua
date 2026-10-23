package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat=require("abyss_combat")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn) count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end;print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err))) end
local S,R="blue_slaver_1","blue_slaver_2"
local function battle(enemies,seed) return Combat.new(Data,{enemies=enemies or {"blue_slaver"},deck={"defend"},seed=seed or 42}) end
local function controlled(roll,fn)
    local old=Combat.random;local calls={}
    Combat.random=function(s,n) calls[#calls+1]=n;return n==100 and roll+1 or 1 end
    local ok,err=pcall(fn,calls);Combat.random=old;assert(ok,err)
end

test("A0 Blue declares a dedicated decision policy retaining HP46–50",function()
    local s=battle();local e=s.enemies[1]
    assert(e.ai,"Blue Slaver decision policy missing");eq(e.ai.kind,"blue_slaver");eq(e.hpRange.min,46);eq(e.hpRange.max,50)
end)
test("first move is random: 0–39 Rake and 40–99 Stab, one roll after HP",function()
    for _,roll in ipairs({0,39,40,99}) do controlled(roll,function(calls)
        local s=battle();eq(Combat.intent(s,1).id,roll<40 and R or S)
        eq(#calls,2);eq(calls[1],5);eq(calls[2],100);eq(s.enemies[1].blueLast,nil)
    end) end
end)
test("900 controlled choices cover both boundaries and both repeat limits",function()
    local Blue=require("abyss_blue_slaver_ai");local a=battle().enemies[1].ai
    for _,last in ipairs({"none",S,R}) do for _,previous in ipairs({"none",S,R}) do for roll=0,99 do
        local expected
        if last==S and previous==S then expected=R
        elseif last==R and previous==R then expected=S
        else expected=roll<40 and R or S end
        eq(Blue.choose(a,last,previous,roll),expected,"roll "..roll)
    end end end
end)
test("high rolls permit two Stabs then force Rake and consume no extra draws",function()
    controlled(99,function(calls)
        local s=battle()
        for _,expected in ipairs({S,S,R,S,S,R}) do
            eq(Combat.intent(s,1).id,expected);assert(Combat.endTurn(s));eq(s.enemies[1].blueLast,expected)
        end
        eq(#calls,8)
    end)
end)
test("low rolls permit two Rakes then force Stab without consecutive-three",function()
    controlled(0,function(calls)
        local s=battle()
        for _,expected in ipairs({R,R,S,R,R,S}) do
            eq(Combat.intent(s,1).id,expected);assert(Combat.endTurn(s));eq(s.enemies[1].blueLast,expected)
        end
        eq(#calls,8)
    end)
end)
test("natural Rake resolves damage7 then Weak1; natural Stab is damage12",function()
    controlled(39,function()
        local s=battle();s.events={};assert(Combat.endTurn(s));eq(s.player.hp,73);eq(s.player.statuses.weak,1)
        local damage,weak
        for i,e in ipairs(s.events) do if e.kind=="damage" and e.detail.source==s.enemies[1].id then damage=i
            elseif e.kind=="status" and e.detail.status=="weak" and e.detail.amount==1 then weak=i end end
        assert(damage and weak and damage<weak)
    end)
    controlled(40,function() local s=battle();assert(Combat.endTurn(s));eq(s.player.hp,68);eq(s.player.statuses.weak or 0,0) end)
end)
test("dead Blue cannot act or advance while another enemy completes the turn",function()
    local s=battle({"blue_slaver","cultist"});local e=s.enemies[1];local intent=Combat.intent(s,1).id
    Combat.addStatus(e,"poison",99);assert(Combat.endTurn(s));eq(e.hp,0);eq(e.blueLast,nil);eq(e.intents[e.intentIndex].id,intent);eq(s.enemies[2].statuses.ritual,3)
end)
test("multiple instances keep independent bounded history",function()
    for seed=1,16 do local s=battle({"blue_slaver","blue_slaver"},seed);s.player.hp=10000
        for _=1,12 do
            local executed={Combat.intent(s,1).id,Combat.intent(s,2).id};assert(Combat.endTurn(s))
            for i,e in ipairs(s.enemies) do eq(e.blueLast,executed[i]);assert(not(e.blueLast==e.bluePrevious and Combat.intent(s,i).id==e.blueLast),"third repeated move") end
        end
    end
end)
test("failed card transaction restores Blue history selected move and seed",function()
    local s=battle();assert(Combat.endTurn(s));local e=s.enemies[1]
    local last,previous,intent,seed,n=e.blueLast,e.bluePrevious,e.intentIndex,s.seed,#s.events
    s.catalog.cards.defend.effects={{op="draw",value=1},{op="gainStatus",status="missing",value=1}}
    assert(not pcall(Combat.play,s,s.hand[1].uid,1));eq(e.blueLast,last);eq(e.bluePrevious,previous);eq(e.intentIndex,intent);eq(s.seed,seed);eq(#s.events,n)
end)
assert(failed==0,tostring(failed).." failed of "..count)
