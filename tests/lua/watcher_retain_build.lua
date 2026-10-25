package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Retained=require("abyss_retained_cards")
local Combat=require("abyss_combat")
local Discard=require("abyss_discard")
local Watcher=require("abyss_watcher_cards")
local Data=require("abyss_data")
local WarriorExhaust=require("abyss_warrior_exhaust_cards")
local count=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();count=count+1;print("ok watcher_retain_build "..count.." - "..name) end
local function prepared() return Retained.withCards(Watcher.withFoundationCards(Data)) end
local function battle(id,up)
    local s=Combat.new(prepared(),{seed=42,enemies={"cultist"},enableStances=true,deck={{cardId=id,upgraded=up}}})
    s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
    return s,s.hand[1]
end
local function adapted(s,instance)
    local card=Combat.copy(s.catalog.cards[instance.cardId])
    if instance.upgraded then for k,v in pairs(card.upgrade or {}) do card[k]=Combat.copy(v) end end
    return Retained.adaptDefinition(s,instance,card)
end
local function composite(deck)
    local s=Combat.new(WarriorExhaust.withCards(prepared()),{seed=42,enemies={"cultist"},enableStances=true,deck=deck})
    s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
    return s
end
local function uid(s,id)
    for _,c in ipairs(s.hand) do if c.cardId==id then return c.uid end end
    error("missing hand card "..id)
