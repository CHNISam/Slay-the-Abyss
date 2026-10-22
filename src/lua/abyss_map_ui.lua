-- Native map controller. root is mapPanel from mapLayout().
-- new(root, map, onChoose, clickEvent): validates availability, then calls
-- onChoose(nodeCopy). The synchronous callback owns the transaction (for example
-- return Nodes.enter(run, map, node.id)); it must call Map.choose and return true
-- on success, or leave map/run unchanged and return false, reason on rejection.
-- The UI never calls Map.choose. Accepted choices disable further navigation;
-- the host must call setNavigationEnabled(true) only after resolving that node.
-- Reopening/restoring a map does not imply its current node has been resolved:
-- an existing nonzero-floor map starts disabled. The host explicitly enables it.
-- setVisible(false) blocks input; render() follows externally changed map state.
local Map = require("abyss_map")
local M = {}
local names = { combat = "普通战斗", elite = "精英", camp = "营地", shop = "商店",
    event = "未知事件", treasure = "宝箱", boss = "首领" }
local lanes = { "左", "中", "右" }
local states = { "locked", "visited", "current", "available" }
local statusText = { locked = "锁定", visited = "已走过", current = "当前位置", available = "可前往" }
local function pageFor(floor) return math.floor((math.max(1, floor) - 1) / 5) + 1 end
local function integer(value) return type(value) == "number" and value == value and value % 1 == 0 end

function M.new(root, map, onChoose, clickEvent)
    assert(type(onChoose) == "function", "map UI requires onChoose callback")
    local self = { root = root, map = map, visible = true, navigationEnabled = map.floor == 0,
        page = pageFor(map.floor), slots = {} }
    local function child(name) return assert(root:GetChild(name), "missing map UI control " .. name) end
    local function label(name, value) child(name).text = value end
    local function bind(name, fn) child(name):GetChild("hit"):AddCursorEventListener(clickEvent, fn) end
    function self:render()
        local view, nodes, taken = Map.view(self.map), {}, {}
        for _, node in ipairs(view.nodes) do nodes[node.id] = node end
        for i = 1, #view.path - 1 do taken[view.path[i] .. ":" .. view.path[i + 1]] = true end
        self.slots = {}
        local first = (self.page - 1) * 5 + 1
        local available = {}
        for _, node in ipairs(Map.available(self.map)) do available[node.id] = true end
        label("page", "第 " .. first .. "–" .. (first + 4) .. " 层 / 共 15 层 · 第 " .. self.page .. "/3 页")
        label("notice", view.complete and "已抵达首领 · 请完成首领战斗" or
            (self.navigationEnabled and "点选白色可前往节点；路线只沿连线推进。" or "请先完成当前节点；地图导航已锁定。"))
        child("previous"):SetVisible(self.page > 1)
        child("next"):SetVisible(self.page < 3)
        for row = 1, 5 do
            local floor = first + row - 1
            label("floor" .. row, "第" .. floor .. "层")
            for lane = 1, 3 do
                local slot = (row - 1) * 3 + lane
                local node = nodes["f" .. floor .. "_l" .. lane]
                local box = child("node" .. slot)
                box:SetVisible(node ~= nil)
                if node then
                    self.slots[slot] = node.id
                    local state = node.id == view.currentNodeId and "current" or
                        (node.visited and "visited" or (available[node.id] and "available" or "locked"))
                    for _, value in ipairs(states) do box:GetChild(value):SetVisible(state == value) end
                    box:GetChild("label").text = floor .. lanes[lane] .. " · " .. assert(names[node.type])
                    box:GetChild("status").text = statusText[state] ..
                        (state == "available" and not self.navigationEnabled and " · 待完成当前节点" or "")
                    local targets = {}
                    for _, id in ipairs(node.nextIds) do
                        local target = assert(nodes[id], "map UI dangling route")
                        targets[#targets + 1] = target.floor .. lanes[target.lane]
                    end
                    box:GetChild("route").text = #targets > 0 and "去向 " .. table.concat(targets, " / ") or "终点 · 首领战"
                end
            end
            if row < 5 then
                for from = 1, 3 do for to = 1, 3 do
                    if math.abs(from - to) <= 1 then
                        local source, targetId = nodes["f" .. floor .. "_l" .. from], "f" .. (floor + 1) .. "_l" .. to
                        local exists = false
                        if source then for _, id in ipairs(source.nextIds) do if id == targetId then exists = true end end end
                        local used = source and taken[source.id .. ":" .. targetId] == true
                        local prefix = "edge" .. row .. "_" .. from .. "_" .. to .. "_"
                        child(prefix .. "normal"):SetVisible(exists and not used)
                        child(prefix .. "taken"):SetVisible(exists and used)
                    end
                end end
            end
        end
    end
    function self:setPage(page)
        if not integer(page) or page < 1 or page > 3 then return false, "invalid_page" end
        self.page = page self:render() return true
    end
    function self:focusCurrent()
        return self:setPage(pageFor(math.min(15, self.map.floor + (self.navigationEnabled and 1 or 0))))
    end
    function self:setNavigationEnabled(enabled)
        assert(type(enabled) == "boolean", "navigation enabled must be boolean")
        self.navigationEnabled = enabled self:focusCurrent()
    end
    function self:setVisible(visible)
        assert(type(visible) == "boolean", "map visibility must be boolean")
        self.visible = visible root:SetVisible(visible)
    end
    function self:choose(nodeId)
        if not self.visible or not self.navigationEnabled or self.choosing then return false, "navigation_disabled" end
        if self.map.floor == 15 then return false, "map_complete" end
        if type(nodeId) ~= "string" then return false, "invalid_node" end
        local selected
        for _, node in ipairs(Map.available(self.map)) do if node.id == nodeId then selected = node break end end
        if not selected then
            for _, node in ipairs(Map.view(self.map).nodes) do
                if node.id == nodeId then return false, "node_unavailable" end
            end
            return false, "invalid_node"
        end
        local expectedFloor = selected.floor
        self.choosing = true
        local called, accepted, reason = pcall(onChoose, selected)
        self.choosing = false
        if not called then error(accepted) end
        if accepted ~= true then return false, reason or "choice_rejected" end
        if self.map.currentNodeId ~= nodeId or self.map.floor ~= expectedFloor then
            return false, "selection_not_committed"
        end
        self.navigationEnabled = false
        self:focusCurrent()
        return true
    end
    for i = 1, 15 do local slot = i bind("node" .. slot, function()
        if self.slots[slot] then return self:choose(self.slots[slot]) end
        return false, "invalid_node"
    end) end
    bind("previous", function() if self.visible then return self:setPage(self.page - 1) end end)
    bind("next", function() if self.visible then return self:setPage(self.page + 1) end end)
    bind("focus", function() if self.visible then return self:focusCurrent() end end)
    self:render()
    return self
end
return M
