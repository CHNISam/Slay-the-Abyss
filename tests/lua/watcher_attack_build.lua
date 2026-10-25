package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Cards=require("abyss_watcher_attack_cards")
local Combat=require("abyss_combat")
local Watcher=require("abyss_watcher_cards")
local Data=require("abyss_data")
local count=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();count=count+1;print("ok watcher_attack_build "..count.." - "..name) end
local function prepared() return Cards.withCards(Watcher.withFoundationCards(Data)) end
local function battle(deck,enemies)
    local s=Combat.new(prepared(),{seed=42,cardRandomSeed="42",enemies=enemies or {"cultist"},enableStances=true,deck=deck})
    for _,e in ipairs(s.enemies) do e.hp=1000;e.maxHp=1000 end
    return s
end
local function find(pile,id)
    for _,c in ipairs(pile) do if c.cardId==id then return c end end
    error("missing "..id)
end
local function play(s,id,target)
    local ok,why=Combat.play(s,find(s.hand,id).uid,target or 1)
    assert(ok,why);return ok
end
local function has(pile,id)
    for _,c in ipairs(pile) do if c.cardId==id then return c end end
end
local function fixtureDraw(s)
    -- Reposition genuine initialized instances, keeping UIDs and card count.
    for i=#s.hand,1,-1 do
        if s.hand[i].cardId=="defend" then s.draw[#s.draw+1]=table.remove(s.hand,i) end
    end
end
local function unchanged(state)
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
test("eighteen independent source definitions and original data isolation",function()
    local n=#Data.cards.cards;local d=prepared();local map={}
    for _,c in ipairs(d.cards.cards) do map[c.id]=c end
    for _,id in ipairs({"consecrate","bowling_bash","flying_sleeves","follow_up","crush_joints","sash_whip","empty_mind","evaluate","halt","carve_reality","deceive_reality","sanctity","signature_move","scrawl","brilliance","insight","safety","smite"}) do
        local c=assert(map[id]);assert(c.sourceId and c.text and c.upgradeText and c.sts_name)
        assert(c.name:find("[\128-\255]"));eq(c.color,c.rarity=="special" and "colorless" or "purple")
    end
    eq(map.scrawl.cost,1);eq(map.scrawl.upgrade.cost,0);eq(map.scrawl.exhaust,true)
    for _,id in ipairs({"insight","safety","smite"}) do eq(map[id].selfRetain,true);eq(map[id].exhaust,true) end
    assert(not pcall(Cards.withCards,d));eq(#Data.cards.cards,n)
    d.cards.cards[1].cost=999;assert(Data.cards.cards[1].cost~=999)
end)
test("Bowling preparation freezes separate hits and ignores dead or escaped enemies",function()
    local s=battle({"bowling_bash"},{"cultist","cultist","cultist"})
    s.enemies[2].hp=0;s.enemies[3].escaped=true
    local p=Cards.prepareEffect(s,{op="bowlingBash",value=7})
    eq(#p,1);eq(p[1].op,"damage");eq(p[1].value,7)
    s.enemies[2].hp=1000;eq(#p,1)
    assert(not pcall(Cards.prepareEffect,s,{op="bowlingBash",value=math.huge}))
end)
test("Halt snapshots each Dexterity/Frail calculation and chooses stance later",function()
    local s=battle({"halt"});s.player.statuses.dexterity=2;s.player.statuses.frail=1
    local preparedEffect=Cards.prepareEffect(s,{op="halt",value=3,wrathValue=9})[1]
    eq(preparedEffect.value,3);eq(preparedEffect.wrathValue,8)
    s.player.statuses.dexterity=20;s.player.stance="Wrath"
    local p=Cards.planEffect(s,preparedEffect);eq(#p,1);eq(p[1].effect.value,11);eq(p[1].effect.fixed,true)
    s.player.stance="Neutral";eq(Cards.planEffect(s,preparedEffect)[1].effect.value,3)
    assert(not pcall(Cards.planEffect,s,{op="halt",value=3,wrathValue=9}))
end)
test("previous-card plan includes current card and Brilliance adds Mantra once",function()
    local s=battle({"brilliance"});s.cardsPlayedThisCombat={{type="attack"},{type="skill"}}
    eq(Cards.planEffect(s,{op="previousCardType",cardType="attack",effect={op="energy",value=1}})[1].effect.value,1)
    eq(#Cards.planEffect(s,{op="previousCardType",cardType="skill",effect={op="draw",value=2}}),0)
    s.mantraGained=9;local i=s.hand[1];local c=Cards.adaptDefinition(s,i,s.catalog.cards.brilliance)
    eq(c.effects[1].value,21);eq(s.catalog.cards.brilliance.effects[1].value,12)
    s.mantraGained=2147483647;assert(not pcall(Cards.adaptDefinition,s,i,s.catalog.cards.brilliance))
end)
test("Consecrate and Flying Sleeves use real area and repeated attack damage",function()
    for _,up in ipairs({false,true}) do
        local s=battle({{cardId="consecrate",upgraded=up}},{"cultist","cultist"})
        play(s,"consecrate");eq(s.enemies[1].hp,1000-(up and 8 or 5));eq(s.enemies[2].hp,s.enemies[1].hp)
        s=battle({{cardId="flying_sleeves",upgraded=up}});s.player.statuses.strength=2
        play(s,"flying_sleeves");eq(s.enemies[1].hp,1000-2*((up and 6 or 4)+2))
    end
end)
test("Bowling Bash freezes live enemy count and applies Strength to every hit",function()
    local s=battle({"bowling_bash"},{"cultist","cultist","cultist"})
    s.player.statuses.strength=2;s.enemies[3].hp=0
    play(s,"bowling_bash");eq(s.enemies[1].hp,982);eq(s.enemies[2].hp,1000)
end)
test("Follow-Up first card has no refund and upgrade refunds after preceding attack",function()
    local s=battle({"follow_up"});play(s,"follow_up");eq(s.energy,2);eq(s.enemies[1].hp,993)
    s=battle({"strike",{cardId="follow_up",upgraded=true}})
    play(s,"strike");play(s,"follow_up");eq(s.energy,2);eq(s.enemies[1].hp,983)
end)
test("Crush Joints and Sash Whip conditions use different previous card types",function()
    local s=battle({"defend",{cardId="crush_joints",upgraded=true},"sash_whip"})
    play(s,"defend");play(s,"crush_joints");eq(s.enemies[1].hp,990);eq(s.enemies[1].statuses.vulnerable,2)
    play(s,"sash_whip");eq(s.enemies[1].hp,978);eq(s.enemies[1].statuses.weak,1)
    s=battle({"defend","sash_whip"});play(s,"defend");play(s,"sash_whip");eq(s.enemies[1].statuses.weak,nil)
end)
test("Follow-Up previous attack persists across actual endTurn",function()
    local s=battle({"strike","follow_up"});play(s,"strike")
    assert(Combat.endTurn(s));play(s,"follow_up");eq(s.energy,3)
end)
test("Follow-Up damage killing final enemy cancels its queued energy refund",function()
    local s=battle({"strike","follow_up"});play(s,"strike");s.enemies[1].hp=1
    play(s,"follow_up");eq(s.energy,1);eq(s.phase,"victory")
end)
test("Empty Mind draws before Calm exit and respects NoDraw without blocking exit",function()
    local s=battle({"empty_mind","defend","defend","defend"});fixtureDraw(s);s.player.stance="Calm"
    play(s,"empty_mind");eq(#s.hand,2);eq(s.player.stance,"Neutral");eq(s.energy,4)
    s=battle({{cardId="empty_mind",upgraded=true},"defend","defend","defend"});fixtureDraw(s)
    s.player.stance="Calm";s.player.noDraw=true;play(s,"empty_mind")
    eq(#s.hand,0);eq(s.player.stance,"Neutral");eq(s.energy,4)
end)
test("Halt real play doubles Dexterity contribution with independently floored Frail",function()
    local s=battle({"halt"});s.player.statuses.dexterity=2;s.player.statuses.frail=1;s.player.stance="Wrath"
    play(s,"halt");eq(s.player.block,11)
    s=battle({{cardId="halt",upgraded=true}});s.player.stance="Wrath";play(s,"halt");eq(s.player.block,18)
end)
test("Evaluate creates unupgraded Insight inside draw without moving existing top",function()
    local s=battle({{cardId="evaluate",upgraded=true},"defend","defend"});fixtureDraw(s)
    local beforeTop=s.draw[#s.draw].uid;local before=s.nextUid
    play(s,"evaluate");eq(s.player.block,10);eq(#s.draw,3);eq(s.draw[#s.draw].uid,beforeTop)
    local c=find(s.draw,"insight");eq(c.upgraded,false);assert(c.uid>=before)
    eq(#s.hand,0)
end)
test("Carve and Deceive upgrades preserve unupgraded generated cards",function()
    local s=battle({{cardId="carve_reality",upgraded=true},{cardId="deceive_reality",upgraded=true}})
    play(s,"carve_reality");eq(s.enemies[1].hp,990);eq(find(s.hand,"smite").upgraded,false)
    play(s,"deceive_reality");eq(s.player.block,7);eq(find(s.hand,"safety").upgraded,false)
    play(s,"smite");eq(s.enemies[1].hp,978);assert(has(s.exhaust,"smite"))
end)
test("Sanctity draws after preceding skill and NoDraw still allows Block",function()
    local s=battle({"defend","sanctity","defend","defend"});fixtureDraw(s)
    -- One genuine skill is returned to hand to establish previous-card history.
    s.hand[#s.hand+1]=table.remove(s.draw)
    play(s,"defend");play(s,"sanctity");eq(s.player.block,11);eq(#s.hand,2)
    s=battle({"defend",{cardId="sanctity",upgraded=true},"defend"});fixtureDraw(s)
    s.hand[#s.hand+1]=table.remove(s.draw);play(s,"defend");s.player.noDraw=true
    play(s,"sanctity");eq(s.player.block,14);eq(#s.hand,0)
end)
test("Signature Move rejects another attack instance with no mutation",function()
    local s=battle({"signature_move","strike","defend"});local e=s.energy;local hp=s.enemies[1].hp
    local ok=Combat.play(s,find(s.hand,"signature_move").uid,1);eq(ok,false);eq(s.energy,e);eq(s.enemies[1].hp,hp)
    play(s,"strike");play(s,"signature_move");eq(s.enemies[1].hp,964)
    s=battle({"signature_move","signature_move"});eq(Combat.play(s,s.hand[1].uid,1),false)
end)
test("Scrawl upgrade draws genuine deck to ten before exhausting",function()
    local deck={{cardId="scrawl",upgraded=true}}
    for _=1,14 do deck[#deck+1]="defend" end
    local s=battle(deck)
    if not has(s.hand,"scrawl") then
        for i,c in ipairs(s.draw) do if c.cardId=="scrawl" then s.draw[i],s.hand[1]=s.hand[1],c;break end end
    end
    play(s,"scrawl");eq(#s.hand,10);eq(#s.draw,4);eq(s.energy,3);assert(has(s.exhaust,"scrawl"))
end)
test("Brilliance combines Mantra with Strength and stance once",function()
    local s=battle({"brilliance"});s.mantraGained=5;s.player.statuses.strength=2;s.player.stance="Divinity"
    play(s,"brilliance");eq(s.enemies[1].hp,943)
    s=battle({{cardId="brilliance",upgraded=true}});s.mantraGained=5;play(s,"brilliance");eq(s.enemies[1].hp,979)
end)
test("generated cards retain through actual endTurn and exhaust when played",function()
    local s=battle({"deceive_reality","insight","defend","defend"});fixtureDraw(s)
    play(s,"deceive_reality");local safety=find(s.hand,"safety");local insight=find(s.hand,"insight")
    assert(Combat.endTurn(s));eq(find(s.hand,"safety"),safety);eq(find(s.hand,"insight"),insight)
    play(s,"safety");eq(s.player.block,12);assert(has(s.exhaust,"safety"))
    play(s,"insight");assert(has(s.exhaust,"insight"))
end)
test("upgraded special cards use their own upgrade values and remain exhaustible",function()
    local s=battle({{cardId="insight",upgraded=true},"defend","defend","defend"});fixtureDraw(s)
    play(s,"insight");eq(#s.hand,3);assert(has(s.exhaust,"insight"))
    s=battle({{cardId="safety",upgraded=true},{cardId="smite",upgraded=true}})
    play(s,"safety");eq(s.player.block,16);play(s,"smite");eq(s.enemies[1].hp,984)
    assert(has(s.exhaust,"safety") and has(s.exhaust,"smite"))
end)
test("Scrawl NoDraw and Halt negative Dexterity honor shared arithmetic",function()
    local s=battle({"scrawl","defend","defend"});fixtureDraw(s);s.player.noDraw=true
    play(s,"scrawl");eq(#s.hand,0);eq(#s.draw,2);eq(s.energy,2);assert(has(s.exhaust,"scrawl"))
    s=battle({"halt"});s.player.stance="Wrath";s.player.statuses.dexterity=-5
    play(s,"halt");eq(s.player.block,4)
end)
test("Evaluate empty draw skips card RNG while singleton draw consumes one call",function()
    local s=battle({"evaluate"});local before=s.cardRandomRng.counter
    play(s,"evaluate");eq(s.cardRandomRng.counter,before);eq(#s.draw,1);eq(s.draw[1].cardId,"insight")
    s=battle({"evaluate","defend"});fixtureDraw(s);before=s.cardRandomRng.counter
    play(s,"evaluate");eq(s.cardRandomRng.counter,before+1)
    eq(s.draw[1].cardId,"insight");eq(s.draw[2].cardId,"defend")
end)
test("real insertion RNG then thrown error restores all original state references",function()
    local s=battle({"evaluate","defend","defend"});fixtureDraw(s)
    local uid=find(s.hand,"evaluate").uid;local verify=unchanged(s)
    local R=require("abyss_sts_random");local original=R.randomInt;local calls=0
    R.randomInt=function(...)
        calls=calls+1;original(...);error("injected after genuine card insertion RNG",0)
    end
    local called,why=pcall(Combat.play,s,uid,1);R.randomInt=original
    eq(called,false);assert(tostring(why):find("injected after genuine",1,true));eq(calls,1)
    verify() -- includes Block, costs, UID, history, queue, events and RNG words.
    play(s,"evaluate");eq(s.player.block,6);eq(#s.draw,3)
end)
print("watcher_attack_build: "..count.." passed")
