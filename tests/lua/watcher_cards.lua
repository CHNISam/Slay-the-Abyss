package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Cards=require("abyss_watcher_cards")
local Combat=require("abyss_combat")
local Stances=require("abyss_stances")
local Data=require("abyss_data")
local Capability=require("abyss_card_capability")
local count=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn(); count=count+1; print("ok watcher_cards "..count.." - "..name) end
local function battle(id,upgraded)
    local s=Combat.new(Cards.withFoundationCards(Data),{seed=42,enemies={"cultist"},enableStances=true,deck={{cardId=id,upgraded=upgraded}}})
    s.enemies[1].hp=200; s.enemies[1].maxHp=200; s.energy=10
    return s,s.hand[1].uid
end
test("opt-in data preserves base source and returns detached definitions",function()
    local n=#Data.cards.cards; local d=Cards.withFoundationCards(Data)
    eq(#Data.cards.cards,n); eq(#d.cards.cards,n+16)
    local function find(source,id)
        for _,card in ipairs(source.cards.cards) do if card.id==id then return card end end
        error("missing card "..id)
    end
    find(d,"tranquility").effects[1].stance="invalid"
    local fresh=Cards.withFoundationCards(Data)
    eq(find(fresh,"tranquility").effects[1].stance,"Calm")
    assert(not pcall(Cards.withFoundationCards,fresh))
end)
test("six base and upgrade definitions pass shared capability",function()
    for _,id in ipairs({"eruption","vigilance","empty_fist","empty_body","crescendo","tranquility"}) do
        for _,up in ipairs({false,true}) do
            local s=battle(id,up); assert(Capability.isImplemented(Combat.cardDefinition(s,s.hand[1])),id)
        end
    end
end)
test("Eruption damage precedes Wrath and upgraded cost changes alone",function()
    for _,up in ipairs({false,true}) do
        local s,uid=battle("eruption",up)
        assert(Combat.play(s,uid,1)); eq(s.enemies[1].hp,191); eq(s.player.stance,"Wrath")
        eq(s.energy,up and 9 or 8)
        eq(Combat.damage(s,s.player,s.enemies[1],3,false),6)
    end
end)
test("Eruption from Calm damages normally then refunds exit energy",function()
    local s,uid=battle("eruption"); Stances.change(s,"Calm")
    assert(Combat.play(s,uid,1)); eq(s.enemies[1].hp,191); eq(s.energy,10)
    eq(s.player.stance,"Wrath")
end)
test("Vigilance base and upgrade grant block before entering Calm",function()
    for _,up in ipairs({false,true}) do
        local s,uid=battle("vigilance",up); assert(Combat.play(s,uid))
        eq(s.player.block,up and 12 or 8); eq(s.player.stance,"Calm"); eq(s.energy,8)
        local block,stance
        for i,e in ipairs(s.events) do
            if e.kind=="block" then block=i end
            if e.kind=="stance" and e.detail.to=="Calm" then stance=i end
        end
        assert(block and stance and block<stance,"block must precede stance")
    end
end)
test("Empty Fist uses old Wrath multiplier then exits",function()
    for _,up in ipairs({false,true}) do
        local s,uid=battle("empty_fist",up); Stances.change(s,"Wrath")
        assert(Combat.play(s,uid,1)); eq(s.enemies[1].hp,up and 172 or 182)
        eq(s.player.stance,"Neutral"); eq(s.energy,9)
    end
end)
test("Empty Body exits Calm after block and restores two energy",function()
    for _,up in ipairs({false,true}) do
        local s,uid=battle("empty_body",up); Stances.change(s,"Calm")
        assert(Combat.play(s,uid)); eq(s.player.block,up and 10 or 7)
        eq(s.player.stance,"Neutral"); eq(s.energy,11)
    end
end)
test("retained transition cards exhaust on use with upgraded zero cost",function()
    for id,stance in pairs({crescendo="Wrath",tranquility="Calm"}) do
        for _,up in ipairs({false,true}) do
            local s,uid=battle(id,up); assert(Combat.play(s,uid))
            eq(s.player.stance,stance); eq(s.energy,up and 10 or 9)
            eq(#s.exhaust,1); eq(s.exhaust[1].uid,uid); eq(#s.discard,0)
        end
    end
end)
test("retained cards keep uid over endTurn and next real draw",function()
    for _,id in ipairs({"crescendo","tranquility"}) do
        local s,uid=battle(id)
        assert(Combat.endTurn(s)); eq(#s.hand,1); eq(s.hand[1].uid,uid)
        eq(#s.discard,0); eq(#s.exhaust,0)
        assert(Combat.play(s,uid)); eq(s.exhaust[1].uid,uid)
    end
end)
test("retained cards occupy the real ten-card hand and stop further draws",function()
    local deck={}
    for i=1,11 do deck[i]="crescendo" end
    local s=Combat.new(Cards.withFoundationCards(Data),{seed=42,enemies={"cultist"},enableStances=true,deck=deck})
    eq(#s.hand,5)
    local original={}; for _,c in ipairs(s.hand) do original[c.uid]=true end
    assert(Combat.endTurn(s)); eq(#s.hand,10); eq(#s.draw,1)
    assert(Combat.endTurn(s)); eq(#s.hand,10); eq(#s.draw,1)
    for _,c in ipairs(s.hand) do original[c.uid]=nil end
    eq(next(original),nil); eq(#s.discard,0)
end)
test("lethal last-enemy hit cancels queued stance change",function()
    local s,uid=battle("eruption"); s.enemies[1].hp=1
    assert(Combat.play(s,uid,1)); eq(s.phase,"victory")
    assert(s.player.stance==nil or s.player.stance=="Neutral")
    eq(s.stanceQueue,nil)
end)
test("insufficient energy does not apply damage or stance",function()
    local s,uid=battle("eruption"); s.energy=1
    local ok,reason=Combat.play(s,uid,1)
    eq(ok,false); eq(reason,"insufficient_energy"); eq(s.enemies[1].hp,200)
    assert(s.player.stance==nil or s.player.stance=="Neutral")
end)
test("overflow after a stance change restores original queue and card references",function()
    local s,uid=battle("empty_body")
    assert(Stances.change(s,"Calm")); Stances.flush(s)
    s.energy=2147483647
    -- A zero-cost valid card exposes the queued +2 overflow after effects.
    s.catalog.cards.empty_body.cost=0
    s.stanceQueue={}
    local queue,hand,card,events=s.stanceQueue,s.hand,s.hand[1],#s.events
    local ok=pcall(Combat.play,s,uid)
    eq(ok,false);eq(s.player.stance,"Calm");eq(s.energy,2147483647)
    eq(s.player.block,0);eq(s.stanceQueue,queue);eq(#queue,0)
    eq(s.hand,hand);eq(s.hand[1],card);eq(#s.events,events);eq(#s.discard,0)
end)
print("WATCHER_CARDS_PASS "..count)
