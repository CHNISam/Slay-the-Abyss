package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Triggers=require("abyss_card_triggers")
local Combat=require("abyss_combat")
local Actors=require("abyss_actor")
local EnemyAI=require("abyss_enemy_ai")
local Queue=require("abyss_action_queue")
local Data=require("abyss_data")
local n=0
local function eq(a,b)
    assert(a==b or type(a)=="number" and type(b)=="number" and a~=a and b~=b,tostring(a).." ~= "..tostring(b))
end
local function test(name,fn) fn();n=n+1;print("ok card_triggers "..n.." - "..name) end
local function data()
    local d=Data
    for _,id in ipairs({"silent","ironclad","defect"}) do d=Triggers.withCards(d,id) end
    return d
end
local function state(deck,orbs)
    return Combat.new(data(),{seed=42,cardRandomSeed="42",enemies={"cultist","jaw_worm"},
        deck=deck or {},orbSlots=orbs==false and nil or 3,enableStances=true})
end
local function find(d,id)
    for _,card in ipairs(d.cards.cards) do if card.id==id then return card end end
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
local function apply(s,id,value) assert(Triggers.apply(s,id,value or 1)) end
local function run(s,actions,extra)
    Queue.start(s,actions)
    local handlers={effect=function(current,a,q)
        local e=a.effect
        if e.op=="cardTriggerStorm" then
            for _,next in ipairs(Triggers.expandStorm(current,e)) do q.pushTop(current,next) end
        elseif e.op=="cardTriggerDamageAll" then Triggers.resolveDamageAll(current,e,Combat)
        elseif e.op=="cardTriggerPoison" then Triggers.resolveEnvenom(current,e)
        elseif e.op=="removeCardTriggerPower" then Triggers.removePower(current,e.status)
        elseif extra and extra[e.op] then extra[e.op](current,e,q)
        else Combat.applyEffects(current,{e},current.player,current.enemies[1]) end
        return true
    end}
    assert(Queue.run(s,handlers));eq(s.actionQueue,nil)
