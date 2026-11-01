package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local C=require("abyss_combat")
local A=require("abyss_actor")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn) count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end;print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err))) end
local function battle() return C.new(Data,{enemies={"jaw_worm"},deck={"defend"},seed=42}) end
local function artifact(s,actor,n) C.addStatus(actor,"artifact",n or 1) end

test("Artifact is a nondecaying stackable buff with a source application boundary",function()
    local s=battle();local def=s.catalog.statuses.artifact;assert(def,"missing Artifact definition")
    eq(def.kind,"buff");eq(def.stack,"intensity");eq(def.decay,"none");eq(type(A.applyPower),"function")
end)
test("one Artifact blocks one full application of each supported ordinary debuff",function()
    for _,id in ipairs({"weak","vulnerable","frail","poison"}) do
        local s=battle();local e=s.enemies[1];artifact(s,e);s.events={}
        eq(A.applyPower(s,e,id,3,s.player),false);eq(e.statuses[id] or 0,0,id);eq(e.statuses.artifact,0)
        eq(e[id.."JustApplied"],nil);eq(#s.events,1);eq(s.events[1].kind,"status");eq(s.events[1].detail.status,"artifact");eq(s.events[1].detail.amount,-1)
        eq(A.applyPower(s,e,id,3,s.player),true);eq(e.statuses[id],3)
    end
end)
test("two Artifact stacks block repeated applications separately then permit stacking",function()
    local s=battle();local e=s.enemies[1];artifact(s,e,2)
    for n=1,2 do eq(A.applyPower(s,e,"weak",1,s.player),false);eq(e.statuses.artifact,2-n);eq(e.statuses.weak or 0,0) end
    assert(A.applyPower(s,e,"weak",1,s.player));assert(A.applyPower(s,e,"weak",2,s.player));eq(e.statuses.weak,3)
end)
test("an existing debuff still spends Artifact when a new stack is blocked",function()
    local s=battle();local e=s.enemies[1];C.addStatus(e,"weak",2);artifact(s,e)
    eq(A.applyPower(s,e,"weak",1,s.player),false);eq(e.statuses.weak,2);eq(e.statuses.artifact,0)
end)
test("signed stat classification uses incoming power amount including zero",function()
    for _,id in ipairs({"strength","dexterity"}) do for _,amount in ipairs({-2,0}) do
        local s=battle();local e=s.enemies[1];C.addStatus(e,id,5);artifact(s,e)
        eq(A.applyPower(s,e,id,amount,s.player),false);eq(e.statuses[id],5);eq(e.statuses.artifact,0)
    end end
end)
test("positive buffs do not consume Artifact even when stat cap makes gain ineffective",function()
    local s=battle();local e=s.enemies[1];artifact(s,e);C.addStatus(e,"strength",999)
    assert(A.applyPower(s,e,"strength",3,e));eq(e.statuses.strength,999);eq(e.statuses.artifact,1)
    assert(A.applyPower(s,e,"dexterity",2,e));eq(e.statuses.dexterity,2);eq(e.statuses.artifact,1)
end)
test("zero ordinary debuff is still a DEBUFF power and consumes Artifact",function()
    local s=battle();local e=s.enemies[1];artifact(s,e)
    eq(A.applyPower(s,e,"weak",0,s.player),false);eq(e.statuses.artifact,0);eq(e.statuses.weak or 0,0)
end)
test("invalid IDs and amounts fail before any Artifact or event mutation",function()
    for _,row in ipairs({{"missing",1},{"weak",-1},{"weak",.5},{"strength",math.huge}}) do
        local s=battle();local e=s.enemies[1];artifact(s,e);local n=#s.events
        eq(pcall(A.applyPower,s,e,row[1],row[2],s.player),false);eq(e.statuses.artifact,1);eq(#s.events,n)
    end
end)
test("dead target cancels application without spending Artifact",function()
    local s=battle();local e=s.enemies[1];artifact(s,e);e.hp=0;local n=#s.events
    eq(A.applyPower(s,e,"weak",1,s.player),false);eq(e.statuses.artifact,1);eq(#s.events,n)
end)
test("raw status/addStatus mutations are not fabricated ApplyPower actions",function()
    local s=battle();local e=s.enemies[1];artifact(s,e)
    C.addStatus(e,"weak",1);A.status(s,e,"strength",-1)
    eq(e.statuses.artifact,1);eq(e.statuses.weak,1);eq(e.statuses.strength,-1)
end)
test("dead source can still apply queued power to live target with Artifact protection",function()
    local s=battle();local e=s.enemies[1];artifact(s,s.player);e.hp=0;s.phase="enemy"
    eq(A.applyPower(s,s.player,"weak",1,e),false);eq(s.player.statuses.artifact,0);eq(s.player.statuses.weak or 0,0)
end)
test("real-context Flex with prior Artifact blocks LoseStrength not its positive gain",function()
    local s=battle();artifact(s,s.player);A.addTemporaryStrength(s.player,2,s)
    eq(s.player.statuses.strength,2);eq(s.player.temporaryStrength or 0,0);eq(s.player.statuses.artifact,0)
    A.endTurn(s,s.player);eq(s.player.statuses.strength,2)
end)
test("Artifact gained after Flex blocks its queued negative Strength at owner end",function()
    local s=battle();A.addTemporaryStrength(s.player,2,s);eq(s.player.temporaryStrength,2);artifact(s,s.player)
    A.endTurn(s,s.player);eq(s.player.statuses.strength,2);eq(s.player.temporaryStrength,0);eq(s.player.statuses.artifact,0)
end)
test("separately blocked Flex loss does not erase an existing loss bookkeeping amount",function()
    local s=battle();A.addTemporaryStrength(s.player,2,s);artifact(s,s.player);A.addTemporaryStrength(s.player,2,s)
    eq(s.player.statuses.strength,4);eq(s.player.temporaryStrength,2);A.endTurn(s,s.player);eq(s.player.statuses.strength,2);eq(s.player.temporaryStrength,0)
end)
test("raw temporary Strength helper does not pretend to apply LoseStrength at setup",function()
    local s=battle();artifact(s,s.player);A.addTemporaryStrength(s.player,2)
    eq(s.player.statuses.artifact,1);eq(s.player.statuses.strength,2);eq(s.player.temporaryStrength,2)
end)
test("real-context temporary Strength cancels for a dead target without Artifact mutation",function()
    local s=battle();artifact(s,s.player);s.player.hp=0;local n=#s.events
    A.addTemporaryStrength(s.player,2,s);eq(s.player.statuses.artifact,1);eq(s.player.statuses.strength or 0,0)
    eq(s.player.temporaryStrength or 0,0);eq(#s.events,n)
end)
test("real-context zero Flex is outside the candidate ABI and rejects without mutation",function()
    local s=battle();artifact(s,s.player);local n=#s.events
    eq(pcall(A.addTemporaryStrength,s.player,0,s),false);eq(s.player.statuses.artifact,1)
    eq(s.player.statuses.strength,nil);eq(s.player.temporaryStrength,nil);eq(#s.events,n)
end)
test("raw two-argument zero temporary Strength retains its previous compatibility",function()
    local s=battle();artifact(s,s.player);local n=#s.events;A.addTemporaryStrength(s.player,0)
    eq(s.player.statuses.artifact,1);eq(s.player.statuses.strength,0);eq(s.player.temporaryStrength,0);eq(#s.events,n)
end)
test("raw temporary Strength still rejects overflowing bookkeeping even with Artifact",function()
    local s=battle();artifact(s,s.player);s.player.temporaryStrength=2147483647;local n=#s.events
    eq(pcall(A.addTemporaryStrength,s.player,2),false);eq(s.player.temporaryStrength,2147483647)
    eq(s.player.statuses.artifact,1);eq(s.player.statuses.strength,nil);eq(#s.events,n)
end)
assert(failed==0,tostring(failed).." failed of "..count)
