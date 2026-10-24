-- Real Run/Map/Nodes and generated native controls; no gameplay rules are mocked.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI, Nodes = require("abyss_node_ui"), require("abyss_nodes")
local Run, Map, Combat = require("abyss_run"), require("abyss_map"), require("abyss_combat")
local Data, Layout, Presentation = require("abyss_data"), require("abyss_ui_layout"), require("abyss_presentation")
local cursor = {CursorEnter="enter", CursorExit="exit", CursorDown="down", CursorUp="up", CursorEndDrag="endDrag"}
local function control(spec, parent)
    local box = {parent=parent, visible=spec.visible~=false, children={}, listeners={}}
    function box:GetChild(key) return self.children[key] end
    function box:SetVisible(value) self.visible=value end
    function box:SetLocalScale(x,y,z) self.scale={x,y,z} end
    function box:SetAnchoredPosition(x,y) self.x,self.y=x,y end
    function box:AddCursorEventListener(event, fn)
        assert(not self.listeners[event], "duplicate listener") self.listeners[event]=fn
    end
    for _, child in ipairs(spec.children or {}) do box.children[child.name]=control(child,box) end
    return box
end
local function same(a,b)
    assert(type(a)==type(b))
    if type(a)~="table" then assert(a==b, tostring(a).." ~= "..tostring(b)) return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil) end
