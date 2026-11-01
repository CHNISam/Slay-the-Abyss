package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Mantra=require("abyss_mantra")
local Stances=require("abyss_stances")
local Queue=require("abyss_action_queue")
local Combat=require("abyss_combat")
local Watcher=require("abyss_watcher_cards")
local Data=require("abyss_data")
local count=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();count=count+1;print("ok watcher_mantra "..count.." - "..name) end
local function prepared() return Watcher.withFoundationCards(Data) end
local function battle(deck)
    local s=Combat.new(prepared(),{seed=42,enemies={"cultist"},enableStances=true,deck=deck or {"defend"}})
    s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
    return s
end
local function uid(s,id)
    for _,c in ipairs(s.hand) do if c.cardId==id then return c.uid end end
    error("missing "..id)
end
-- Module contract checks use real combat state and the actual action queue,
-- without pretending these handler-level checks exercised a source card.
local handlers={effect=function(s,a,q)
    local e=a.effect
    if e.op=="applyMantra" then return Mantra.apply(s,e.value,q)
    elseif e.op=="removeMantra" then return Mantra.remove(s)
    elseif e.op=="changeStance" then Stances.change(s,e.stance);Stances.flush(s,Combat);return true end
    error("unexpected module-contract action")
end}
local function apply(s,amount)
    Queue.start(s,{{kind="effect",effect=Mantra.prepareGain(s,amount)}})
    return Queue.run(s,handlers)
