package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Combat=require("abyss_combat")
local ExhaustCards=require("abyss_warrior_exhaust_cards")
local Retained=require("abyss_retained_cards")
local Watcher=require("abyss_watcher_cards")
local Data=require("abyss_data")
-- Source319009: DiscardAtEndOfTurnAction TOP-pushes Restore, auto-all
-- DiscardAction, then Ethereal ExhaustSpecific (last pushed, first executed).
-- DiscardAction SHA256 8c711be291822386b64fe0a6c9bc55b920b7a09122fb55f09184b6ca96063c10
local count=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();count=count+1;print("ok end_turn_discard_order "..count.." - "..name) end
local function prepared()
    local d=ExhaustCards.withCards(Retained.withCards(Watcher.withFoundationCards(Data)))
    -- An arithmetic boundary fixture, not a claimed new playable source card.
    d.cards.cards[#d.cards.cards+1]={id="ordinary_high_skill",name="费用边界夹具",type="skill",rarity="special",cost=20,
        effects={{op="block",value=1}}}
    return d
end
local function battle(deck)
    return Combat.new(prepared(),{seed=42,enemies={"cultist"},enableStances=true,deck=deck})
end
local function find(pile,id)
    for _,card in ipairs(pile) do if card.cardId==id then return card end end
    error("missing "..id)
end
local function has(pile,uid)
    for _,card in ipairs(pile) do if card.uid==uid then return card end end
end
local function event(s,kind,after)
    for i=(after or 0)+1,#s.events do if s.events[i].kind==kind then return s.events[i],i end end
    error("missing event "..kind)
end
test("single Ethereal hand hook lowers ordinary high-cost skill before auto discard",function()
    local s=battle({"corruption","ordinary_high_skill","dazed"})
    local high=find(s.hand,"ordinary_high_skill")
    assert(Combat.play(s,find(s.hand,"corruption").uid))
    eq(high.combatCost,11);eq(high.turnCost,11)
    local before=#s.events
    assert(Combat.endTurn(s))
    -- Source: Ethereal move sees the still-held skill and applies another -9;
    -- later ordinary discard moves that 2-cost card, then real draw sets turn0.
    eq(high.combatCost,2);eq(high.turnCost,0)
    local exhausted=event(s,"exhaust",before)
    local inHand=assert(has(exhausted.frame.hand,high.uid))
    eq(inHand.combatCost,2);eq(#exhausted.frame.discard,0)
end)
test("retained instances leave hand before Ethereal, ordinary discard precedes Restore",function()
    local s=battle({"corruption","ordinary_high_skill","dazed","protect","sands_of_time"})
    local high=find(s.hand,"ordinary_high_skill")
    local protect=find(s.hand,"protect");local sands=find(s.hand,"sands_of_time")
    assert(Combat.play(s,find(s.hand,"corruption").uid))
    local before=#s.events;assert(Combat.endTurn(s))
    local exhausted,ei=event(s,"exhaust",before)
    local restored,ri=event(s,"retain",before)
    local cost,ci=event(s,"retained_cost",before)
    local enemy,mi=event(s,"enemy_turn",before)
    assert(ei<ri and ri<ci and ci<mi)
    assert(has(exhausted.frame.hand,high.uid));eq(has(exhausted.frame.hand,protect.uid),nil)
    eq(has(exhausted.frame.hand,sands.uid),nil);eq(#exhausted.frame.discard,0)
    eq(assert(has(restored.frame.discard,high.uid)).combatCost,2)
    assert(has(restored.frame.hand,protect.uid) and has(restored.frame.hand,sands.uid))
    eq(assert(has(cost.frame.hand,sands.uid)).combatCost,3)
    eq(assert(has(enemy.frame.hand,sands.uid)).combatCost,3)
end)
test("nonadvanced automatic discard takes hand tail without manual discard hooks",function()
    local s=battle({"strike","defend","bash"})
    local original={};for i,card in ipairs(s.hand) do original[i]=card.uid end
    local before=#s.events;assert(Combat.endTurn(s))
    local enemy=event(s,"enemy_turn",before)
    eq(#enemy.frame.discard,3)
    for i=1,3 do eq(enemy.frame.discard[i].uid,original[4-i]) end
    for i=before+1,#s.events do assert(s.events[i].kind~="manual_discard") end
end)
test("NoDraw removal precedes Ethereal and permits the later real Dark Embrace draw",function()
    local s=battle({"dark_embrace","battle_trance","dazed","protect","sands_of_time"})
    assert(Combat.play(s,find(s.hand,"dark_embrace").uid))
    local trance=find(s.hand,"battle_trance").uid
    assert(Combat.play(s,trance));eq(s.player.noDraw,true)
    local before=#s.events;assert(Combat.endTurn(s))
    local removed,ni=event(s,"no_draw_removed",before)
    local exhausted,ei=event(s,"exhaust",before)
    local restored,ri=event(s,"retain",before)
    local cost,ci=event(s,"retained_cost",before)
    assert(ni<ei and ei<ri and ri<ci)
    eq(removed.frame.player.noDraw,false);eq(exhausted.frame.player.noDraw,false)
    eq(#restored.frame.hand,2)
    assert(has(cost.frame.hand,trance),"Dark Embrace should really draw the discarded Battle Trance")
    eq(#cost.frame.hand,3)
end)
print("END_TURN_DISCARD_ORDER_PASS "..count)
