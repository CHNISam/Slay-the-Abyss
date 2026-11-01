package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Discard = require("abyss_combat"), require("abyss_discard")
local data = require("abyss_data")
local count = 0
local function eq(a,b,label) assert(a==b,(label or "value")..": "..tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();count=count+1;print("ok silent discard "..count.." - "..name) end
local function fresh(ids)
    local d=Combat.copy(data)
    for _,id in ipairs({"tactician","reflex"}) do
        d.cards.cards[#d.cards.cards+1]={id=id,cost=-2,type="skill",effects={}}
    end
    return Combat.new(d,{deck=ids or {},enemies={"jaw_worm"},seed=42})
end
local function find(s,id)
    for _,card in ipairs(s.hand) do if card.cardId==id then return card end end
    error("missing "..id)
end
local function start(s,n)
    local ok,token=Discard.begin(s,n);assert(ok,token);return token
end

test("empty and zero requests leave no pending action",function()
    local s=fresh();eq(start(s,1),nil);eq(Discard.active(s),false)
    s=fresh({"defend"});eq(start(s,0),nil);eq(#s.hand,1);eq(#s.discard,0)
end)
test("one card auto-discards without waiting for choice",function()
    local s=fresh({"tactician"});local card=s.hand[1];local energy=s.energy
    eq(start(s,1),nil);eq(Discard.active(s),false);eq(s.energy,energy+1)
    eq(s.discard[1],card);eq(#s.hand,0)
end)
test("insufficient hand auto-discards from top with upgraded gains",function()
    local s=fresh({"tactician",{cardId="tactician",upgraded=true}})
    local top=s.hand[#s.hand];local bottom=s.hand[1];local energy=s.energy
    eq(start(s,5),nil);eq(s.discard[1],top);eq(s.discard[2],bottom);eq(s.energy,energy+3)
    local gains={}
    for _,e in ipairs(s.events) do if e.kind=="discard_energy" then gains[#gains+1]=e.detail.uid end end
    eq(gains[1],bottom.uid);eq(gains[2],top.uid)
end)
test("selection is serializable and does not move cards before confirmation",function()
    local s=fresh({"defend","strike","bash"});local original=s.hand[1]
    local token=start(s,1);assert(type(token)=="number");eq(s.pendingDiscard.serial,token)
    eq(#s.hand,3);eq(#s.discard,0);eq(s.pendingDiscard.handUids[1],original.uid)
    assert(Discard.choose(s,{original.uid},token));eq(s.discard[1],original);eq(#s.hand,2)
    eq(Discard.choose(s,{original.uid},token),false)
end)
test("duplicate missing wrong-count and sparse selections reject without mutation",function()
    local s=fresh({"defend","strike","bash"});local token=start(s,2)
    local a=s.hand[1].uid;local pending=s.pendingDiscard;local events=#s.events
    for _,uids in ipairs({{a,a},{99999,a},{a},{[1]=a,[3]=s.hand[2].uid},{a,a,extra=true}}) do
        eq(Discard.choose(s,uids,token),false);eq(#s.hand,3);eq(#s.discard,0)
        eq(s.pendingDiscard,pending);eq(#s.events,events)
    end
    eq(Discard.choose(s,{a,s.hand[2].uid},token+1),false)
end)
test("changed hand or turn invalidates an old selection",function()
    local s=fresh({"defend","strike"});local token=start(s,1);local uid=s.hand[1].uid
    s.hand[1],s.hand[2]=s.hand[2],s.hand[1]
    eq(Discard.choose(s,{uid},token),false);eq(#s.discard,0)
    s.hand[1],s.hand[2]=s.hand[2],s.hand[1];s.turn=s.turn+1
    eq(Discard.choose(s,{uid},token),false)
end)
test("new pending action never reuses an old token",function()
    local s=fresh({"defend","strike","bash"});local first=start(s,1)
    assert(Discard.choose(s,{s.hand[1].uid},first));local second=start(s,1)
    assert(second>first);eq(Discard.choose(s,{s.hand[1].uid},first),false)
    eq(Discard.begin(s,1),false);eq(Discard.manualDiscard(s,s.hand[1].uid),false)
end)
test("Tactician gains are LIFO before FIFO Reflex draws",function()
    local s=fresh({"reflex","tactician",{cardId="reflex",upgraded=true},{cardId="tactician",upgraded=true},"defend"})
    local reflex,tactician={},{}
    for _,c in ipairs(s.hand) do
        if c.cardId=="reflex" then reflex[c.upgraded and 2 or 1]=c
        elseif c.cardId=="tactician" then tactician[c.upgraded and 2 or 1]=c end
    end
    local token=start(s,4);local base=s.energy;local calls={}
    local selected={reflex[1].uid,tactician[1].uid,reflex[2].uid,tactician[2].uid}
    assert(Discard.choose(s,selected,token,{draw=function(state,n)
        eq(state.energy,base+3);if #calls==0 then eq(#state.discard,4) end;calls[#calls+1]=n
        Combat.draw(state,n)
    end}))
    eq(calls[1],2);eq(calls[2],3)
    local trigger={}
    for _,e in ipairs(s.events) do if e.kind=="discard_energy" or e.kind=="discard_draw" then trigger[#trigger+1]=e.detail.uid end end
    eq(trigger[1],tactician[2].uid);eq(trigger[2],tactician[1].uid)
    eq(trigger[3],reflex[1].uid);eq(trigger[4],reflex[2].uid)
end)
test("energy overflow preflight retains pending choice",function()
    local s=fresh({"tactician","defend"});local token=start(s,1);s.energy=2147483647
    local p=s.pendingDiscard;local ok,reason=Discard.choose(s,{find(s,"tactician").uid},token)
    eq(ok,false);eq(reason,"energy_overflow");eq(s.pendingDiscard,p);eq(#s.hand,2);eq(#s.discard,0)
end)
test("failed draw restores original table graph including nested RNG and card refs",function()
    local s=fresh({"reflex","defend"});local card=find(s,"reflex");local token=start(s,1)
    s.extraRng={primitive={words={1,2}},counter=7}
    local hand,discard,draw,events,pending=s.hand,s.discard,s.draw,s.events,s.pendingDiscard
    local rng,primitive,words=s.extraRng,s.extraRng.primitive,s.extraRng.primitive.words
    local nEvents,energy,seed=#s.events,s.energy,s.seed;local sentinel={}
    local ok,err=pcall(Discard.choose,s,{card.uid},token,{draw=function(state,n)
        Combat.draw(state,n)
        state.extraRng.counter=8;state.extraRng.primitive.words[1]=999
        state.extraRng.primitive={};card.extra="changed";state.hand={};state.events={}
        error(sentinel)
    end})
    eq(ok,false);eq(err,sentinel);eq(s.hand,hand);eq(s.discard,discard);eq(s.draw,draw)
    eq(s.events,events);eq(s.pendingDiscard,pending);eq(s.extraRng,rng);eq(rng.primitive,primitive)
    eq(primitive.words,words);eq(words[1],1);eq(rng.counter,7);eq(card.extra,nil)
    eq(#s.events,nEvents);eq(s.energy,energy);eq(s.seed,seed);eq(#s.hand,2);eq(#s.discard,0)
    assert(Discard.choose(s,{card.uid},token))
end)
test("manual discard uses draw noDraw flag and rejects duplicate UID",function()
    local s=fresh({"reflex","defend"});local card=find(s,"reflex")
    s.player.noDraw=true;assert(Discard.manualDiscard(s,card.uid))
    eq(#s.hand,1);eq(#s.discard,1);eq(Discard.manualDiscard(s,card.uid),false)
end)
test("normal Combat.endTurn never triggers manual discard rewards",function()
    local s=fresh({"tactician","reflex"})
    assert(Combat.endTurn(s));eq(s.energy,s.rules.player.energyPerTurn)
    for _,e in ipairs(s.events) do
        assert(e.kind~="manual_discard" and e.kind~="discard_energy" and e.kind~="discard_draw")
    end
end)
test("Reflex obeys real full-hand draw capacity",function()
    local deck={"reflex"};for _=1,10 do deck[#deck+1]="defend" end
    local s=fresh(deck)
    local held=false
    for _,c in ipairs(s.hand) do if c.cardId=="reflex" then held=true end end
    if not held then
        for i,c in ipairs(s.draw) do
            if c.cardId=="reflex" then s.draw[i],s.hand[1]=s.hand[1],c;break end
        end
    end
    Combat.draw(s,5);eq(#s.hand,10)
    assert(Discard.manualDiscard(s,find(s,"reflex").uid));eq(#s.hand,10)
    eq(#s.discard,1);eq(#s.draw,0)
end)
test("malformed counts and token overflow fail before writes",function()
    for _,value in ipairs({-1,1.5,11,"1"}) do local s=fresh({"defend"});eq(Discard.begin(s,value),false);eq(#s.hand,1) end
    local s=fresh({"defend","strike"});s.discardSerial=2147483647
    eq(Discard.begin(s,1),false);eq(s.pendingDiscard,nil)
    s=fresh({"defend","strike"});s.phase="victory";eq(Discard.begin(s,1),false)
end)
test("auto-all failure rolls back its serial and pending action as well",function()
    local s=fresh({"tactician"});s.energy=2147483647
    assert(not pcall(Discard.begin,s,1));eq(#s.hand,1);eq(#s.discard,0)
    eq(s.discardSerial,nil);eq(s.pendingDiscard,nil)
end)
test("resolving-card Reflex tails wait for shared disposal and flush FIFO",function()
    local s=fresh({"reflex",{cardId="reflex",upgraded=true},"tactician"})
    local first,second
    for _,c in ipairs(s.hand) do
        if c.cardId=="reflex" then if c.upgraded then second=c else first=c end end
    end
    local energy=s.energy;s.resolvingCard=true
    assert(Discard.manualDiscard(s,first.uid));assert(Discard.manualDiscard(s,second.uid))
    assert(Discard.manualDiscard(s,find(s,"tactician").uid))
    eq(s.energy,energy+1);eq(#s.hand,0);eq(#s.discard,3)
    eq(s.pendingDiscardDraws[1].uid,first.uid);eq(s.pendingDiscardDraws[2].uid,second.uid)
    local calls={}
    assert(Discard.flushDraws(s,{draw=function(state,n)
        eq(state.pendingDiscardDraws,nil);calls[#calls+1]=n
        Combat.draw(state,n)
    end}))
    eq(calls[1],2);eq(calls[2],3);eq(s.pendingDiscardDraws,nil)
    eq(#s.hand,3);assert(Discard.flushDraws(s));eq(#calls,2)
end)
test("tail draw failure restores the exact queue and prior draw state for retry",function()
    local s=fresh({"reflex",{cardId="reflex",upgraded=true}})
    s.resolvingCard=true
    assert(Discard.manualDiscard(s,s.hand[1].uid));assert(Discard.manualDiscard(s,s.hand[1].uid))
    local queue=s.pendingDiscardDraws;local entry=queue[1]
    local hand,discard,events=s.hand,s.discard,s.events
    local seed,eventsCount=s.seed,#s.events;local sentinel={};local calls=0
    local ok,err=pcall(Discard.flushDraws,s,{draw=function(state,n)
        calls=calls+1;Combat.draw(state,n)
        if calls==2 then entry.amount=99;error(sentinel) end
    end})
    eq(ok,false);eq(err,sentinel);eq(s.pendingDiscardDraws,queue);eq(queue[1],entry)
    assert(entry.amount==2 or entry.amount==3);eq(s.hand,hand);eq(s.discard,discard);eq(s.events,events)
    eq(#s.hand,0);eq(#s.discard,2);eq(s.seed,seed);eq(#s.events,eventsCount)
    assert(Discard.flushDraws(s));eq(s.pendingDiscardDraws,nil);eq(#s.hand,2)
end)
test("queued Reflex is cancelled after player death or final enemy death",function()
    for _,owner in ipairs({"player","enemy"}) do
        local s=fresh({"reflex"});s.resolvingCard=true
        assert(Discard.manualDiscard(s,s.hand[1].uid))
        if owner=="player" then s.player.hp=0 else s.enemies[1].hp=0 end
        assert(Discard.flushDraws(s,{draw=function() error("dead combat drew") end}))
        eq(s.pendingDiscardDraws,nil);eq(#s.hand,0);eq(#s.discard,1)
    end
end)
test("malformed tail queue and missing draw API reject before queue mutation",function()
    local s=fresh({"reflex"});s.resolvingCard=true
    assert(Discard.manualDiscard(s,s.hand[1].uid));local queue=s.pendingDiscardDraws
    eq(Discard.flushDraws(s,{}),false);eq(s.pendingDiscardDraws,queue)
    queue[1].amount=4;eq(Discard.flushDraws(s),false);eq(s.pendingDiscardDraws,queue)
end)
print("SILENT_DISCARD_PASS "..count)
