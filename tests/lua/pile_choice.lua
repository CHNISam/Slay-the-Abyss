package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Pile=require("abyss_pile_choice")
local Cards=require("abyss_retrieval_cards")
local Combat=require("abyss_combat")
local Actors=require("abyss_actor")
local Queue=require("abyss_action_queue")
local Data=require("abyss_data")
local generation=23
local n=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();n=n+1;print("ok pile_choice "..n.." - "..name) end
local function data()
    return Cards.withCards(Cards.withCards(Data,"ironclad"),"defect")
end
local function setup(deck,d)
    return Combat.new(d or data(),{seed=42,cardRandomSeed="42",enemies={"cultist"},deck=deck or {}})
end
local function arrange(s,layout)
    local all={}
    for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust}) do for _,card in ipairs(pile) do all[#all+1]=card end end
    for _,name in ipairs({"hand","draw","discard","exhaust"}) do s[name]={} end
    s.cardInUse=nil
    for _,name in ipairs({"hand","draw","discard","exhaust","using"}) do
        for _,id in ipairs(layout[name] or {}) do
            local found
            for i,card in ipairs(all) do if card.cardId==id then found=table.remove(all,i);break end end
            assert(found,"missing fixture instance "..id)
            if name=="using" then assert(not s.cardInUse);s.cardInUse=found else s[name][#s[name]+1]=found end
        end
    end
    for _,card in ipairs(all) do s.draw[#s.draw+1]=card end
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
local function rngUnchanged(s)
    local check=freeze(s.cardRandomRng);local rng=s.cardRandomRng;local seed,nextUid=s.seed,s.nextUid
    return function()check();eq(s.cardRandomRng,rng);eq(s.seed,seed);eq(s.nextUid,nextUid)end
end
local function tokens(s) return assert(s.pendingPileChoice).token end
local function plainData(value,seen)
    local kind=type(value)
    if kind=="table" then
        assert(getmetatable(value)==nil);seen=seen or {};assert(not seen[value]);seen[value]=true
        for key,v in pairs(value) do assert(type(key)=="string" or type(key)=="number");plainData(v,seen) end
        seen[value]=nil
    else assert(kind=="number" or kind=="boolean" or kind=="string") end
end
test("empty source piles finish without a selection, movement or RNG",function()
    for _,mode in ipairs({"headbutt","exhume","hologram","seek"}) do
        local s=setup();local unchanged=freeze(s)
        eq(Pile.begin(s,mode,1,generation),true);eq(Pile.view(s),nil);unchanged()
    end
end)
test("Headbutt one discard auto-moves the same upgraded instance to actual deck top",function()
    local s=setup({"defend","strike"});arrange(s,{draw={"strike"},discard={"defend"}})
    local card=s.discard[1];card.upgraded=true;card.damageBonus=4
    local draw,discard=s.draw,s.discard;local rng=rngUnchanged(s)
    eq(Pile.begin(s,"headbutt",1,generation),true);eq(s.draw,draw);eq(s.discard,discard)
    eq(s.draw[#s.draw],card);eq(#s.discard,0);eq(card.upgraded,true);eq(card.damageBonus,4);rng()
end)
test("Headbutt several discards pause and cannot retrieve the current using card",function()
    local s=setup({"headbutt","defend","strike"})
    arrange(s,{using={"headbutt"},discard={"defend","strike"}})
    local used=s.cardInUse;local selected=s.discard[2];local rng=rngUnchanged(s)
    eq(Pile.begin(s,"headbutt",1,generation),"pause")
    local view=Pile.view(s);eq(#view.candidates,2);eq(view.count,1);eq(view.minCount,1);eq(view.maxCount,1);eq(view.optional,false)
    eq(Pile.choose(s,{used.uid},tokens(s),generation),false)
    assert(Pile.choose(s,{selected.uid},tokens(s),generation));eq(s.cardInUse,used);eq(s.draw[#s.draw],selected);rng()
end)
test("Hologram one discard auto-adds the original card without cloning or upgrading",function()
    local s=setup({"defend"});arrange(s,{discard={"defend"}})
    local card=s.discard[1];local rng=rngUnchanged(s)
    eq(Pile.begin(s,"hologram",1,generation),true);eq(s.hand[1],card);eq(card.upgraded,false);eq(#s.discard,0);rng()
end)
test("Hologram full hand leaves an auto-selected card in its original discard pile",function()
    local deck={};for i=1,10 do deck[i]="defend" end;deck[11]="strike"
    local s=setup(deck);local hand={};for i=1,10 do hand[i]="defend" end
    arrange(s,{hand=hand,discard={"strike"}})
    local card=s.discard[1];local pile=s.discard;local rng=rngUnchanged(s)
    eq(Pile.begin(s,"hologram",1,generation),true);eq(#s.hand,10);eq(s.discard,pile);eq(s.discard[1],card);rng()
end)
test("Hologram several candidates still asks when full and confirmation leaves selection in discard",function()
    local deck={};for i=1,10 do deck[i]="defend" end;deck[11]="strike";deck[12]="bash"
    local s=setup(deck);local hand={};for i=1,10 do hand[i]="defend" end
    arrange(s,{hand=hand,discard={"strike","bash"}})
    local card=s.discard[2];eq(Pile.begin(s,"hologram",1,generation),"pause")
    assert(Pile.choose(s,{card.uid},tokens(s),generation));eq(#s.hand,10);eq(s.discard[2],card);eq(Pile.active(s),false)
end)
test("Seek plus auto-all follows original draw group order without RNG",function()
    local s=setup({"strike","defend"});arrange(s,{draw={"strike","defend"}})
    local first,second=s.draw[1],s.draw[2];local rng=rngUnchanged(s)
    eq(Pile.begin(s,"seek",2,generation),true);eq(s.hand[1],first);eq(s.hand[2],second);eq(#s.draw,0);rng()
end)
test("Seek plus with fewer source cards selects only the available original card",function()
    local s=setup({"defend"});arrange(s,{draw={"defend"}})
    local card=s.draw[1];eq(Pile.begin(s,"seek",2,generation),true);eq(s.hand[1],card);eq(#s.draw,0)
end)
test("Seek selected click order determines the kept card at nine-card hand capacity",function()
    local deck={};for i=1,9 do deck[i]="defend" end
    deck[10]="strike";deck[11]="bash";deck[12]="headbutt"
    local s=setup(deck);local hand={};for i=1,9 do hand[i]="defend" end
    arrange(s,{hand=hand,draw={"strike","bash","headbutt"}})
    local keep,overflow=s.draw[3],s.draw[1];local rng=rngUnchanged(s)
    eq(Pile.begin(s,"seek",2,generation),"pause");eq(Pile.view(s).count,2)
    eq(Pile.choose(s,{keep.uid},tokens(s),generation),false)
    assert(Pile.choose(s,{keep.uid,overflow.uid},tokens(s),generation))
    eq(#s.hand,10);eq(s.hand[10],keep);eq(s.discard[1],overflow);eq(s.draw[1].cardId,"bash");rng()
end)
test("Seek full hand overflow is a pile move without manual discard counters or energy triggers",function()
    local d=require("abyss_silent").withFoundationCards(data())
    local deck={};for i=1,10 do deck[i]="defend" end;deck[11]="tactician";deck[12]="reflex"
    local s=setup(deck,d);local hand={};for i=1,10 do hand[i]="defend" end
    arrange(s,{hand=hand,draw={"tactician","reflex"}})
    local first,second=s.draw[1],s.draw[2];local energy,discarded=s.energy,s.discardedThisTurn
    eq(Pile.begin(s,"seek",2,generation),true)
    eq(s.discard[1],first);eq(s.discard[2],second);eq(s.energy,energy);eq(s.discardedThisTurn,discarded);eq(#s.hand,10)
end)
test("Exhume one non-Exhume auto-moves its original upgrade and metadata unchanged",function()
    local s=setup({"defend"});arrange(s,{exhaust={"defend"}})
    local card=s.exhaust[1];card.upgraded=true;card.damageBonus=7
    local rng=rngUnchanged(s);eq(Pile.begin(s,"exhume",1,generation),true)
    eq(s.hand[1],card);eq(card.upgraded,true);eq(card.damageBonus,7);eq(#s.exhaust,0);rng()
end)
test("Exhume excludes every base and upgraded copy of itself",function()
    local s=setup({"exhume",{cardId="exhume",upgraded=true}})
    arrange(s,{exhaust={"exhume","exhume"}});local unchanged=freeze(s)
    eq(Pile.begin(s,"exhume",1,generation),true);unchanged();eq(Pile.active(s),false)
end)
test("Exhume raw size above one pauses even when filtering leaves only one candidate",function()
    local s=setup({"exhume","strike"});arrange(s,{exhaust={"exhume","strike"}})
    local card=s.exhaust[2];eq(Pile.begin(s,"exhume",1,generation),"pause")
    eq(#Pile.view(s).candidates,1);eq(Pile.view(s).candidates[1].uid,card.uid)
    assert(Pile.choose(s,{card.uid},tokens(s),generation));eq(s.hand[1],card);eq(s.exhaust[1].cardId,"exhume")
end)
test("Exhume restores excluded cards at exhaust tail in their original relative order",function()
    local s=setup({"exhume","strike",{cardId="exhume",upgraded=true},"defend"})
    arrange(s,{exhaust={"exhume","strike","exhume","defend"}})
    local a,b,c,chosen=s.exhaust[1],s.exhaust[2],s.exhaust[3],s.exhaust[4];local pile=s.exhaust
    eq(Pile.begin(s,"exhume",1,generation),"pause")
    -- The pure-data headless projection keeps ownership in the original pile
    -- while asking; final restoration matches the source's temporary filter.
    eq(s.exhaust[1],a)
    assert(Pile.choose(s,{chosen.uid},tokens(s),generation))
    eq(s.exhaust,pile);eq(s.exhaust[1],b);eq(s.exhaust[2],a);eq(s.exhaust[3],c);eq(s.hand[1],chosen)
end)
test("Exhume full hand skips before opening a filtered choice",function()
    local deck={};for i=1,10 do deck[i]="defend" end;deck[11]="strike";deck[12]="exhume"
    local s=setup(deck);local hand={};for i=1,10 do hand[i]="defend" end
    arrange(s,{hand=hand,exhaust={"strike","exhume"}});local unchanged=freeze(s)
    eq(Pile.begin(s,"exhume",1,generation),true);unchanged();eq(Pile.active(s),false)
end)
test("retrieval is not drawing and ignores No Draw without resetting Eviscerate stored cost",function()
    local d=require("abyss_silent_discard_cards").withCardDefinitions(data())
    for _,mode in ipairs({"exhume","hologram","seek"}) do
        local s=setup({"eviscerate"},d);local source=mode=="exhume" and "exhaust" or mode=="hologram" and "discard" or "draw"
        arrange(s,{[source]={"eviscerate"}})
        local card=s[source][1];card.storedDiscardCost=2;s.discardedThisTurn=5;s.player.noDraw=true
        local energy=s.energy;eq(Pile.begin(s,mode,1,generation),true)
        eq(s.hand[1],card);eq(card.storedDiscardCost,2);eq(s.discardedThisTurn,5);eq(s.energy,energy)
    end
end)
test("only Exhume applies explicit Corruption turn cost; other hand retrievals do not",function()
    for _,mode in ipairs({"exhume","hologram","seek"}) do
        local s=setup({"defend","strike"})
        local source=mode=="exhume" and "exhaust" or mode=="hologram" and "discard" or "draw"
        arrange(s,{hand={"strike"},[source]={"defend"}})
        local def=require("abyss_corruption").definition();s.catalog.statuses.corruption=def
        -- Existing Power + a not-yet-modified source instance is a component
        -- boundary fixture, not a simulated Corruption card application.
        Actors.applyPower(s,s.player,"corruption",1,s.player)
        local card=s[source][1];eq(Pile.begin(s,mode,1,generation),true)
        eq(s.hand[2],card);eq(card.combatCost,nil);eq(card.turnCost,mode=="exhume" and 0 or nil)
    end
end)
test("Seek overflow invokes the genuine hand-wide Corruption hook but Hologram staying does not",function()
    for _,mode in ipairs({"seek","hologram"}) do
        local deck={};for i=1,10 do deck[i]="defend" end;deck[11]="strike"
        local s=setup(deck);local hand={};for i=1,10 do hand[i]="defend" end
        local source=mode=="seek" and "draw" or "discard";arrange(s,{hand=hand,[source]={"strike"}})
        s.catalog.statuses.corruption=require("abyss_corruption").definition()
        Actors.applyPower(s,s.player,"corruption",1,s.player)
        local card=s.hand[1];eq(Pile.begin(s,mode,1,generation),true)
        eq(card.combatCost,mode=="seek" and 0 or nil);eq(s.discardedThisTurn or 0,0)
    end
end)
test("view and pending are pure detached data and support more than ten candidates",function()
    local deck={};for i=1,17 do deck[i]="defend" end
    local s=setup(deck);local draw={};for i=1,17 do draw[i]="defend" end;arrange(s,{draw=draw})
    local rng=rngUnchanged(s);eq(Pile.begin(s,"seek",2,generation),"pause")
    plainData(s.pendingPileChoice);local unchanged=freeze(s);local view=Pile.view(s);unchanged()
    eq(#view.candidates,17);plainData(view);view.candidates[1].uid=99999;view.candidateUids[1]=99999
    eq(Pile.view(s).candidates[1].uid,s.pendingPileChoice.candidateUids[1]);rng()
end)
test("Seek manual candidates sort temporary display by rarity then name with statuses last",function()
    local s=setup({"defend","strike","bash","exhume"})
    arrange(s,{draw={"strike","defend","bash","exhume"}})
    s.catalog.cards.strike.name="B";s.catalog.cards.defend.name="A";s.catalog.cards.bash.name="C"
    s.catalog.cards.bash.type="status";s.catalog.cards.bash.rarity="special"
    local original={};for i,c in ipairs(s.draw) do original[i]=c end
    eq(Pile.begin(s,"seek",1,generation),"pause")
    local view=Pile.view(s);eq(view.candidates[1].cardId,"exhume");eq(view.candidates[2].cardId,"defend")
    eq(view.candidates[3].cardId,"strike");eq(view.candidates[4].cardId,"bash")
    for i,c in ipairs(original) do eq(s.draw[i],c) end
end)
test("bad counts duplicates missing UIDs and foreign-pile choices are atomic refusals",function()
    local s=setup({"strike","defend","bash","headbutt"})
    arrange(s,{hand={"headbutt"},discard={"strike","defend","bash"}})
    eq(Pile.begin(s,"hologram",1,generation),"pause")
    local uid=s.discard[1].uid;local token=tokens(s);local unchanged=freeze(s)
    for _,bad in ipairs({{}, {uid,uid}, {99999}, {s.hand[1].uid}, {[2]=uid}, {[1]=uid,extra=true}}) do
        eq(Pile.choose(s,bad,token,generation),false);unchanged()
    end
    eq(Pile.choose(s,{uid},token+1,generation),false);unchanged()
    eq(Pile.choose(s,{uid},token,generation+1),false);unchanged()
    eq(Pile.choose(s,{uid},token,"23"),false);unchanged()
end)
test("pile order identity upgrade using-card or turn changes invalidate an old selection",function()
    for _,change in ipairs({"order","uid","upgrade","using","turn","hand"}) do
        local s=setup({"headbutt","strike","defend","bash"})
        arrange(s,{using={"headbutt"},discard={"strike","defend","bash"}})
        eq(Pile.begin(s,"headbutt",1,generation),"pause");local p=s.pendingPileChoice;local uid=s.discard[1].uid
        if change=="order" then s.discard[1],s.discard[2]=s.discard[2],s.discard[1]
        elseif change=="uid" then s.discard[1].uid=99999
        elseif change=="upgrade" then s.discard[1].upgraded=true
        elseif change=="using" then s.cardInUse=nil
        elseif change=="turn" then s.turn=s.turn+1
        else s.hand[#s.hand+1]=table.remove(s.discard) end
        local unchanged=freeze(s);eq(Pile.choose(s,{uid},p.token,generation),false);unchanged();eq(Pile.view(s),nil)
    end
end)
test("pending generation and source metadata tampering are refused without movement",function()
    for _,field in ipairs({"source","destination","count","generation","token"}) do
        local s=setup({"strike","defend"});arrange(s,{discard={"strike","defend"}})
        eq(Pile.begin(s,"hologram",1,generation),"pause");local p=s.pendingPileChoice
        if field=="source" then p.source="draw" elseif field=="destination" then p.destination="draw"
        else p[field]=p[field]+1 end
        local unchanged=freeze(s);eq(Pile.choose(s,{s.discard[1].uid},p.token,generation),false);unchanged()
    end
end)
test("duplicate pile UIDs using-card collisions invalid mode and token overflow reject before changes",function()
    for _,change in ipairs({"duplicate","using","serial","mode","generation"}) do
        local s=setup({"strike","defend"});arrange(s,{discard={"strike","defend"}})
        if change=="duplicate" then s.discard[2].uid=s.discard[1].uid
        elseif change=="using" then s.cardInUse=s.discard[1]
        elseif change=="serial" then s.pileChoiceSerial=2147483647 end
        local unchanged=freeze(s)
        local mode=change=="mode" and "unknown" or "hologram"
        local g=generation;if change=="generation" then g=false end
        eq(pcall(Pile.begin,s,mode,1,g),false);unchanged()
    end
end)
test("NoDraw retrieval picks Void without running its real energy-on-draw trigger",function()
    local d=require("abyss_defect_utility_cards").withCards(data())
    local s=setup({"void"},d);arrange(s,{draw={"void"}});s.player.noDraw=true
    local c=s.draw[1];local energy=s.energy;eq(Pile.begin(s,"seek",1,generation),true)
    eq(s.hand[1],c);eq(s.energy,energy)
end)
test("component continuation pauses before a real later effect and resumes once",function()
    local s=setup({"strike","defend"});arrange(s,{discard={"strike","defend"}})
    local actions={{kind="effect",effect={op="pileChoice",mode="hologram",value=1}},
        {kind="effect",effect={op="block",value=5}}}
    local handlers={effect=function(current,a)
        if a.effect.op=="pileChoice" then return Pile.begin(current,a.effect.mode,a.effect.value,generation) end
        Combat.applyEffects(current,{a.effect},current.player);return true
    end}
    Queue.start(s,actions);eq(Queue.run(s,handlers),"pause");eq(s.player.block,0)
    local token=tokens(s);local card=s.discard[1]
    assert(Pile.choose(s,{card.uid},token,generation));eq(s.player.block,0)
    assert(Queue.resume(s,handlers));eq(s.player.block,5);eq(s.hand[1],card);eq(Pile.choose(s,{card.uid},token,generation),false)
end)
test("copied serialized pause can choose its own instance without changing the original state",function()
    local s=setup({"strike","defend"});arrange(s,{discard={"strike","defend"}})
    eq(Pile.begin(s,"hologram",1,generation),"pause");local original=s.discard[1];local unchanged=freeze(s)
    local replay=Combat.copy(s);assert(replay.discard[1]~=original)
    assert(Pile.choose(replay,{original.uid},tokens(replay),generation));eq(replay.hand[1].uid,original.uid)
    assert(replay.hand[1]~=original);unchanged();assert(Pile.active(s))
end)
test("a real move-hook failure restores the current selection objects costs and piles",function()
    local deck={};for i=1,10 do deck[i]="defend" end;deck[11]="strike";deck[12]="bash"
    local s=setup(deck);local hand={};for i=1,10 do hand[i]="defend" end
    arrange(s,{hand=hand,draw={"strike","bash"}})
    s.catalog.statuses.corruption=require("abyss_corruption").definition();Actors.applyPower(s,s.player,"corruption",1,s.player)
    eq(Pile.begin(s,"seek",1,generation),"pause")
    local p=s.pendingPileChoice;local uid=s.draw[1].uid;local unchanged=freeze(s)
    local Cost=require("abyss_corruption");local real=Cost.onDrawOrDiscard;local fault={after_real_hook=true}
    Cost.onDrawOrDiscard=function(current)
        real(current);eq(#current.draw,1);eq(current.hand[1].combatCost,0);error(fault)
    end
    local ok,why=pcall(Pile.choose,s,{uid},p.token,generation);Cost.onDrawOrDiscard=real
    eq(ok,false);eq(why,fault);unchanged();eq(s.pendingPileChoice,p)
    assert(Pile.choose(s,{uid},p.token,generation));eq(s.discard[1].uid,uid);eq(s.hand[1].combatCost,0)
end)
test("victory death and another selection never open a new retrieval modal",function()
    for _,kind in ipairs({"victory","death"}) do
        local s=setup({"strike","defend"});arrange(s,{discard={"strike","defend"}})
        if kind=="victory" then s.enemies[1].hp=0 else s.player.hp=0 end
        local unchanged=freeze(s);eq(Pile.begin(s,"headbutt",1,generation),true);unchanged()
    end
    local s=setup({"strike","defend"});arrange(s,{discard={"strike","defend"}});s.pendingHandChoice={}
    local unchanged=freeze(s);eq(pcall(Pile.begin,s,"hologram",1,generation),false);unchanged()
end)
print("PILE_CHOICE_COMPONENT_PASS "..n)
