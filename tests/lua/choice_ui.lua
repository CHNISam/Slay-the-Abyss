local NativeContract = dofile('tests/lua/support/native_ui_contract.lua')
package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local ChoiceUI=require("abyss_choice_ui")
local Combat=require("abyss_combat")
local Run=require("abyss_run")
local Data=require("abyss_data")
local Presentation=require("abyss_presentation")
local Silent=require("abyss_silent")
local Watcher=require("abyss_watcher_cards")
local Warrior=require("abyss_warrior_cards")
local count=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();count=count+1;print("ok choice_ui "..count.." - "..name) end
local function control(name)
    local c={name=name,children={},listeners={},visible=true,interactable=true,text=""}
    function c:GetChild(key) return self.children[key] end
    function c:SetVisible(value) self.visible=value end
    function c:SetAsLastSibling() self.raised=true end
    function c:AddCursorEventListener(event,fn) NativeContract.listener(event,fn); assert(not self.listeners[event]);self.listeners[event]=fn end
    return c
end
local function button(name)
    local c=control(name);local hit=control("hit");c.children.hit=hit
    for _,state in ipairs({"normal","hover","pressed","disabled"}) do
        local face=control(state);face.children.label=control("label");face.children.border=control("border");hit.children[state]=face
    end
    return c
end
local function root()
    local c=control("choices")
    for _,name in ipairs({"blocker","title","hint","status"}) do c.children[name]=control(name) end
    for i=1,10 do c.children["card"..i]=button("card"..i) end
    for _,name in ipairs({"confirm","before","after"}) do c.children[name]=button(name) end
    return c
end
local function uid(s,id)
    for _,card in ipairs(s.hand) do if card.cardId==id then return card.uid end end
    error("missing opening card "..id)
