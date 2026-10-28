local first,last=...
first,last=first or 1,last or 7
assert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=15 and first<=last,'invalid exit UI slice')
local registered=0
local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local Combat, Nodes = F.Combat, F.Nodes
local count = 0
local function test(name, fn)
    registered=registered+1
    if registered<first or registered>last then return end
    fn(); count=count+1; print("ok exit UI "..count.." - "..name)
    print("GAME_UI_EXIT_CASE "..registered)
end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
-- Unlike normal game commands, this overlay intentionally freezes a busy
-- feedback queue. Do not use the fixture helper that drains every animation.
local function tap(root,panel,button)
    local hit=assert(root:GetChild(panel)):GetChild(button):GetChild("hit")
    local parent=hit
    while parent do assert(parent.visible,"hidden exit control"); parent=parent.parent end
    if hit.interactable then return hit.click() end
end
local function open(root)
    if not tap(root,"exitEntry","open") then return false end
    assert(root:GetChild('runMenu').visible,'native menu must open before abandon confirmation')
    local ok=tap(root,'runMenu','abandon')
    assert(not root:GetChild('runMenu').visible and root:GetChild('exitPanel').visible)
    return ok
end
local function cancel(root) return tap(root,"exitPanel","cancel") end
local function confirm(root) return tap(root,"exitPanel","confirm") end
local function battle(ui) assert(testStart(ui)); assert(ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id)) end

test("visible mouse/touch exit works before start and from the map without a keyboard",function()
    local calls=0
    local ui,root=F.fixture(nil,function(victory) assert(victory==false); calls=calls+1; return true end)
    assert(assert(root:GetChild("exitEntry"),"no visible exit entry").visible)
    assert(open(root) and root:GetChild("exitPanel").visible)
    assert(cancel(root) and ui.mode=="menu" and calls==0)
    assert(testStart(ui))
    local before=Combat.copy(ui.run)
    assert(open(root))
    assert(not ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id))
    assert(not ui:openDeck() and not testStart(ui))
    assert(cancel(root) and same(before,ui.run) and ui.mapUI.navigationEnabled)
end)

test("battle and reward commands cannot pass through exit confirmation and cancel preserves the run",function()
    local ui,root=F.fixture(nil,function() return true end)
    battle(ui)
    local before=Combat.copy(ui.run)
    assert(open(root))
    ui.battleUI:playSlot(1); ui.battleUI:endTurn(); ui.battleUI:usePotion(1)
    root:GetChild("battlePanel"):GetChild("skip").click()
    ui:update(30)
    assert(same(before,ui.run),"confirmation changed rules, time or RNG")
    assert(cancel(root) and ui.battleUI.active)
    F.win(ui,root)
    F.click(root,"battlePanel","cardReward")
    before=Combat.copy(ui.run)
    assert(open(root))
    ui.battleUI:playSlot(1); root:GetChild("battlePanel"):GetChild("skip").click()
    assert(cancel(root) and same(before,ui.run))
    F.click(root,"battlePanel","skip")
    assert(ui.mode=="battle" and ui.run.phase=="reward" and not ui.run.rewards.cardResolved)
    F.click(root,"battlePanel","continue")
    assert(ui.mode=="map")
end)

test("exit remains available during enemy feedback and does not wait for its banner",function()
    local calls=0
    local ui,root=F.fixture(nil,function(victory) calls=calls+1; assert(not victory); return true end)
    battle(ui); ui.battleUI:endTurn()
    assert(ui.battleUI.busy)
    local before=Combat.copy(ui.run)
    assert(open(root),"feedback locked the exit")
    local elapsed=ui.battleUI.feedback.elapsed
    ui:update(20)
    assert(same(before,ui.run) and ui.battleUI.feedback.elapsed==elapsed)
    assert(confirm(root) and calls==1 and ui.settlementRequested)
    assert(not ui:confirmExit() and not ui:closeExit() and not testStart(ui))
    ui:update(20)
    assert(same(before,ui.run) and calls==1)
end)

