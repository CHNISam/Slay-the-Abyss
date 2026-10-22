local Map = require("abyss_map")
local MapUI = require("abyss_map_ui")
local data = require("abyss_data")
local count = 0
local function test(name, run) run(); count = count + 1; print("ok map UI " .. count .. " - " .. name) end
local function control()
    local self = { children = {}, visible = true, text = "" }
    function self:GetChild(name) return self.children[name] end
    function self:SetVisible(value) assert(type(value) == "boolean"); self.visible = value end
    function self:AddCursorEventListener(event, fn) assert(event == "click"); assert(not self.click); self.click = fn end
    return self
end
local function mock()
    local root = control()
    for _, name in ipairs({"page", "notice", "previous", "next", "focus"}) do root.children[name] = control() end
    for _, name in ipairs({"previous", "next", "focus"}) do root.children[name].children.hit = control() end
    for row = 1, 5 do
        root.children["floor" .. row] = control()
        for lane = 1, 3 do
            local box = control(); root.children["node" .. ((row - 1) * 3 + lane)] = box
            for _, name in ipairs({"label", "status", "route", "hit", "locked", "visited", "current", "available"}) do
                box.children[name] = control()
            end
        end
        if row < 5 then for from = 1, 3 do for to = 1, 3 do if math.abs(from - to) <= 1 then
            for _, state in ipairs({"normal", "taken"}) do root.children["edge" .. row .. "_" .. from .. "_" .. to .. "_" .. state] = control() end
        end end end end
    end
    return root
end
local function click(root, name) return root:GetChild(name):GetChild("hit").click() end
local function fixture(seed, callback)
    local root, map = mock(), Map.generate(data, seed or 42)
    return root, map, MapUI.new(root, map, callback or function(node) return Map.choose(map, node.id) end, "click")
end
local function idIndex(map)
    local index = {}; for _, node in ipairs(map.nodes) do index[node.id] = node end; return index
end

test("initial controls show legal starts and all real route destinations", function()
    local root, map, ui = fixture()
    assert(ui.page == 1 and ui.navigationEnabled)
    assert(not root:GetChild("previous").visible and root:GetChild("next").visible)
    local index = idIndex(map)
    local lanes = {"左", "中", "右"}
    for page = 1, 3 do
        assert(ui:setPage(page))
        for slot = 1, 15 do
            local node = index[ui.slots[slot]]
            local box = root:GetChild("node" .. slot)
            assert(box.visible == (node ~= nil))
            if node then
                assert(box:GetChild(node.floor == 1 and "available" or "locked").visible)
                assert(box:GetChild("status").text == (node.floor == 1 and "可前往" or "锁定"))
                for _, nextId in ipairs(node.nextIds) do
                    local target = index[nextId]
                    assert(box:GetChild("route").text:find(target.floor .. lanes[target.lane], 1, true))
                end
            end
        end
    end
    assert(root:GetChild("node14"):GetChild("label").text:find("首领", 1, true))
    assert(not root:GetChild("next").visible)
end)

