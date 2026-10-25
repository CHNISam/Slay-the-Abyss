package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Silent, Combat = require("abyss_silent"), require("abyss_combat")
local data = require("abyss_data")
local count = 0
local function test(name, fn) fn(); count=count+1; print("ok silent foundation "..count.." - "..name) end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function fresh(deck)
    return Combat.new(Silent.withFoundationCards(data), {deck=deck or {}, enemies={"jaw_worm"}, seed=42})
end

test("registration is detached and duplicate registration fails", function()
    local n=#data.cards.cards
    local extended=Silent.withFoundationCards(data)
    eq(#data.cards.cards,n); eq(#extended.cards.cards,n+18)
    assert(not pcall(Silent.withFoundationCards,extended))
end)
for _, upgraded in ipairs({false,true}) do
    test("real poison card play, cost, Artifact and turn tick "..tostring(upgraded),function()
        local s=fresh({{cardId="deadly_poison",upgraded=upgraded}})
        local uid=s.hand[1].uid
        local energy=s.energy
        assert(Combat.play(s,uid,1)); eq(s.energy,energy-1)
        eq(Combat.play(s,uid,1),false)
        eq(s.enemies[1].statuses.poison,upgraded and 7 or 5)
        local hp=s.enemies[1].hp
        assert(Combat.endTurn(s))
        eq(s.enemies[1].hp,hp-(upgraded and 7 or 5))
        eq(s.enemies[1].statuses.poison,upgraded and 6 or 4)
        s=fresh({{cardId="deadly_poison",upgraded=upgraded}})
        Combat.addStatus(s.enemies[1],"artifact",1)
        assert(Combat.play(s,s.hand[1].uid,1))
        eq(s.enemies[1].statuses.poison or 0,0); eq(s.enemies[1].statuses.artifact,0)
    end)
end
test("lethal poison ends combat before enemy attack",function()
    local s=fresh({"deadly_poison"}); s.enemies[1].hp=5
    assert(Combat.play(s,s.hand[1].uid,1)); local hp=s.player.hp
    assert(Combat.endTurn(s)); eq(s.phase,"victory"); eq(s.player.hp,hp)
end)
for _, upgraded in ipairs({false,true}) do
    test("generated Shiv uses Combat play and exhaust "..tostring(upgraded),function()
        local s=fresh(); local ids=Silent.generateShivs(s,3,upgraded)
        local hp=s.enemies[1].hp; local energy=s.energy
        assert(Combat.play(s,ids[1],1)); eq(s.enemies[1].hp,hp-(upgraded and 6 or 4))
        eq(s.energy,energy); eq(#s.exhaust,1); eq(s.exhaust[1].uid,ids[1])
        eq(Combat.play(s,ids[1],1),false)
        assert(ids[1]~=ids[2] and ids[2]~=ids[3])
    end)
end
test("one hand slot sends remaining generated cards to discard",function()
    local s=fresh(); Silent.generateShivs(s,9)
    local ids=Silent.generateShivs(s,4)
    eq(#s.hand,10); eq(#s.discard,3); eq(s.hand[10].uid,ids[1]); eq(s.discard[1].uid,ids[2])
    eq(#s.exhaust,0)
end)
test("full hand routes all generation to discard without replacing cards",function()
    local s=fresh(); Silent.generateShivs(s,10); local first=s.hand[1]
    Silent.generateShivs(s,3); eq(#s.hand,10); eq(#s.discard,3); eq(s.hand[1],first)
end)
test("invalid generation is rejected before pile, event or UID mutation",function()
    -- More than ten is legal generation; excess cards go to discard.
    for _,value in ipairs({-1,1.5,2147483648,"3"}) do
        local s=fresh();local uid,events=s.nextUid,#s.events
        assert(not pcall(Silent.generateShivs,s,value))
        eq(s.nextUid,uid);eq(#s.events,events);eq(#s.hand,0);eq(#s.discard,0)
    end
    local s=fresh(); Silent.generateShivs(s,1);s.nextUid=s.hand[1].uid
    assert(not pcall(Silent.generateShivs,s,1));eq(#s.hand,1)
    s=fresh(); s.phase="victory";assert(not pcall(Silent.generateShivs,s,1))
    s=fresh();s.player.statuses.master_reality=1;assert(not pcall(Silent.generateShivs,s,1));eq(#s.hand,0)
end)
test("zero generation is a no-op and temporary cards stay out of source deck",function()
    local deck={"defend"};local s=fresh(deck);local uid,events=s.nextUid,#s.events
    eq(#Silent.generateShivs(s,0),0);eq(s.nextUid,uid);eq(#s.events,events)
    Silent.generateShivs(s,3);eq(#deck,1);eq(deck[1],"defend")
end)
print("SILENT_FOUNDATION_PASS "..count)
