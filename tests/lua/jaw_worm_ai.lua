-- Independent STS1 A0 expectations: developer-posted getMove and pinned method bodies.
-- The controlled rolls below are input values, never claims about original seeds.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, data = require("abyss_combat"), require("abyss_data")
local count = 0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn) fn(); count=count+1; print("ok jaw "..count.." - "..name) end
local function battle(enemies,seed)
    return Combat.new(data,{enemies=enemies or {"jaw_worm"},deck={"defend"},seed=seed or 42})
end
local C,T,B = "jaw_worm_1","jaw_worm_2","jaw_worm_3"
local function intent(enemy,id)
    for i,item in ipairs(enemy.intents) do if item.id==id then enemy.intentIndex=i; return end end
    error("missing intent "..id)
end

test("A0 HP is actually sampled inclusively from 40 through 44",function()
    local seen={}
    for seed=0,63 do
        local s=battle(nil,seed); local e=s.enemies[1]
        assert(e.hpRange and e.hpRange.min==40 and e.hpRange.max==44,"40–44 HP range missing")
        assert(e.hp>=40 and e.hp<=44); eq(e.maxHp,e.hp); eq(battle(nil,seed).enemies[1].hp,e.hp)
        seen[e.hp]=true
    end
    for hp=40,44 do assert(seen[hp],"unreached project sample HP "..hp) end
end)

test("normal opening is Chomp 11 without hard-mode bonuses",function()
    local s=battle(); local e=s.enemies[1]
    eq(e.ai.kind,"jaw_worm"); eq(Combat.intent(s,1).id,C)
    eq(e.block,0); eq(e.statuses.strength or 0,0)
    assert(Combat.endTurn(s)); eq(s.player.hp,69); eq(e.jawLast,C)
    assert(Combat.intent(s,1).id~=C,"Chomp cannot immediately repeat")
end)

