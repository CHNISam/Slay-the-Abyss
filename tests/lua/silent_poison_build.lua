package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Silent, Poison = require("abyss_combat"), require("abyss_silent"), require("abyss_poison")
local Actors, Random = require("abyss_actor"), require("abyss_sts_random")
local data = require("abyss_data")
local count=0
local function eq(a,b,label) assert(a==b,(label or "value")..": "..tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();count=count+1;print("ok silent poison "..count.." - "..name) end
local function fresh(id,upgraded,two)
    local s=Combat.new(Silent.withFoundationCards(data),{deck={{cardId=id,upgraded=upgraded}},
        enemies=two and {"jaw_worm","jaw_worm"} or {"jaw_worm"},seed=42})
    for _,enemy in ipairs(s.enemies) do enemy.hp=300;enemy.maxHp=300 end
    s.cardRandomRng=Random.fromSeed("123")
    return s,s.hand[1]
end
for _,upgraded in ipairs({false,true}) do
    test("Catalyst reads current poison through actual play and exhausts "..tostring(upgraded),function()
        local s,card=fresh("catalyst",upgraded);Actors.addStatus(s.enemies[1],"poison",5)
        local energy=s.energy
        assert(Combat.play(s,card.uid,1));eq(s.energy,energy-1)
        eq(s.enemies[1].statuses.poison,upgraded and 15 or 10)
        eq(#s.exhaust,1);eq(s.exhaust[1],card);eq(#s.discard,0)
    end)
    test("Catalyst Artifact blocks additive application but leaves original poison "..tostring(upgraded),function()
        local s,card=fresh("catalyst",upgraded)
        Actors.addStatus(s.enemies[1],"poison",7);Actors.addStatus(s.enemies[1],"artifact",1)
        assert(Combat.play(s,card.uid,1));eq(s.enemies[1].statuses.poison,7)
        eq(s.enemies[1].statuses.artifact,0)
    end)
    test("Catalyst without poison does not consume Artifact "..tostring(upgraded),function()
        local s,card=fresh("catalyst",upgraded);Actors.addStatus(s.enemies[1],"artifact",1)
        assert(Combat.play(s,card.uid,1));eq(s.enemies[1].statuses.poison or 0,0)
        eq(s.enemies[1].statuses.artifact,1);eq(#s.exhaust,1)
    end)
    test("Flask singleton consumes every bounce RNG including lookahead "..tostring(upgraded),function()
        local s,card=fresh("bouncing_flask",upgraded);local bounces=upgraded and 4 or 3
        local energy=s.energy;local original=Actors.applyPower;local trace={}
        Actors.applyPower=function(state,target,id,amount,source,...)
            if id=="poison" then trace[#trace+1]={counter=state.cardRandomRng.counter,target=target} end
            return original(state,target,id,amount,source,...)
        end
        local ok,result=pcall(Combat.play,s,card.uid)
        Actors.applyPower=original;assert(ok,result);assert(result)
        eq(s.energy,energy-2);eq(s.cardRandomRng.counter,bounces)
        eq(s.enemies[1].statuses.poison,bounces*3);eq(#trace,bounces)
        for i,entry in ipairs(trace) do eq(entry.counter,math.min(i+1,bounces));eq(entry.target,s.enemies[1]) end
    end)
    test("Flask applies distinct Artifact checks for every bounce "..tostring(upgraded),function()
        local s,card=fresh("bouncing_flask",upgraded);Actors.addStatus(s.enemies[1],"artifact",2)
        assert(Combat.play(s,card.uid));eq(s.enemies[1].statuses.artifact,0)
        eq(s.enemies[1].statuses.poison,(upgraded and 4 or 3)*3-6)
    end)
    test("Fumes first triggers next player post-draw, then poison ticks on enemy turn "..tostring(upgraded),function()
        local s,card=fresh("noxious_fumes",upgraded);local amount=upgraded and 3 or 2
        assert(Combat.play(s,card.uid));eq(s.player.statuses.noxious_fumes,amount)
        eq(s.enemies[1].statuses.poison or 0,0);eq(#s.discard,0);eq(#s.exhaust,0)
        assert(Combat.endTurn(s));eq(s.enemies[1].hp,300);eq(s.enemies[1].statuses.poison,amount)
        assert(Combat.endTurn(s));eq(s.enemies[1].hp,300-amount)
        eq(s.enemies[1].statuses.poison,amount*2-1)
    end)
end
test("two-target Flask uses independent stream and leaves legacy RNG untouched",function()
    local s,card=fresh("bouncing_flask",true,true)
    local seed=s.seed;local expected=Random.cloneState(s.cardRandomRng);local stacks={0,0}
    for _=1,4 do local selected=Random.randomInt(expected,1)+1;stacks[selected]=stacks[selected]+3 end
    assert(Combat.play(s,card.uid));eq(s.seed,seed);eq(s.cardRandomRng.counter,4)
    for i,enemy in ipairs(s.enemies) do eq(enemy.statuses.poison or 0,stacks[i]) end
end)
test("Flask excludes dying halfdead and escaping targets without changing candidate order",function()
    local s,card=fresh("bouncing_flask",false,true);s.enemies[1].isEscaping=true
    assert(Combat.play(s,card.uid));eq(s.enemies[1].statuses.poison or 0,0);eq(s.enemies[2].statuses.poison,9)
    for _,flag in ipairs({"isDying","halfDead"}) do
        s=fresh("bouncing_flask",false,true);s.enemies[1][flag]=true
        assert(Poison.flask(s,3));eq(s.enemies[1].statuses.poison or 0,0);eq(s.enemies[2].statuses.poison,9)
    end
end)
test("high poison distinguishes new constructor cap from existing stackAmount",function()
    local s=fresh("noxious_fumes",false,true)
    Actors.addStatus(s.player,"noxious_fumes",20000)
    Actors.addStatus(s.enemies[2],"poison",1)
    assert(Poison.postDraw(s));eq(s.enemies[1].statuses.poison,9999);eq(s.enemies[2].statuses.poison,20001)
    assert(Poison.multiply(s,s.enemies[1],3));eq(s.enemies[1].statuses.poison,29997)
end)
test("Fumes applies in enemy list order and Artifact is per-target",function()
    local s=fresh("noxious_fumes",false,true);Actors.addStatus(s.player,"noxious_fumes",2)
    Actors.addStatus(s.enemies[1],"artifact",1)
    local before=#s.events;assert(Poison.postDraw(s))
    eq(s.enemies[1].statuses.poison or 0,0);eq(s.enemies[2].statuses.poison,2)
    eq(s.events[before+1].detail.target,s.enemies[1].id)
    eq(s.events[before+2].detail.target,s.enemies[2].id)
end)
test("NoDraw does not suppress Fumes post-draw hook",function()
    local s=fresh("noxious_fumes",false);s.player.noDraw=true
    Actors.addStatus(s.player,"noxious_fumes",3)
    local hand=#s.hand;assert(Poison.postDraw(s));eq(#s.hand,hand);eq(s.enemies[1].statuses.poison,3)
end)
test("bad Flask RNG rolls back paid energy and original card/pile/RNG refs",function()
    local s,card=fresh("bouncing_flask",false);s.cardRandomRng.primitive.a={}
    local energy,seed,hand,discard,events=s.energy,s.seed,s.hand,s.discard,s.events
    local rng,primitive,bad=s.cardRandomRng,s.cardRandomRng.primitive,s.cardRandomRng.primitive.a
    local nEvents=#events;assert(not pcall(Combat.play,s,card.uid))
    eq(s.energy,energy);eq(s.seed,seed);eq(s.hand,hand);eq(s.discard,discard)
    eq(s.hand[1],card);eq(s.events,events);eq(#events,nEvents)
    eq(s.cardRandomRng,rng);eq(rng.primitive,primitive);eq(primitive.a,bad);eq(rng.counter,0)
end)
test("failure after a bounce restores source RNG and already-applied poison",function()
    local s,card=fresh("bouncing_flask",false,true)
    local rng,primitive=s.cardRandomRng,s.cardRandomRng.primitive
    local snapshot=Random.snapshot(rng);local energy=s.energy;local statuses=s.enemies[1].statuses
    local original=Actors.applyPower;local calls=0;local sentinel={}
    Actors.applyPower=function(...)
        calls=calls+1
        if calls==2 then error(sentinel) end
        return original(...)
    end
    local ok,err=pcall(Combat.play,s,card.uid);Actors.applyPower=original
    eq(ok,false);eq(err,sentinel);eq(s.energy,energy);eq(s.hand[1],card)
    eq(s.cardRandomRng,rng);eq(rng.primitive,primitive);eq(rng.counter,snapshot.counter)
    local restored=Random.snapshot(rng)
    eq(restored.words[1],snapshot.words[1]);eq(restored.words[2],snapshot.words[2])
    eq(s.enemies[1].statuses,statuses)
    eq(s.enemies[1].statuses.poison or 0,0);eq(s.enemies[2].statuses.poison or 0,0)
end)
test("unsafe poison overflow rolls back Catalyst without silently truncating",function()
    local s,card=fresh("catalyst",true);Actors.addStatus(s.enemies[1],"poison",1000000000)
    local energy=s.energy;assert(not pcall(Combat.play,s,card.uid,1))
    eq(s.energy,energy);eq(s.hand[1],card);eq(s.enemies[1].statuses.poison,1000000000)
end)
test("dead source or final dead target cancels further poison and RNG",function()
    local s=fresh("bouncing_flask",false);s.player.hp=0
    eq(Poison.flask(s,3),false);eq(s.cardRandomRng.counter,0)
    s=fresh("catalyst",false);Actors.addStatus(s.enemies[1],"poison",5);s.enemies[1].hp=0
    eq(Poison.multiply(s,s.enemies[1],2),false);eq(s.enemies[1].statuses.poison,5)
end)
print("SILENT_POISON_BUILD_PASS "..count)
