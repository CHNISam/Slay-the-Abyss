package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Combat=require("abyss_combat")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn) count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end;print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err))) end
local function battle(ids) return Combat.new(Data,{enemies=ids,deck={"defend"},seed=42}) end
local function controlled(roll,fn)
    local old=Combat.random;local calls={}
    Combat.random=function(s,n) calls[#calls+1]=n;return n==100 and roll+1 or 1 end
    local ok,err=pcall(fn,calls);Combat.random=old;assert(ok,err)
end

test("Fat and Sneaky both consume exactly one initial primary roll after HP",function()
    for _,id in ipairs({"fat_gremlin","sneaky_gremlin"}) do for _,roll in ipairs({0,99}) do controlled(roll,function(calls)
        local s=battle({id});eq(Combat.intent(s,1).id,id.."_1");eq(#calls,2);eq(calls[1],5);eq(calls[2],100)
    end) end end
end)
test("Fat consumes one roll after each completed living damage4 and Weak1 action",function()
    controlled(99,function(calls)
        local s=battle({"fat_gremlin"})
        for turn=1,6 do assert(Combat.endTurn(s));eq(s.player.hp,80-4*turn);eq(s.player.statuses.weak,1);eq(#calls,2+turn);eq(calls[#calls],100) end
    end)
end)
test("Sneaky SetMove repeats damage9 without any post-action roll",function()
    controlled(0,function(calls)
        local s=battle({"sneaky_gremlin"})
        for turn=1,6 do assert(Combat.endTurn(s));eq(s.player.hp,80-9*turn);eq(#calls,2);eq(Combat.intent(s,1).id,"sneaky_gremlin_1") end
    end)
end)
test("mixed owners consume a post-action roll only for Fat",function()
    controlled(99,function(calls)
        local s=battle({"fat_gremlin","sneaky_gremlin"});eq(#calls,4)
        for turn=1,4 do assert(Combat.endTurn(s));eq(s.player.hp,80-13*turn);eq(#calls,4+turn) end
    end)
end)
test("full Block and zero modified damage do not change either roll policy",function()
    for _,id in ipairs({"fat_gremlin","sneaky_gremlin"}) do controlled(99,function(calls)
        local s=battle({id});local base=id=="fat_gremlin" and 4 or 9;s.player.block=base
        assert(Combat.endTurn(s));eq(s.player.hp,80);eq(#calls,id=="fat_gremlin" and 3 or 2)
        Combat.addStatus(s.enemies[1],"strength",-base);assert(Combat.endTurn(s));eq(s.player.hp,80);eq(#calls,id=="fat_gremlin" and 4 or 2)
    end) end
end)
test("poison before action does not enqueue Fat or Sneaky follow-up draws",function()
    for _,id in ipairs({"fat_gremlin","sneaky_gremlin"}) do controlled(0,function(calls)
        local s=battle({id,"cultist"});local before=#calls;Combat.addStatus(s.enemies[1],"poison",99)
        assert(Combat.endTurn(s));eq(s.enemies[1].hp,0);eq(s.player.hp,80);eq(#calls,before+1);eq(calls[#calls],100);eq(s.enemies[2].statuses.ritual,3) -- only the living Cultist rolls
    end) end
end)
test("Sneaky killed by Thorns has no queued roll even with a living teammate",function()
    controlled(99,function(calls)
        local s=battle({"sneaky_gremlin","cultist"});local before=#calls;s.enemies[1].hp=1;Combat.addStatus(s.player,"thorns",1)
        assert(Combat.endTurn(s));eq(s.enemies[1].hp,0);eq(s.player.hp,71);eq(#calls,before+1);eq(calls[#calls],100);eq(s.enemies[2].statuses.ritual,3) -- only the living Cultist rolls
    end)
end)
test("failed skill transactions preserve both actors choices seed and events",function()
    local s=battle({"fat_gremlin","sneaky_gremlin"});local seed,n=s.seed,#s.events
    s.catalog.cards.defend.effects={{op="draw",value=1},{op="gainStatus",status="missing",value=1}}
    assert(not pcall(Combat.play,s,s.hand[1].uid,1));eq(s.seed,seed);eq(#s.events,n)
    for _,e in ipairs(s.enemies) do eq(e.intentIndex,1) end
end)
assert(failed==0,tostring(failed).." failed of "..count)
