package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Silent, Discard = require("abyss_combat"), require("abyss_silent"), require("abyss_discard")
local data = require("abyss_data")
local count = 0
local function eq(a,b,label) assert(a==b,(label or "value")..": "..tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();count=count+1;print("ok silent expansion "..count.." - "..name) end
local function fresh(id,upgraded,enemies)
    local deck={{cardId=id,upgraded=upgraded}}
    for _=1,12 do deck[#deck+1]="defend" end
    local s=Combat.new(Silent.withFoundationCards(data),{deck=deck,enemies=enemies or {"jaw_worm"},seed=42})
    local card
    for _,c in ipairs(s.hand) do if c.cardId==id then card=c end end
    if not card then
        for i,c in ipairs(s.draw) do
            if c.cardId==id then s.draw[i],s.hand[1]=s.hand[1],c;card=c;break end
        end
    end
    for _,enemy in ipairs(s.enemies) do enemy.hp=300;enemy.maxHp=300 end
    return s,assert(card)
end
local function chooseDefends(s)
    if not s.pendingDiscard then return end
    local uids={}
    for _,c in ipairs(s.hand) do
        if c.cardId=="defend" and #uids<s.pendingDiscard.count then uids[#uids+1]=c.uid end
    end
    assert(Combat.chooseDiscard(s,uids,s.pendingDiscard.token))
end

for _,upgraded in ipairs({false,true}) do
    test("Footwork power grants persistent Dexterity before later real Defend "..tostring(upgraded),function()
        local s,card=fresh("footwork",upgraded)
        local energy=s.energy
        assert(Combat.play(s,card.uid));eq(s.energy,energy-1)
        eq(s.player.statuses.dexterity,upgraded and 3 or 2)
        eq(#s.discard,0);eq(#s.exhaust,0);eq(#s.hand,4)
        assert(Combat.play(s,s.hand[1].uid));eq(s.player.block,upgraded and 8 or 7)
        eq(Combat.play(s,card.uid),false)
    end)
    test("Backflip grants block then draws exactly two "..tostring(upgraded),function()
        local s,card=fresh("backflip",upgraded)
        local hand,draw,energy=#s.hand,#s.draw,s.energy
        assert(Combat.play(s,card.uid));eq(s.player.block,upgraded and 8 or 5)
        eq(s.energy,energy-1);eq(#s.hand,hand-1+2);eq(#s.draw,draw-2)
        local found=false
        for _,e in ipairs(s.events) do
            if e.kind=="block" then found=true;eq(#e.frame.hand,hand-1) end
        end
        assert(found,"block must be observed before subsequent draw")
    end)
    test("Dagger Throw damages then draws before mandatory discard "..tostring(upgraded),function()
        local s,card=fresh("dagger_throw",upgraded)
        local hand,draw,energy=#s.hand,#s.draw,s.energy
        local expectedDrawn=s.draw[#s.draw]
        assert(Combat.play(s,card.uid,1));eq(s.enemies[1].hp,300-(upgraded and 12 or 9))
        eq(s.energy,energy-1);eq(#s.draw,draw-1);eq(#s.hand,hand)
        assert(s.pendingDiscard);eq(s.pendingDiscard.count,1)
        local included=false
        for _,uid in ipairs(s.pendingDiscard.handUids) do if uid==expectedDrawn.uid then included=true end end
        assert(included,"newly drawn card must be selectable")
        eq(Combat.endTurn(s),false);chooseDefends(s)
        eq(#s.hand,hand-1);eq(s.pendingDiscard,nil)
    end)
    test("Dagger Spray performs two separate hits on every enemy "..tostring(upgraded),function()
        local s,card=fresh("dagger_spray",upgraded,{"jaw_worm","jaw_worm"})
        local energy=s.energy;local damage=upgraded and 6 or 4
        s.enemies[1].block=3
        assert(Combat.play(s,card.uid));eq(s.energy,energy-1)
        eq(s.enemies[1].hp,300-(2*damage-3));eq(s.enemies[2].hp,300-2*damage)
        local hits={}
        for _,e in ipairs(s.events) do
            if e.kind=="damage" and e.detail.source==s.player.id then hits[#hits+1]=e.detail.target end
        end
        eq(#hits,4);eq(hits[1],s.enemies[1].id);eq(hits[2],s.enemies[2].id)
        eq(hits[3],s.enemies[1].id);eq(hits[4],s.enemies[2].id)
    end)
    test("Cloak and Dagger grants six block and creates basic Shivs "..tostring(upgraded),function()
        local s,card=fresh("cloak_and_dagger",upgraded)
        local energy=s.energy;assert(Combat.play(s,card.uid));eq(s.energy,energy-1)
        eq(s.player.block,6)
        local shivs={}
        for _,c in ipairs(s.hand) do if c.cardId=="shiv" then shivs[#shivs+1]=c;eq(c.upgraded,false) end end
        eq(#shivs,upgraded and 2 or 1)
        local hp=s.enemies[1].hp;assert(Combat.play(s,shivs[1].uid,1))
        eq(s.enemies[1].hp,hp-4);eq(#s.exhaust,1)
        for _,e in ipairs(s.events) do
            if e.kind=="silent_generate" then eq(e.frame.player.block,6) end
        end
    end)
    test("Prepared zero cost draws and discards equal upgraded count "..tostring(upgraded),function()
        local s,card=fresh("prepared",upgraded)
        local hand,draw,energy=#s.hand,#s.draw,s.energy
        local n=upgraded and 2 or 1
        assert(Combat.play(s,card.uid));eq(s.energy,energy)
        eq(#s.hand,hand-1+n);eq(#s.draw,draw-n);eq(s.pendingDiscard.count,n)
        chooseDefends(s);eq(#s.hand,hand-1);eq(#s.discard,1+n)
    end)
    test("Quick Slash damages then draws one "..tostring(upgraded),function()
        local s,card=fresh("quick_slash",upgraded)
        local hand,draw,energy=#s.hand,#s.draw,s.energy
        assert(Combat.play(s,card.uid,1));eq(s.enemies[1].hp,300-(upgraded and 12 or 8))
        eq(#s.hand,hand);eq(#s.draw,draw-1);eq(s.energy,energy-1)
    end)
end
test("Dagger Throw final kill cancels draw and discard tail",function()
    local s,card=fresh("dagger_throw",false);s.enemies[1].hp=9
    local draw=#s.draw;assert(Combat.play(s,card.uid,1))
    eq(s.phase,"victory");eq(#s.hand,4);eq(#s.draw,draw);eq(s.pendingDiscard,nil)
end)
test("Quick Slash final kill cancels its draw tail",function()
    local s,card=fresh("quick_slash",true);s.enemies[1].hp=12
    local draw=#s.draw;assert(Combat.play(s,card.uid,1))
    eq(s.phase,"victory");eq(#s.hand,4);eq(#s.draw,draw)
end)
test("upgraded Cloak at full hand overflows one basic Shiv to discard",function()
    local s,card=fresh("cloak_and_dagger",true);Combat.draw(s,5);eq(#s.hand,10)
    assert(Combat.play(s,card.uid));eq(#s.hand,10);eq(#s.discard,2)
    eq(s.discard[1].cardId,"shiv");eq(s.discard[1].upgraded,false)
    eq(s.discard[2],card)
end)
test("Backflip full hand only draws the slot freed by playing",function()
    local s,card=fresh("backflip",false);Combat.draw(s,5);local draw=#s.draw
    assert(Combat.play(s,card.uid));eq(#s.hand,10);eq(#s.draw,draw-1);eq(s.player.block,5)
end)
test("Prepared with NoDraw still performs mandatory discard",function()
    local s,card=fresh("prepared",true);s.player.noDraw=true;local draw=#s.draw
    assert(Combat.play(s,card.uid));eq(#s.draw,draw);eq(s.pendingDiscard.count,2)
    chooseDefends(s);eq(#s.hand,2)
end)
test("invalid target and insufficient energy leave real combat unchanged",function()
    local s,card=fresh("dagger_throw",false);local seed=s.seed;local events=#s.events
    eq(Combat.play(s,card.uid,999),false);eq(#s.hand,5);eq(s.seed,seed);eq(#s.events,events)
    s.energy=0;eq(Combat.play(s,card.uid,1),false);eq(#s.hand,5);eq(s.pendingDiscard,nil)
end)
print("SILENT_EXPANSION_PASS "..count)