end
local function setup(pointerEvents)
    local run,map=Run.new(Data,42),Map.generate(Data,42)
    while not run.nodeFlow do
        local choices=Map.available(map) assert(#choices>0)
        for _,node in ipairs(choices) do
            if node.type=="shop" then assert(Nodes.enter(run,map,node.id)) break end
        end
        if not run.nodeFlow then assert(Map.choose(map,choices[1].id)) end
    end
    run.gold=10000 -- funding fixture only; original cards, prices and rules are unchanged
    local function find(list)
        for _,spec in ipairs(list) do
            if spec.name=="nodePanel" then return spec end
            local found=spec.children and find(spec.children) if found then return found end
        end
    end
    local root=control(assert(find(Layout)))
    local ui=UI.new(root,run,map,Presentation,"click",nil,{cursorEvents=pointerEvents~=false and cursor or nil})
    ui:setVisible(true)
    local function get(key)
        local box=root for part in key:gmatch("[^/]+") do box=assert(box:GetChild(part),key) end
        return box
    end
    local function emit(key,event,id,payload)
        local fn=get(key.."/hit").listeners[event]
        if fn then
            if payload=="nil" then return fn() end
            if payload=="empty" then return fn({}) end
            return fn({touchId=id})
        end
    end
    local function tap(key,id,payload)
        local box=get(key) while box do assert(box.visible,"hidden physical target") box=box.parent end
        emit(key,"down",id) emit(key,"up",id) return emit(key,"click",id,payload)
    end
    local function picker()
        assert(tap("shopView/removal",22)) assert(tap("pickerView/card1",22))
        assert(ui.mode=="picker" and ui.selected)
    end
    return ui,get,emit,tap,picker
end
local passed,failed=0,0
local function test(name,fn)
    local ok,err=pcall(fn)
    if ok then passed=passed+1 print("ok node gesture - "..name)
    else failed=failed+1 print("FAIL node gesture - "..name..": "..tostring(err)) end
end
for _,payload in ipairs({"id","nil","empty"}) do
    test("cancelled Delete cannot become Leave ("..payload..")",function()
        local ui,get,emit,tap,picker=setup() picker()
        local before,mapBefore=Combat.copy(ui.run),Map.snapshot(ui.map)
        emit("confirm","down",11) assert(get("confirm/pressed").visible)
        assert(tap("back",22))
        assert(get("confirm/label").text=="离开商店" and not get("confirm/pressed").visible)
        emit("confirm","up",11)
        assert(not emit("confirm","click",11,payload))
        assert(not emit("confirm","click",11,payload),"rejected token became click-only fallback")
        same(ui.run,before) same(ui.map,mapBefore)
        assert(tap("confirm",11,payload) and ui.run.nodeFlow.complete)
    end)
    test("old Leave cannot remove the selected card ("..payload..")",function()
        local ui,get,emit,tap,picker=setup()
        local before,mapBefore=Combat.copy(ui.run),Map.snapshot(ui.map)
        emit("confirm","down",11) picker()
        assert(get("confirm/label").text=="删除 · 75 金币")
        emit("confirm","up",11)
        assert(not emit("confirm","click",11,payload))
        same(ui.run,before) same(ui.map,mapBefore)
        local price=Nodes.view(ui.run,ui.map).node.removePrice
        assert(tap("confirm",11,payload))
        assert(#ui.run.deck==#before.deck-1 and ui.run.gold==before.gold-price)
        assert(not emit("confirm","click",11,payload),"consumed Delete token became Leave")
        assert(not ui.run.nodeFlow.complete)
        assert(tap("confirm",11,payload) and ui.run.nodeFlow.complete)
    end)
end
for _,boundary in ipairs({"render","hide","exit","endDrag"}) do
    test(boundary.." cancels pointer input until a fresh gesture",function()
        local ui,get,emit,tap=setup()
        local before,mapBefore=Combat.copy(ui.run),Map.snapshot(ui.map)
        emit("confirm","down",7)
        if boundary=="render" then ui:render()
        elseif boundary=="hide" then ui:setVisible(false) ui:setVisible(true)
        else emit("confirm",boundary,7) end
        emit("confirm","up",7)
        assert(not emit("confirm","click",7))
        same(ui.run,before) same(ui.map,mapBefore)
        assert(get("confirm").scale[1]==1 and not get("confirm/pressed").visible)
        assert(tap("confirm",7) and ui.run.nodeFlow.complete)
    end)
end
test("foreign release cannot consume the owner's gesture",function()
    local ui,get,emit,tap=setup()
    emit("confirm","down",1) emit("confirm","up",2)
    assert(not emit("confirm","click",2))
    assert(get("confirm/pressed").visible)
    emit("confirm","up",1) assert(emit("confirm","click",1))
    assert(ui.run.nodeFlow.complete)
end)
test("a Down received while hidden cannot become input after reopening",function()
    local ui,get,emit,tap=setup()
    local before=Combat.copy(ui.run)
    ui:setVisible(false) emit("confirm","down",1) ui:setVisible(true)
    emit("confirm","up",1) assert(not emit("confirm","click",1))
    same(ui.run,before)
    assert(tap("confirm",1) and ui.run.nodeFlow.complete)
end)
test("Exit after Up still cancels the pending click",function()
    local ui,get,emit,tap=setup()
    local before=Combat.copy(ui.run)
    emit("confirm","down",1) emit("confirm","up",1) emit("confirm","exit",1)
    assert(not emit("confirm","click",1)) same(ui.run,before)
    assert(tap("confirm",1) and ui.run.nodeFlow.complete)
end)
test("direct press and true click-only hosts remain available",function()
    for _,events in ipairs({false,true}) do
        local ui,get,emit,tap,picker=setup(events) picker()
        local n=#ui.run.deck
        assert(emit("confirm","click",1,"nil")) assert(#ui.run.deck==n-1)
        assert(emit("confirm","click",1,"empty") and ui.run.nodeFlow.complete)
    end
    local ui=setup() assert(ui:press("confirm") and ui.run.nodeFlow.complete)
end)
test("many cancelled touches recover without retaining earlier ownership",function()
    local ui,get,emit,tap=setup()
    local before=Combat.copy(ui.run)
    for id=1,200 do
        emit("confirm","down",id) emit("confirm","endDrag",id)
        emit("confirm","up",id) assert(not emit("confirm","click",id))
    end
    same(ui.run,before)
    emit("confirm","down",201) emit("confirm","up",201)
    assert(not emit("confirm","click",1))
    assert(emit("confirm","click",201) and ui.run.nodeFlow.complete)
end)
local function at(id,x,y) return {touchId=id,GetUIPos=function() return x,y end} end
local function drag(get,from,to,id,x0,x1,y1)
    get(from.."/hit").listeners.down(at(id,x0,0))
    get(to.."/hit").listeners.up(at(id,x1,y1 or 0))
    return get(to.."/hit").listeners.click({touchId=id})
end
test("normal shop swallows horizontal drag without paging or buying",function()
    local ui,get=setup()
    assert(ui.pageCount==1 and ui.page==1 and not ui:setPage(2))
    local before=Combat.copy(ui.run)
    assert(not drag(get,"shopView/card3","shopView/card1",5,300,180))
    assert(ui.page==1) same(ui.run,before)
    assert(not get('shopView/next').visible)
    assert(not drag(get,"shopView/card1","shopView/card4",6,100,400))
    assert(ui.page==1) same(ui.run,before)
end)
test("short, vertical and out-of-range drags never page, and edges never buy",function()
    local ui,get,emit,tap=setup()
    local before=Combat.copy(ui.run)
    assert(not drag(get,"shopView/card2","shopView/card2",7,300,320,200)) -- mostly vertical
    assert(ui.page==1)
    assert(not drag(get,"shopView/card2","shopView/card2",8,100,300)) -- already on page 1
    assert(ui.page==1) same(ui.run,before)
    local deck=#ui.run.deck
    get("shopView/card2/hit").listeners.down(at(9,300,0))
    get("shopView/card2/hit").listeners.up(at(9,310,0))
    assert(get("shopView/card2/hit").listeners.click({touchId=9}),"a short move is still a tap")
    assert(#ui.run.deck==deck+1)
end)
test("relic row swipe and duplicate terminal events never page or buy",function()
    local ui,get=setup()
    local before=Combat.copy(ui.run)
    assert(not drag(get,"shopView/relic1","shopView/relic2",10,400,100)) same(ui.run,before)
    ui:setPage(1)
    get("shopView/card3/hit").listeners.down(at(11,300,0))
    get("shopView/card3/hit").listeners.endDrag(at(11,100,0))
    get("shopView/card3/hit").listeners.up(at(11,100,0))
    assert(ui.page==1,"normal shop must not page")
    assert(not get("shopView/card3/hit").listeners.click({touchId=11})) same(ui.run,before)
end)
test("swipe distance is measured in design units after resize",function()
    local ui,get,_,_,picker=setup();picker()
    ui:resize(2560,1440)
    get("pickerView/card3/hit").listeners.down(at(12,600,0))
    get("pickerView/card3/hit").listeners.up(at(12,540,0)) -- 60 px = 30 design units
    assert(ui.pickPage==1)
    assert(not drag(get,"pickerView/card3","pickerView/card3",13,600,400))
    assert(ui.pickPage==2)
end)
test("picker rows page by swipe too",function()
    local ui,get,emit,tap,picker=setup() picker()
    if ui.pageCount<2 then return end
    local selected=ui.selected
    assert(not drag(get,"pickerView/card3","pickerView/card1",14,300,100))
    assert(ui.pickPage==2 and ui.selected==selected)
end)
print("LUA_NODE_GESTURES_PASS "..passed.." FAIL "..failed)
assert(failed==0,"node gesture regressions failed")