test("forced opening still consumes the primary roll but no conditional coin",function()
    local AI=require("abyss_enemy_ai"); local s=battle(); local e=s.enemies[1]; local calls={}
    AI.initialize(s,e,function(_,maximum) calls[#calls+1]=maximum; return 100 end)
    eq(#calls,1,"opening primary draw"); eq(calls[1],100); eq(Combat.intent(s,1).id,C)
    eq(e.jawLast,nil); eq(e.jawPrevious,nil)
end)

test("every integer roll boundary follows history and only illegal branches consume a coin",function()
    local Jaw=require("abyss_jaw_worm_ai")
    local a=battle().enemies[1].ai
    -- Each row explicitly specifies results for rolls 0..24,25..54,55..99.
    local cases={
        {last=C,previous=B,low={B,T,B},high={T,T,B},coin={true,false,false}},
        {last=T,previous=C,low={C,T,B},high={C,T,B},coin={false,false,false}},
        {last=T,previous=T,low={C,C,B},high={C,B,B},coin={false,true,false}},
        {last=B,previous=T,low={C,T,C},high={C,T,T},coin={false,false,true}},
    }
    for _,case in ipairs(cases) do
        for roll=0,99 do
            local band=roll<25 and 1 or roll<55 and 2 or 3
            for _,high in ipairs({false,true}) do
                local calls=0
                local id=Jaw.choose(a,case.last,case.previous,roll,function() calls=calls+1; return high and 0.999999 or 0 end)
                eq(id,(high and case.high or case.low)[band],"controlled roll "..roll)
                eq(calls,case.coin[band] and 1 or 0,"conditional coin calls")
            end
        end
    end
end)

test("conditional coins preserve Java float cutoffs and strict less-than",function()
    local Jaw=require("abyss_jaw_worm_ai"); local a=battle().enemies[1].ai
    -- nextFloat has a 24-bit grid. These adjacent values straddle each Java float.
    for _,case in ipairs({
        {C,B,0,0.5625,B,T},
        {T,T,25,0.3569999933242798,C,B},
        {B,T,55,0.41600000858306885,C,T},
    }) do
        local lo=math.ceil(case[4]*16777216)-1
        eq(Jaw.choose(a,case[1],case[2],case[3],function() return lo/16777216 end),case[5])
        eq(Jaw.choose(a,case[1],case[2],case[3],function() return (lo+1)/16777216 end),case[6])
        eq(Jaw.choose(a,case[1],case[2],case[3],function() return case[4] end),case[6])
    end
end)

test("production adapter rolls once then draws an extra fraction only when required",function()
    local AI=require("abyss_enemy_ai"); local s=battle(); local e=s.enemies[1]
    local calls={}; local values={1,1}
    AI.advance(s,e,function(_,maximum) calls[#calls+1]=maximum; return table.remove(values,1) end)
    eq(calls[1],100); eq(calls[2],65536); eq(#calls,2); eq(Combat.intent(s,1).id,B)
    calls={}; intent(e,T)
    AI.advance(s,e,function(_,maximum) calls[#calls+1]=maximum; return 26 end)
    eq(#calls,1); eq(calls[1],100); eq(Combat.intent(s,1).id,T)
    eq(e.jawPrevious,C); eq(e.jawLast,T)
end)

test("Thrash attacks for seven before gaining five Block",function()
    local s=battle(); local e=s.enemies[1]; intent(e,T); s.events={}
    assert(Combat.endTurn(s)); eq(s.player.hp,73); eq(e.block,5)
    local damage,block
    for i,event in ipairs(s.events) do
        if event.kind=="damage" and event.detail.source==e.id then damage=i; eq(event.detail.amount,7) end
        if event.kind=="block" and event.detail.target==e.id then block=i; eq(event.detail.amount,5) end
    end
    assert(damage and block and damage<block,"Thrash Block must follow attack")
end)

test("Bellow grants three Strength before six Block and buffs the next attack",function()
    local s=battle(); local e=s.enemies[1]; intent(e,B); s.events={}
    assert(Combat.endTurn(s)); eq(s.player.hp,80); eq(e.statuses.strength,3); eq(e.block,6)
    local strength,block
    for i,event in ipairs(s.events) do
        if event.kind=="status" and event.detail.target==e.id then strength=i end
        if event.kind=="block" and event.detail.target==e.id then block=i end
    end
    assert(strength and block and strength<block)
    intent(e,C); assert(Combat.endTurn(s)); eq(s.player.hp,66); eq(e.block,0)
end)

test("existing Weak, Vulnerable and Block modifiers apply to Thrash",function()
    local s=battle(); local e=s.enemies[1]; intent(e,T)
    Combat.addStatus(e,"strength",3); Combat.addStatus(e,"weak",1)
    Combat.addStatus(s.player,"vulnerable",2); Combat.addStatus(s.player,"barricade",1); s.player.block=4
    assert(Combat.endTurn(s)); eq(s.player.hp,73); eq(e.block,5)
end)

test("lethal poison prevents an action, history advance and any AI draw",function()
    local s=battle({"jaw_worm","shield_gremlin"}); local e=s.enemies[1]; e.hp=1
    local seed=s.seed -- one-card deck and Shield Protect/SetMove do not use post-opening RNG
    Combat.addStatus(e,"poison",1); assert(Combat.endTurn(s)); eq(e.hp,0); eq(e.jawLast,nil)
    eq(s.seed,seed)
    for _,event in ipairs(s.events) do assert(event.kind~="intent" or event.detail.enemy~=e.id) end
end)

test("lethal Thorns cancels Thrash Block but keeps its queued roll while a teammate lives",function()
    local s=battle({"jaw_worm","shield_gremlin"}); local e=s.enemies[1]
    e.hp=1; intent(e,T); local seed=s.seed
    Combat.addStatus(s.player,"thorns",1)
    assert(Combat.endTurn(s)); eq(e.hp,0); eq(e.block,0); eq(e.jawLast,T); assert(s.seed~=seed)
    eq(Combat.intent(s,1),nil) -- rolled intent is not a new action for a dead owner
end)

test("separate enemies own their history and obey all repeat limits over live rounds",function()
    for seed=0,15 do
        local s=battle({"jaw_worm","jaw_worm"},seed)
        for _=1,24 do
            s.player.hp=80; s.player.block=999; Combat.addStatus(s.player,"barricade",1)
            assert(Combat.endTurn(s))
            for _,e in ipairs(s.enemies) do
                local next=Combat.intent(s,tonumber(e.id:match("_(%d+)$"))).id
                assert(next~=C or e.jawLast~=C)
                assert(next~=B or e.jawLast~=B)
                assert(next~=T or e.jawLast~=T or e.jawPrevious~=T)
            end
        end
    end
    local untouched=battle(); eq(untouched.enemies[1].jawLast,nil); eq(Combat.intent(untouched,1).id,C)
end)

test("failed card preserves sampled actor and flat decision history atomically",function()
    local s=Combat.new(data,{enemies={"jaw_worm"},deck={"strike"},seed=42}); assert(Combat.endTurn(s))
    local e=s.enemies[1]; local hp,last,previous,index,seed=e.hp,e.jawLast,e.jawPrevious,e.intentIndex,s.seed
    s.catalog.cards.strike.effects={{op="damage",value=6},{op="gainStatus",status="strength",value=2147483647}}
    s.player.statuses.strength=1
    eq(pcall(Combat.play,s,s.hand[1].uid,1),false)
    eq(e.hp,hp); eq(e.jawLast,last); eq(e.jawPrevious,previous); eq(e.intentIndex,index); eq(s.seed,seed)
end)
print("LUA_JAW_WORM_AI_PASS "..count)
