package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Combat=require("abyss_combat")
local Run=require("abyss_run")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn) count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end;print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err))) end
local A,W="acid_slime_s_1","acid_slime_s_2"
local function battle(enemies,seed) return Combat.new(Data,{enemies=enemies or {"acid_slime_s"},deck={"defend"},seed=seed or 42}) end
local function controlled(primary,boolean,fn)
    local old=Combat.random;local calls={}
    Combat.random=function(s,n) calls[#calls+1]=n;if n==100 then return primary+1 elseif n==2 then return boolean else return 1 end end
    local ok,err=pcall(fn,calls);Combat.random=old;assert(ok,err)
end

test("A0 small Acid Slime samples inclusive HP8–12 reproducibly",function()
    local seen={};local def
    for _,e in ipairs(Data.enemies.enemies) do if e.id=="acid_slime_s" then def=e end end
    assert(def.hpRange,"small Acid Slime HP range missing");eq(def.hpRange.min,8);eq(def.hpRange.max,12)
    for seed=0,127 do local e=battle(nil,seed).enemies[1];assert(e.hp>=8 and e.hp<=12);eq(e.maxHp,e.hp);eq(e.hp,battle(nil,seed).enemies[1].hp);seen[e.hp]=true end
    for hp=8,12 do assert(seen[hp],"missing HP "..hp) end
end)
test("opening ignores primary roll then consumes one independent Boolean request",function()
    for _,primary in ipairs({0,99}) do for boolean=1,2 do controlled(primary,boolean,function(calls)
        local s=battle();eq(Combat.intent(s,1).id,boolean==2 and A or W)
        eq(#calls,3);eq(calls[1],5);eq(calls[2],100);eq(calls[3],2)
    end) end end
end)
test("both random openings strictly alternate without any subsequent AI roll",function()
    for boolean=1,2 do controlled(99,boolean,function(calls)
        local s=battle();local next=boolean==2 and A or W
        for turn=1,10 do
            eq(Combat.intent(s,1).id,next);assert(Combat.endTurn(s));next=next==A and W or A
        end
        eq(#calls,3,"no rollMove after takeTurn")
    end) end
end)
test("natural Tackle is damage3 and natural Lick applies Weak1 without damage",function()
    controlled(0,2,function()
        local s=battle();assert(Combat.endTurn(s));eq(s.player.hp,77);eq(s.player.statuses.weak or 0,0)
        assert(Combat.endTurn(s));eq(s.player.hp,77);eq(s.player.statuses.weak,1)
    end)
    controlled(99,1,function()
        local s=battle();assert(Combat.endTurn(s));eq(s.player.hp,80);eq(s.player.statuses.weak,1)
        assert(Combat.endTurn(s));eq(s.player.hp,77)
    end)
end)
test("instances may open differently and advance independently",function()
    local old=Combat.random;local booleans=0
    Combat.random=function(s,n) if n==2 then booleans=booleans+1;return booleans==1 and 2 or 1 end;return 1 end
    local ok,err=pcall(function()
        local s=battle({"acid_slime_s","acid_slime_s"});eq(booleans,2);eq(Combat.intent(s,1).id,A);eq(Combat.intent(s,2).id,W)
        assert(Combat.endTurn(s));eq(Combat.intent(s,1).id,W);eq(Combat.intent(s,2).id,A);eq(booleans,2);eq(s.player.hp,77)
    end);Combat.random=old;assert(ok,err)
end)
test("lethal poison does not execute the selected action or request another roll",function()
    controlled(0,2,function(calls)
        local s=battle({"acid_slime_s","cultist"});local e=s.enemies[1];local requests=#calls
        Combat.addStatus(e,"poison",99);assert(Combat.endTurn(s));eq(e.hp,0);eq(e.intentIndex,1);eq(s.player.hp,80);eq(#calls,requests+1);eq(calls[#calls],100);eq(s.enemies[2].statuses.ritual,3) -- surviving Cultist's post-Ritual roll
    end)
end)
test("lethal Thorns ends small slime actions while a teammate continues",function()
    controlled(0,2,function(calls)
        local s=battle({"acid_slime_s","cultist"});s.enemies[1].hp=1;Combat.addStatus(s.player,"thorns",1);local requests=#calls
        assert(Combat.endTurn(s));eq(s.enemies[1].hp,0);eq(s.player.hp,77);eq(s.enemies[2].statuses.ritual,3);eq(#calls,requests+1);eq(calls[#calls],100) -- Cultist, not the dead slime
    end)
end)
test("a failed skill transaction preserves chosen opening HP seed and events",function()
    local s=battle();local e=s.enemies[1];local intent,hp,seed,n=e.intentIndex,e.hp,s.seed,#s.events
    s.catalog.cards.defend.effects={{op="draw",value=1},{op="gainStatus",status="missing",value=1}}
    assert(not pcall(Combat.play,s,s.hand[1].uid,1));eq(e.intentIndex,intent);eq(e.hp,hp);eq(s.seed,seed);eq(#s.events,n)
end)
test("real small_slimes Run encounter retains members and resolves source actions",function()
    controlled(0,2,function()
        local run=Run.new(Data,42)
        for _,e in ipairs(Data.enemies.encounters) do if e.id=="small_slimes" then run.floor=e.minFloor end end
        assert(Run.startCombat(run,"small_slimes"));eq(#run.combat.enemies,2)
        eq(run.combat.enemies[1].definitionId,"acid_slime_s");eq(run.combat.enemies[2].definitionId,"spike_slime_s")
        assert(Run.endTurn(run));eq(run.combat.player.hp,72);eq(run.combat.enemies[1].intentIndex,2)
    end)
end)
assert(failed==0,tostring(failed).." failed of "..count)
