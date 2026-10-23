-- A0 action payload expectations from fixed read-only mirrors, not a full AI oracle.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local data = require("abyss_data")
local count, failed = 0, 0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn)
    count=count+1; local ok,err=pcall(fn); if not ok then failed=failed+1 end
    print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err)))
end
local function battle(seed,enemies)
    return Combat.new(data,{seed=seed or 42,enemies=enemies or {"jaw_worm"},deck={"strike"}})
end
local function action(s,semantic)
    local id = assert(s.enemies[1].ai[semantic .. "Intent"], "missing semantic action " .. semantic)
    for i,v in ipairs(s.enemies[1].intents) do if v.id==id then s.enemies[1].intentIndex=i; return Combat.intent(s,1) end end
    error("missing action "..id)
end
local function eventIndex(s,kind,predicate)
    for i,e in ipairs(s.events) do if e.kind==kind and predicate(e.detail) then return i end end
    error("missing event "..kind)
end

test("normal first action remains Chomp 11 without prebattle Strength or Block",function()
    local s=battle(); local e=s.enemies[1]; local i=Combat.intent(s,1)
    eq(i.id,"jaw_worm_1"); eq(i.kind,"attack"); eq(#i.effects,1); eq(i.effects[1].op,"damage");eq(i.effects[1].value,11)
    eq(e.block,0);eq(e.statuses.strength or 0,0);assert(Combat.endTurn(s));eq(s.player.hp,69)
end)

test("Bellow payload is Strength 3 then Block 6 and preview is detached",function()
    local s=battle();local i=action(s,"bellow")
    eq(i.kind,"buff");eq(#i.effects,2);eq(i.effects[1].op,"gainStatus");eq(i.effects[1].status,"strength");eq(i.effects[1].value,3)
    eq(i.effects[2].op,"block");eq(i.effects[2].value,6)
    i.effects[2].value=99;eq(Combat.intent(s,1).effects[2].value,6)
end)

test("Bellow resolves Strength before Block without attacking",function()
    local s=battle();action(s,"bellow");s.events={};assert(Combat.endTurn(s))
    eq(s.player.hp,80);eq(s.enemies[1].statuses.strength,3);eq(s.enemies[1].block,6)
    local strength=eventIndex(s,"status",function(d)return d.status=="strength" and d.target=="jaw_worm_1" end)
    local block=eventIndex(s,"block",function(d)return d.target=="jaw_worm_1" end)
    assert(strength<block,"Strength must precede Block")
end)

test("Thrash payload is damage 7 then Block 5",function()
    local s=battle();local i=action(s,"thrash")
    eq(i.kind,"attack");eq(#i.effects,2);eq(i.effects[1].op,"damage");eq(i.effects[1].value,7);eq(i.effects[2].op,"block");eq(i.effects[2].value,5)
end)

test("Thrash resolves damage before Block",function()
    local s=battle();action(s,"thrash");s.events={};assert(Combat.endTurn(s))
    eq(s.player.hp,73);eq(s.enemies[1].block,5);eq(s.enemies[1].statuses.strength or 0,0)
    local damage=eventIndex(s,"damage",function(d)return d.source=="jaw_worm_1" end)
    local block=eventIndex(s,"block",function(d)return d.target=="jaw_worm_1" end)
    assert(damage<block,"damage must precede Block")
end)

test("fully blocked Thrash still grants five Block",function()
    local s=battle();action(s,"thrash");s.player.block=7;assert(Combat.endTurn(s));eq(s.player.hp,80);eq(s.enemies[1].block,5)
end)

test("zero damage Thrash still grants five Block",function()
    local s=battle();action(s,"thrash");Combat.addStatus(s.enemies[1],"strength",-7)
    assert(Combat.endTurn(s));eq(s.player.hp,80);eq(s.enemies[1].block,5)
end)

test("Thrash uses existing Strength Weak Vulnerable and Dexterity modifiers",function()
    local s=battle();action(s,"thrash");local e=s.enemies[1]
    Combat.addStatus(e,"strength",2);Combat.addStatus(e,"weak",1);Combat.addStatus(e,"dexterity",2)
    Combat.addStatus(s.player,"vulnerable",2);s.player.block=2;assert(Combat.endTurn(s))
    eq(s.player.hp,72,"floor((7+2)*.75*1.5)-2");eq(e.block,7)
end)

test("forced Bellow then Thrash demonstrates permanent Strength and Block reset",function()
    local s=battle();action(s,"bellow");assert(Combat.endTurn(s));eq(s.enemies[1].block,6)
    action(s,"thrash");assert(Combat.endTurn(s));eq(s.player.hp,70);eq(s.enemies[1].block,5);eq(s.enemies[1].statuses.strength,3)
    action(s,"chomp");assert(Combat.endTurn(s));eq(s.player.hp,56);eq(s.enemies[1].block,0)
end)

test("repeated forced Bellow stacks Strength but not expired Block",function()
    local s=battle()
    for n=1,3 do action(s,"bellow");assert(Combat.endTurn(s));eq(s.enemies[1].statuses.strength,3*n);eq(s.enemies[1].block,6);eq(s.player.hp,80) end
end)

test("HP covers inclusive 40 through 44 with matching maxHp and repeatability",function()
    local seen={}
    for seed=0,127 do
        local s,r=battle(seed),battle(seed);local e=s.enemies[1]
        assert(e.hp>=40 and e.hp<=44 and e.hp%1==0);eq(e.maxHp,e.hp);eq(r.enemies[1].hp,e.hp);eq(r.seed,s.seed);seen[e.hp]=true
    end
    for hp=40,44 do assert(seen[hp],"missing HP sample "..hp) end
end)

test("Bellow buffs its own instance only",function()
    local s=battle(42,{"jaw_worm","jaw_worm"});action(s,"bellow");assert(Combat.endTurn(s))
    eq(s.enemies[1].statuses.strength,3);eq(s.enemies[1].block,6);eq(s.enemies[2].statuses.strength or 0,0);eq(s.enemies[2].block,0);eq(s.player.hp,69)
end)

test("poison-killed Jaw Worm cannot act while teammate survives",function()
    local s=battle(42,{"jaw_worm","sneaky_gremlin"});action(s,"bellow");Combat.addStatus(s.enemies[1],"poison",44)
    assert(Combat.endTurn(s));eq(s.enemies[1].hp,0);eq(s.enemies[1].statuses.strength or 0,0);eq(s.enemies[1].block,0);eq(s.player.hp,71)
end)

test("real Strike consumes Bellow Block before HP",function()
    local s=battle();action(s,"bellow");assert(Combat.endTurn(s));local hp=s.enemies[1].hp
    assert(Combat.play(s,s.hand[1].uid,1));eq(s.enemies[1].block,0);eq(s.enemies[1].hp,hp)
end)

test("Run host entry retains opening Chomp and bounded actual HP",function()
    local run=Run.new(data,42)
    assert(Run.startCombat(run,"jaw_solo"))
    local s=run.combat;local e=s.enemies[1]
    assert(e.hp>=40 and e.hp<=44);eq(e.maxHp,e.hp);eq(Combat.intent(s,1).id,"jaw_worm_1")
    local hp=s.player.hp;assert(Run.endTurn(run));eq(s.player.hp,hp-11)
end)

assert(failed==0,tostring(failed).." Jaw Worm groups failed")
print("Jaw Worm: "..count.." groups passed")

