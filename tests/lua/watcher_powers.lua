package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Cards=require("abyss_watcher_cards")
local Stances=require("abyss_stances")
local Combat=require("abyss_combat")
local Data=require("abyss_data")
-- Fixed source: aeubanks/sts@319009d5. Data independently authored from rules.
-- cards/purple/Rushdown.java SHA256 fda5c51ee80682511c1be218023ac51897af49cb97bad38bcd2c7780a579a480
-- cards/purple/MentalFortress.java SHA256 4d465fe000e233c67c2902ee6f6c2cd2b36f2e0691b017ba09d54915df7697b5
-- cards/purple/InnerPeace.java SHA256 34289877ff9e35d719318fa9a7c2e045f591dea82227f374984bd8d8c121ae4c
-- powers/watcher/RushdownPower.java SHA256 a52faa11af8665a1e1e41be69f84ea589b186e2eb8d46bf2fc5c89f00483e28d
-- powers/watcher/MentalFortressPower.java SHA256 1561c52d6e2a9e323d2f97bc436b517447207f9e1948de94c5905625ab52d7d8
-- actions/watcher/InnerPeaceAction.java SHA256 e03e2f90845e777588b0b728a3fbec39d47175b9d6fcb72752f96760e5028185
local count=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn(); count=count+1; print("ok watcher_powers "..count.." - "..name) end
local function battle(deck)
    local s=Combat.new(Cards.withFoundationCards(Data),{seed=42,enemies={"cultist"},enableStances=true,deck=deck})
    s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;s.energy=20
    return s
end
local function uid(s,id)
    for _,c in ipairs(s.hand) do if c.cardId==id then return c.uid end end
    error("missing hand card "..id)