test("node and deck overlays retain state when exit is cancelled",function()
    local ui,root=F.fixture(nil,function() return true end)
    assert(testStart(ui)); ui.run.hp=20
    -- Stage navigation along the unchanged canonical graph; prior rooms are
    -- not played here because this case isolates exit/deck overlay ownership.
    local Map=require('abyss_map')
    local routes=dofile('tests/lua/support/map_routes.lua')
    local path=routes.to(ui.map,function(node)return node.type=='camp'end)
    for i=1,#path-1 do assert(Map.choose(ui.map,path[i]))end
    ui.run.floor=ui.map.floor
    local available=routes.at(ui.map,path[#path])
    assert(ui.mapUI:choose(available.id))
    assert(ui:openDeck()); local cards=ui.deckUI.cards
    local before=Combat.copy(ui.run)
    assert(open(root) and ui.deckUI.visible)
    assert(not ui:closeDeck() and not ui.nodeUI:press("campView/rest"))
    assert(cancel(root) and ui.deckUI.visible and ui.deckUI.cards==cards and same(before,ui.run))
    assert(ui:closeDeck()); assert(open(root))
    assert(not ui.nodeUI:press("campView/rest"))
    assert(cancel(root) and ui.nodeUI:press("campView/rest"))
end)

test("failed platform requests stay visible and retry submits only once",function()
    local calls=0
    local ui,root=F.fixture(nil,function()
        calls=calls+1
        if calls==1 then error("injected rejection") end
        return calls>2
    end)
    battle(ui); local before=Combat.copy(ui.run)
    assert(open(root))
    assert(not confirm(root) and not ui.settlementRequested)
    assert(root:GetChild("exitPanel"):GetChild("status").text:find("重试",1,true))
    assert(not confirm(root) and calls==2)
    assert(confirm(root) and calls==3 and ui.settlementRequested)
    assert(not ui:confirmExit() and calls==3 and same(before,ui.run))
end)

test("a cancelled pointer gesture cannot confirm a subsequently reopened dialog",function()
    local events={CursorDown="down",CursorUp="up",CursorExit="out",CursorDrag="drag",CursorEndDrag="endDrag",CursorMove="move"}
    local calls=0
    local ui,root=F.fixture(nil,function() calls=calls+1; return true end,nil,events)
    assert(testStart(ui)); assert(open(root))
    local hit=root:GetChild("exitPanel"):GetChild("confirm"):GetChild("hit")
    hit.listeners.down()
    assert(cancel(root)); assert(open(root))
    hit.listeners.up(); hit.click()
    assert(calls==0 and ui.exitOpen)
    hit.listeners.down(); hit.listeners.up(); hit.click(); hit.click()
    assert(calls==1 and ui.settlementRequested)
end)

test("resize invalidates a pending exit confirmation gesture",function()
    local events={CursorDown="down",CursorUp="up",CursorExit="out"}
    local calls=0
    local ui,root=F.fixture(nil,function() calls=calls+1; return true end,nil,events)
    assert(open(root))
    local hit=root:GetChild("exitPanel"):GetChild("confirm"):GetChild("hit")
    hit.listeners.down(); ui:resize(1920,1080); hit.listeners.up(); hit.click()
    assert(calls==0)
    hit.listeners.down(); hit.listeners.up(); hit.click()
    assert(calls==1)
end)

test("completed victory keeps its earned outcome when leaving through the shared entry",function()
    local result
    local ui,root=F.fixture(nil,function(victory) result=victory; return true end)
    assert(testStart(ui))
    ui.run.phase="victory"; ui.run.nodeFlow={complete=true,result="boss_treasure_complete"}
    ui:refresh(); assert(ui.mode=="victory")
    assert(open(root)); assert(confirm(root)); assert(result==true)
end)

test("one finger cannot borrow another finger's exit confirmation",function()
    local events={CursorDown="down",CursorUp="up",CursorExit="out"}
    local calls=0
    local ui,root=F.fixture(nil,function() calls=calls+1; return true end,nil,events)
    assert(open(root))
    local hit=root:GetChild("exitPanel"):GetChild("confirm"):GetChild("hit")
    hit.listeners.down({touchId=101})
    hit.listeners.up({touchId=202}); hit.click({touchId=202})
    assert(calls==0,"different touch confirmed exit")
    hit.listeners.up({touchId=101}); hit.click({touchId=101})
    assert(calls==1)
end)

test("missing platform integration keeps a cancelable exit dialog",function()
    local ui,root=F.fixture()
    assert(open(root))
    assert(not confirm(root) and not ui.settlementRequested)
    assert(root:GetChild("exitPanel"):GetChild("status").text:find("重试",1,true))
    assert(cancel(root) and not ui.exitOpen)
end)

test("another touch leaving the button cannot cancel the owner's release",function()
    local events={CursorDown="down",CursorUp="up",CursorExit="out",CursorEndDrag="endDrag"}
    local calls=0
    local ui,root=F.fixture(nil,function() calls=calls+1; return true end,nil,events)
    assert(open(root))
    local hit=root:GetChild("exitPanel"):GetChild("confirm"):GetChild("hit")
    hit.listeners.down({touchId=11}); hit.listeners.out({touchId=22}); hit.listeners.endDrag({touchId=22})
    hit.listeners.up({touchId=11}); hit.click({touchId=11})
    assert(calls==1)
end)

test("a first touch click without its own down and up cannot confirm exit",function()
    local events={CursorDown="down",CursorUp="up",CursorExit="out"}
    local calls=0
    local ui,root=F.fixture(nil,function() calls=calls+1; return true end,nil,events)
    assert(open(root))
    local hit=root:GetChild("exitPanel"):GetChild("confirm"):GetChild("hit")
    hit.click({touchId=303})
    assert(calls==0,"orphan first touch used click-only fallback")
    hit.listeners.down({touchId=303}); hit.listeners.up({touchId=303}); hit.click({touchId=303})
    assert(calls==1)
end)

test("a click missing its up consumes that incomplete confirmation",function()
    local events={CursorDown="down",CursorUp="up",CursorExit="out"}
    local calls=0
    local ui,root=F.fixture(nil,function() calls=calls+1; return true end,nil,events)
    assert(open(root))
    local hit=root:GetChild("exitPanel"):GetChild("confirm"):GetChild("hit")
    hit.listeners.down({touchId=11}); hit.click({touchId=11})
    hit.listeners.up({touchId=11}); hit.click({touchId=11})
    assert(calls==0)
end)

test("new touches remain usable after dialog replacement or resize cancels an old hold",function()
    for _,transition in ipairs({"reopen","resize"}) do
        local events={CursorDown="down",CursorUp="up",CursorExit="out"}
        local calls=0
        local ui,root=F.fixture(nil,function() calls=calls+1; return true end,nil,events)
        assert(open(root))
        local hit=root:GetChild("exitPanel"):GetChild("confirm"):GetChild("hit")
        hit.listeners.down({touchId=101})
        if transition=="reopen" then assert(cancel(root)); assert(open(root))
        else ui:resize(1600,900) end
        hit.listeners.down({touchId=202}); hit.listeners.up({touchId=202}); hit.click({touchId=202})
        assert(calls==1,"old hold blocked a new touch after "..transition)
    end
end)

test("cancel during feedback resumes its queue and later accepts game commands",function()
    local ui,root=F.fixture(nil,function() return true end)
    battle(ui); ui.battleUI:endTurn()
    assert(ui.battleUI.busy and open(root))
    local before=Combat.copy(ui.run)
    ui:update(5); assert(same(before,ui.run))
    assert(cancel(root))
    for _=1,400 do if not ui.battleUI.busy then break end ui:update(0.05) end
    assert(not ui.battleUI.busy and ui.battleUI.active and ui.run.phase=="combat")
    local turn=ui.run.combat.turn
    ui.battleUI:endTurn()
    assert(ui.run.combat.turn>turn or ui.run.phase=="defeat")
end)

print("LUA_GAME_UI_EXIT_PASS "..count)
assert(registered==15,"all original exit UI cases must register")
assert(count==last-first+1,"all selected exit UI cases must execute")
print("GAME_UI_EXIT_PART "..first.." "..last.." "..count)