end
local function append(out,items) for _,a in ipairs(items) do out[#out+1]=a end end
test("independent class groups preserve exact source numbers upgrades and Innate",function()
    local old=#Data.cards.cards
    local unchanged=freeze(Data)
    local function missing(ids)
        local total=0;for _,id in ipairs(ids) do if not find(Data,id) then total=total+1 end end;return total
    end
    local function unique(d)
        local ids={};for _,card in ipairs(d.cards.cards) do assert(not ids[card.id],"duplicate prepared card");ids[card.id]=true end
        ids={};for _,status in ipairs(d.statuses.statuses) do assert(not ids[status.id],"duplicate prepared status");ids[status.id]=true end
    end
    local silent=Triggers.withCards(Data,"silent");eq(#silent.cards.cards,old+missing({"after_image","thousand_cuts","envenom"}))
    local ai=find(silent,"after_image");eq(ai.cost,1);eq(ai.rarity,"rare");eq(ai.effects[1].value,1);eq(ai.upgrade.innate,true)
    local cuts=find(silent,"thousand_cuts");eq(cuts.cost,2);eq(cuts.effects[1].value,1);eq(cuts.upgrade.effects[1].value,2)
    local venom=find(silent,"envenom");eq(venom.cost,2);eq(venom.upgrade.cost,1);eq(venom.effects[1].value,1)
    local red=Triggers.withCards(Data,"ironclad");eq(#red.cards.cards,old+missing({"rage"}))
    local rage=find(red,"rage");eq(rage.type,"skill");eq(rage.cost,0);eq(rage.effects[1].value,3);eq(rage.upgrade.effects[1].value,5)
    local blue=Triggers.withCards(Data,"defect");eq(#blue.cards.cards,old+missing({"heat_sinks","storm"}))
    local heat=find(blue,"heat_sinks");eq(heat.cost,1);eq(heat.effects[1].value,1);eq(heat.upgrade.effects[1].value,2)
    local storm=find(blue,"storm");eq(storm.cost,1);eq(storm.effects[1].value,1);eq(storm.upgrade.innate,true)
    for _,entry in ipairs({{silent,"rage"},{red,"heat_sinks"},{blue,"after_image"}}) do
        local prepared,native=find(entry[1],entry[2]),find(Data,entry[2])
        if native then eq(prepared.target,native.target);eq(prepared.effects[1].op,native.effects[1].op)
        else eq(prepared,nil) end
    end
    unique(silent);unique(red);unique(blue)
    eq(silent.experimentalMechanics,true);eq(red.experimentalMechanics,true);eq(blue.experimentalMechanics,true)
    unchanged();eq(#Data.cards.cards,old)
end)
test("helpers detach definitions and reject duplicates or unknown character",function()
    local d=Triggers.withCards(Data,"silent");d.cards.cards[#d.cards.cards].cost=9
    eq(find(Data,"envenom"),nil);eq(find(Triggers.withCards(Data,"silent"),"envenom").cost,2)
    eq(pcall(Triggers.withCards,d,"silent"),false);eq(pcall(Triggers.withCards,Data,"watcher"),false)
end)
test("native card and associated Power are normalized only in the detached helper result",function()
    local native=Combat.copy(Data);local rage=find(native,"rage")
    if not rage then
        rage={id="rage",sourceId="Rage",type="skill",cost=0,target="SELF",effects={{op="gainStatus",status="rage",value=3}}}
        native.cards.cards[#native.cards.cards+1]=rage
        native.statuses.statuses[#native.statuses.statuses+1]={id="rage",kind="buff",stack="intensity",decay="none"}
    end
    for _,status in ipairs(native.statuses.statuses) do if status.id=="rage" then status.nativePower="rage" end end
    local unchanged=freeze(native);local out=Triggers.withCards(native,"ironclad");local prepared=find(out,"rage")
    eq(prepared.target,nil);eq(prepared.effects[1].op,"gainCardTriggerPower");eq(prepared.effects[1].value,3)
    for _,status in ipairs(out.statuses.statuses) do if status.id=="rage" then eq(status.nativePower,nil);eq(status.priority,5) end end
    unchanged();local copiedUnchanged=freeze(out);eq(pcall(Triggers.withCards,out,"ironclad"),false);copiedUnchanged()
    rage.sourceId="UnknownRage";local malformed=freeze(native);eq(pcall(Triggers.withCards,native,"ironclad"),false);malformed()
end)
test("recorded Power priority is five and equal-priority acquisition is stable on stacking",function()
    local s=state();apply(s,"rage",3);apply(s,"after_image",1);apply(s,"rage",5)
    eq(s.player.statuses.rage,8);eq(#s.cardTriggerPowerOrder,2);eq(s.cardTriggerPowerSerial,2)
    eq(s.cardTriggerPowerOrder[1].id,"rage");eq(s.cardTriggerPowerOrder[1].priority,5);eq(s.cardTriggerPowerOrder[1].order,1)
    eq(s.cardTriggerPowerOrder[2].id,"after_image");eq(Triggers.recordApplied(s,"rage"),false)
    local plan=Triggers.prepareUse(s,{type="attack"})
    eq(plan.beforeUse[1].triggerPower,"rage");eq(plan.beforeUse[1].effect.value,8)
    eq(plan.beforeUse[2].triggerPower,"after_image")
end)
test("removal and reapplication get a fresh position instead of resurrecting an old slot",function()
    local s=state();apply(s,"rage",3);apply(s,"after_image",1)
    assert(Triggers.removePower(s,"rage"));apply(s,"rage",5)
    eq(s.cardTriggerPowerOrder[1].id,"after_image");eq(s.cardTriggerPowerOrder[2].id,"rage")
    eq(s.cardTriggerPowerOrder[2].order,3);eq(s.player.statuses.rage,5)
end)
test("After Image triggers every card type with fixed block",function()
    local s=state();apply(s,"after_image",2)
    for _,kind in ipairs({"attack","skill","power","status","curse"}) do
        local p=Triggers.prepareUse(s,{type=kind})
        eq(#p.top,0);eq(#p.beforeUse,1);eq(#p.afterUse,0)
        eq(p.beforeUse[1].effect.op,"block");eq(p.beforeUse[1].effect.value,2);eq(p.beforeUse[1].effect.fixed,true)
    end
end)
test("Rage triggers only attacks and shares stable player Power order with After Image",function()
    local s=state();apply(s,"after_image",1);apply(s,"rage",3)
    for _,kind in ipairs({"skill","power","status","curse"}) do eq(#Triggers.prepareUse(s,{type=kind}).beforeUse,1) end
    local p=Triggers.prepareUse(s,{type="attack"})
    eq(p.beforeUse[1].triggerPower,"after_image");eq(p.beforeUse[2].triggerPower,"rage");eq(p.beforeUse[2].effect.fixed,true)
end)
test("Heat Sinks is a TOP draw only for Power cards",function()
    local s=state();apply(s,"heat_sinks",2)
    local p=Triggers.prepareUse(s,{type="power"});eq(#p.top,1);eq(p.top[1].effect.op,"draw");eq(p.top[1].effect.value,2)
    eq(#p.beforeUse,0);eq(#p.afterUse,0)
    for _,kind in ipairs({"attack","skill","status","curse"}) do eq(#Triggers.prepareUse(s,{type=kind}).top,0) end
end)
test("Storm is before UseCard and expands as individual lazy Channel actions",function()
    local s=state();apply(s,"storm",3)
    local p=Triggers.prepareUse(s,{type="power"});eq(#p.beforeUse,1)
    local e=p.beforeUse[1].effect;eq(e.op,"cardTriggerStorm");eq(e.remaining,3)
    local expanded=Triggers.expandStorm(s,e);eq(#expanded,2);eq(expanded[1].effect.remaining,2)
    eq(expanded[2].effect.op,"channelOrb");eq(expanded[2].effect.value,1)
    run(s,p.beforeUse);eq(#s.orbs.balls,3)
    for _,ball in ipairs(s.orbs.balls) do eq(ball.kind,"lightning") end
    eq(s.cardRandomRng.counter,0)
    for _,kind in ipairs({"attack","skill","status","curse"}) do eq(#Triggers.prepareUse(s,{type=kind}).beforeUse,0) end
end)
test("large Storm stacks build constant-size pure-data continuations",function()
    local s=state();local e={op="cardTriggerStorm",remaining=2147483647}
    local expanded=Triggers.expandStorm(s,e);eq(#expanded,2);eq(expanded[1].effect.remaining,2147483646)
    eq(#Triggers.expandStorm(s,{op="cardTriggerStorm",remaining=1}),1)
end)
test("Thousand Cuts belongs after UseCard for all card types and snapshots a pure matrix",function()
    local s=state();apply(s,"thousand_cuts",2)
    for _,kind in ipairs({"attack","skill","power","status","curse"}) do
        local p=Triggers.prepareUse(s,{type=kind});eq(#p.beforeUse,0);eq(#p.afterUse,1)
        local e=p.afterUse[1].effect;eq(e.op,"cardTriggerDamageAll");eq(#e.matrix,#s.enemies)
        eq(e.matrix[1].targetId,s.enemies[1].id);eq(e.matrix[1].amount,2)
    end
end)
test("Thousand Cuts uses real fixed Combat damage unaffected by attack modifiers or thorns",function()
    local s=state();apply(s,"thousand_cuts",2)
    s.player.statuses.strength=20;s.player.statuses.weak=2;s.player.stance="Wrath"
    local hp={};for i,e in ipairs(s.enemies) do
        hp[i]=e.hp;e.block=1;e.statuses.vulnerable=2;e.statuses.thorns=5;e.statuses.curl_up=4;e.statuses.angry=3
    end
    local p=Triggers.prepareUse(s,{type="attack"});local playerHp=s.player.hp
    eq(Triggers.resolveDamageAll(s,p.afterUse[1].effect,Combat),2)
    for i,e in ipairs(s.enemies) do eq(e.hp,hp[i]-1);eq(e.block,0);eq(e.curlUpTriggered,nil);eq(e.statuses.strength or 0,0) end
    eq(s.player.hp,playerHp)
end)
test("newly applied Powers do not retroactively join a prepared use and old amounts stay detached",function()
    local s=state();local empty=Triggers.prepareUse(s,{type="power"})
    apply(s,"after_image",1);apply(s,"heat_sinks",1);apply(s,"thousand_cuts",1)
    eq(#empty.top,0);eq(#empty.beforeUse,0);eq(#empty.afterUse,0)
    local old=Triggers.prepareUse(s,{type="power"})
    apply(s,"after_image",1);apply(s,"heat_sinks",1);apply(s,"thousand_cuts",1)
    eq(old.top[1].effect.value,1);eq(old.beforeUse[1].effect.value,1);eq(old.afterUse[1].effect.matrix[1].amount,1)
    local next=Triggers.prepareUse(s,{type="power"})
    eq(next.top[1].effect.value,2);eq(next.beforeUse[1].effect.value,2);eq(next.afterUse[1].effect.matrix[1].amount,2)
end)
test("source dontTriggerOnUseCard suppresses both use and after-card hooks",function()
    local s=state();for _,id in ipairs({"after_image","rage","thousand_cuts","heat_sinks","storm"}) do apply(s,id,1) end
    local p=Triggers.prepareUse(s,{type="power",dontTriggerOnUseCard=true})
    eq(#p.top,0);eq(#p.beforeUse,0);eq(#p.afterUse,0)
end)
test("pure-data plans are read-only and accepted by the real continuation queue",function()
    local s=state();for _,id in ipairs({"after_image","rage","thousand_cuts","heat_sinks","storm","envenom"}) do apply(s,id,1) end
    local unchanged=freeze(s);local p=Triggers.prepareUse(s,{type="power"});unchanged()
    local actions={};append(actions,p.top);append(actions,p.beforeUse);append(actions,p.afterUse)
    Queue.start(s,Combat.copy(actions));assert(Queue.active(s));s.actionQueue=nil
end)
test("component queue resolves TOP Heat Sinks draw before a real native block effect",function()
    local deck={};for i=1,12 do deck[i]="defend" end
    local s=state(deck);apply(s,"heat_sinks",2);local initial=#s.hand
    local p=Triggers.prepareUse(s,{type="power"})
    local actions={{kind="effect",effect={op="block",value=1}}}
    Queue.start(s,actions);for _,a in ipairs(p.top) do Queue.pushTop(s,a) end
    assert(Queue.run(s,{effect=function(current,a)Combat.applyEffects(current,{a.effect},current.player);return true end}))
    eq(#s.hand,initial+2);eq(s.player.block,1)
    local last=s.events[#s.events];eq(last.kind,"block");eq(#last.frame.hand,initial+2)
end)
test("No Draw affects the real Heat Sinks draw without cancelling subsequent native effects",function()
    local deck={};for i=1,12 do deck[i]="defend" end
    local s=state(deck);apply(s,"heat_sinks",2);s.player.noDraw=true;local initial=#s.hand
    local p=Triggers.prepareUse(s,{type="power"});run(s,p.top)
    eq(#s.hand,initial);eq(#s.draw,12-initial)
    Combat.applyEffects(s,{{op="block",value=1}},s.player);eq(s.player.block,1)
end)
test("real After Image and Rage fixed block precede real captured Sharp Hide retaliation in a component host",function()
    local s=state();apply(s,"after_image",1);apply(s,"rage",3)
    s.player.statuses.dexterity=20;s.player.statuses.frail=2
    s.enemies[1].statuses.sharp_hide=3
    local reactions=EnemyAI.cardReactions(s,{type="attack"});local hp=s.player.hp
    local p=Triggers.prepareUse(s,{type="attack"});local actions={}
    actions[1]={kind="effect",effect={op="damage",value=1}}
    append(actions,p.beforeUse);actions[#actions+1]={kind="effect",effect={op="componentCapturedSharpHide"}}
    run(s,actions,{componentCapturedSharpHide=function(current)EnemyAI.afterCard(current,reactions)end})
    eq(s.player.hp,hp);eq(s.player.block,1)
    local block,last
    for i,e in ipairs(s.events) do if e.kind=="block" then block=i elseif e.kind=="status_damage" and e.detail.status=="sharp_hide" then last=i end end
    assert(block and last and block<last)
end)
test("Envenom prepares a TOP poison action without eager Artifact or poison mutation",function()
    local s=state();apply(s,"envenom",2);local t=s.enemies[1];t.statuses.artifact=1
    local lost=Actors.damage(s,s.player,t,6)
    local unchanged=freeze(s);local a=Triggers.onAttack(s,s.player,t,lost,"NORMAL");assert(a);unchanged()
    eq(a.effect.op,"cardTriggerPoison");eq(a.effect.value,2);eq(a.effect.targetId,t.id)
    eq(Triggers.resolveEnvenom(s,a.effect),false);eq(t.statuses.artifact,0);eq(t.statuses.poison or 0,0)
end)
test("queued Envenom poison precedes an existing native bottom action",function()
    local s=state();apply(s,"envenom",1);local t=s.enemies[1]
    local a=Triggers.onAttack(s,s.player,t,1,"NORMAL")
    Queue.start(s,{{kind="effect",effect={op="block",value=5}}});Queue.pushTop(s,a)
    assert(Queue.run(s,{effect=function(current,entry)
        if entry.effect.op=="cardTriggerPoison" then Triggers.resolveEnvenom(current,entry.effect)
        else Combat.applyEffects(current,{entry.effect},current.player) end
        return true
    end}))
    eq(t.statuses.poison,1);eq(s.player.block,5)
    local poison,block
    for i,e in ipairs(s.events) do
        if e.kind=="status" and e.detail.status=="poison" then poison=i;eq(e.frame.player.block,0)
        elseif e.kind=="block" then block=i end
    end
    assert(poison and block and poison<block)
end)
test("Envenom snapshots the old amount and its queued action survives later Power removal",function()
    local s=state();apply(s,"envenom",2);local t=s.enemies[1]
    local a=Triggers.onAttack(s,s.player,t,1,"NORMAL")
    apply(s,"envenom",1);assert(Triggers.removePower(s,"envenom"))
    assert(Triggers.resolveEnvenom(s,a.effect));eq(t.statuses.poison,2)
end)
test("Envenom requires an unblocked positive NORMAL hit and ignores THORNS and HP loss",function()
    local s=state();apply(s,"envenom",1);local t=s.enemies[1]
    t.block=20;local blocked=Actors.damage(s,s.player,t,6);eq(blocked,0)
    eq(Triggers.onAttack(s,s.player,t,blocked,"NORMAL"),nil)
    t.block=4;local partial=Actors.damage(s,s.player,t,6);eq(partial,2)
    assert(Triggers.onAttack(s,s.player,t,partial,"NORMAL"))
    eq(Triggers.onAttack(s,s.player,t,partial,"THORNS"),nil);eq(Triggers.onAttack(s,s.player,t,partial,"HP_LOSS"),nil)
    eq(Triggers.onAttack(s,t,s.player,1,"NORMAL"),nil)
end)
test("new poison constructor caps 9999 while existing poison stacks the raw Envenom amount",function()
    local s=state();apply(s,"envenom",10000);local t=s.enemies[1]
    local a=Triggers.onAttack(s,s.player,t,1,"NORMAL");assert(Triggers.resolveEnvenom(s,a.effect));eq(t.statuses.poison,9999)
    assert(Triggers.resolveEnvenom(s,a.effect));eq(t.statuses.poison,19999)
end)
test("dead target player death and final enemy death skip poison without spending Artifact",function()
    for _,condition in ipairs({"target","player","all"}) do
        local s=state();apply(s,"envenom",1);local t=s.enemies[1];t.statuses.artifact=1
        local a=Triggers.onAttack(s,s.player,t,1,"NORMAL");assert(a)
        if condition=="target" then t.hp=0 elseif condition=="player" then s.player.hp=0
        else for _,e in ipairs(s.enemies) do e.hp=0 end end
        local unchanged=freeze(s);eq(Triggers.resolveEnvenom(s,a.effect),false);unchanged();eq(t.statuses.artifact,1)
        eq(Triggers.onAttack(s,s.player,t,1,"NORMAL"),nil)
    end
end)
test("lethal real Thorns prevents the collapsed post-hit Envenom adapter from rescuing the player",function()
    local s=state();apply(s,"envenom",1);local t=s.enemies[1]
    t.statuses.thorns=4;t.statuses.artifact=1;s.player.hp=4
    local lost=Combat.damage(s,s.player,t,1);eq(lost,1);eq(s.player.hp,0)
    eq(Triggers.onAttack(s,s.player,t,lost,"NORMAL"),nil);eq(t.statuses.artifact,1);eq(t.statuses.poison or 0,0)
end)
test("Rage removal is queued at end turn and reapplication receives a new acquisition position",function()
    local s=state();apply(s,"rage",3);apply(s,"after_image",1)
    local actions=Triggers.prepareEndTurn(s);eq(#actions,1);eq(actions[1].effect.op,"removeCardTriggerPower")
    eq(s.player.statuses.rage,3);run(s,actions);eq(s.player.statuses.rage,nil);eq(s.player.statuses.after_image,1)
    apply(s,"rage",5);eq(s.cardTriggerPowerOrder[2].id,"rage");eq(s.cardTriggerPowerOrder[2].order,3)
end)
test("missing registration history is rejected instead of guessing active Power order",function()
    local s=state();s.player.statuses.after_image=1
    local unchanged=freeze(s);eq(pcall(Triggers.prepareUse,s,{type="attack"}),false);unchanged()
    assert(Triggers.recordApplied(s,"after_image"));eq(#Triggers.prepareUse(s,{type="attack"}).beforeUse,1)
    s.player.statuses.rage=3;eq(pcall(Triggers.prepareEndTurn,s),false)
end)
test("late invalid matrix entry rejects before the first real damage",function()
    local s=state();apply(s,"thousand_cuts",2)
    local e=Triggers.prepareUse(s,{type="skill"}).afterUse[1].effect;e.matrix[2].amount=1.5
    local unchanged=freeze(s);eq(pcall(Triggers.resolveDamageAll,s,e,Combat),false);unchanged()
end)
test("malformed acquisition data overflow and incompatible status reject application atomically",function()
    for _,condition in ipairs({"duplicate","priority","serial","amount","definition"}) do
        local s=state();apply(s,"after_image",1)
        if condition=="duplicate" then s.cardTriggerPowerOrder[2]=Combat.copy(s.cardTriggerPowerOrder[1])
        elseif condition=="priority" then s.cardTriggerPowerOrder[1].priority=4
        elseif condition=="serial" then s.cardTriggerPowerSerial=2147483647
        elseif condition=="amount" then s.player.statuses.rage=0/0
        else s.catalog.statuses.rage.stack="none" end
        local unchanged=freeze(s);eq(pcall(Triggers.apply,s,"rage",3),false);unchanged()
    end
end)
print("CARD_TRIGGERS_COMPONENT_PASS "..n)

-- The following cases use the integrated Combat.play without a queue-host
-- substitute. Keep this count separate from the independent component cases.
local playCount=0
local function playTest(name,fn) fn();playCount=playCount+1;print("ok card_triggers_play "..playCount.." - "..name) end
local function playData()
    local d=require("abyss_silent_attack_cards").withCardDefinitions(data())
    return require("abyss_defect_cards").withFoundationCards(d)
end
local function playState(deck,enemies)
    return Combat.new(playData(),{seed=42,cardRandomSeed="42",deck=deck,enemies=enemies or {"cultist","jaw_worm"},orbSlots=3})
end
local function held(s,id)
    for _,c in ipairs(s.hand) do if c.cardId==id then return c end end
    error("missing real hand card "..id)
end
local function play(s,id,target)
    local ok,why=Combat.play(s,held(s,id).uid,target);assert(ok,why)
end
local function inPile(pile,uid)
    for _,c in ipairs(pile) do if c.uid==uid then return true end end
    return false
end
local function arrange(s,handIds,destination)
    local all={}
    for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust}) do for _,c in ipairs(pile) do all[#all+1]=c end end
    s.hand={};s.draw={};s.discard={};s.exhaust={}
    for _,id in ipairs(handIds) do
        local found
        for i,c in ipairs(all) do if c.cardId==id then found=table.remove(all,i);break end end
        s.hand[#s.hand+1]=assert(found,"missing pile fixture card "..id)
    end
    for _,c in ipairs(all) do s[destination or "draw"][#s[destination or "draw"]+1]=c end
end
for _,up in ipairs({false,true}) do
    playTest("After Image real play does not trigger itself and blocks once on the next Strike "..tostring(up),function()
        local s=playState({{cardId="after_image",upgraded=up},"strike"})
        local power=held(s,"after_image");play(s,"after_image")
        eq(s.player.statuses.after_image,1);eq(s.player.block,0);eq(s.energy,2)
        eq(inPile(s.discard,power.uid),false);eq(inPile(s.exhaust,power.uid),false)
        local strike=held(s,"strike");play(s,"strike",1);eq(s.player.block,1);eq(s.energy,1)
        local block
        for _,event in ipairs(s.events) do if event.kind=="block" then block=event end end
        assert(block);eq(inPile(block.frame.discard,strike.uid),false)
        assert(inPile(s.discard,strike.uid));eq(s.cardTriggerPowerOrder[1].id,"after_image")
    end)
    playTest("Rage real Skill affects only later attacks and expires then reacquires at end turn "..tostring(up),function()
        local s=playState({{cardId="rage",upgraded=up},"strike","defend"},{"cultist"})
        play(s,"rage");eq(s.player.block,0);eq(s.energy,3);eq(s.player.statuses.rage,up and 5 or 3)
        play(s,"defend");eq(s.player.block,5)
        play(s,"strike",1);eq(s.player.block,up and 10 or 8)
        assert(Combat.endTurn(s));eq(s.player.statuses.rage,nil);eq(#s.cardTriggerPowerOrder,0)
        play(s,"rage");eq(s.player.statuses.rage,up and 5 or 3);eq(s.cardTriggerPowerOrder[1].order,2)
    end)
    playTest("Thousand Cuts real damage runs after Strike disposal and affects every enemy "..tostring(up),function()
        local s=playState({{cardId="thousand_cuts",upgraded=up},"strike"})
        local hp={s.enemies[1].hp,s.enemies[2].hp};local value=up and 2 or 1
        play(s,"thousand_cuts");eq(s.enemies[1].hp,hp[1]);eq(s.enemies[2].hp,hp[2])
        local strike=held(s,"strike");play(s,"strike",1)
        eq(s.enemies[1].hp,hp[1]-6-value);eq(s.enemies[2].hp,hp[2]-value)
        local cuts=0
        for _,event in ipairs(s.events) do
            if event.kind=="damage" and event.detail.amount==value then
                cuts=cuts+1;assert(inPile(event.frame.discard,strike.uid))
            end
        end
        eq(cuts,2);eq(s.energy,0)
    end)
    playTest("Envenom real Bane first hit applies poison before its conditional second hit "..tostring(up),function()
        local s=playState({{cardId="envenom",upgraded=up},{cardId="bane",upgraded=up}})
        local target=s.enemies[1];local hp=target.hp;local hit=up and 10 or 7
        play(s,"envenom");eq(s.energy,up and 2 or 1);eq(target.statuses.poison or 0,0)
        play(s,"bane",1);eq(target.hp,hp-hit*2);eq(target.statuses.poison,2)
        local timeline={}
        for _,event in ipairs(s.events) do
            if event.kind=="damage" and event.detail.target==target.id then timeline[#timeline+1]="hit"
            elseif event.kind=="status" and event.detail.status=="poison" then timeline[#timeline+1]="poison" end
        end
        eq(table.concat(timeline,","),"hit,poison,hit,poison")
    end)
    playTest("Heat Sinks real Power draws before the next Power applies Focus "..tostring(up),function()
        local deck={{cardId="heat_sinks",upgraded=up},"defragment"};for i=1,12 do deck[#deck+1]="defend" end
        local s=playState(deck);arrange(s,{"heat_sinks","defragment"})
        play(s,"heat_sinks");eq(#s.hand,1);eq(s.player.statuses.heat_sinks,up and 2 or 1)
        play(s,"defragment");local expected=up and 2 or 1;eq(#s.hand,expected);eq(s.player.statuses.focus,1)
        local gained
        for _,event in ipairs(s.events) do
            if event.kind=="status" and event.detail.status=="focus" then gained=event end
        end
        assert(gained);eq(#gained.frame.hand,expected);eq(s.energy,1)
    end)
    playTest("Storm real Power channels after the next Power Focus and never on itself "..tostring(up),function()
        local s=playState({{cardId="storm",upgraded=up},"defragment"})
        play(s,"storm");eq(s.player.statuses.storm,1);eq(#s.orbs.balls,0)
        play(s,"defragment");eq(s.player.statuses.focus,1);eq(#s.orbs.balls,1);eq(s.orbs.balls[1].kind,"lightning")
        local preview=require("abyss_orbs").view(s)
        eq(preview.balls[1].passive,4);eq(preview.balls[1].evoke,9);eq(s.energy,1)
    end)
end
playTest("real After Image and Rage prevent same-card Sharp Hide damage before UseCard cleanup",function()
    for _,up in ipairs({false,true}) do
        local s=playState({"after_image",{cardId="rage",upgraded=up},"strike"},{"cultist"})
        play(s,"after_image");play(s,"rage") -- old After Image also sees the Rage Skill
        eq(s.player.block,1)
        Actors.applyPower(s,s.enemies[1],"sharp_hide",3,s.enemies[1])
        local hp=s.player.hp;play(s,"strike",1)
        eq(s.player.hp,hp);eq(s.player.block,up and 4 or 2)
        local block,hide
        for i,event in ipairs(s.events) do
            if event.kind=="block" then block=i
            elseif event.kind=="status_damage" and event.detail.status=="sharp_hide" then hide=i end
        end
        assert(block and hide and block<hide)
    end
end)
playTest("Thousand Cuts afterUse DAMAGE and old After Image block survive the final native kill",function()
    local s=playState({"thousand_cuts","after_image","slice"},{"cultist"})
    play(s,"thousand_cuts");play(s,"after_image") -- the preexisting Cuts sees this Power after disposal
    s.enemies[1].hp=6
    local slice=held(s,"slice");local real=Triggers.resolveDamageAll;local called=0
    Triggers.resolveDamageAll=function(current,effect,api)
        called=called+1;assert(inPile(current.discard,slice.uid));eq(Combat.outcome(current),"victory")
        return real(current,effect,api)
    end
    local ok,why=pcall(Combat.play,s,slice.uid,1);Triggers.resolveDamageAll=real
    assert(ok,why);eq(why,true);eq(called,1);eq(s.phase,"victory");eq(s.player.block,1)
    assert(inPile(s.discard,slice.uid));eq(s.actionQueue,nil);eq(s.pendingPlay,nil)
end)
playTest("real Envenom Artifact rejection prevents Bane conditional second hit",function()
    local s=playState({"envenom","bane"},{"cultist"});play(s,"envenom")
    local target=s.enemies[1];Actors.applyPower(s,target,"artifact",1,target);local hp=target.hp
    play(s,"bane",1);eq(target.hp,hp-7);eq(target.statuses.artifact,0);eq(target.statuses.poison or 0,0)
end)
playTest("stacking Heat Sinks draws only the old amount before adding the new upgraded Power",function()
    local deck={"heat_sinks",{cardId="heat_sinks",upgraded=true}};for i=1,10 do deck[#deck+1]="defend" end
    local s=playState(deck);arrange(s,{"heat_sinks","heat_sinks"})
    -- Arrange the two real instances in base then upgraded order independently
    -- of shuffle, while preserving their original Combat-created UIDs.
    if s.hand[1].upgraded then s.hand[1],s.hand[2]=s.hand[2],s.hand[1] end
    play(s,"heat_sinks");eq(#s.hand,1);play(s,"heat_sinks")
    eq(#s.hand,1);eq(s.player.statuses.heat_sinks,3);eq(#s.cardTriggerPowerOrder,1)
end)
playTest("Thousand Cuts THORNS pings never add an extra Envenom poison stack",function()
    local s=playState({{cardId="envenom",upgraded=true},"thousand_cuts","slice"})
    play(s,"envenom");play(s,"thousand_cuts");play(s,"slice",1)
    eq(s.enemies[1].statuses.poison,1);eq(s.enemies[2].statuses.poison or 0,0)
end)
playTest("playing a second Storm channels only the preexisting Storm amount",function()
    local s=playState({"storm",{cardId="storm",upgraded=true}})
    play(s,"storm");eq(#s.orbs.balls,0);play(s,"storm")
    eq(s.player.statuses.storm,2);eq(#s.orbs.balls,1);eq(s.orbs.balls[1].kind,"lightning")
end)
playTest("playing a second After Image grants only the old stack amount",function()
    local s=playState({"after_image",{cardId="after_image",upgraded=true}})
    play(s,"after_image");eq(s.player.block,0);play(s,"after_image")
    eq(s.player.statuses.after_image,2);eq(s.player.block,1)
end)
playTest("real play fault after acquisition restores the old Power-order table cards and shuffle RNG",function()
    local deck={"heat_sinks","after_image"};for i=1,4 do deck[#deck+1]="defend" end
    local s=playState(deck);arrange(s,{"heat_sinks","after_image"});play(s,"heat_sinks")
    arrange(s,{"after_image"},"discard")
    local history=s.cardTriggerPowerOrder;local hand,discard=s.hand,s.discard
    local uid=held(s,"after_image").uid;local seed=s.seed;local nextUid=s.nextUid
    local unchanged=freeze(s);local real=Triggers.recordApplied;local fault={after_real_acquisition=true}
    Triggers.recordApplied=function(current,id)
        local result=real(current,id)
        if id=="after_image" then
            assert(current.seed~=seed);eq(#current.hand,1);eq(#current.cardTriggerPowerOrder,2)
            eq(current.player.statuses.after_image,1);error(fault)
        end
        return result
    end
    local ok,why=pcall(Combat.play,s,uid);Triggers.recordApplied=real
    eq(ok,false);eq(why,fault);unchanged();eq(s.cardTriggerPowerOrder,history);eq(s.hand,hand);eq(s.discard,discard)
    eq(s.nextUid,nextUid);eq(s.seed,seed);assert(Combat.play(s,uid));eq(s.player.statuses.after_image,1);eq(#s.cardTriggerPowerOrder,2)
end)
playTest("real Storm evoke fault restores Power history card UID orb objects and independent RNG",function()
    local s=playState({"storm","after_image"});play(s,"storm")
    local Orbs=require("abyss_orbs")
    for i=1,3 do Orbs.channel(s,"lightning",Combat) end
    local history=s.cardTriggerPowerOrder;local first=s.orbs.balls[1];local rng=s.cardRandomRng
    local counter=rng.counter;local uid=held(s,"after_image").uid
    local unchanged=freeze(s);local real=Combat.damage;local fault={after_real_orb_damage=true}
    Combat.damage=function(current,...)
        local lost=real(current,...)
        eq(current.player.statuses.after_image,1);eq(#current.cardTriggerPowerOrder,2)
        assert(current.cardRandomRng.counter>counter);assert(lost>0);error(fault)
    end
    local ok,why=pcall(Combat.play,s,uid);Combat.damage=real
    eq(ok,false);eq(why,fault);unchanged();eq(s.cardTriggerPowerOrder,history);eq(s.cardRandomRng,rng)
    eq(s.cardRandomRng.counter,counter);eq(s.orbs.balls[1],first);eq(held(s,"after_image").uid,uid)
    assert(Combat.play(s,uid));eq(s.player.statuses.after_image,1);assert(s.cardRandomRng.counter>counter);eq(#s.orbs.balls,3)
end)
print("CARD_TRIGGERS_PLAY_PASS "..playCount)
