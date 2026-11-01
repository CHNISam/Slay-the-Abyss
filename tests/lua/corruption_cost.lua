package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Corruption=require("abyss_corruption")
local Combat=require("abyss_combat")
local Data=require("abyss_data")
local Snapshot=require("abyss_snapshot")
local count=0
local function eq(a,b)
    assert(a==b or type(a)=="number" and type(b)=="number" and a~=a and b~=b,tostring(a).." ~= "..tostring(b))
end
local function test(name,fn) fn();count=count+1;print("ok corruption_cost "..count.." - "..name) end
local function state()
    return Combat.new(Data,{seed=42,enemies={"cultist"},deck={}})
end
local function card(s,pile,id,cost,kind,upgrade)
    s.catalog.cards[id]={id=id,type=kind or "skill",cost=cost,effects={},upgrade=upgrade and {cost=upgrade} or nil}
    s.fixtureNextUid=(s.fixtureNextUid or 0)+1
    local c={uid=s.fixtureNextUid,cardId=id,upgraded=false}
    s[pile][#s[pile]+1]=c
    return c
end
local function effective(s,c)
    local def=Combat.copy(s.catalog.cards[c.cardId])
    if c.upgraded then for k,v in pairs(def.upgrade or {}) do def[k]=Combat.copy(v) end end
    return Corruption.adaptDefinition(s,c,def)
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
test("first application reduces only skill instances in all four piles and preserves native label and input",function()
    local inputUnchanged=freeze(Data)
    local nativeStatus,sourceCard
    for _,d in ipairs(Data.statuses.statuses)do if d.id=="corruption"then nativeStatus=d end end
    for _,c in ipairs(Data.cards.cards)do if c.id=="corruption"then sourceCard=c end end
    assert(nativeStatus and sourceCard,"native75 includes the Corruption card and status")
    eq(nativeStatus.name,"孤注一掷");eq(sourceCard.sts_name,"Corruption")
    local s=state();local skills,others={},{}
    for _,pile in ipairs({"hand","draw","discard","exhaust"}) do
        skills[#skills+1]=card(s,pile,"skill_"..pile,2)
        others[#others+1]=card(s,pile,"attack_"..pile,2,"attack")
    end
    assert(Corruption.apply(s,1));eq(s.player.statuses.corruption,1)
    for _,c in ipairs(skills) do eq(c.combatCost,0);eq(c.turnCost,0);eq(effective(s,c).cost,0) end
    for _,c in ipairs(others) do eq(c.combatCost,nil);eq(c.turnCost,nil);eq(effective(s,c).cost,2) end
    local d=s.catalog.statuses.corruption
    eq(d.id,"corruption");eq(d.name,nativeStatus.name);eq(s.catalog.cards.corruption.sts_name,"Corruption")
    eq(d.kind,"buff");eq(d.stack,"none");eq(d.decay,"none");assert(#d.description>0)
    eq(s.events[#s.events].detail.status,"corruption");eq(s.events[#s.events].frame.hand[1].combatCost,0)
    inputUnchanged()
end)
test("upgrade costs are resolved before constructor reduction without modifying definitions",function()
    local s=state();local c=card(s,"hand","upgraded_skill",3,nil,1);c.upgraded=true
    local before=Combat.copy(s.catalog.cards.upgraded_skill)
    assert(Corruption.apply(s));eq(c.combatCost,0);eq(effective(s,c).cost,0)
    eq(s.catalog.cards.upgraded_skill.cost,before.cost);eq(s.catalog.cards.upgraded_skill.upgrade.cost,1)
end)
test("zero cost skills stay zero and X and unplayable sentinel skills stay negative",function()
    local s=state();local zero=card(s,"hand","zero",0)
    local x=card(s,"draw","x_skill",-1);local unplayable=card(s,"discard","unplayable_skill",-2)
    assert(Corruption.apply(s));eq(zero.combatCost,0);eq(zero.turnCost,0)
    for _,c in ipairs({x,unplayable}) do
        eq(c.combatCost,nil);eq(c.turnCost,nil);eq(effective(s,c).cost,s.catalog.cards[c.cardId].cost)
        eq(Corruption.onDraw(s,c),false)
    end
end)
test("constructor prepare precedes marker and apply consumes preparation without a second subtraction",function()
    local s=state();local c=card(s,"hand","high_cost",20)
    local events=#s.events
    assert(Corruption.prepare(s));eq(c.combatCost,11);eq(c.turnCost,11);eq(s.player.statuses.corruption,nil)
    eq(s.corruptionPrepared,true);eq(#s.events,events)
    local later=card(s,"draw","created_after_constructor",2)
    assert(Corruption.apply(s,1));eq(c.combatCost,11);eq(later.combatCost,nil);eq(s.corruptionPrepared,nil)
end)
test("two actual constructors each subtract nine before their marker applications",function()
    local s=state();local c=card(s,"draw","large",20)
    assert(Corruption.prepare(s));assert(Corruption.prepare(s));eq(c.combatCost,2)
    assert(Corruption.apply(s));eq(c.combatCost,2);eq(Corruption.apply(s),false)
end)
test("duplicate active Corruption skips scanning entirely",function()
    local s=state();assert(Corruption.apply(s))
    local c=card(s,"hand","new_after_power",3)
    local events=#s.events;eq(Corruption.apply(s),false);eq(Corruption.prepare(s),false)
    eq(c.combatCost,nil);eq(c.turnCost,nil);eq(#s.events,events)
end)
test("constructor subtraction uses positive turn cost and otherwise combat cost",function()
    local s=state();local current=card(s,"hand","current_turn",20)
    current.turnCost=5
    local zero=card(s,"draw","zero_turn",20);zero.turnCost=0
    assert(Corruption.prepare(s));eq(current.combatCost,0);eq(current.turnCost,0)
    eq(zero.combatCost,11);eq(zero.turnCost,0)
end)
test("a new draw receives only temporary zero before the hand-wide hook",function()
    local s=state();assert(Corruption.apply(s))
    local c=card(s,"hand","drawn_late",2)
    assert(Corruption.onDraw(s,c));eq(c.turnCost,0);eq(c.combatCost,nil)
    assert(Corruption.onDrawOrDiscard(s));eq(c.combatCost,nil);eq(effective(s,c).cost,0)
    assert(Corruption.remove(s));assert(Corruption.resetEndTurn(s));eq(effective(s,c).cost,2)
end)
test("a new generated hand skill is permanently reduced before final turn cost is zeroed",function()
    local s=state();assert(Corruption.apply(s))
    local normal=card(s,"hand","generated",2)
    assert(Corruption.created(s,normal));eq(normal.combatCost,0);eq(normal.turnCost,0)
    local high=card(s,"hand","generated_high",20)
    assert(Corruption.created(s,high));eq(high.combatCost,11);eq(high.turnCost,0)
    assert(Corruption.remove(s));assert(Corruption.resetEndTurn(s));eq(effective(s,normal).cost,0);eq(effective(s,high).cost,11)
end)
test("generation of an attack still invokes the hand skill hook but never modifies the attack",function()
    local s=state();assert(Corruption.apply(s))
    local skill=card(s,"hand","waiting_skill",2)
    local attack=card(s,"hand","generated_attack",1,"attack")
    assert(Corruption.created(s,attack));eq(skill.combatCost,0);eq(attack.combatCost,nil);eq(attack.turnCost,nil)
end)
test("generation must have entered hand and rejects before modifying another card",function()
    local s=state();assert(Corruption.apply(s))
    card(s,"hand","waiting",2);local c=card(s,"discard","not_in_hand",2)
    local unchanged=freeze(s);eq(pcall(Corruption.created,s,c),false);unchanged()
end)
test("hand hook rescans only nonzero current turn costs and leaves other piles unchanged",function()
    local s=state();assert(Corruption.apply(s))
    local h=card(s,"hand","hand_skill",20);local d=card(s,"draw","draw_skill",20)
    local z=card(s,"hand","zero_hand",20);z.turnCost=0
    assert(Corruption.onDrawOrDiscard(s));eq(h.combatCost,11);eq(z.combatCost,nil);eq(d.combatCost,nil)
    assert(Corruption.onDrawOrDiscard(s));eq(h.combatCost,2)
    assert(Corruption.onDrawOrDiscard(s));eq(h.combatCost,0)
end)
test("end turn resets hand draw discard including retained and all card types but not exhaust",function()
    local s=state();local cards={}
    for _,pile in ipairs({"hand","draw","discard","exhaust"}) do
        cards[pile]=card(s,pile,"reset_"..pile,2,pile=="draw" and "attack" or "skill")
        cards[pile].turnCost=0
    end
    s.catalog.cards.reset_hand.selfRetain=true
    assert(Corruption.resetEndTurn(s))
    for _,pile in ipairs({"hand","draw","discard"}) do eq(cards[pile].turnCost,nil);eq(effective(s,cards[pile]).cost,2) end
    eq(cards.exhaust.turnCost,0);eq(effective(s,cards.exhaust).cost,0)
end)
test("end-turn Dark Embrace draw stays temporarily zero through the following start turn",function()
    local s=state();assert(Corruption.apply(s));assert(Corruption.resetEndTurn(s))
    local c=card(s,"hand","end_turn_draw",2)
    assert(Corruption.onDraw(s,c));assert(Corruption.onDrawOrDiscard(s));eq(c.combatCost,nil)
    assert(Corruption.remove(s));assert(Corruption.beginTurn(s));eq(effective(s,c).cost,0)
    assert(Corruption.resetEndTurn(s));eq(effective(s,c).cost,2)
end)
test("removal does not restore old combat reductions or rewrite sentinel costs",function()
    local s=state();local c=card(s,"draw","old",2);local x=card(s,"hand","x",-1)
    assert(Corruption.apply(s));assert(Corruption.remove(s));eq(s.player.statuses.corruption,nil)
    eq(Corruption.remove(s),false);eq(c.combatCost,0);eq(effective(s,c).cost,0);eq(effective(s,x).cost,-1)
end)
test("normal payment bypass applies to positive skill cost while its actual cost stays observable",function()
    local s=state();local c=card(s,"hand","high",20);assert(Corruption.apply(s))
    local skill=effective(s,c);eq(skill.cost,11);eq(Corruption.freePayment(s,skill),true)
    eq(Corruption.freePayment(s,{type="attack",cost=2}),false)
    eq(Corruption.freePayment(s,{type="power",cost=2}),false)
    eq(Corruption.freePayment(s,{type="skill",cost=-1}),false)
    eq(Corruption.freePayment(s,{type="skill",cost=-2}),false)
    assert(Corruption.remove(s));eq(Corruption.freePayment(s,skill),false)
end)
test("component costs are separate from stored discard costs retain metadata and damage",function()
    local s=state();local c=card(s,"hand","other_fields",2)
    c.storedDiscardCost=3;c.damageBonus=7;c.shivAccuracyBonus=4;c.retain=true
    assert(Corruption.apply(s));eq(c.storedDiscardCost,3);eq(c.damageBonus,7);eq(c.shivAccuracyBonus,4);eq(c.retain,true)
    local def=effective(s,c);eq(def.cost,0);eq(def.type,"skill")
    assert(Corruption.resetEndTurn(s));eq(c.storedDiscardCost,3);eq(c.retain,true)
end)
test("late invalid cost metadata aborts the entire application before any rule write",function()
    for _,field in ipairs({"cost","combatCost","turnCost"}) do
        local s=state();card(s,"hand","valid",2);local invalid=card(s,"exhaust","invalid",2)
        if field=="cost" then s.catalog.cards.invalid.cost=0/0 else invalid[field]=0/0 end
        local unchanged=freeze(s);eq(pcall(Corruption.apply,s,1),false);unchanged()
    end
end)
test("duplicate UIDs sparse piles and incompatible buff reject constructor atomically",function()
    for _,kind in ipairs({"duplicate","sparse","status"}) do
        local s=state();local a=card(s,"hand","first",2);local b=card(s,"exhaust","second",2)
        if kind=="duplicate" then b.uid=a.uid
        elseif kind=="sparse" then s.discard[2]=table.remove(s.exhaust)
        else s.catalog.statuses.corruption={id="corruption",kind="debuff",stack="none",decay="none"} end
        local unchanged=freeze(s);eq(pcall(Corruption.prepare,s),false);unchanged()
    end
end)
test("adaptation rejects catalog mutation and malformed sentinel overrides before touching the definition",function()
    local s=state();local c=card(s,"hand","skill",2);c.turnCost=0
    local original=s.catalog.cards.skill
    eq(pcall(Corruption.adaptDefinition,s,c,original),false);eq(original.cost,2)
    local x=card(s,"draw","x_skill",-1);x.turnCost=0
    local def=Combat.copy(s.catalog.cards.x_skill)
    eq(pcall(Corruption.adaptDefinition,s,x,def),false);eq(def.cost,-1)
end)
test("prepared flags and constructor cost writes restore with the original full graph transaction",function()
    local s=state();local c=card(s,"hand","transaction_skill",20)
    local restore=Snapshot.capture(s)
    assert(Corruption.prepare(s));eq(c.combatCost,11);eq(s.corruptionPrepared,true)
    restore();eq(c.combatCost,nil);eq(s.corruptionPrepared,nil);eq(s.hand[1],c)
    assert(Corruption.apply(s));eq(c.combatCost,11);eq(s.player.statuses.corruption,1)
end)
print("CORRUPTION_COST_PASS "..count)
