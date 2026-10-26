-- Boundary fixtures exercise real Combat commands, not a completed Act2 run.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local C, Run, R, Data = require("abyss_combat"), require("abyss_run"), require("abyss_sts_random"), require("abyss_data")
local count, failed = 0, 0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function same(a,b,path)
    path=path or "state"; eq(type(a),type(b),path)
    if type(a)~="table" then eq(a,b,path); return end
    for k,v in pairs(a) do same(v,b[k],path.."."..tostring(k)) end
    for k in pairs(b) do assert(a[k]~=nil,path.." missing "..tostring(k)) end
end
local function test(name,fn)
    count=count+1; local ok,err=pcall(fn); if not ok then failed=failed+1 end
    print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err)))
end
local function battle(source,deck,hp)
    return C.new(Data,{seed=42,hp=hp,deck=deck or {},enemies=Data.enemies.act2Encounters[source or "Spheric Guardian"]})
end
local function id(s,i) return C.intent(s,i or 1).id end
local function hits(s,first,source)
    local found={}
    for i=first,#s.events do local ev=s.events[i]
        if ev.kind=="damage" and ev.detail.source==source then found[#found+1]=ev.detail end
    end
    return found
end
local function controlled(endpoint,fn)
    local old,calls=C.random,{}
    C.random=function(state,maximum) calls[#calls+1]=maximum;return maximum==100 and endpoint+1 or old(state,maximum) end
    local ok,err=pcall(fn,calls); C.random=old;assert(ok,err)
end
local function rollCount(calls) local n=0;for _,range in ipairs(calls) do if range==100 then n=n+1 end end;return n end
local function play(s,cardId,target)
    for _,card in ipairs(s.hand) do if card.cardId==cardId then return C.play(s,card.uid,target or 1) end end
    error("missing card "..cardId)
end

test("prebattle orders Barricade then Artifact3 then Block40 before first player command",function()
    local s=battle(); local e=s.enemies[1];eq(e.hp,20);eq(e.maxHp,20);eq(e.block,40)
    eq(e.statuses.barricade,1);eq(e.statuses.artifact,3);eq(id(s),"spheric_guardian_2")
    local order={}
    for _,ev in ipairs(s.events) do
        if ev.kind=="status" and ev.detail.target==e.id then order[#order+1]=ev.detail.status
        elseif ev.kind=="block" and ev.detail.target==e.id then order[#order+1]="block";eq(ev.detail.amount,40) end
    end
    same(order,{"barricade","artifact","block"})
    same(e.powerOrder,{"barricade","artifact"})
end)

test("public intent is isolated and opening Block is additive and retained",function()
    local s=battle(nil,{"strike"});local e=s.enemies[1]
    local preview=C.intent(s,1);preview.effects[1].value=999;eq(C.intent(s,1).effects[1].value,25)
    assert(play(s,"strike"));eq(e.block,34);eq(e.hp,20)
    assert(C.endTurn(s));eq(e.block,59);eq(e.hp,20);eq(s.player.hp,80)
    assert(C.endTurn(s));eq(e.block,59);eq(s.player.hp,70)
    assert(C.endTurn(s));eq(e.block,59);eq(s.player.hp,50)
    local first=#s.events+1;assert(C.endTurn(s));eq(e.block,74);eq(s.player.hp,40)
    local order={};for i=first,#s.events do local ev=s.events[i]
        if ev.kind=="block" and ev.detail.target==e.id then order[#order+1]="block"
        elseif ev.kind=="damage" and ev.detail.source==e.id then order[#order+1]="damage" end
    end;same(order,{"block","damage"})
end)

test("natural A0 sequence has damage10 then Frail5, two distinct hits, and alternating harden",function()
    local s=battle();local expected={"spheric_guardian_4","spheric_guardian_1","spheric_guardian_3","spheric_guardian_1","spheric_guardian_3"}
    local hp={80,70,50,40,20};local frail={0,5,4,3,2}
    for turn,nextId in ipairs(expected) do
        local first=#s.events+1;assert(C.endTurn(s));eq(id(s),nextId);eq(s.player.hp,hp[turn]);eq(s.player.statuses.frail or 0,frail[turn])
        local damage=hits(s,first,s.enemies[1].id);eq(#damage,turn==1 and 0 or turn%2==1 and 2 or 1)
        for _,hit in ipairs(damage) do eq(hit.amount,10) end
        if turn==2 then
            local order={};for i=first,#s.events do local ev=s.events[i]
                if ev.kind=="damage" and ev.detail.source==s.enemies[1].id then order[#order+1]="damage"
                elseif ev.kind=="status" and ev.detail.target=="player" and ev.detail.status=="frail" then order[#order+1]="frail" end
            end;same(order,{"damage","frail"})
        end
    end
end)

test("fresh monster Frail keeps five for the first player turn and reduces Defend by floor",function()
    local s=battle(nil,{"defend"});assert(C.endTurn(s));assert(C.endTurn(s));eq(s.player.statuses.frail,5)
    assert(play(s,"defend"));eq(s.player.block,3);assert(C.endTurn(s));eq(s.player.hp,53);eq(s.player.statuses.frail,4)
end)

test("Artifact3 blocks exactly three actual Bash debuffs and fourth applies",function()
    local s=battle(nil,{"bash"});local e=s.enemies[1]
    for n=1,3 do assert(play(s,"bash"));eq(e.statuses.artifact,3-n);eq(e.statuses.vulnerable or 0,0);assert(C.endTurn(s)) end
    assert(play(s,"bash"));eq(e.statuses.artifact,0);eq(e.statuses.vulnerable,2);eq(e.hp,20)
end)

test("player Artifact cancels Frail once without cancelling the preceding damage",function()
    local s=battle();C.addStatus(s.player,"artifact",1);assert(C.endTurn(s));assert(C.endTurn(s))
    eq(s.player.hp,70);eq(s.player.statuses.artifact,0);eq(s.player.statuses.frail or 0,0)
end)

for _,endpoint in ipairs({0,99}) do
    test("ignored roll endpoint "..endpoint.." consumes opening and every complete move",function()
        controlled(endpoint,function(calls)
            local s=battle();eq(rollCount(calls),1)
            for turn=1,4 do assert(C.endTurn(s));eq(rollCount(calls),turn+1) end
            eq(id(s),"spheric_guardian_1")
        end)
    end)
end

test("ordered Sentry then Sphere composition preserves opening parity, powers and live actions",function()
    local s=battle("Sentry and Sphere");eq(#s.enemies,2);eq(s.enemies[1].definitionId,"sentry");eq(s.enemies[2].definitionId,"spheric_guardian")
    eq(id(s,1),"sentry_2");eq(id(s,2),"spheric_guardian_2");eq(s.enemies[1].statuses.artifact,1);eq(s.enemies[2].statuses.artifact,3)
    assert(C.endTurn(s));eq(s.player.hp,80);eq(s.enemies[2].block,65)
    local dazed=0;for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust}) do for _,card in ipairs(pile) do if card.cardId=="dazed" then dazed=dazed+1 end end end;eq(dazed,2)
    local first=#s.events+1;assert(C.endTurn(s));eq(s.player.hp,61)
    local actions={};for i=first,#s.events do local ev=s.events[i];if ev.kind=="intent" then actions[#actions+1]=ev.detail.enemy end end
    same(actions,{s.enemies[1].id,s.enemies[2].id});eq(s.player.statuses.frail,5)
end)

test("source streams consume fixed HP20 draw and all opening AI rolls, not visual entropy",function()
    for _,source in ipairs({"Spheric Guardian","Sentry and Sphere"}) do
        local streams=Run.roomStreams(Run.new(Data,"42"),18);local initial=C.copy(streams)
        local expectedHp,expectedAi=R.cloneState(streams.monsterHpRng),R.cloneState(streams.aiRng)
        local countActors=#Data.enemies.act2Encounters[source]
        if countActors==2 then R.randomInt(expectedHp,4) end
        R.randomInt(expectedHp,0);for _=1,countActors do R.randomInt(expectedAi,99) end
        local s=C.new(Data,{seed=101,deck={},enemies=Data.enemies.act2Encounters[source],roomSeed=streams.seed,roomStreams=streams})
        same(streams,initial,"constructor mutated caller streams");same(R.snapshot(s.monsterHpRng),R.snapshot(expectedHp));same(R.snapshot(s.aiRng),R.snapshot(expectedAi));eq(s.seed,101)
        local hp=R.snapshot(s.monsterHpRng);local card=R.snapshot(s.cardRandomRng)
        assert(C.endTurn(s));for _=1,countActors do R.randomInt(expectedAi,99) end
        same(R.snapshot(s.aiRng),R.snapshot(expectedAi));same(R.snapshot(s.monsterHpRng),hp);same(R.snapshot(s.cardRandomRng),card)
    end
end)

for _,withCompanion in ipairs({false,true}) do
    test("first Slam hit retaliation death stops second hit; companion="..tostring(withCompanion),function()
        controlled(0,function(calls)
            local s=battle(withCompanion and "Sentry and Sphere" or nil);local slot=withCompanion and 2 or 1;local e=s.enemies[slot]
            assert(C.endTurn(s));assert(C.endTurn(s));eq(id(s,slot),"spheric_guardian_1")
            -- Explicit retaliation boundary fixture, not a natural-playthrough claim.
            e.block,e.hp=0,1;C.addStatus(s.player,"thorns",1)
            local first,before=#s.events+1,rollCount(calls);assert(C.endTurn(s));eq(e.hp,0);eq(#hits(s,first,e.id),1)
            eq(rollCount(calls),before+(withCompanion and 2 or 0));eq(s.phase,withCompanion and "player" or "victory")
            if withCompanion then eq(e.intents[e.intentIndex].id,"spheric_guardian_3");assert(C.endTurn(s));eq(rollCount(calls),before+3)
            else local snapshot=C.copy(s);eq(C.endTurn(s),false);same(s,snapshot) end
        end)
    end)
end

for _,withCompanion in ipairs({false,true}) do
    test("queued Frail after retaliation death; companion="..tostring(withCompanion),function()
        controlled(0,function(calls)
            local s=battle(withCompanion and "Sentry and Sphere" or nil);assert(C.endTurn(s))
            local e=s.enemies[withCompanion and 2 or 1];e.block,e.hp=0,1;C.addStatus(s.player,"thorns",1)
            local before=rollCount(calls);assert(C.endTurn(s));eq(e.hp,0)
            eq(s.player.hp,withCompanion and 61 or 70);eq(s.player.statuses.frail or 0,withCompanion and 5 or 0)
            eq(rollCount(calls),before+(withCompanion and 2 or 0));eq(s.phase,withCompanion and "player" or "victory")
        end)
    end)
end

for _,hp in ipairs({20,21}) do
    test("Slam player-death boundary at initial HP"..hp.." clears later hit and queued roll",function()
        controlled(99,function(calls)
            local s=battle(nil,nil,hp);assert(C.endTurn(s));assert(C.endTurn(s));eq(s.player.hp,hp-10)
            local first,before=#s.events+1,rollCount(calls);assert(C.endTurn(s));eq(s.phase,"defeat");eq(s.player.hp,0)
            eq(#hits(s,first,s.enemies[1].id),hp==20 and 1 or 2);eq(rollCount(calls),before)
            local snapshot=C.copy(s);eq(C.endTurn(s),false);same(s,snapshot)
        end)
    end)
end

test("lethal Frail attack clears its queued power and roll",function()
    controlled(0,function(calls)
        local s=battle(nil,nil,10);assert(C.endTurn(s));eq(rollCount(calls),2);assert(C.endTurn(s))
        eq(s.phase,"defeat");eq(s.player.statuses.frail or 0,0);eq(rollCount(calls),2)
    end)
end)

test("poison before the move suppresses that actor and its unqueued roll",function()
    controlled(0,function(calls)
        local s=battle("Sentry and Sphere");local e=s.enemies[2];C.addStatus(e,"poison",20)
        assert(C.endTurn(s));eq(e.hp,0);eq(e.block,40);eq(rollCount(calls),3);eq(s.player.hp,80)
    end)
end)

test("failed actual Bash restores block Artifact card costs and all state before retry",function()
    local s=battle(nil,{"bash"});local old=C.copy(s);local apply=C.applyEffects;local sentinel={failure="after-bash-effects"}
    C.applyEffects=function(...) apply(...);error(sentinel) end
    local ok,err=pcall(C.play,s,s.hand[1].uid,1);C.applyEffects=apply
    eq(ok,false);eq(err,sentinel);same(s,old);assert(play(s,"bash"));eq(s.enemies[1].statuses.artifact,2)
end)

test("explicit implementation never opens ordinary or experimental Act2 production combat",function()
    for _,campaign in ipairs({false,true}) do
        local run=Run.new(Data,"42",campaign and {experimental=true,campaign=true} or nil);run.act,run.floor=2,18
        local snapshot=C.copy(run);local ok,why=Run.startRoomCombat(run,"normal")
        eq(ok,false);eq(why,"act_content_unavailable");same(run,snapshot)
    end
    eq(#Data.enemies.encounters,18)
end)
assert(failed==0,tostring(failed).." failed of "..count)
print("SPHERIC_GUARDIAN_PASS "..count)