end
test("Rushdown cost upgrade changes price but preserves draw amount",function()
    for _,up in ipairs({false,true}) do
        local s=battle({{cardId="rushdown",upgraded=up}})
        assert(Combat.play(s,uid(s,"rushdown")))
        eq(s.energy,up and 20 or 19);eq(s.player.statuses.rushdown,2)
        eq(#s.stancePowerOrder,1);eq(s.stancePowerOrder[1],"rushdown")
        eq(#s.hand+#s.draw+#s.discard+#s.exhaust,0)
    end
end)
test("Mental Fortress applies and stacks 4 or 6 without duplicate order",function()
    local s=battle({{cardId="mental_fortress"},{cardId="mental_fortress",upgraded=true},"inner_peace"})
    assert(Combat.play(s,uid(s,"mental_fortress")));eq(s.player.statuses.mental_fortress,4)
    assert(Combat.play(s,uid(s,"mental_fortress")));eq(s.player.statuses.mental_fortress,10)
    eq(#s.stancePowerOrder,1)
    s.player.statuses.dexterity=9;s.player.statuses.frail=2
    assert(Combat.play(s,uid(s,"inner_peace")));eq(s.player.block,10)
end)
test("power hook queue honors both acquisition orders before stance energy",function()
    for _,reverse in ipairs({false,true}) do
        local s=battle({"rushdown","mental_fortress"})
        local first=reverse and "mental_fortress" or "rushdown"
        local second=reverse and "rushdown" or "mental_fortress"
        assert(Combat.play(s,uid(s,first)));assert(Combat.play(s,uid(s,second)))
        Stances.change(s,"Calm");Stances.flush(s,Combat)
        Stances.change(s,"Wrath",{violetLotus=true})
        eq(s.stanceQueue[1].reason,first);eq(s.stanceQueue[2].reason,second)
        eq(s.stanceQueue[3].reason,"violet_lotus");eq(s.stanceQueue[4].reason,"calm_exit")
        local before=s.energy;Stances.flush(s,Combat);eq(s.energy,before+3)
    end
end)
test("same stance neither draws nor blocks; entering Calm only blocks",function()
    local s=battle({"rushdown","mental_fortress"})
    assert(Combat.play(s,uid(s,"rushdown")));assert(Combat.play(s,uid(s,"mental_fortress")))
    Stances.change(s,"Calm");Stances.flush(s,Combat);eq(s.player.block,4)
    eq(Stances.change(s,"Calm"),false);eq(Stances.flush(s,Combat),0);eq(s.player.block,4)
end)
test("Inner Peace while Neutral enters Calm without drawing",function()
    for _,up in ipairs({false,true}) do
        local s=battle({{cardId="inner_peace",upgraded=up},"defend"})
        assert(Combat.play(s,uid(s,"inner_peace")));eq(s.player.stance,"Calm")
        eq(#s.hand,1);eq(s.hand[1].cardId,"defend");eq(s.energy,19)
    end
end)
test("Inner Peace already Calm draws exactly 3 or 4 without stance hooks",function()
    for _,up in ipairs({false,true}) do
        local deck={{cardId="inner_peace",upgraded=up}}
        for i=1,20 do deck[#deck+1]="defend" end
        local s
        -- Select a reproducible seed where the real opening hand has the card.
        for seed=1,100 do
            local candidate=Combat.new(Cards.withFoundationCards(Data),{seed=seed,enemies={"cultist"},enableStances=true,deck=deck})
            for _,c in ipairs(candidate.hand) do if c.cardId=="inner_peace" then s=candidate;break end end
            if s then break end
        end
        assert(s,"no natural opening fixture found")
        Stances.change(s,"Calm");local before=#s.hand;local events=#s.events
        assert(Combat.play(s,uid(s,"inner_peace")))
        eq(#s.hand,before-1+(up and 4 or 3));eq(s.player.stance,"Calm")
        for i=events+1,#s.events do assert(s.events[i].kind~="stance") end
    end
end)
test("Rushdown can draw the triggering Eruption after real card disposal",function()
    local s=Combat.new(Cards.withFoundationCards(Data),{seed=42,enemies={"cultist"},enableStances=true,
        deck={"rushdown",{cardId="eruption",upgraded=true},"inner_peace"}})
    -- Durable enemy fixture bounds ten loops; real initial energy stays three.
    s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
    eq(s.energy,3)
    assert(Combat.play(s,uid(s,"rushdown")))
    eq(s.energy,2)
    for i=1,10 do
        assert(Combat.play(s,uid(s,"inner_peace")));eq(s.player.stance,"Calm")
        assert(Combat.play(s,uid(s,"eruption"),1));eq(s.player.stance,"Wrath")
        eq(s.energy,2);eq(#s.hand,2)
    end
    eq(s.enemies[1].hp,910)
end)
test("failed play restores newly acquired power order and nested queue",function()
    local s=battle({"rushdown","inner_peace"})
    local order={};s.stancePowerOrder=order
    local hand=s.hand;local events=#s.events;local energy=s.energy
    local id=uid(s,"rushdown")
    s.catalog.cards.rushdown.effects[2]={op="gainTemporaryStrength",value=-1}
    assert(not pcall(Combat.play,s,id))
    eq(s.stancePowerOrder,order);eq(#order,0);eq(s.player.statuses.rushdown,nil)
    eq(s.hand,hand);eq(uid(s,"rushdown"),id);eq(#s.events,events);eq(s.energy,energy)
end)
test("terminal damage clears Rushdown hooks without drawing",function()
    local s=battle({"rushdown","eruption"})
    assert(Combat.play(s,uid(s,"rushdown")));s.enemies[1].hp=1
    assert(Combat.play(s,uid(s,"eruption"),1));eq(s.phase,"victory")
    eq(s.player.stance,"Neutral");eq(s.stanceQueue,nil);eq(#s.hand,0)
end)
test("missing combat API refuses power flush without consuming pending queue",function()
    local s=battle({"rushdown"});assert(Combat.play(s,uid(s,"rushdown")))
    Stances.change(s,"Wrath");local queue=s.stanceQueue
    assert(not pcall(Stances.flush,s));eq(s.stanceQueue,queue);eq(#queue,1)
    Stances.flush(s,Combat);eq(s.stanceQueue,nil)
end)
test("unknown duplicate sparse or missing acquisition order fails closed",function()
    local s=battle({"defend"})
    for _,bad in ipairs({{"unknown"},{"rushdown","rushdown"},{[2]="rushdown"}}) do
        s.stancePowerOrder=bad
        assert(not pcall(Stances.change,s,"Wrath"));eq(s.player.stance,"Neutral")
    end
    s.stancePowerOrder=nil;s.player.statuses.rushdown=2
    assert(not pcall(Stances.change,s,"Wrath"));eq(s.player.stance,"Neutral")
end)
test("turn start Divinity exit queues Mental Fortress once",function()
    local s=battle({"mental_fortress"});assert(Combat.play(s,uid(s,"mental_fortress")))
    Stances.change(s,"Divinity");Stances.flush(s,Combat);eq(s.player.block,4)
    Stances.startTurn(s);eq(s.player.stance,"Neutral");eq(s.player.block,4)
    Stances.flush(s,Combat);eq(s.player.block,8)
end)
print("WATCHER_POWERS_PASS "..count)
