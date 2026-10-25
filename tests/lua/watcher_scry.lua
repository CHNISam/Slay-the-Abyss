package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Combat=require("abyss_combat")
local Watcher=require("abyss_watcher_cards")
local Data=require("abyss_data")
-- Fixed319009 ScryAction a22d8875a9ac3a4b6c445abad65a6ca4defa8fb309d1f6a6e51506a8e3b55147
-- CTF4272d2efb273ef4783037a9355378fdb1188d8fbcca831734212500d9e36a4a8
-- ThirdEye6e03daa91f0879c139284107bd3b010b64d9306fa6b006b82a2f85cc9e3dba29
-- JustLucky4ffc7870d841075d6a7ffebf01cc825f71465b09b7612cb35229fdc44040d07b
-- Nirvana2232c8c028b30d87567511320f68cad009322c357713126f3f903ce99ee5449e
-- NirvanaPowerd1d0c348c75c619d75a69397bfe440c09a009b73fe0eb3af37e88431ee5d6dae
local count=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();count=count+1;print("ok watcher_scry "..count.." - "..name) end
local function uid(s,id)
    for _,c in ipairs(s.hand) do if c.cardId==id then return c.uid end end
    error("missing hand card "..id)
end
local function contains(pile,id)
    for _,c in ipairs(pile) do if c.uid==id then return true end end
    return false
