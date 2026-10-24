package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local cursor = {CursorEnter="enter", CursorExit="exit", CursorDown="down", CursorUp="up", CursorEndDrag="endDrag"}
Enum = {CursorEventType=cursor}
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local function reachShop(ui,root)
    for floor=1,15 do
        local choices=F.Nodes.available(ui.run,ui.map)
        local next=choices[1]
        for _,node in ipairs(choices) do if node.type=="shop" then next=node break end end
        assert(ui.mapUI:choose(next.id))
        next.type=ui.run.nodeFlow.type
        if next.type=="shop" then return ui,root end
        if ui.mode=="battle" then
            F.win(ui,root); F.click(root,"battlePanel","skip")
            if ui.run.phase=="reward" and ui.run.rewards.manualContinue then
                if ui.run.rewards.potion and not ui.run.rewards.potion.resolved then F.click(root,"battlePanel","skipPotion") end
                F.click(root,"battlePanel","continue")
            end
        elseif next.type=="camp" then
            F.click(root,"nodePanel","campView/forge")
            F.click(root,"nodePanel","pickerView/card1")
            F.click(root,"nodePanel","confirm"); F.click(root,"nodePanel","confirm")
        elseif next.type=="treasure" then F.click(root,"nodePanel","treasureView/chest"); F.click(root,"nodePanel","treasureView/take")
        elseif next.type=="event" then
            for i=3,1,-1 do
                local box=root:GetChild("nodePanel"):GetChild("eventView"):GetChild("option"..i)
                if box.visible and box:GetChild("title").text=="［离开］" then F.click(root,"nodePanel","eventView/option"..i); break end
            end
            F.click(root,"nodePanel","confirm")
        end
    end
    error("fixture route has no shop")
end

local function setup()
    local data=F.Combat.copy(F.Data)
    for _,enemy in ipairs(data.enemies.enemies) do enemy.hp,enemy.hpRange=1,nil end
    data.rules.player.startingGold=10000 -- funding only; offers/rules unchanged
    local ui,root=F.fixture(data,nil,nil,cursor)
    ui.seed=42; assert(ui:start())
    return reachShop(ui,root)
end
local function hit(root,key)
    local b=root:GetChild("nodePanel") for p in key:gmatch("[^/]+") do b=assert(b:GetChild(p)) end
    return b:GetChild("hit")
end
local function emit(h,event,id)
    if h.listeners[event] then return h.listeners[event]({touchId=id,GetUIPos=function() return 100,100 end}) end
end
local passed,failed=0,0
local function test(name,fn)
    local ok,err=pcall(fn); if ok then passed=passed+1 else failed=failed+1 end
    print((ok and "PASS " or "FAIL ")..name..(ok and "" or ": "..tostring(err)))
end
for _,boundary in ipairs({"page","overlay","refresh"}) do
 test("stale shop card after "..boundary,function()
    local ui,root=setup(); local h=hit(root,"shopView/card1")
    emit(h,"down",11)
    if boundary=="page" then assert(not ui.nodeUI:setPage(2)); ui:refresh()
    elseif boundary=="overlay" then assert(ui:openDeck()); assert(ui:closeDeck())
    else ui:refresh() end
    local gold,n=ui.run.gold,#ui.run.deck
    emit(h,"up",11); emit(h,"click",11)
    assert(ui.run.gold==gold and #ui.run.deck==n,"old touch bought a card")
    emit(h,"down",12); emit(h,"up",12); assert(emit(h,"click",12))
    assert(#ui.run.deck==n+1,"fresh touch must buy")
 end)
end
for _,boundary in ipairs({"page","overlay"}) do
 test("stale picker card after "..boundary,function()
    local ui,root=setup()
    F.click(root,"nodePanel","shopView/removal")
    local h=hit(root,"pickerView/card1"); emit(h,"down",11)
    if boundary=="page" then assert(ui.nodeUI:setPage(2))
    else assert(ui:openDeck()); assert(ui:closeDeck()) end
    local gold,n=ui.run.gold,#ui.run.deck
    emit(h,"up",11); emit(h,"click",11)
    assert(ui.nodeUI.selected==nil,"old touch selected a different card")
    assert(ui.run.gold==gold and #ui.run.deck==n)
    emit(h,"down",12); emit(h,"up",12); assert(emit(h,"click",12))
    assert(ui.nodeUI.selected,"fresh touch must select")
 end)
end
test("old shop card cannot buy in a restarted run",function()
    local ui,root=setup(); local h=hit(root,"shopView/card1")
    emit(h,"down",11)
    F.click(root,"nodePanel","confirm")
    local Run=require("abyss_run")
    assert(Run.startCombat(ui.run,"cultist_solo")); ui:refresh()
    ui.run.combat.player.hp=1 -- isolate defeat routing, not combat balance
    for i=1,3 do if ui.mode~="defeat" then F.click(root,"battlePanel","endTurn") end end
    assert(ui.mode=="defeat")
    local old=ui.run; ui.seed=42
    F.click(root,"menuPanel","start"); assert(ui.run~=old)
    reachShop(ui,root)
    local gold,n=ui.run.gold,#ui.run.deck
    emit(h,"up",11); emit(h,"click",11)
    assert(ui.run.gold==gold and #ui.run.deck==n,"old run touch bought in new run")
    emit(h,"down",12); emit(h,"up",12); assert(emit(h,"click",12))
    assert(#ui.run.deck==n+1)
end)
print("LUA_NODE_CARD_OWNERSHIP "..passed.." passed; "..failed.." failed")
assert(failed==0)
