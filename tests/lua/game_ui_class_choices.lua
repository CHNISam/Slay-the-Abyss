local sliceFirst,sliceLast=...
sliceFirst,sliceLast=sliceFirst or 1,sliceLast or 5
local sliceRegistered=0
package.path="src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;"..package.path
local X=require("support.experimental_ui_fixture")
local Run=require("abyss_run")
local Combat=require("abyss_combat")
local n=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn)
    sliceRegistered=sliceRegistered+1
    if sliceRegistered>=sliceFirst and sliceRegistered<=sliceLast then
        fn();n=n+1;print("ok game_ui_class_choices "..n.." - "..name)
        print("GAME_UI_CLASS_CHOICES_CASE "..sliceRegistered)
    end
end
local cursor={CursorDown="down",CursorUp="up",CursorExit="exit",CursorEndDrag="enddrag"}
local classIndex={ironclad=1,silent=2,watcher=4}
local control=dofile('tests/lua/support/native_control_path_fixture.lua')
local function hit(root,path)
    local c=control(root,path)
    return c.listeners and c.listeners.click and c or assert(c:GetChild("hit"),path)
end
local function click(root,path,event) return assert(hit(root,path).listeners.click)(event) end
local function pointer(root,path,kind,touch)
    return assert(hit(root,path).listeners[kind],path.." "..kind)({touchId=touch})
end
local function tap(root,path,touch)
    pointer(root,path,"down",touch);pointer(root,path,"up",touch);return click(root,path,{touchId=touch})
end
local function drain(ui)
    for _=1,400 do
        if not ui.battleUI.busy then return end
        assert(ui:update(0.05))
    end
    error("real battle feedback remained busy")
end
local function setup(character,card,up,physical)
    local ui,root=X.new({cursor=physical and cursor})
    assert(ui:start());assert(ui:selectCharacter('traveler'));assert(ui:selectElement(character));assert(ui:confirmCharacter())
    local run=ui.run
    -- Exact permanent-deck fixture, not natural acquisition or source drop odds.
    run.deck={}
    for i=1,12 do run.deck[i]={uid=i,cardId=card,upgraded=up==true} end
    run.nextDeckUid=13
    assert(Run.obtainPotion(run,"block_potion"))
    assert(Run.startCombat(run,"cultist_solo"));ui:refresh()
    eq(ui.mode,"battle");eq(ui.battleUI.busy,false);eq(ui.choiceUI.visible,false)
    local s=run.combat
    local position,used
    for i,c in ipairs(s.hand) do if c.cardId==card then position,used=i,c;break end end
    assert(position,"fixture opening card unavailable")
    -- The real rendered card and explicit target/field click invoke perform.
    click(root,"battlePanel/card"..position)
    eq(ui.battleUI.selected,used.uid)
    click(root,card=="cut_through_fate" and "battlePanel/enemy1" or "battlePanel/playArea")
    eq(ui.battleUI.busy,true)
    local kind=s.pendingDiscard and "discard" or s.pendingScry and "scry" or s.pendingHandChoice and "hand"
    assert(kind,"real Run.play did not establish a core selection")
    local pending=s.pendingDiscard or s.pendingScry or s.pendingHandChoice
    eq(ui.choiceUI.visible,false)
    drain(ui)
    eq(ui.choiceUI.visible,true);eq(root:GetChild("choicePanel").visible,true)
    eq(ui.battleUI.active,false)
    return ui,root,s,pending,kind,used
