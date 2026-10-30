package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Opening=require("abyss_opening_hand")
local Combat=require("abyss_combat")
local Random=require("abyss_sts_random")
local Data=require("abyss_data")
local count=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();count=count+1;print("ok opening_hand "..count.." - "..name) end
local function fixture(n,innateCount)
    local list,catalog={},{}
    for i=1,n do
        local id="opening_"..i
        list[i]={uid=i,cardId=id,upgraded=false}
        catalog[id]={id=id,innate=i<=innateCount}
    end
    return list,catalog
end
local function drawState(list,catalog)
    local s=Combat.new(Data,{seed=42,enemies={"cultist"},deck={"defend"}})
    s.catalog.cards=catalog;s.hand={};s.draw=list;s.discard={};s.exhaust={}
    return s
end
test("stable partition preserves instance identity and both original subsequences",function()
    local list,catalog=fixture(7,0)
    catalog.opening_2.innate=true;catalog.opening_4.innate=true;catalog.opening_7.innate=true
    local arranged,extra,summary=Opening.stage(list,catalog,5)
    local expected={1,3,5,6,2,4,7}
    for i,uid in ipairs(expected) do eq(arranged[i],list[uid]);eq(arranged[i].uid,uid) end
    for i,card in ipairs(list) do eq(card.uid,i) end
    eq(extra,0);eq(summary.innateCount,3);eq(summary.ordinaryCount,4)
    -- Top is the LAST element: the top-to-bottom order of the innate cards
    -- remains 7,4,2, not their original unshuffled/permanent deck order.
    local s=drawState(arranged,catalog);Combat.draw(s,5)
    for i,uid in ipairs({7,4,2,6,5}) do eq(s.hand[i].uid,uid) end
end)
test("upgraded-only Innate follows effective definition override",function()
    local list,catalog=fixture(3,0)
    catalog.opening_1.upgrade={innate=true}
    catalog.opening_2.innate=true;catalog.opening_2.upgrade={innate=false}
    list[1].upgraded=true;list[2].upgraded=true
    local arranged,extra,summary=Opening.stage(list,catalog,5)
    eq(arranged[1].uid,2);eq(arranged[2].uid,3);eq(arranged[3].uid,1)
    eq(summary.innateCount,1);eq(extra,0)
end)
test("runtime explicit flags are validated and override static metadata",function()
    local list,catalog=fixture(2,0)
    catalog.opening_1.innate=true;list[1].innate=false;list[2].innate=true
    local arranged,extra,summary=Opening.stage(list,catalog,0)
    eq(arranged[1],list[1]);eq(arranged[2],list[2]);eq(summary.innateCount,1);eq(extra,1)
end)
test("zero, below, equal and above opening draw counts match independent source partition",function()
    for n=0,12 do
        local list,catalog=fixture(16,n)
        local arranged,extra,summary=Opening.stage(list,catalog,5)
        eq(extra,math.max(0,n-5));eq(summary.innateCount,n)
        local s=drawState(arranged,catalog)
        Combat.draw(s,extra)
        Combat.draw(s,5)
        local expected={}
        for uid=n,1,-1 do expected[#expected+1]=uid end
        for uid=16,n+1,-1 do expected[#expected+1]=uid end
        local size=math.min(10,math.max(5,n))
        eq(#s.hand,size)
        for i=1,size do eq(s.hand[i].uid,expected[i]) end
        if n>10 then eq(s.draw[#s.draw].uid,n-10) end
    end
end)
test("excess Innate draw drains in prebattle before normal Draw5 and battle-start draw",function()
    local list,catalog=fixture(14,7)
    local arranged,extra=Opening.stage(list,catalog,5)
    eq(extra,2)
    local s=drawState(arranged,catalog)
    -- WaitAction and other initial prebattle actions drain first. During
    -- AbstractRoom.waitTimer, the manager then consumes preTurnActions before
    -- the room is allowed to enqueue its normal first-hand actions.
    Combat.draw(s,extra);eq(#s.hand,2);eq(s.hand[2].uid,6)
    Combat.draw(s,5);eq(#s.hand,7);eq(s.hand[7].uid,1)
    Combat.draw(s,2);eq(#s.hand,9)
    eq(s.hand[8].uid,14);eq(s.hand[9].uid,13)
end)
test("generated opening card consumes a real slot; more than ten Innate stay on draw top",function()
    local list,catalog=fixture(15,12)
    local arranged,extra=Opening.stage(list,catalog,5)
    local s=drawState(arranged,catalog)
    Combat.draw(s,extra);eq(#s.hand,7)
    -- Pure Water is atBattleStartPreDraw, after prebattle excess-innate draw.
    s.hand[#s.hand+1]={uid=100,cardId="miracle"}
    Combat.draw(s,5);eq(#s.hand,10)
    eq(s.hand[1].uid,12);eq(s.hand[8].uid,100);eq(s.hand[10].uid,4);eq(s.draw[#s.draw].uid,3)
end)
test("no new RNG calls occur after the one full-deck source shuffle",function()
    local list,catalog=fixture(12,6)
    local rng=Random.fromSeed("42")
    Random.shuffle(rng,list)
    local before=Random.snapshot(rng);eq(before.counter,1)
    local arranged,extra=Opening.stage(list,catalog,5)
    local after=Random.snapshot(rng);eq(after.counter,before.counter)
    for i,v in ipairs(before.words) do eq(after.words[i],v) end
    local expectedInnate,expectedOrdinary={},{}
    for _,card in ipairs(list) do
        local target=catalog[card.cardId].innate and expectedInnate or expectedOrdinary
        target[#target+1]=card.uid
    end
    for i,uid in ipairs(expectedOrdinary) do eq(arranged[i].uid,uid) end
    for i,uid in ipairs(expectedInnate) do eq(arranged[#expectedOrdinary+i].uid,uid) end
    eq(extra,1)
end)
test("empty and singleton staging do not replace the mandatory prior source shuffle",function()
    for n=0,1 do
        local list,catalog=fixture(n,n)
        local rng=Random.fromSeed("42")
        Random.shuffle(rng,list);eq(rng.counter,1)
        local arranged,extra=Opening.stage(list,catalog,5)
        eq(#arranged,n);eq(extra,0);eq(rng.counter,1)
    end
end)
test("bottles bind exact instances with innate upgrade high costs and hand capacity",function()
    for _,field in ipairs({"inBottleFlame","inBottleLightning","inBottleTornado","bottled"}) do
        local list,catalog=fixture(4,0)
        list[1][field]=true;list[1].upgraded=true
        catalog.opening_1.cost=5;catalog.opening_1.upgrade={cost=4}
        catalog.opening_3.innate=true
        local staged,extra=Opening.stage(list,catalog,2)
        for i,uid in ipairs({2,4,1,3})do eq(staged[i],list[uid])end
        eq(extra,0);eq(list[1][field],true);eq(list[1].upgraded,true)
        eq(catalog.opening_1.cost,5);eq(catalog.opening_1.upgrade.cost,4)
        for _,where in ipairs({"definition","upgrade"}) do
            local list,catalog=fixture(2,1)
            local owner=catalog.opening_1
            if where=="upgrade" then owner.upgrade={};owner=owner.upgrade;list[1].upgraded=true end
            owner[field]=true
            assert(not pcall(Opening.stage,list,catalog,5))
            eq(list[1].uid,1);eq(list[2].uid,2);eq(owner[field],true)
        end
        for _,value in ipairs({1,'true',{}})do
            local list,catalog=fixture(2,0);list[1][field]=value
            assert(not pcall(Opening.stage,list,catalog,5))
        end
    end
    local list,catalog=fixture(15,6)
    for i=5,12 do list[i].inBottleFlame=true end
    local staged,extra=Opening.stage(list,catalog,5);eq(extra,7)
    local s=drawState(staged,catalog);Combat.draw(s,extra);Combat.draw(s,5)
    eq(#s.hand,10);eq(s.hand[1].uid,12);eq(s.hand[10].uid,3);eq(s.draw[#s.draw].uid,2)
end)
test("malformed arrays, IDs, duplicate UIDs and flag types fail closed",function()
    local list,catalog=fixture(2,1)
    assert(not pcall(Opening.stage,{[2]=list[2]},catalog,5))
    list[2].uid=list[1].uid;assert(not pcall(Opening.stage,list,catalog,5));list[2].uid=2
    catalog.opening_1.innate=1;assert(not pcall(Opening.stage,list,catalog,5));catalog.opening_1.innate=true
    list[1].upgraded=1;assert(not pcall(Opening.stage,list,catalog,5));list[1].upgraded=false
    list[1].cardId="unknown";assert(not pcall(Opening.stage,list,catalog,5));list[1].cardId="opening_1"
    for _,size in ipairs({-1,0.5,0/0,math.huge,"5"}) do assert(not pcall(Opening.stage,list,catalog,size)) end
    catalog.opening_1.isInnate=true;assert(not pcall(Opening.stage,list,catalog,5))
end)
print("OPENING_HAND_PASS "..count)