end
test("ordinary first gain stores buff without consuming Artifact",function()
    local s=battle();s.player.statuses.artifact=2
    assert(apply(s,2));eq(s.player.statuses.mantra,2);eq(s.mantraGained,2)
    eq(s.player.statuses.artifact,2);eq(s.player.stance,"Neutral")
end)
test("ten threshold removes zero Mantra before entering Divinity",function()
    local s=battle();apply(s,5)
    Queue.start(s,{{kind="effect",effect=Mantra.prepareGain(s,5)}})
    local effect=table.remove(s.actionQueue.actions,1).effect
    assert(Mantra.apply(s,effect.value,Queue));eq(s.player.statuses.mantra,0)
    eq(s.actionQueue.actions[1].effect.op,"removeMantra")
    eq(s.actionQueue.actions[2].effect.op,"changeStance")
    local energy=s.energy;assert(Queue.run(s,handlers))
    eq(s.player.statuses.mantra,nil);eq(s.player.stance,"Divinity")
    eq(s.energy,energy+3);eq(s.mantraGained,10)
end)
test("threshold preserves the remainder and does not consume Artifact",function()
    local s=battle();apply(s,8);s.player.statuses.artifact=2
    apply(s,5);eq(s.player.statuses.mantra,3);eq(s.mantraGained,13)
    eq(s.player.stance,"Divinity");eq(s.player.statuses.artifact,2)
end)
test("large existing stack subtracts ten once rather than looping",function()
    local s=battle();apply(s,5);local energy=s.energy
    apply(s,20);eq(s.player.statuses.mantra,15);eq(s.mantraGained,25)
    eq(s.energy,energy+3)
end)
test("threshold while already Divinity spends Mantra without duplicate energy",function()
    local s=battle();apply(s,5);apply(s,5);local energy=s.energy
    apply(s,5);apply(s,5)
    eq(s.player.statuses.mantra,nil);eq(s.player.stance,"Divinity")
    eq(s.energy,energy);eq(s.mantraGained,20)
end)
test("constructor count happens before actual application or cancellation",function()
    local s=battle();local e=Mantra.prepareGain(s,5)
    eq(s.mantraGained,5);eq(s.player.statuses.mantra,nil)
    Queue.start(s,{{kind="effect",effect=e}})
    Queue.run(s,{allow=function() return false end,effect=handlers.effect})
    eq(s.mantraGained,5);eq(s.player.statuses.mantra,nil)
end)
test("unsupported first ten is explicit, not guessed into Divinity",function()
    local s=battle();local before=s.energy
    local ok,reason=Mantra.apply(s,10,Queue)
    eq(ok,false);eq(reason,"unsupported_initial_mantra_threshold")
    eq(s.player.statuses.mantra,nil);eq(s.player.stance,"Neutral");eq(s.energy,before)
end)
test("Devotion absent Mantra at ten bypasses Mantra and its counter",function()
    for _,amount in ipairs({10,12}) do
        local s=battle();assert(Mantra.applyDevotion(s,amount))
        Queue.start(s,{});assert(Mantra.postDraw(s,Queue))
        eq(s.actionQueue.actions[1].effect.op,"changeStance")
        assert(Queue.run(s,handlers));eq(s.player.stance,"Divinity")
        eq(s.player.statuses.mantra,nil);eq(s.mantraGained,nil)
    end
end)
test("ordinary Devotion records construction and queues its later application",function()
    local s=battle();Mantra.applyDevotion(s,2);Mantra.applyDevotion(s,3)
    Queue.start(s,{});Mantra.postDraw(s,Queue)
    eq(s.mantraGained,5);eq(s.player.statuses.mantra,nil)
    Queue.run(s,handlers);eq(s.player.statuses.mantra,5)
end)
test("an existing zero Devotion is distinct from no Devotion",function()
    local s=battle();Mantra.applyDevotion(s,0)
    Queue.start(s,{});Mantra.postDraw(s,Queue)
    eq(#s.actionQueue.actions,1);eq(s.mantraGained,0)
    Queue.run(s,handlers);eq(s.player.statuses.mantra,0)
end)
test("Divinity exits next own turn before Devotion can re-enter",function()
    local s=battle();apply(s,5);apply(s,5);eq(s.player.stance,"Divinity")
    Mantra.applyDevotion(s,10)
    Stances.startTurn(s);Stances.flush(s,Combat);eq(s.player.stance,"Neutral")
    local energy=s.energy
    Queue.start(s,{});Mantra.postDraw(s,Queue);Queue.run(s,handlers)
    eq(s.player.stance,"Divinity");eq(s.energy,energy+3);eq(s.mantraGained,10)
end)
test("invalid inputs and arithmetic overflow refuse before mutation",function()
    local s=battle()
    for _,amount in ipairs({-1,0.5,0/0,math.huge,"2"}) do
        assert(not pcall(Mantra.prepareGain,s,amount))
        assert(not pcall(Mantra.apply,s,amount,Queue))
    end
    eq(s.player.statuses.mantra,nil);eq(s.mantraGained,nil)
    s.mantraGained=2147483647
    assert(not pcall(Mantra.prepareGain,s,1));eq(s.mantraGained,2147483647)
    s.player.statuses.mantra=2147483647
    assert(not pcall(Mantra.apply,s,1,Queue));eq(s.player.statuses.mantra,2147483647)
end)
test("data helper is opt-in detached and repeated insertion rejects",function()
    local n=#Data.cards.cards;local d=prepared();eq(#Data.cards.cards,n)
    local ids={};for _,c in ipairs(d.cards.cards) do ids[c.id]=c end
    eq(ids.prostrate.cost,0);eq(ids.worship.cost,2);eq(ids.worship.upgrade.selfRetain,true)
    eq(ids.devotion.cost,1)
    assert(not pcall(Mantra.withCards,d))
end)
print("WATCHER_MANTRA_MODULE_PASS "..count)

-- Integration checks below MUST run through real Combat.play/endTurn. They
-- remain red until the owning host integrates the new queued effects/hooks.
test("Prostrate basic and upgraded resolve Mantra before four block",function()
    for _,up in ipairs({false,true}) do
        local s=battle({{cardId="prostrate",upgraded=up}});local before=s.energy
        assert(Combat.play(s,uid(s,"prostrate")))
        eq(s.energy,before);eq(s.player.statuses.mantra,up and 3 or 2)
        eq(s.player.block,4);eq(s.mantraGained,up and 3 or 2)
        local mantra,block
        for i,e in ipairs(s.events) do if e.kind=="mantra" then mantra=i elseif e.kind=="block" then block=i end end
        assert(mantra and block and mantra<block)
    end
end)
test("Worship threshold enters Divinity and upgraded card self-retains",function()
    local s=battle({"worship",{cardId="worship",upgraded=true}})
    local first=uid(s,"worship");assert(Combat.play(s,first));eq(s.energy,1)
    assert(Combat.endTurn(s));eq(s.player.statuses.mantra,5)
    local upgraded
    for _,card in ipairs(s.hand) do if card.cardId=="worship" and card.upgraded then upgraded=card.uid end end
    assert(upgraded,"upgraded Worship did not retain")
    local before=s.energy;assert(Combat.play(s,upgraded))
    eq(s.player.statuses.mantra,nil);eq(s.player.stance,"Divinity")
    eq(s.energy,before-2+3);eq(s.mantraGained,10)
end)
test("Devotion first ticks after next own-turn draw, not when played",function()
    for _,up in ipairs({false,true}) do
        local s=battle({{cardId="devotion",upgraded=up},"defend"})
        assert(Combat.play(s,uid(s,"devotion")))
        eq(s.player.statuses.devotion,up and 3 or 2);eq(s.player.statuses.mantra,nil)
        assert(Combat.endTurn(s))
        eq(s.player.statuses.mantra,up and 3 or 2);eq(s.mantraGained,up and 3 or 2)
        local frame
        for _,e in ipairs(s.events) do if e.kind=="mantra" then frame=e.frame end end
        assert(frame and #frame.hand==#s.hand and #frame.hand>0,"Devotion applied before the actual turn draw")
    end
end)
test("Prostrate TOP Divinity precedes its block; Mental Fortress and energy follow UseCard",function()
    local s=battle({"mental_fortress","worship",{cardId="prostrate",upgraded=true},"prostrate"})
    local upgraded,basic
    for _,card in ipairs(s.hand) do
        if card.cardId=="prostrate" then if card.upgraded then upgraded=card.uid else basic=card.uid end end
    end
    assert(upgraded and basic)
    assert(Combat.play(s,uid(s,"mental_fortress")))
    assert(Combat.play(s,uid(s,"worship")))
    assert(Combat.play(s,upgraded));eq(s.player.statuses.mantra,8);eq(s.player.block,4);eq(s.energy,0)
    local before=#s.events
    assert(Combat.play(s,basic));eq(s.player.stance,"Divinity")
    eq(s.player.block,12);eq(s.energy,3)
    local blocks,stance={}
    for i=before+1,#s.events do
        local e=s.events[i]
        if e.kind=="stance" then stance=e.frame elseif e.kind=="block" then blocks[#blocks+1]=e.frame end
    end
    assert(stance);eq(stance.player.block,4);eq(stance.energy,0)
    eq(#blocks,2);eq(blocks[1].player.block,8);eq(blocks[2].player.block,12)
    local function discarded(frame)
        for _,card in ipairs(frame.discard) do if card.uid==basic then return true end end
        return false
    end
    eq(discarded(blocks[1]),false);eq(discarded(blocks[2]),true)
    eq(blocks[1].energy,0);eq(blocks[2].energy,0)
end)
test("real stacked Devotion exits prior Divinity then re-enters after next draw",function()
    local s=battle({{cardId="devotion",upgraded=true},{cardId="devotion",upgraded=true},"devotion","devotion","prostrate"})
    for _=1,3 do
        local chosen
        -- Prefer the two upgraded copies, then one base copy: 3+3+2=8.
        for _,card in ipairs(s.hand) do if card.cardId=="devotion" and card.upgraded then chosen=card.uid;break end end
        chosen=chosen or uid(s,"devotion")
        assert(Combat.play(s,chosen))
    end
    eq(s.player.statuses.devotion,8);eq(s.energy,0)
    assert(Combat.endTurn(s));eq(s.player.statuses.mantra,8);eq(s.mantraGained,8)
    assert(Combat.play(s,uid(s,"devotion")));eq(s.player.statuses.devotion,10)
    assert(Combat.play(s,uid(s,"prostrate")))
    eq(s.player.stance,"Divinity");eq(s.player.statuses.mantra,nil);eq(s.mantraGained,10)
    local events=#s.events
    assert(Combat.endTurn(s));eq(s.player.stance,"Divinity");eq(s.energy,6)
    eq(s.player.statuses.mantra,nil);eq(s.mantraGained,10)
    local changes={}
    for i=events+1,#s.events do if s.events[i].kind=="stance" then changes[#changes+1]=s.events[i].detail.to end end
    eq(#changes,2);eq(changes[1],"Neutral");eq(changes[2],"Divinity")
end)
test("a blocked actual turn draw does not suppress Devotion post-draw",function()
    local s=battle({"devotion","defend"})
    assert(Combat.play(s,uid(s,"devotion")))
    local before=#s.hand
    -- The existing one-shot opening hook supplies a controlled NoDraw fixture;
    -- this verifies ordering, not a naturally acquired new NoDraw source.
    assert(Combat.startPlayerTurn(s,function(current) current.player.noDraw=true;return true end))
    eq(s.player.noDraw,true);eq(#s.hand,before)
    eq(s.player.statuses.mantra,2);eq(s.mantraGained,2)
end)
test("Devotion constructor counter advances before real draw but applies only afterwards",function()
    for _,blocked in ipairs({false,true}) do
        local s=battle({"devotion","defend"})
        assert(Combat.play(s,uid(s,"devotion")))
        eq(s.mantraGained,nil);eq(s.player.statuses.mantra,nil)
        local calls={};local realDraw=Combat.draw
        Combat.draw=function(current,amount)
            -- Instrumentation only: do not replace any part of real draw or
            -- implement the Power effect here. No callback is stored in state.
            local row={beforeCount=current.mantraGained,beforeMantra=current.player.statuses.mantra,
                beforeHand=#current.hand,noDraw=current.player.noDraw,amount=amount}
            calls[#calls+1]=row
            local result=realDraw(current,amount)
            row.afterDrawMantra=current.player.statuses.mantra
            row.afterDrawCount=current.mantraGained;row.afterHand=#current.hand
            return result
        end
        local ok,reason=pcall(function()
            if blocked then
                -- Controlled opening-hook NoDraw boundary, as in the prior
                -- fixture; ordinary case runs the complete actual end turn.
                assert(Combat.startPlayerTurn(s,function(current) current.player.noDraw=true;return true end))
            else assert(Combat.endTurn(s)) end
        end)
        Combat.draw=realDraw
        assert(ok,reason);eq(#calls,1)
        local row=calls[1]
        eq(row.beforeCount,2);eq(row.afterDrawCount,2)
        eq(row.beforeMantra,nil);eq(row.afterDrawMantra,nil)
        eq(row.amount,5)
        if blocked then eq(row.noDraw,true);eq(row.afterHand,row.beforeHand) end
        eq(s.mantraGained,2);eq(s.player.statuses.mantra,2)
    end
end)
print("WATCHER_MANTRA_PASS "..count)
