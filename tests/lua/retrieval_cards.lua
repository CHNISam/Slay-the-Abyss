package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Cards=require("abyss_retrieval_cards")
local Combat=require("abyss_combat")
local Data=require("abyss_data")
local definitions,plays=0,0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function definitionTest(name,fn)fn();definitions=definitions+1;print("ok retrieval definition "..definitions.." - "..name)end
local function playTest(name,fn)fn();plays=plays+1;print("ok retrieval play "..plays.." - "..name)end
local function allData()return Cards.withCards(Cards.withCards(Data,"ironclad"),"defect")end
local function find(d,id)for _,c in ipairs(d.cards.cards)do if c.id==id then return c end end end
local function held(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error("missing "..id)end
local function setup(deck)return Combat.new(allData(),{seed=42,cardRandomSeed="42",enemies={"cultist"},deck=deck})end
local function play(s,id,target)local ok,why=Combat.play(s,held(s,id).uid,target);assert(ok,why)end
local function choose(s,uids)
    local p=assert(s.pendingPileChoice,"real card did not establish pile choice")
    local fn=assert(Combat.choosePile,"Core.choosePile continuation is not connected")
    return fn(s,uids,p.token,p.generation)
end
local function arrange(s,layout)
    local all={}
    for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(pile)do all[#all+1]=c end end
    for _,name in ipairs({"hand","draw","discard","exhaust"})do s[name]={}end
    for _,name in ipairs({"hand","draw","discard","exhaust"})do
        for _,id in ipairs(layout[name] or {})do
            local found
            for i,c in ipairs(all)do if c.cardId==id then found=table.remove(all,i);break end end
            s[name][#s[name]+1]=assert(found,"missing fixture "..id)
        end
    end
    for _,c in ipairs(all)do s.draw[#s.draw+1]=c end
end
local function contains(pile,card)for _,c in ipairs(pile)do if c==card then return true end end;return false end
local function freeze(value)
    local saved,queue={}, {value}
    while #queue>0 do
        local t=table.remove(queue)
        if not saved[t]then
            local entries={};saved[t]=entries
            for k,v in pairs(t)do entries[k]=v;if type(v)=="table"then queue[#queue+1]=v end end
        end
    end
    return function()
        for t,entries in pairs(saved)do
            for k,v in pairs(entries)do eq(t[k],v)end
            for k,v in pairs(t)do eq(entries[k],v)end
        end
    end
end
definitionTest("character helpers replace only native red cards, append missing cards and detach source data",function()
    local original=#Data.cards.cards
    local unchanged=freeze(Data)
    local function missing(ids)
        local count=0;for _,id in ipairs(ids)do if not find(Data,id)then count=count+1 end end;return count
    end
    local redMissing=missing({'headbutt','exhume'});local blueMissing=missing({'hologram','seek'})
    local red=Cards.withCards(Data,"ironclad");local blue=Cards.withCards(Data,"defect")
    eq(#red.cards.cards,original+redMissing);eq(#blue.cards.cards,original+blueMissing)
    assert(find(red,"headbutt") and find(red,"exhume"));eq(find(red,"hologram"),nil)
    assert(find(blue,"hologram") and find(blue,"seek"))
    for _,d in ipairs({red,blue})do
        local ids={};for _,c in ipairs(d.cards.cards)do assert(not ids[c.id],'duplicate prepared card');ids[c.id]=true end
    end
    for _,id in ipairs({'headbutt','exhume'})do
        local native=find(Data,id);local prepared=find(red,id)
        eq(prepared.experimental,true);eq(prepared.target,nil)
        if native then assert(native.target~=nil);eq(native.experimental,nil);assert(prepared~=native) end
        local kept=find(blue,id)
        eq(kept and kept.target,native and native.target)
        eq(kept and kept.experimental,native and native.experimental)
    end
    find(red,"headbutt").cost=8;eq(find(Cards.withCards(Data,"ironclad"),"headbutt").cost,1)
    eq(#Data.cards.cards,original);eq(find(Data,"seek"),nil);unchanged()
end)
definitionTest("Headbutt source damage precedes discard-to-deck choice",function()
    local c=find(allData(),"headbutt");eq(c.type,"attack");eq(c.rarity,"common");eq(c.color,"red");eq(c.cost,1)
    eq(c.effects[1].op,"damage");eq(c.effects[1].value,9);eq(c.upgrade.effects[1].value,12)
    eq(c.effects[2].op,"pileChoice");eq(c.effects[2].mode,"headbutt");eq(c.effects[2].value,1)
end)
definitionTest("Exhume upgrade only changes cost and keeps exhaust",function()
    local c=find(allData(),"exhume");eq(c.type,"skill");eq(c.rarity,"rare");eq(c.cost,1);eq(c.upgrade.cost,0)
    eq(c.exhaust,true);eq(c.upgrade.effects,nil);eq(c.effects[1].mode,"exhume");eq(c.effects[1].value,1)
end)
definitionTest("Hologram upgrade changes block and removes its own exhaust",function()
    local c=find(allData(),"hologram");eq(c.type,"skill");eq(c.rarity,"common");eq(c.color,"blue");eq(c.cost,1)
    eq(c.exhaust,true);eq(c.upgrade.exhaust,false);eq(c.effects[1].value,3);eq(c.upgrade.effects[1].value,5)
    eq(c.effects[2].mode,"hologram");eq(c.upgrade.effects[2].mode,"hologram")
end)
definitionTest("Seek is zero-cost exhaust and chooses one then two",function()
    local c=find(allData(),"seek");eq(c.type,"skill");eq(c.rarity,"rare");eq(c.cost,0);eq(c.exhaust,true)
    eq(c.effects[1].mode,"seek");eq(c.effects[1].value,1);eq(c.upgrade.effects[1].value,2)
end)
definitionTest("unknown character and duplicate registration reject without source mutation",function()
    local d=allData();local unchanged=freeze(d)
    eq(pcall(Cards.withCards,d,"ironclad"),false);unchanged()
    eq(pcall(Cards.withCards,d,"defect"),false);unchanged()
    eq(pcall(Cards.withCards,{cards={cards={{id='headbutt'}}}},"ironclad"),false)
    eq(pcall(Cards.withCards,Data,"silent"),false);eq(pcall(Cards.withCards,{},"defect"),false)
end)
print("RETRIEVAL_CARD_DEFINITIONS_PASS "..definitions)

-- These are genuine Core.play tests. Until root attaches pileChoice and its
-- continuation they remain visibly red; component green is reported separately.
for _,up in ipairs({false,true})do
    playTest("Headbutt native damage pauses before retrieving and before its own disposal "..tostring(up),function()
        local s=setup({{cardId="headbutt",upgraded=up},"strike","defend","bash"})
        arrange(s,{hand={"headbutt","strike"},discard={"defend","bash"}})
        local using=held(s,"headbutt");local chosen=s.discard[1];local hp=s.enemies[1].hp
        play(s,"headbutt",1);eq(s.enemies[1].hp,hp-(up and 12 or 9));eq(s.energy,2)
        eq(s.cardInUse,using);assert(s.pendingPileChoice);eq(s.pendingPileChoice.mode,"headbutt")
        assert(choose(s,{chosen.uid}));eq(s.draw[#s.draw],chosen);assert(contains(s.discard,using))
        eq(s.cardInUse,nil);eq(s.pendingPileChoice,nil);eq(s.actionQueue,nil)
    end)
    playTest("Exhume retrieves an original non-upgraded card and exhausts itself "..tostring(up),function()
        local s=setup({{cardId="exhume",upgraded=up},"defend"})
        arrange(s,{hand={"exhume"},exhaust={"defend"}})
        local used=held(s,"exhume");local chosen=s.exhaust[1]
        play(s,"exhume");eq(s.hand[1],chosen);eq(chosen.upgraded,false);eq(s.energy,up and 3 or 2)
        eq(s.exhaust[1],used);eq(#s.exhaust,1);eq(s.pendingPileChoice,nil);eq(s.cardInUse,nil)
    end)
    playTest("Hologram blocks then selects discard and obeys base/upgraded disposal "..tostring(up),function()
        local s=setup({{cardId="hologram",upgraded=up},"strike","defend"})
        arrange(s,{hand={"hologram"},discard={"strike","defend"}})
        local used=held(s,"hologram");local chosen=s.discard[1];chosen.damageBonus=4
        play(s,"hologram");eq(s.player.block,up and 5 or 3);eq(s.energy,2);eq(s.cardInUse,used)
        assert(choose(s,{chosen.uid}));eq(s.hand[1],chosen);eq(chosen.damageBonus,4)
        assert(contains(up and s.discard or s.exhaust,used));eq(s.cardInUse,nil);eq(s.pendingPileChoice,nil)
    end)
    playTest("Seek searches without drawing under No Draw and exhausts after exact selection "..tostring(up),function()
        local s=setup({{cardId="seek",upgraded=up},"strike","defend","bash"})
        arrange(s,{hand={"seek"},draw={"strike","defend","bash"}});s.player.noDraw=true
        local used=held(s,"seek");local first,second=s.draw[1],s.draw[2]
        play(s,"seek");eq(s.energy,3);eq(s.cardInUse,used);eq(#s.hand,0);eq(s.pendingPileChoice.count,up and 2 or 1)
        assert(choose(s,up and {second.uid,first.uid} or {first.uid}))
        eq(s.hand[1],up and second or first);if up then eq(s.hand[2],first)end
        eq(s.exhaust[1],used);eq(s.cardInUse,nil);eq(s.pendingPileChoice,nil)
    end)
end
playTest("Headbutt lethal final hit skips retrieval and still disposes the played card",function()
    local s=setup({"headbutt","strike"});arrange(s,{hand={"headbutt"},discard={"strike"}})
    local used=held(s,"headbutt");local original=s.discard[1];s.enemies[1].hp=9
    play(s,"headbutt",1);eq(s.phase,"victory");eq(s.pendingPileChoice,nil);eq(#s.draw,0)
    eq(s.discard[1],original);assert(contains(s.discard,used))
end)
playTest("Headbutt cannot choose itself when its original discard pile was empty",function()
    local s=setup({"headbutt"});local used=held(s,"headbutt")
    play(s,"headbutt",1);eq(s.pendingPileChoice,nil);eq(#s.draw,0);eq(s.discard[1],used)
end)
playTest("Exhume filtered single choice restores excluded copies after the remaining eligible pile",function()
    local s=setup({"exhume","exhume","strike","defend"})
    arrange(s,{hand={"exhume"},exhaust={"exhume","strike","defend"}})
    local used=held(s,"exhume");local excluded,left,selected=s.exhaust[1],s.exhaust[2],s.exhaust[3]
    play(s,"exhume");assert(choose(s,{selected.uid}));eq(s.hand[1],selected)
    eq(s.exhaust[1],left);eq(s.exhaust[2],excluded);eq(s.exhaust[3],used)
end)
playTest("invalid continuation does not replay earlier native damage or spend energy twice",function()
    local s=setup({"headbutt","strike","defend"})
    arrange(s,{hand={"headbutt"},discard={"strike","defend"}})
    play(s,"headbutt",1);local hp=s.enemies[1].hp;local energy=s.energy;local used=s.cardInUse
    local unchanged=freeze(s);eq(choose(s,{used.uid}),false);unchanged()
    assert(choose(s,{s.discard[1].uid}));eq(s.enemies[1].hp,hp);eq(s.energy,energy)
end)
playTest("later real reaction failure restores this paused phase without replaying damage",function()
    local s=setup({"headbutt","strike","defend"})
    arrange(s,{hand={"headbutt"},discard={"strike","defend"}})
    play(s,"headbutt",1);local hp=s.enemies[1].hp;local p=s.pendingPileChoice
    local chosen=s.discard[1];local unchanged=freeze(s)
    local AI=require("abyss_enemy_ai");local real=AI.afterCard;local fault={after_real_reaction=true}
    AI.afterCard=function(current,reactions)
        real(current,reactions);eq(current.draw[#current.draw],chosen);error(fault)
    end
    local ok,why=pcall(choose,s,{chosen.uid});AI.afterCard=real
    eq(ok,false);eq(why,fault);unchanged();eq(s.pendingPileChoice,p);eq(s.enemies[1].hp,hp)
    assert(choose(s,{chosen.uid}));eq(s.enemies[1].hp,hp);eq(s.draw[#s.draw],chosen)
end)
print("RETRIEVAL_CARDS_PLAY_PASS "..plays)