end
local function battle(data,id,up,filler)
    local deck={{cardId=id,upgraded=up}}
    for _=1,filler or 12 do deck[#deck+1]="defend" end
    for seed=1,100 do
        local s=Combat.new(data,{seed=seed,cardRandomSeed="42",enemies={"cultist"},deck=deck,enableStances=true})
        if pcall(uid,s,id) then s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;return s end
    end
    error("no reproducible choice fixture")
end
local function wrap(s) return {phase="combat",combat=s,combatGeneration=7,deck={}} end
local function callback(run)
    return function(kind,uids,token,generation)
        return (kind=="scry" and Run.chooseScry or kind=="discard" and Run.chooseDiscard or Run.chooseHand)(run,uids,token,generation)
    end
end
local cursor={CursorDown="down",CursorUp="up",CursorExit="exit",CursorEndDrag="endDrag"}
local function ui(run,fn,pointers)
    local r=root()
    local u=ChoiceUI.new(r,Presentation,"click",{cursorEvents=pointers and cursor,
        color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end},fn or callback(run))
    assert(u:refresh(run,true));return u,r
end
local function hit(r,name) return r:GetChild(name):GetChild("hit") end
local function event(r,name,kind,touch)
    local fn=assert(hit(r,name).listeners[kind],"missing listener "..kind)
    return fn(touch and {touchId=touch} or nil)
end
local function click(r,name) return event(r,name,"click") end
local function tap(r,name,touch)
    event(r,name,"down",touch);event(r,name,"up",touch);return event(r,name,"click",touch)
end
local function scry()
    local s=battle(Watcher.withFoundationCards(Data),"third_eye",true)
    assert(Combat.play(s,uid(s,"third_eye")));return wrap(s)
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
test("Survivor displays a real pending discard and confirmation moves only chosen UID",function()
    local s=battle(Silent.withFoundationCards(Data),"survivor",false,4)
    assert(Combat.play(s,uid(s,"survivor")));local run=wrap(s)
    local u,r=ui(run);local p=s.pendingDiscard;local chosen=p.handUids[2]
    eq(r:GetChild("title").text,"选择弃牌");eq(hit(r,"confirm").interactable,false)
    local unchanged=freeze(run);assert(click(r,"card2"));unchanged()
    assert(hit(r,"card2"):GetChild("normal"):GetChild("label").text:find("费用 1",1,true))
    assert(click(r,"confirm"));eq(s.pendingDiscard,nil)
    eq(s.discard[1].uid,chosen);eq(s.discard[#s.discard].cardId,'survivor');eq(u.visible,false)
end)
test("Prepared upgraded requires both choices and preserves click order",function()
    local s=battle(Silent.withFoundationCards(Data),"prepared",true)
    assert(Combat.play(s,uid(s,"prepared")));eq(s.pendingDiscard.count,2)
    local u,r=ui(wrap(s));local p=s.pendingDiscard;local first,second=p.handUids[3],p.handUids[1]
    eq(click(r,"confirm"),false);assert(click(r,"card3"));eq(hit(r,"confirm").interactable,false)
    assert(click(r,"card1"));eq(hit(r,"confirm").interactable,true)
    local before=#s.discard;assert(click(r,"confirm"));eq(s.discard[before+1].uid,first);eq(s.discard[before+2].uid,second)
    eq(u.visible,false)
end)
test("real Scry retains top order, selected order, and never mutates before confirm",function()
    local run=scry();local s=run.combat;local p=s.pendingScry
    local u,r=ui(run);local unchanged=freeze(run)
    assert(click(r,"card2"));assert(click(r,"card1"));unchanged()
    eq(u.selected[1],p.candidateUids[2]);eq(u.selected[2],p.candidateUids[1])
    assert(r:GetChild("hint").text:find("首张为抽牌堆顶",1,true))
    assert(click(r,"confirm"));eq(s.discard[1].uid,p.candidateUids[2]);eq(s.discard[2].uid,p.candidateUids[1])
    eq(s.pendingScry,nil);eq(s.pendingPlay,nil)
end)
test("Scry permits keeping every card and resolves the real continuation",function()
    local run=scry();local s=run.combat;local top=s.draw[#s.draw]
    local u,r=ui(run);eq(hit(r,"confirm").interactable,true)
    eq(hit(r,"confirm"):GetChild("normal"):GetChild("label").text,"全部保留")
    assert(click(r,"confirm"));eq(s.draw[#s.draw],top);eq(s.pendingScry,nil);eq(u.visible,false)
end)
test("upgraded True Grit selects and exhausts a real remaining hand card",function()
    local s=battle(Warrior.withFoundationCards(Data),"true_grit",true,4)
    local used=uid(s,"true_grit");assert(Combat.play(s,used));eq(s.pendingHandChoice.mode,"exhaust_choose")
    local u,r=ui(wrap(s));local chosen=s.hand[2].uid
    eq(r:GetChild("title").text,"选择消耗");assert(click(r,"card2"));assert(click(r,"confirm"))
    eq(s.exhaust[1].uid,chosen);eq(s.pendingPlay,nil);eq(s.pendingHandChoice,nil);eq(u.visible,false)
end)
test("Warcry offers put-on-top and distinguishes upgrade text and current cost",function()
    local s=battle(Warrior.withFoundationCards(Data),"warcry",false,4)
    assert(Combat.play(s,uid(s,"warcry")));local u,r=ui(wrap(s));local chosen=s.hand[1]
    eq(r:GetChild("title").text,"放回抽牌堆顶")
    assert(click(r,"card1"));assert(click(r,"card2"));eq(#u.selected,1);eq(u.selected[1],s.hand[2].uid)
    assert(click(r,"card1"));assert(click(r,"confirm"));eq(s.draw[#s.draw],chosen)
    eq(s.exhaust[1].cardId,"warcry");eq(u.visible,false)
end)
test("toggle deselection preserves ordered selections and strict count",function()
    local run=scry();local u,r=ui(run)
    assert(click(r,"card3"));assert(click(r,"card1"));assert(click(r,"card3"));assert(click(r,"card2"))
    eq(#u.selected,2);eq(u.selected[1],u.cards[1].uid);eq(u.selected[2],u.cards[2].uid)
end)
test("failed callback keeps selection and returns the original rejection",function()
    local run=scry();local reason={code="injected_reject"};local calls=0
    local u,r=ui(run,function() calls=calls+1;return false,reason end)
    assert(click(r,"card1"));local chosen=u.selected[1];local unchanged=freeze(run)
    local ok,why=click(r,"confirm");eq(ok,false);eq(why,reason);eq(calls,1);eq(u.selected[1],chosen)
    eq(u.visible,true);assert(#r:GetChild("status").text>0);unchanged()
end)
test("thrown callback preserves original error object and permits retry",function()
    local run=scry();local reason={code="injected_throw"};local fail=true
    local u,r=ui(run,function(...) if fail then error(reason) end;return callback(run)(...) end)
    assert(click(r,"card1"));local ok,why=click(r,"confirm");eq(ok,false);eq(why,reason);eq(#u.selected,1)
    fail=false;assert(click(r,"confirm"));eq(u.visible,false)
end)
test("synchronous host refresh during a rejected command retains local selection",function()
    local run=scry();local u
    local r=root()
    u=ChoiceUI.new(r,Presentation,"click",{color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end},function()
        assert(u:refresh(run,true));return false,"host_rejected"
    end)
    assert(u:refresh(run,true));assert(click(r,"card2"));local chosen=u.selected[1]
    local ok,why=click(r,"confirm");eq(ok,false);eq(why,"host_rejected");eq(u.selected[1],chosen)
end)
test("upgraded card shows its own upgraded name, cost, type and complete text in every button state",function()
    local run=scry();local top=run.combat.draw[#run.combat.draw];top.upgraded=true
    run.combat.catalog.cards.defend.upgrade.cost=0
    local u,r=ui(run)
    for _,state in ipairs({"normal","hover","pressed","disabled"}) do
        local text=hit(r,"card1"):GetChild(state):GetChild("label").text
        assert(text:find(Presentation.defend.name.."＋",1,true),text)
        assert(text:find("技能 · 费用 0",1,true),text)
        assert(text:find("8",1,true),text)
    end
    eq(u:select("1"),false);eq(u:select(11),false)
end)
test("changing selection invalidates a previously released confirm",function()
    local run=scry();local calls=0;local u,r=ui(run,function()calls=calls+1;return false,"test" end,true)
    event(r,"confirm","down",1);event(r,"confirm","up",1)
    assert(tap(r,"card1",2));eq(event(r,"confirm","click",1),false);eq(calls,0)
    eq(click(r,"confirm"),false);eq(calls,0)
end)
test("foreign Down, Up and click do not steal the owning touch",function()
    local run=scry();local calls=0;local u,r=ui(run,function()calls=calls+1;return false,"test" end,true)
    event(r,"confirm","down",1);event(r,"confirm","down",2);event(r,"confirm","up",2)
    eq(event(r,"confirm","click",2),false);eq(calls,0)
    event(r,"confirm","up",1);eq(event(r,"confirm","click",2),false)
    eq(event(r,"confirm","click",1),false);eq(calls,1)
    eq(event(r,"confirm","click",1),false);eq(calls,1)
end)
test("resize, close and reopen cannot revive old physical confirmation",function()
    for _,action in ipairs({"resize","close"}) do
        local run=scry();local calls=0;local u,r=ui(run,function()calls=calls+1;return false,"test" end,true)
        event(r,"confirm","down",1);event(r,"confirm","up",1)
        if action=="resize" then u:resize() else u:close();assert(u:refresh(run,true)) end
        eq(event(r,"confirm","click",1),false);eq(calls,0)
        eq(tap(r,"confirm",1),false);eq(calls,1)
    end
end)
test("new pending identity, battle, turn and generation reject old gestures",function()
    for _,change in ipairs({"pending","battle","turn","generation"}) do
        local run=scry();local calls=0;local u,r=ui(run,function()calls=calls+1;return false,"test" end,true)
        event(r,"confirm","down",1);event(r,"confirm","up",1)
        if change=="pending" then run.combat.pendingScry=Combat.copy(run.combat.pendingScry)
        elseif change=="battle" then run.combat=Combat.copy(run.combat)
        elseif change=="turn" then run.combat.turn=run.combat.turn+1
        else run.combatGeneration=run.combatGeneration+1 end
        eq(event(r,"confirm","click",1),false);eq(calls,0)
    end
end)
test("changed candidate identity or upgrade refuses local selection before callback",function()
    for _,change in ipairs({"replacement","upgrade","uid","order"}) do
        local run=scry();local calls=0;local u,r=ui(run,function()calls=calls+1;return true end)
        local draw=run.combat.draw;local top=draw[#draw]
        if change=="replacement" then draw[#draw]=Combat.copy(top)
        elseif change=="upgrade" then top.upgraded=not top.upgraded
        elseif change=="order" then draw[#draw],draw[#draw-1]=draw[#draw-1],draw[#draw]
        else top.uid=99999 end
        eq(click(r,"card1"),false);eq(click(r,"confirm"),false);eq(calls,0)
    end
end)
test("rapid duplicate confirm commits at most once through the real core",function()
    local run=scry();local calls=0
    local u,r=ui(run,function(...)calls=calls+1;return callback(run)(...)end,true)
    assert(tap(r,"confirm",1));eq(event(r,"confirm","click",1),false);eq(u:confirm(),false);eq(calls,1)
end)
test("hidden controller blocks commands and has no cancel route for mandatory choice",function()
    local run=scry();local calls=0;local u,r=ui(run,function()calls=calls+1;return true end)
    assert(not r:GetChild("cancel"));u:refresh(run,false)
    eq(r.visible,false);eq(click(r,"confirm"),false);eq(calls,0);assert(run.combat.pendingScry)
end)
test("more than ten Scry candidates page without losing ordered selection",function()
    local run=scry();local s=run.combat
    -- Reuse real instances to exercise a larger source Scry selection. The UI
    -- remains read-only; this is not evidence that a new card is obtainable.
    while #s.draw<11 do s.draw[#s.draw+1]=table.remove(s.hand) end
    local p=s.pendingScry;p.candidateUids={};p.drawSize=#s.draw
    for i=1,11 do p.candidateUids[i]=s.draw[#s.draw-i+1].uid end
    local u,r=ui(run);local first=p.candidateUids[1];local eleventh=p.candidateUids[11]
    assert(click(r,"card1"));assert(click(r,"after"));eq(u.page,2);eq(r:GetChild("card2").visible,false)
    assert(click(r,"card1"));assert(click(r,"before"));eq(u.selected[1],first);eq(u.selected[2],eleventh)
    assert(click(r,"confirm"));eq(s.discard[1].uid,first);eq(s.discard[2].uid,eleventh)
end)
print("CHOICE_UI_PASS "..count)