end
local function immutable(state)
    local saved,pending={},{state}
    while #pending>0 do
        local t=table.remove(pending)
        if not saved[t] then
            local values={};saved[t]=values
            for k,v in pairs(t) do values[k]=v;if type(v)=="table" then pending[#pending+1]=v end end
        end
    end
    return function()
        for t,values in pairs(saved) do
            for k,v in pairs(values) do eq(t[k],v) end
            for k,v in pairs(t) do eq(values[k],v) end
        end
    end
end
test("four opt-in card definitions preserve source data",function()
    local sourceCount=#Data.cards.cards;local d=prepared();local cards={}
    for _,card in ipairs(d.cards.cards) do cards[card.id]=card end
    for _,spec in ipairs({{"protect",2,12,16},{"perseverance",1,5,7},{"windmill_strike",2,7,10},{"sands_of_time",4,20,26}}) do
        local c=cards[spec[1]];eq(c.cost,spec[2]);eq(c.selfRetain,true)
        eq(c.effects[1].value,spec[3]);eq(c.upgrade.effects[1].value,spec[4])
        assert(c.name:find("[\128-\255]") and c.text and c.upgradeText)
    end
    assert(not pcall(Retained.withCards,d))
    eq(#Data.cards.cards,sourceCount)
    d.cards.cards[1].effects[1].value=999
    assert(Data.cards.cards[1].effects[1].value~=999)
    for _,card in ipairs(Data.cards.cards) do assert(card.id~="perseverance" and card.id~="protect") end
end)
test("Perseverance retains historical unupgraded gains across upgrade",function()
    local s,c=battle("perseverance")
    assert(Retained.onRetained(s,c));eq(c.retainedBlockBonus,2);eq(adapted(s,c).effects[1].value,7)
    eq(Retained.onRetained(s,c),false)
    c.upgraded=true;eq(adapted(s,c).effects[1].value,9)
    s.turn=s.turn+1;assert(Retained.onRetained(s,c))
    eq(c.retainedBlockBonus,5);eq(adapted(s,c).effects[1].value,12)
end)
test("Windmill Strike retains historical damage rather than multiplying count by new rate",function()
    local s,c=battle("windmill_strike")
    assert(Retained.onRetained(s,c));eq(c.retainedDamageBonus,4);eq(adapted(s,c).effects[1].value,11)
    c.upgraded=true;eq(adapted(s,c).effects[1].value,14)
    s.turn=s.turn+1;assert(Retained.onRetained(s,c))
    eq(c.retainedDamageBonus,9);eq(adapted(s,c).effects[1].value,19)
end)
test("Protect retains without inventing a growth effect",function()
    local s,c=battle("protect")
    assert(Retained.onRetained(s,c));eq(c.retainedBlockBonus,nil)
    eq(adapted(s,c).effects[1].value,12)
end)
test("Sands schedules later cost change and never falls below zero",function()
    local s,c=battle("sands_of_time")
    for i=1,6 do
        s.turn=i
        local before=adapted(s,c).cost
        local ok,intent=Retained.onRetained(s,c);assert(ok)
        eq(intent.op,"reduceRetainedCost");eq(intent.uid,c.uid)
        eq(adapted(s,c).cost,before)
        assert(Retained.reduceBaseCost(s,c))
        eq(c.combatCost,math.max(0,4-i));eq(c.turnCost,c.combatCost)
        eq(adapted(s,c).cost,math.max(0,4-i))
    end
    eq(c.retainedCostReduction,4)
end)
test("Sands applies source cost arithmetic to current overrides",function()
    local s,c=battle("sands_of_time")
    c.combatCost=7;c.turnCost=3
    assert(Retained.reduceBaseCost(s,c));eq(c.combatCost,2);eq(c.turnCost,2)
    c.combatCost=4;c.turnCost=0
    assert(Retained.reduceBaseCost(s,c));eq(c.combatCost,3);eq(c.turnCost,0)
    -- Adapter's base does not re-subtract from shared combatCost; the generic
    -- host applies these explicit overrides LAST, so the source result is 3/0.
    eq(adapted(s,c).cost,2);eq(c.combatCost,3);eq(c.turnCost,0)
end)
test("actual used and manually discarded cards do not grow",function()
    local used,card=battle("perseverance")
    assert(Combat.play(used,card.uid));eq(Retained.onRetained(used,card),false)
    eq(card.retainedBlockBonus,nil)
    local discarded,other=battle("windmill_strike")
    assert(Discard.manualDiscard(discarded,other.uid,Combat))
    eq(Retained.onRetained(discarded,other),false);eq(other.retainedDamageBonus,nil)
end)
test("already exhausted cards do not grow and current retain+ethereal compound refuses",function()
    local s,c=battle("perseverance")
    s.hand={};s.exhaust={c};eq(Retained.onRetained(s,c),false);eq(c.retainedBlockBonus,nil)
    s.exhaust={};s.hand={c};s.catalog.cards.perseverance.ethereal=true
    local ok,reason=pcall(Retained.onRetained,s,c)
    eq(ok,false);assert(tostring(reason):find("unsupported_currentcompound",1,true));eq(c.retainedBlockBonus,nil)
end)
test("limbo restoration is supported but dead player cannot retain-grow",function()
    local s,c=battle("windmill_strike")
    s.hand={};s.retainedCards={c}
    assert(Retained.onRetained(s,c));eq(c.retainedDamageBonus,4)
    s.turn=s.turn+1;s.player.hp=0
    eq(Retained.onRetained(s,c),false);eq(c.retainedDamageBonus,4)
end)
test("Corruption does not block retain growth; Establishment remains explicitly unsupported",function()
    local s,c=battle("perseverance");s.player.statuses.corruption=1
    assert(Retained.onRetained(s,c));eq(c.retainedBlockBonus,2)
    local a,attack=battle("windmill_strike");a.player.statuses.corruption=1
    assert(Retained.onRetained(a,attack));eq(attack.retainedDamageBonus,4)
    a.turn=a.turn+1;a.player.statuses.establishment=1
    local ok,reason=pcall(Retained.onRetained,a,attack)
    eq(ok,false);assert(tostring(reason):find("unsupported_retained_establishment",1,true))
end)
test("malformed instance values and overflow fail before any growth",function()
    local s,c=battle("perseverance")
    c.retainedBlockBonus=2147483647
    assert(not pcall(Retained.onRetained,s,c));eq(c.retainedBlockBonus,2147483647);eq(c.retainedTurn,nil)
    c.retainedBlockBonus=-1;assert(not pcall(Retained.onRetained,s,c))
    c.retainedBlockBonus=nil;c.turnCost=0.5;assert(not pcall(Retained.onRetained,s,c));eq(c.retainedTurn,nil)
end)
test("new battle constructs fresh instances without combat growth or cost persistence",function()
    local s,c=battle("windmill_strike",true);Retained.onRetained(s,c)
    local nextBattle,fresh=battle("windmill_strike",true)
    eq(fresh.retainedDamageBonus,nil);eq(fresh.retainedTurn,nil);eq(adapted(nextBattle,fresh).effects[1].value,10)
    local sands,old=battle("sands_of_time");Retained.onRetained(sands,old);Retained.reduceBaseCost(sands,old)
    local freshState,new=battle("sands_of_time");eq(new.combatCost,nil);eq(new.turnCost,nil);eq(adapted(freshState,new).cost,4)
end)
print("WATCHER_RETAIN_MODULE_PASS "..count)

-- Real shared entrypoints below remain red until the host connects the new
-- retention callback, delayed cost action, and definition/cost adapters.
test("real endTurn grows Perseverance and real play consumes its current value",function()
    for _,up in ipairs({false,true}) do
        local s,c=battle("perseverance",up)
        assert(Combat.endTurn(s))
        eq(Combat.cardDefinition(s,c).effects[1].value,up and 10 or 7)
        assert(Combat.play(s,c.uid));eq(s.player.block,up and 10 or 7)
    end
end)
test("real endTurn grows Windmill damage before a real attack",function()
    local s,c=battle("windmill_strike")
    assert(Combat.endTurn(s));eq(Combat.cardDefinition(s,c).effects[1].value,11)
    local before=s.enemies[1].hp;assert(Combat.play(s,c.uid,1));eq(s.enemies[1].hp,before-11)
end)
test("real endTurn reduces Sands cost then shared play pays that cost",function()
    local s,c=battle("sands_of_time")
    assert(Combat.endTurn(s));eq(Combat.cardDefinition(s,c).cost,3)
    eq(s.energy,3);assert(Combat.play(s,c.uid,1));eq(s.energy,0)
    eq(s.enemies[1].hp,980)
end)
test("real retained growth and delayed cost reduction finish before enemy actions",function()
    local s=Combat.new(prepared(),{seed=42,enemies={"cultist"},enableStances=true,deck={"windmill_strike","sands_of_time"}})
    local wind,sands
    for _,c in ipairs(s.hand) do if c.cardId=="windmill_strike" then wind=c else sands=c end end
    assert(Combat.endTurn(s))
    local retained,cost,enemy
    for i,e in ipairs(s.events) do
        if e.kind=="retain" then retained=i elseif e.kind=="retained_cost" then cost=i elseif e.kind=="enemy_turn" then enemy=i end
    end
    assert(retained and cost and enemy and retained<cost and cost<enemy)
    local function find(frame,id)
        for _,card in ipairs(frame.hand) do if card.uid==id then return card end end
        error("retained instance missing from phase frame")
    end
    eq(find(s.events[retained].frame,wind.uid).retainedDamageBonus,4)
    eq(find(s.events[retained].frame,sands.uid).combatCost,nil)
    eq(find(s.events[cost].frame,sands.uid).combatCost,3)
    eq(find(s.events[enemy].frame,sands.uid).combatCost,3)
end)
test("real retain occupies all ten slots and stops the next draw",function()
    local deck={};for i=1,11 do deck[i]="protect" end
    local s=Combat.new(prepared(),{seed=42,enemies={"cultist"},enableStances=true,deck=deck})
    assert(Combat.endTurn(s));eq(#s.hand,10);eq(#s.draw,1)
    local refs={};for _,card in ipairs(s.hand) do refs[card.uid]=card end
    assert(Combat.endTurn(s));eq(#s.hand,10);eq(#s.draw,1)
    for _,card in ipairs(s.hand) do eq(refs[card.uid],card) end
    eq(#s.discard,0);eq(#s.exhaust,0)
end)
test("late retain growth failure rolls back earlier retained instances and complete end turn",function()
    local s=Combat.new(prepared(),{seed=42,enemies={"cultist"},enableStances=true,deck={"perseverance","windmill_strike"}})
    local first,second
    for _,c in ipairs(s.hand) do if c.cardId=="perseverance" then first=c else second=c end end
    -- Preserve actual instances, arrange deterministic callback order. Both
    -- pre-turn definitions remain valid; the SECOND growth overflows its value.
    s.hand[1],s.hand[2]=first,second
    second.retainedDamageBonus=2147483640
    eq(Combat.cardDefinition(s,second).effects[1].value,2147483647)
    local unchanged=immutable(s)
    local ok,reason=pcall(Combat.endTurn,s)
    eq(ok,false);assert(tostring(reason):find("retained card value overflow",1,true))
    unchanged();eq(first.retainedBlockBonus,nil);eq(second.retainedTurn,nil)
end)
test("Corruption and both retained skills compose through real turn and skill use",function()
    local s=composite({"corruption","protect","perseverance"})
    local protect,perseverance=uid(s,"protect"),uid(s,"perseverance")
    assert(Combat.play(s,uid(s,"corruption")));eq(s.energy,0)
    assert(Combat.endTurn(s));eq(s.player.statuses.corruption,1)
    local per
    for _,c in ipairs(s.hand) do if c.uid==perseverance then per=c end end
    eq(Combat.cardDefinition(s,per).effects[1].value,7)
    local energy=s.energy
    assert(Combat.play(s,protect));eq(s.energy,energy);eq(s.exhaust[1].uid,protect)
    assert(Combat.play(s,perseverance));eq(s.energy,energy);eq(s.exhaust[2].uid,perseverance)
    eq(s.player.block,19);eq(#s.discard,0)
end)
test("full-hand restore does not invent a Corruption hand hook or erase the source energy gate",function()
    local s=composite({"corruption"})
    assert(Combat.play(s,uid(s,"corruption")))
    -- Controlled source lifecycle: cards newly introduced to DRAW after the
    -- constructor scan retain their printed combat base. Real draw applies
    -- zero turn cost, then the hand hook skips that already-zero turn cost.
    for i=1,10 do
        s.draw[#s.draw+1]={uid=s.nextUid,cardId="protect",upgraded=false};s.nextUid=s.nextUid+1
    end
    Combat.draw(s,10);eq(#s.hand,10)
    for _,c in ipairs(s.hand) do eq(c.combatCost,nil);eq(c.turnCost,0) end
    assert(Combat.endTurn(s));eq(#s.hand,10)
    for _,c in ipairs(s.hand) do eq(c.combatCost,nil);eq(c.turnCost,nil);eq(Combat.cardDefinition(s,c).cost,2) end
    local target=s.hand[1].uid
    s.energy=1;local unchanged=immutable(s)
    local ok,reason=Combat.play(s,target)
    eq(ok,false);eq(reason,"insufficient_energy");unchanged()
    s.energy=2
    assert(Combat.play(s,target));eq(s.energy,2);eq(s.exhaust[1].uid,target)
    -- Source exhaust calls onCardDrawOrDiscard, so the remaining hand now
    -- really does receive the persisted zero-cost change.
    for _,c in ipairs(s.hand) do eq(c.combatCost,0);eq(c.turnCost,0) end
end)
test("ordinary ethereal exhaust restores retained cards before Dark Embrace tail draw",function()
    local s=composite({"dark_embrace","sands_of_time","perseverance","dazed","defend"})
    assert(Combat.play(s,uid(s,"dark_embrace")))
    assert(Combat.endTurn(s));eq(#s.exhaust,1);eq(s.exhaust[1].cardId,"dazed")
    local retained,cost
    for _,e in ipairs(s.events) do
        if e.kind=="retain" then retained=e.frame elseif e.kind=="retained_cost" then cost=e.frame end
    end
    assert(retained and cost)
    eq(#retained.hand,2);eq(#cost.hand,3)
    local ordinary=false
    for _,c in ipairs(cost.hand) do if c.cardId=="defend" then ordinary=true end end
    assert(ordinary,"real Dark Embrace draw must run after Restore and before Sands cost tail")
    eq(#s.hand,3)
end)
print("WATCHER_RETAIN_BUILD_PASS "..count)