end
local function contains(pile,uid)
    for _,c in ipairs(pile) do if c.uid==uid then return true end end
    return false
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
local specs={
    {"silent","survivor",false}, {"silent","prepared",true},
    {"watcher","cut_through_fate",false}, {"watcher","third_eye",true},
    {"ironclad","true_grit",true}, {"ironclad","warcry",false},
}
for _,spec in ipairs(specs) do
    test(spec[2].." real play pauses, feedback opens choice and confirmation resumes feedback",function()
        local ui,root,s,p,kind,used=setup(spec[1],spec[2],spec[3])
        local first=ui.choiceUI.cards[1].uid
        local second=ui.choiceUI.cards[2] and ui.choiceUI.cards[2].uid
        local needed=kind=="scry" and 1 or p.count
        local beforeHand,beforeDraw,beforeDiscard=#s.hand,#s.draw,#s.discard
        for i=1,needed do assert(click(root,"choicePanel/card"..i)) end
        local text=hit(root,"choicePanel/card1"):GetChild("normal"):GetChild("label").text
        assert(#text>0 and text:find("费用",1,true),text)
        assert(click(root,"choicePanel/confirm"));eq(ui.battleUI.busy,true)
        eq(s.pendingDiscard,nil);eq(s.pendingScry,nil);eq(s.pendingHandChoice,nil)
        eq(s.pendingPlay,nil);eq(s.actionQueue,nil)
        if kind=="discard" then
            eq(#s.hand,beforeHand-needed);eq(#s.discard,beforeDiscard+needed+1)
            assert(contains(s.discard,first));if needed==2 then assert(contains(s.discard,second)) end
            assert(contains(s.discard,used.uid),'source UseCard disposes only after the selected discard')
        elseif spec[2]=="true_grit" then
            assert(contains(s.exhaust,first));assert(contains(s.discard,used.uid));eq(#s.hand,beforeHand-1)
        elseif spec[2]=="warcry" then
            eq(s.draw[#s.draw].uid,first);assert(contains(s.exhaust,used.uid));eq(#s.hand,beforeHand-1)
        else
            assert(contains(s.discard,first));assert(contains(s.discard,used.uid))
            eq(#s.draw,beforeDraw-1-(spec[2]=="cut_through_fate" and 1 or 0))
            eq(#s.hand,beforeHand+(spec[2]=="cut_through_fate" and 1 or 0))
        end
        local stopped=freeze(s)
        eq(ui.choiceUI:confirm(),false);stopped()
        drain(ui);eq(ui.choiceUI.visible,false);eq(ui.battleUI.active,true);eq(ui.mode,"battle")
        eq(ui.battleUI.busy,false)
    end)
end
test("pending selection blocks underlying end turn, card, deck and potion commands",function()
    local ui,root,s=setup("silent","survivor")
    local unchanged=freeze(s);local turn=s.turn;local potions=Run.potionCount(ui.run)
    ui.battleUI:endTurn();ui.battleUI:playSlot(1);ui.battleUI:playSelected(1)
    eq(ui:openDeck(),false);eq(ui:openPotions(),false);eq(ui.battleUI:usePotion(1),false)
    hit(root,"battlePanel/endTurn").listeners.click()
    eq(s.turn,turn);eq(Run.potionCount(ui.run),potions);unchanged()
    eq(root:GetChild("deckEntry").visible,false);eq(root:GetChild("potionEntry").visible,false)
end)
test("exit covers the mandatory selection and cancel restores the same pending without rule changes",function()
    local ui,root,s,p=setup("watcher","third_eye",true)
    assert(click(root,"choicePanel/card1"));local unchanged=freeze(s)
    assert(ui:openExit());eq(ui.exitOpen,true);eq(ui.choiceUI.visible,false)
    eq(root:GetChild("exitPanel").visible,true);eq(ui.battleUI.active,false)
    eq(click(root,"choicePanel/confirm"),false);unchanged()
    assert(ui:closeExit());eq(ui.choiceUI.visible,true);eq(s.pendingScry,p);unchanged()
    eq(#ui.choiceUI.selected,0) -- hiding only resets the view, never the mandatory core choice
    assert(click(root,"choicePanel/confirm"));drain(ui);eq(s.pendingScry,nil)
end)
test("real core refusal preserves selected UID and pending through perform refresh then retries",function()
    local ui,root,s,p=setup("watcher","third_eye",true)
    assert(click(root,"choicePanel/card1"));local selected=ui.choiceUI.selected[1]
    -- UI identity stays current, but this independent core counter is invalid.
    -- No mock perform/Run callback is installed: Scry.choose rejects it itself.
    s.scrySerial=p.token+1
    local unchanged=freeze(s)
    local ok,reason=click(root,"choicePanel/confirm")
    eq(ok,false);eq(reason,"stale_scry_token");eq(ui.battleUI.busy,false)
    eq(s.pendingScry,p);eq(ui.choiceUI.visible,true);eq(ui.choiceUI.selected[1],selected);unchanged()
    assert(#root:GetChild("choicePanel"):GetChild("status").text>0)
    s.scrySerial=p.token;assert(click(root,"choicePanel/confirm"));drain(ui);eq(s.pendingScry,nil)
end)
test("old physical confirmation cannot survive selection changes or exit cancel",function()
    for _,action in ipairs({"select","exit"}) do
        local ui,root,s,p=setup("watcher","third_eye",true,true)
        pointer(root,"choicePanel/confirm","down",1);pointer(root,"choicePanel/confirm","up",1)
        if action=="select" then assert(tap(root,"choicePanel/card1",2))
        else assert(ui:openExit());assert(ui:closeExit()) end
        eq(click(root,"choicePanel/confirm",{touchId=1}),false)
        eq(s.pendingScry,p);eq(ui.battleUI.busy,false)
        if #ui.choiceUI.selected==0 then assert(tap(root,"choicePanel/card1",4)) end
        assert(tap(root,"choicePanel/confirm",3));eq(ui.battleUI.busy,true)
        local unchanged=freeze(s)
        eq(click(root,"choicePanel/confirm",{touchId=3}),false)
        eq(ui.battleUI:chooseCards("scry",{},p.token,ui.run.combatGeneration),false)
        unchanged();drain(ui);eq(s.pendingScry,nil)
    end
end)
print("GAME_UI_CLASS_CHOICES_PASS "..n)

assert(sliceRegistered==10,"all ten original class choice cases must register")
assert(n==sliceLast-sliceFirst+1,"every selected original class choice case must execute")
print("GAME_UI_CLASS_CHOICES_SLICE "..sliceFirst.." "..sliceLast.." "..n)
