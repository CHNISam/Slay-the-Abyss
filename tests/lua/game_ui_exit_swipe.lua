package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local cursor = {CursorEnter="enter", CursorExit="exit", CursorDown="down", CursorUp="up", CursorEndDrag="endDrag"}
Enum = {CursorEventType=cursor} -- Native NodeUI uses the global enum fallback.
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local passed, failed = 0, 0

local function setup(relicSeed)
    local host, root = F.fixture(nil, function() return true end, nil, cursor)
    assert(host:start())
    -- Independent complete source queue for the relic-purchase component only;
    -- the original run/map/card/merchant seed1 and all gestures stay unchanged.
    if relicSeed then host.run.relicPool=require('abyss_relic_pool').new(relicSeed,host.run.data.relicSource) end
    local destination = F.Nodes.available(host.run, host.map)[1]
    -- Explicit setup: force the first available node to shop and fund purchases.
    -- Node entry, offers, paging, purchases and inventory use real commands/rules.
    for _, node in ipairs(host.map.nodes) do
        if node.id == destination.id then node.type = "shop" end
    end
    assert(host.mapUI:choose(destination.id))
    host.run.gold = 10000
    host:refresh()
    local ui = host.nodeUI
    assert(ui.swipeEnabled and ui.pageCount == 1)
    assert(not ui:setPage(2))
    local function hit(key)
        local box = root:GetChild("nodePanel")
        for part in key:gmatch("[^/]+") do box = assert(box:GetChild(part)) end
        return box:GetChild("hit")
    end
    local function emit(key, kind, touch, x)
        return assert(hit(key).listeners[kind])({touchId=touch, GetUIPos=function() return x or 100, 100 end})
    end
    local function tap(key, touch)
        emit(key, "down", touch)
        emit(key, "up", touch)
        return emit(key, "click", touch)
    end
    return host, ui, emit, tap
end

local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(why)))
end

test("exit cancels old shop swipe, preserves its page and accepts fresh swipe and purchase", function()
    local host, ui, emit, tap = setup()
    local count, gold = #host.run.deck, host.run.gold
    emit("shopView/card1", "down", 11, 100)
    assert(host:openExit())
    assert(host:closeExit() and ui.visible and ui.page == 1)
    emit("shopView/card1", "up", 11, 400)
    assert(not emit("shopView/card1", "click", 11), "old swipe purchased after exit cancel")
    assert(#host.run.deck == count and host.run.gold == gold)
    emit("shopView/card1", "down", 22, 100)
    emit("shopView/card1", "up", 22, 400)
    assert(not emit("shopView/card1", "click", 22))
    assert(ui.page == 1 and #host.run.deck == count and host.run.gold == gold)
    assert(tap("shopView/card1", 33))
    assert(#host.run.deck == count + 1 and host.run.gold < gold)
end)

test("simulated callbacks below exit cannot page or survive cancellation", function()
    local host, ui, emit = setup()
    local count, gold = #host.run.deck, host.run.gold
    assert(host:openExit())
    -- Deliberately deliver callbacks despite the modal; this does not assert
    -- that the native client dispatches physical events through its blocker.
    emit("shopView/card1", "down", 11, 100)
    emit("shopView/card1", "up", 11, 400)
    assert(not emit("shopView/card1", "click", 11) and ui.page == 1)
    emit("shopView/card1", "down", 22, 100)
    assert(host:closeExit())
    emit("shopView/card1", "up", 22, 400)
    assert(not emit("shopView/card1", "click", 22))
    assert(ui.page == 1 and #host.run.deck == count and host.run.gold == gold)
end)

test("old leave hold cannot execute after exit cancel and fresh input works", function()
    local host, ui, emit, tap = setup()
    emit("confirm", "down", 11)
    assert(host:openExit() and host:closeExit())
    emit("confirm", "up", 11)
    assert(not emit("confirm", "click", 11))
    assert(not host.run.nodeFlow.complete and ui.page == 1)
    assert(tap("confirm", 22) and host.run.nodeFlow.complete)
end)

test("old relic hold cannot buy after exit cancel and fresh input works", function()
    local host, ui, emit, tap = setup(dofile('tests/fixtures/economy_relic_seeds.lua').membership.seed)
    local gold, count = host.run.gold, #host.run.relics
    emit("shopView/relic3", "down", 11)
    assert(host:openExit() and host:closeExit())
    emit("shopView/relic3", "up", 11)
    assert(not emit("shopView/relic3", "click", 11))
    assert(host.run.gold == gold and #host.run.relics == count and ui.page == 1)
    assert(tap("shopView/relic3", 22))
    assert(#host.run.relics == count + 1 and host.run.gold < gold)
end)

test("old picker hold cannot select after exit cancel and fresh input keeps its page", function()
    local host, ui, emit, tap = setup()
    assert(ui:press("shopView/removal") and ui:setPage(2))
    local count, gold = #host.run.deck, host.run.gold
    emit("pickerView/card1", "down", 11)
    assert(host:openExit() and host:closeExit())
    emit("pickerView/card1", "up", 11)
    assert(not emit("pickerView/card1", "click", 11))
    assert(ui.selected == nil and ui.pickPage == 2)
    assert(tap("pickerView/card1", 22) and ui.selected ~= nil and ui.pickPage == 2)
    assert(#host.run.deck == count and host.run.gold == gold)
end)

print("LUA_GAME_UI_EXIT_SWIPE " .. passed .. " passed; " .. failed .. " failed")
assert(failed == 0, "exit swipe ownership regressions failed")
