package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Combat=require("abyss_combat")
local Warrior=require("abyss_warrior_cards")
local ExhaustCards=require("abyss_warrior_exhaust_cards")
local HandChoice=require("abyss_hand_choice")
local Discard=require("abyss_discard")
local Data=require("abyss_data")
local n=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();n=n+1;print("ok corruption_cost_integration "..n.." - "..name) end
local function fixtureData(energy)
    local d=ExhaustCards.withCards(Warrior.withFoundationCards(Data))
    -- Synthetic typed boundary card: no source card costs twenty. Its sole
    -- ordinary block effect uses the real effect dispatcher, never a mock.
    d.cards.cards[#d.cards.cards+1]={id="corruption_cost_probe",name="费用边界探针",type="skill",color="red",
        rarity="common",cost=20,effects={{op="block",value=1}}}
    if energy then d.rules.player.energyPerTurn=energy end
    return d
end
local function setup(deck,energy)
    return Combat.new(fixtureData(energy),{seed=42,cardRandomSeed="42",enemies={"cultist"},deck=deck})
end
local function held(s,id)
    for _,c in ipairs(s.hand) do if c.cardId==id then return c end end
    error("fixture opening card unavailable: "..id)
end
local function play(s,id,target)
    local ok,why=Combat.play(s,held(s,id).uid,target);assert(ok,why)
end
local function freeze(value)
    local saved,queue={}, {value}
    while #queue>0 do
        local t=table.remove(queue)
        if not saved[t] then
            local entries={};saved[t]=entries
            for k,v in pairs(t) do entries[k]=v;if type(v)=="table" then queue[#queue+1]=v end end
        end
    end
    return function()
        for t,entries in pairs(saved) do
            for k,v in pairs(entries) do eq(t[k],v) end
            for k,v in pairs(t) do eq(entries[k],v) end
        end
    end
end
local probe="corruption_cost_probe"
for _,up in ipairs({false,true}) do
    test("Corruption Power disposal never adds a hand hook after its constructor "..tostring(up),function()
        local s=setup({{cardId="corruption",upgraded=up},probe})
        local c=held(s,probe)
        play(s,"corruption")
        eq(c.combatCost,11);eq(c.turnCost,11);eq(Combat.cardDefinition(s,c).cost,11)
        eq(s.energy,up and 1 or 0);eq(s.player.statuses.corruption,1)
        eq(#s.discard,0);eq(#s.exhaust,0);eq(s.cardInUse,nil)
    end)
end
test("ordinary immediate attack discard runs one hook on the remaining hand",function()
    local s=setup({{cardId="corruption",upgraded=true},probe,"strike"})
    local c=held(s,probe);play(s,"corruption");eq(c.combatCost,11)
    local attack=held(s,"strike");play(s,"strike",1)
    eq(c.combatCost,2);eq(c.turnCost,2);eq(s.discard[1],attack);eq(s.energy,0)
    eq(s.pendingPlay,nil);eq(s.actionQueue,nil)
end)
test("corrupted skill self-exhaust runs exactly one move hook",function()
    local s=setup({"corruption",probe,"defend"})
    local c=held(s,probe);local defend=held(s,"defend")
    play(s,"corruption");eq(c.combatCost,11);eq(Combat.cardDefinition(s,defend).cost,0)
    play(s,"defend")
    eq(c.combatCost,2);eq(c.turnCost,2);eq(s.exhaust[1],defend);eq(s.player.block,5);eq(s.energy,0)
end)
test("hand put-on-top does not run a discard or exhaust hook",function()
    local s=setup({"corruption",probe,"strike"})
    local c=held(s,probe);play(s,"corruption");eq(c.combatCost,11)
    local attack=held(s,"strike")
    eq(HandChoice.begin(s,"put_on_deck",1),"pause")
    assert(HandChoice.choose(s,{attack.uid},s.pendingHandChoice.token))
    eq(s.draw[#s.draw],attack);eq(c.combatCost,11);eq(c.turnCost,11);eq(#s.discard,0);eq(#s.exhaust,0)
end)
test("manual discard runs a hand hook once per moved card",function()
    local s=setup({"corruption",probe,"strike","strike"})
    local c=held(s,probe);play(s,"corruption");eq(c.combatCost,11)
    local selected={};for _,card in ipairs(s.hand) do if card.cardId=="strike" then selected[#selected+1]=card.uid end end
    assert(Discard.begin(s,2));assert(s.pendingDiscard)
    assert(Discard.choose(s,{selected[2],selected[1]},s.pendingDiscard.token,Combat))
    eq(c.combatCost,0);eq(c.turnCost,0);eq(s.discard[1].uid,selected[2]);eq(s.discard[2].uid,selected[1])
    eq(#s.hand,1);eq(s.hand[1],c);eq(s.discardedThisTurn,2)
end)
for _,probeOnTop in ipairs({false,true}) do
    test("ordinary end-turn discard moves actual hand top before each hook; probeOnTop="..tostring(probeOnTop),function()
        local s=setup({"corruption",probe,"strike","strike"})
        local c=held(s,probe);play(s,"corruption");eq(c.combatCost,11)
        local attacks={};for _,card in ipairs(s.hand) do if card.cardId=="strike" then attacks[#attacks+1]=card end end
        -- Reorder only existing real UIDs to compare the source auto-all
        -- getTopCard path. This is a pile-position fixture, not acquisition.
        s.hand=probeOnTop and {attacks[1],attacks[2],c} or {c,attacks[1],attacks[2]}
        assert(Combat.endTurn(s));eq(s.phase,"player")
        -- Probe top: it leaves hand before either later hook, keeping 11.
        -- Probe bottom: two preceding Strike moves reduce 11 -> 2 -> 0.
        eq(c.combatCost,probeOnTop and 11 or 0)
        eq(s.player.statuses.corruption,1);eq(s.turn,2)
    end)
end
test("positive energy threshold remains strict while actual corrupted skill payment is free",function()
    -- Controlled initial energy via fixture rules avoids editing energy during
    -- a command and does not claim the original starter grants 13/14 energy.
    local low=setup({"corruption",probe},13)
    local c=held(low,probe);play(low,"corruption");eq(low.energy,10);eq(Combat.cardDefinition(low,c).cost,11)
    local unchanged=freeze(low)
    local ok,why=Combat.canPlay(low,c.uid);eq(ok,false);eq(why,"insufficient_energy")
    ok,why=Combat.play(low,c.uid);eq(ok,false);eq(why,"insufficient_energy");unchanged()
    local enough=setup({"corruption",probe},14)
    c=held(enough,probe);play(enough,"corruption");eq(enough.energy,11);eq(Combat.cardDefinition(enough,c).cost,11)
    assert(Combat.canPlay(enough,c.uid));play(enough,probe)
    eq(enough.energy,11);eq(enough.player.block,1);eq(enough.exhaust[1],c)
end)
print("CORRUPTION_COST_INTEGRATION_PASS "..n)