end
local function battle(id,up,extra,filler)
    local deck={{cardId=id,upgraded=up}}
    for _,value in ipairs(extra or {}) do deck[#deck+1]=value end
    for i=1,(filler==nil and 12 or filler) do deck[#deck+1]="defend" end
    for seed=1,100 do
        local s=Combat.new(Watcher.withFoundationCards(Data),{seed=seed,enemies={"cultist"},enableStances=true,deck=deck})
        local ready=pcall(uid,s,id)
        for _,value in ipairs(extra or {}) do ready=ready and pcall(uid,s,type(value)=="table" and value.cardId or value) end
        if ready then s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;return s end
    end
    error("no reproducible opening hand fixture")
end
local function immutable(s)
    local saved,pending={},{s}
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
test("Cut Through Fate pauses between damage and draw, preserving top order",function()
    for _,up in ipairs({false,true}) do
        local s=battle("cut_through_fate",up)
        local id=uid(s,"cut_through_fate");local draw=s.draw;local n=#draw
        local top,second=draw[n].uid,draw[n-1].uid
        local beforeEnergy=s.energy
        assert(Combat.play(s,id,1));eq(s.enemies[1].hp,up and 991 or 993)
        eq(s.energy,beforeEnergy-1);eq(#s.draw,n);assert(not contains(s.discard,id))
        local p=assert(s.pendingScry);eq(#p.candidateUids,up and 3 or 2)
        eq(p.candidateUids[1],top);eq(p.candidateUids[2],second)
        assert(Combat.chooseScry(s,{top},p.token))
        eq(s.draw,draw);eq(s.discard[1].uid,top);assert(contains(s.hand,second))
        assert(contains(s.discard,id));eq(s.pendingScry,nil);eq(s.actionQueue,nil)
    end
end)
test("empty selection keeps all looked cards and draws original top",function()
    local s=battle("cut_through_fate")
    local top=s.draw[#s.draw].uid;local n=#s.draw
    assert(Combat.play(s,uid(s,"cut_through_fate"),1))
    assert(Combat.chooseScry(s,{},s.pendingScry.token))
    eq(#s.draw,n-1);assert(contains(s.hand,top));eq(#s.discard,1)
end)
test("selected discard order follows selected UID order; unselected stay fixed",function()
    local s=battle("third_eye",true)
    local original={};for i,c in ipairs(s.draw) do original[i]=c.uid end
    assert(Combat.play(s,uid(s,"third_eye")))
    local p=s.pendingScry;local first,second=p.candidateUids[1],p.candidateUids[2]
    assert(Combat.chooseScry(s,{second,first},p.token))
    eq(s.discard[1].uid,second);eq(s.discard[2].uid,first)
    for i=1,#original-2 do eq(s.draw[i].uid,original[i]) end
end)
test("Third Eye grants block before pending selection",function()
    for _,up in ipairs({false,true}) do
        local s=battle("third_eye",up)
        assert(Combat.play(s,uid(s,"third_eye")));eq(s.player.block,up and 9 or 7)
        eq(#s.pendingScry.candidateUids,up and 5 or 3)
        assert(Combat.chooseScry(s,{},s.pendingScry.token))
    end
end)
test("Just Lucky defers both block and damage until scry confirmation",function()
    for _,up in ipairs({false,true}) do
        local s=battle("just_lucky",up)
        assert(Combat.play(s,uid(s,"just_lucky"),1));eq(s.player.block,0);eq(s.enemies[1].hp,1000)
        eq(#s.pendingScry.candidateUids,up and 2 or 1)
        assert(Combat.chooseScry(s,{},s.pendingScry.token))
        eq(s.player.block,up and 3 or 2);eq(s.enemies[1].hp,up and 996 or 997)
    end
end)
test("Nirvana resolves after remaining draw and used card disposal",function()
    for _,up in ipairs({false,true}) do
        local s=battle("cut_through_fate",false,{{cardId="nirvana",upgraded=up}})
        assert(Combat.play(s,uid(s,"nirvana")))
        local card=uid(s,"cut_through_fate");local top=s.draw[#s.draw].uid
        assert(Combat.play(s,card,1));eq(s.player.block,0)
        assert(Combat.chooseScry(s,{},s.pendingScry.token));eq(s.player.block,up and 4 or 3)
        local frame
        for _,e in ipairs(s.events) do if e.kind=="block" then frame=e.frame end end
        assert(frame and contains(frame.hand,top) and contains(frame.discard,card))
    end
end)
test("empty draw still triggers Nirvana without reshuffling or selection",function()
    local s=battle("third_eye",false,{"nirvana"},0)
    assert(Combat.play(s,uid(s,"nirvana")))
    eq(#s.draw,0);local seed=s.seed
    assert(Combat.play(s,uid(s,"third_eye")))
    eq(s.pendingScry,nil);eq(s.player.block,10);eq(s.seed,seed);eq(#s.draw,0)
end)
test("zero requested scry also triggers Nirvana once",function()
    local s=battle("third_eye",false,{"nirvana"})
    assert(Combat.play(s,uid(s,"nirvana")))
    s.catalog.cards.third_eye.effects={{op="scry",value=0}}
    local n=#s.draw;local seed=s.seed
    assert(Combat.play(s,uid(s,"third_eye")))
    eq(s.pendingScry,nil);eq(s.player.block,3);eq(#s.draw,n);eq(s.seed,seed)
end)
test("insufficient draw pile exposes only existing top cards",function()
    local s=battle("third_eye",true,nil,5)
    eq(#s.draw,1);assert(Combat.play(s,uid(s,"third_eye")))
    eq(#s.pendingScry.candidateUids,1)
    assert(Combat.chooseScry(s,{},s.pendingScry.token));eq(#s.draw,1)
end)
test("pending selection rejects play and end turn without advancing",function()
    local s=battle("third_eye")
    assert(Combat.play(s,uid(s,"third_eye")))
    local unchanged=immutable(s)
    eq(Combat.play(s,uid(s,"defend")),false);unchanged()
    eq(Combat.endTurn(s),false);unchanged()
end)
test("bad, duplicate, stale and changed candidate UIDs are atomic rejects",function()
    local s=battle("third_eye");assert(Combat.play(s,uid(s,"third_eye")))
    local p=s.pendingScry;local unchanged=immutable(s)
    for _,choice in ipairs({{999999},{p.candidateUids[1],p.candidateUids[1]},{[2]=p.candidateUids[1]}}) do
        eq(Combat.chooseScry(s,choice,p.token),false);unchanged()
    end
    eq(Combat.chooseScry(s,{},p.token+1),false);unchanged()
    local n=#s.draw;s.draw[n],s.draw[n-1]=s.draw[n-1],s.draw[n]
    local changed=immutable(s);eq(Combat.chooseScry(s,{},p.token),false);changed()
    s.draw[n],s.draw[n-1]=s.draw[n-1],s.draw[n]
    assert(Combat.chooseScry(s,{},p.token));eq(Combat.chooseScry(s,{},p.token),false)
end)
test("scry discard never fires manual Tactician or Reflex triggers",function()
    local s=battle("third_eye")
    -- Existing real instances keep their UIDs; add the cross-class source
    -- definitions only as an isolated interaction fixture, not a legal pool.
    s.catalog.cards.tactician={id="tactician",type="skill",cost=-2,effects={}}
    s.catalog.cards.reflex={id="reflex",type="skill",cost=-2,effects={}}
    local top=s.draw[#s.draw];top.cardId="tactician"
    local second=s.draw[#s.draw-1];second.cardId="reflex"
    assert(Combat.play(s,uid(s,"third_eye")))
    local before=s.energy;local hand=#s.hand
    assert(Combat.chooseScry(s,{top.uid,second.uid},s.pendingScry.token))
    eq(s.energy,before);eq(#s.hand,hand)
    for _,e in ipairs(s.events) do assert(e.kind~="manual_discard" and e.kind~="discard_energy" and e.kind~="discard_draw") end
end)
test("lethal Cut Through Fate skips scry, draw, and Nirvana entirely",function()
    local s=battle("cut_through_fate",false,{"nirvana"})
    assert(Combat.play(s,uid(s,"nirvana")));s.enemies[1].hp=1
    local n=#s.draw;local before=#s.events
    assert(Combat.play(s,uid(s,"cut_through_fate"),1));eq(s.phase,"victory")
    eq(s.pendingScry,nil);eq(#s.draw,n);eq(s.player.block,0)
    for i=before+1,#s.events do assert(s.events[i].kind~="scry") end
end)
test("draw failure after choosing restores this phase without replaying prior damage",function()
    local s=battle("cut_through_fate",false,nil,6)
    assert(Combat.play(s,uid(s,"cut_through_fate"),1));eq(s.enemies[1].hp,993)
    eq(#s.draw,2)
    local p=s.pendingScry;local token=p.token
    local selected={p.candidateUids[1],p.candidateUids[2]}
    local unchanged=immutable(s)
    local realDraw=Combat.draw;local executed=false;local fault={after_real_draw=true}
    Combat.draw=function(state,amount)
        realDraw(state,amount)
        assert(#state.hand==5,"the queued real Draw1 did not run")
        executed=true;error(fault)
    end
    local ok,reason=pcall(Combat.chooseScry,s,selected,token)
    Combat.draw=realDraw
    eq(ok,false);eq(reason,fault);eq(executed,true);unchanged()
    eq(s.enemies[1].hp,993)
    assert(Combat.chooseScry(s,selected,token));eq(s.enemies[1].hp,993)
    eq(s.pendingScry,nil);eq(s.pendingPlay,nil);eq(s.actionQueue,nil)
end)
test("copied pure-data pause resumes independently of the original state",function()
    local s=battle("cut_through_fate")
    assert(Combat.play(s,uid(s,"cut_through_fate"),1));local unchanged=immutable(s)
    local restored=Combat.copy(s)
    assert(restored~=s and restored.pendingScry~=s.pendingScry and restored.actionQueue~=s.actionQueue)
    assert(Combat.chooseScry(restored,{},restored.pendingScry.token))
    eq(restored.pendingPlay,nil);eq(restored.actionQueue,nil);eq(restored.enemies[1].hp,993)
    unchanged();assert(s.pendingScry and s.pendingPlay and s.actionQueue)
    assert(Combat.chooseScry(s,{},s.pendingScry.token))
end)
test("Just Lucky killing the final enemy preserves queued Nirvana block",function()
    local s=battle("just_lucky",false,{"nirvana"})
    assert(Combat.play(s,uid(s,"nirvana")));s.enemies[1].hp=1
    assert(Combat.play(s,uid(s,"just_lucky"),1))
    assert(Combat.chooseScry(s,{},s.pendingScry.token))
    eq(s.phase,"victory");eq(s.player.block,5);eq(s.player.hp,80)
    eq(s.pendingPlay,nil);eq(s.actionQueue,nil)
end)
test("player death during Just Lucky damage cancels queued Nirvana rescue",function()
    local s=battle("just_lucky",false,{"nirvana"})
    assert(Combat.play(s,uid(s,"nirvana")));s.player.hp=1
    s.enemies[1].statuses.thorns=10
    assert(Combat.play(s,uid(s,"just_lucky"),1))
    assert(Combat.chooseScry(s,{},s.pendingScry.token))
    eq(s.phase,"defeat");eq(s.player.hp,0);eq(s.player.block,0)
    eq(s.pendingPlay,nil);eq(s.actionQueue,nil)
end)
test("using card UID forged into candidate draw is refused before moving",function()
    local s=battle("third_eye")
    assert(Combat.play(s,uid(s,"third_eye")))
    local p=s.pendingScry;local n=#s.draw;local original=s.draw[n].uid
    s.draw[n].uid=s.cardInUse.uid;p.candidateUids[1]=s.cardInUse.uid
    local unchanged=immutable(s)
    eq(Combat.chooseScry(s,{},p.token),false);unchanged()
    s.draw[n].uid=original;p.candidateUids[1]=original
    assert(Combat.chooseScry(s,{},p.token))
end)
print("WATCHER_SCRY_PASS "..count)