test("actual control clicks advance once, notify copied node and lock pending work", function()
    local received, callbackBlocked
    local root, map, ui
    root, map, ui = fixture(42, function(node)
        received = node
        local ok, reason = ui:choose(node.id)
        callbackBlocked = not ok and reason == "navigation_disabled"
        node.nextIds[1] = "tamper"
        return Map.choose(map, node.id)
    end)
    assert(click(root, "node1"))
    assert(map.floor == 1 and #map.path == 1 and callbackBlocked and not ui.navigationEnabled)
    assert(received.id == map.currentNodeId and map.nodes[1].nextIds[1] ~= "tamper")
    assert(root:GetChild("node1"):GetChild("current").visible)
    local ok, reason = click(root, "node4")
    assert(not ok and reason == "navigation_disabled" and map.floor == 1)
    ui:setNavigationEnabled(true)
    local nextNode = Map.available(map)[1]
    local slot = (nextNode.floor - 1) * 3 + nextNode.lane
    assert(click(root, "node" .. slot) and map.floor == 2)
    assert(root:GetChild("node1"):GetChild("visited").visible)
    assert(root:GetChild("edge1_1_" .. nextNode.lane .. "_taken").visible)
end)

test("invalid, locked, backward, disconnected and hidden clicks never mutate map", function()
    local callbacks = 0
    local root, map, ui
    root, map, ui = fixture(42, function(node) callbacks = callbacks + 1 return Map.choose(map, node.id) end)
    for _, id in ipairs({false, {}, "missing", "f5_l2"}) do
        assert(not ui:choose(id)); assert(map.floor == 0 and #map.path == 0)
    end
    assert(not ui:choose(nil))
    assert(not click(root, "node4")); assert(callbacks == 0)
    ui:setVisible(false)
    assert(not click(root, "node1")); click(root, "next"); assert(ui.page == 1)
    ui:setVisible(true); assert(click(root, "node1"))
    ui:setNavigationEnabled(true)
    local allowed = {}; for _, node in ipairs(Map.available(map)) do allowed[node.id] = true end
    for lane = 1, 3 do if not allowed["f2_l" .. lane] then assert(not click(root, "node" .. (3 + lane))) end end
    assert(not click(root, "node1")); assert(map.floor == 1 and callbacks == 1)
    for _, bad in ipairs({0, 4, 1.5, false, "2", 0/0, math.huge}) do assert(not ui:setPage(bad)) end
    assert(ui.page == 1)
end)

test("paging covers 15 floors, follows progress, shows exact graph edges and boss completion", function()
    local callbacks = 0
    local root, map, ui
    root, map, ui = fixture(313, function(node) callbacks = callbacks + 1 return Map.choose(map, node.id) end)
    local index = idIndex(map)
    for floor = 1, 15 do
        ui:setNavigationEnabled(true)
        assert(ui.page == math.floor((floor - 1) / 5) + 1)
        local selected = Map.available(map)[1]
        local row = (floor - 1) % 5 + 1
        local slot = (row - 1) * 3 + selected.lane
        assert(click(root, "node" .. slot))
        assert(map.currentNodeId == selected.id and callbacks == floor)
        if row < 5 then
            for from = 1, 3 do for to = 1, 3 do if math.abs(from - to) <= 1 then
                local source = index["f" .. floor .. "_l" .. from]
                local exists = false
                if source then for _, id in ipairs(source.nextIds) do if id == "f" .. (floor + 1) .. "_l" .. to then exists = true end end end
                assert(root:GetChild("edge" .. row .. "_" .. from .. "_" .. to .. "_normal").visible == exists)
            end end end
        end
    end
    ui:setNavigationEnabled(true)
    assert(not ui:choose("f15_l2") and callbacks == 15 and #map.path == 15)
    assert(root:GetChild("notice").text == "已抵达首领 · 请完成首领战斗")
    click(root, "previous"); assert(ui.page == 2)
    click(root, "focus"); assert(ui.page == 3)
end)

test("restored in-progress maps start locked until the host resolves the node", function()
    local map = Map.generate(data, 1)
    for _ = 1, 7 do assert(Map.choose(map, Map.available(map)[1].id)) end
    local restored = assert(Map.restore(data, Map.snapshot(map)))
    local root = mock()
    local ui = MapUI.new(root, restored, function(node) return Map.choose(restored, node.id) end, "click")
    assert(not ui.navigationEnabled and ui.page == 2)
    assert(not ui:choose(Map.available(restored)[1].id) and restored.floor == 7)
    ui:setNavigationEnabled(true)
    assert(ui:choose(Map.available(restored)[1].id) and restored.floor == 8)
end)

test("transaction rejection preserves map, lock and page, and accepts a later retry", function()
    local accepted, called = false, 0
    local root, map, ui
    root, map, ui = fixture(42, function(node)
        called = called + 1
        if not accepted then return false, "node_pending" end
        return Map.choose(map, node.id)
    end)
    local ok, reason = click(root, "node2")
    assert(not ok and reason == "node_pending" and called == 1)
    assert(map.floor == 0 and #map.path == 0 and ui.navigationEnabled and ui.page == 1)
    accepted = true
    assert(click(root, "node2") and map.floor == 1 and called == 2 and not ui.navigationEnabled)
    local otherRoot = mock()
    local incomplete = MapUI.new(otherRoot, Map.generate(data, 1), function() return true end, "click")
    ok, reason = click(otherRoot, "node1")
    assert(not ok and reason == "selection_not_committed" and incomplete.navigationEnabled)
end)

print("LUA_MAP_UI_PASS " .. count)
