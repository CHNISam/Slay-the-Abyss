package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local C=require("abyss_combat")
local A=require("abyss_actor")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn) count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end;print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err))) end
local function battle() return C.new(Data,{enemies={"jaw_worm"},deck={"battle_trance"},seed=42}) end

test("real Battle Trance applies NoDraw only when Artifact does not block it",function()
    for stacks=0,1 do local s=battle();C.addStatus(s.player,"artifact",stacks)
        assert(C.play(s,s.hand[1].uid,1));eq(s.player.noDraw,stacks==0);eq(s.player.statuses.artifact,0)
    end
end)
test("already-existing NoDraw bypasses Artifact consumption on another real Trance",function()
    local s=battle();s.player.noDraw=true;C.addStatus(s.player,"artifact",2)
    assert(C.play(s,s.hand[1].uid,1));eq(s.player.noDraw,true);eq(s.player.statuses.artifact,2)
end)
test("source NoDraw boundary cancels on a dead target without spending Artifact",function()
    local s=battle();C.addStatus(s.player,"artifact",1);s.player.hp=0;local n=#s.events
    eq(A.applyNoDraw(s,s.player),false);eq(s.player.noDraw,false);eq(s.player.statuses.artifact,1);eq(#s.events,n)
end)
test("NoDraw's special duplicate gate precedes generic Artifact gate",function()
    local s=battle();C.addStatus(s.player,"artifact",1)
    eq(A.applyNoDraw(s,s.player),false);eq(s.player.noDraw,false);eq(s.player.statuses.artifact,0)
    eq(A.applyNoDraw(s,s.player),true);C.addStatus(s.player,"artifact",1)
    eq(A.applyNoDraw(s,s.player),false);eq(s.player.noDraw,true);eq(s.player.statuses.artifact,1)
end)
test("real Trance canPlay preflight remains read-only before Artifact is spent",function()
    local s=battle();C.addStatus(s.player,"artifact",1);local n,seed=#s.events,s.seed
    for _=1,5 do assert(C.canPlay(s,s.hand[1].uid,1));eq(s.player.statuses.artifact,1);eq(s.player.noDraw,false);eq(#s.events,n);eq(s.seed,seed) end
    assert(C.play(s,s.hand[1].uid,1));eq(s.player.statuses.artifact,0);eq(s.player.noDraw,false)
end)
test("failure after blocked NoDraw restores Artifact flag references and events",function()
    local s=battle();C.addStatus(s.player,"artifact",1)
    s.catalog.cards.battle_trance.effects[#s.catalog.cards.battle_trance.effects+1]={op="gainStatus",status="missing",value=1}
    local p,statuses,events,hand=s.player,s.player.statuses,s.events,s.hand
    local n,seed,energy=#s.events,s.seed,s.energy
    local old=A.applyNoDraw;local calls=0;A.applyNoDraw=function(...)calls=calls+1;return old(...) end
    local ok=pcall(C.play,s,s.hand[1].uid,1);A.applyNoDraw=old
    eq(ok,false);eq(calls,1);eq(s.player,p);eq(p.statuses,statuses);eq(s.events,events);eq(s.hand,hand)
    eq(p.statuses.artifact,1);eq(p.noDraw,false);eq(#s.events,n);eq(s.seed,seed);eq(s.energy,energy)
end)
assert(failed==0,tostring(failed).." failed of "..count)
