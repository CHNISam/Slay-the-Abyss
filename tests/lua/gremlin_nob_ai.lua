package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Data = require("abyss_data")
local count, failed = 0, 0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn)
    count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end
    print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err)))
end
local function battle(deck,enemies,seed) return Combat.new(Data,{deck=deck or {"defend"},enemies=enemies or {"gremlin_nob"},seed=seed or 42}) end
local B,S,R="gremlin_nob_1","gremlin_nob_2","gremlin_nob_3"
local function force(s,id)
    for i,v in ipairs(s.enemies[1].intents) do if v.id==id then s.enemies[1].intentIndex=i;return end end
    error("missing intent "..id)
end
local function index(s,kind,predicate)
    for i,e in ipairs(s.events) do if e.kind==kind and predicate(e.detail) then return i end end
    error("missing event "..kind)
end
local function controlled(roll,fn)
    local old=Combat.random;local calls={}
    Combat.random=function(s,n) calls[#calls+1]=n;return n==100 and roll+1 or 1 end
    local ok,err=pcall(fn,calls);Combat.random=old;assert(ok,err)
end

test("A0 HP samples inclusive 82 through 86 with matching maxHp",function()
    local seen={}
    assert(Data.enemies.enemies[1])
    local def
    for _,e in ipairs(Data.enemies.enemies) do if e.id=="gremlin_nob" then def=e end end
    assert(def.hpRange,"Nob HP range missing")
    eq(def.hpRange.min,82);eq(def.hpRange.max,86)
    for seed=0,127 do local e=battle(nil,nil,seed).enemies[1];assert(e.hp>=82 and e.hp<=86);eq(e.maxHp,e.hp);seen[e.hp]=true end
    for hp=82,86 do assert(seen[hp],"uncovered HP "..hp) end
end)
test("opening Bellow grants Enrage 2 without direct Strength or damage",function()
    local s=battle();local e=s.enemies[1];eq(Combat.intent(s,1).id,B);eq(e.statuses.enrage or 0,0)
    assert(Combat.play(s,s.hand[1].uid,1));eq(e.statuses.strength or 0,0,"skill before Bellow")
    assert(Combat.endTurn(s));eq(e.statuses.enrage,2);eq(e.statuses.strength or 0,0);eq(s.player.hp,80)
end)
test("one skill triggers Enrage once before its Block; buffs stack",function()
    local s=battle();assert(Combat.endTurn(s));s.events={}
    assert(Combat.play(s,s.hand[1].uid,1));eq(s.enemies[1].statuses.strength,2);eq(s.player.block,5)
    assert(index(s,"status",function(d)return d.status=="strength" end)<index(s,"block",function(d)return d.target=="player" end))
    assert(Combat.endTurn(s));assert(Combat.play(s,s.hand[1].uid,1));eq(s.enemies[1].statuses.strength,4)
end)
test("attack and power cards do not trigger Enrage",function()
    for _,id in ipairs({"strike","inflame"}) do
        local s=battle({id});assert(Combat.endTurn(s));assert(Combat.play(s,s.hand[1].uid,1));eq(s.enemies[1].statuses.strength or 0,0,id)
    end
end)
test("invalid plays and failed card transactions preserve Enrage and Strength",function()
    local s=battle();assert(Combat.endTurn(s));s.energy=0;local events=#s.events
    local ok,reason=Combat.play(s,s.hand[1].uid,1);eq(ok,false);eq(reason,"insufficient_energy");eq(#s.events,events);eq(s.enemies[1].statuses.strength or 0,0)
    s.energy=3;s.catalog.cards.defend.effects={{op="gainStatus",status="unknown",value=1}}
    local hp,seed,hand=s.player.hp,s.seed,s.hand[1];ok=pcall(Combat.play,s,hand.uid,1);eq(ok,false)
    eq(s.enemies[1].statuses.strength or 0,0);eq(s.enemies[1].statuses.enrage,2);eq(s.player.hp,hp);eq(s.seed,seed);eq(s.hand[1],hand);eq(#s.events,events)
end)
test("Skull Bash deals 6 before applying Vulnerable 2 in one action",function()
    local s=battle();force(s,S);s.events={};assert(Combat.endTurn(s));eq(s.player.hp,74);eq(s.player.statuses.vulnerable,2)
    assert(index(s,"damage",function(d)return d.source=="gremlin_nob_1" end)<index(s,"status",function(d)return d.status=="vulnerable" and d.amount==2 end))
    force(s,R);assert(Combat.endTurn(s));eq(s.player.hp,53,"next Bull Rush 14*1.5")
end)
test("Enrage Strength changes subsequent attack damage",function()
    local s=battle();assert(Combat.endTurn(s));assert(Combat.play(s,s.hand[1].uid,1));force(s,R)
    assert(Combat.endTurn(s));eq(s.player.hp,69,"16 damage minus 5 Block");eq(s.enemies[1].statuses.enrage,2)
end)
test("all 100 rolls and nine histories obey A0 33 boundary and Rush cap",function()
    local Nob=require("abyss_gremlin_nob_ai");local ai=battle().enemies[1].ai
    for _,last in ipairs({B,S,R}) do for _,previous in ipairs({B,S,R}) do for roll=0,99 do
        local expected=(roll<33 or (last==R and previous==R)) and S or R
        eq(Nob.choose(ai,last,previous,roll),expected,"roll "..roll)
    end end end
end)
test("forced opening and every completed action consume exactly one primary roll",function()
    controlled(99,function(calls)
        local s=battle();eq(#calls,2);eq(calls[1],5);eq(calls[2],100);eq(Combat.intent(s,1).id,B)
        assert(Combat.endTurn(s));eq(Combat.intent(s,1).id,R)
        assert(Combat.endTurn(s));eq(Combat.intent(s,1).id,R)
        assert(Combat.endTurn(s));eq(Combat.intent(s,1).id,S);eq(#calls,5)
    end)
    controlled(32,function() local s=battle();assert(Combat.endTurn(s));eq(Combat.intent(s,1).id,S) end)
    controlled(33,function() local s=battle();assert(Combat.endTurn(s));eq(Combat.intent(s,1).id,R) end)
end)
test("multiple living Nobs react independently; dead owners cannot gain Strength",function()
    local s=battle(nil,{"gremlin_nob","gremlin_nob","cultist"});assert(Combat.endTurn(s));s.enemies[1].hp=0;s.events={}
    assert(Combat.play(s,s.hand[1].uid,1));eq(s.enemies[1].statuses.strength or 0,0);eq(s.enemies[2].statuses.strength,2);eq(s.enemies[3].statuses.strength or 0,0)
end)
test("poison death cannot execute or advance Nob while another enemy continues",function()
    local s=battle(nil,{"gremlin_nob","cultist"});local e=s.enemies[1];Combat.addStatus(e,"poison",99)
    assert(Combat.endTurn(s));eq(e.hp,0);eq(e.statuses.enrage or 0,0);eq(e.nobLast,nil);eq(s.phase,"player");eq(s.enemies[2].statuses.ritual,3)
end)
test("Nob retains bounded history without Bellow repeats or triple Rush",function()
    for seed=1,32 do local s=battle(nil,nil,seed);s.player.hp=10000
        local last,previous
        for turn=1,12 do local id=Combat.intent(s,1).id
            assert(turn==1 or id~=B);assert(not(id==R and last==R and previous==R));previous,last=last,id
            assert(Combat.endTurn(s));eq(s.enemies[1].nobLast,id)
        end
    end
end)
assert(failed==0,tostring(failed).." failed of "..count)
