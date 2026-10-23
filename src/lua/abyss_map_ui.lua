-- Read Map.view/available, issue a synchronous choice command to the coordinator.
-- The coordinator owns Map.choose / Nodes.enter and resolving the chosen node.
-- No camp/shop/event/combat/run rules live in this module.
local Map = require("abyss_map")
local Theme = require("abyss_theme")
local Layout = require("abyss_map_layout")
local M = {}
local states = { "locked", "visited", "current", "available" }
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function clamp(n, low, high) return math.max(low, math.min(high, n)) end
local function child(control, name) return assert(control:GetChild(name), "missing map UI control " .. name) end

-- Standalone root holds mapBackdrop + stage/mapPanel from mapLayout(). With
-- options.embedded, root is the host's mapPanel and the host alone scales stage.
-- options may supply color(r,g,b,a) and imageSource; client defaults otherwise.
-- options.cursor (the platform cursor event enum) enables drag-to-scroll.
-- Host OnStart calls resize(game.GetUICanvasSize()), OnUpdate calls update(dt).
-- Host wheel deltas may call scrollBy(baseCanvasPixels).
function M.new(root, map, onChoose, clickEvent, options)
    assert(type(onChoose) == "function", "map UI requires onChoose callback")
    options = options or {}
    local colour = options.color or Color
    local imageSource = options.imageSource or (Enum and Enum.ImageSource.StaticReference)
    -- Platform Color has static methods and can be a callable table/userdata.
    -- Requiring a plain Lua function aborts the entire host before input binds.
    assert(colour ~= nil and imageSource ~= nil, "map UI needs client Color and imageSource")
    local embedded = options.embedded == true
    local stage, backdrop, panel
    if embedded then stage, panel = root, root
    else
        stage, backdrop = child(root, "stage"), child(root, "mapBackdrop")
        panel = child(stage, "mapPanel")
    end
    local view = Map.view(map)
    local self = { root = root, map = map, visible = true, navigationEnabled = view.floor == 0,
        scroll = 0, slots = {}, time = 0, breathing = {}, stage = stage, panel = panel,
        embedded = embedded, scale = 1, observedMap = map,
        observedNodeId = view.currentNodeId, observedFloor = view.floor }
    local drag
    local function cancelDrag()
        if drag then self.dragged = true end
        drag = nil
    end
    local function at(name)
        local i = 1
        while true do
            local group = panel:GetChild("mapGroup" .. i)
            if not group then break end
            local found = group:GetChild(name)
            if found then return found end
            i = i + 1
        end
        error("missing map UI control " .. name)
    end
    local function tint(control, c) control.imageColor = colour(c.r, c.g, c.b, c.a) end
    local function bind(name, fn) child(at(name), "hit"):AddCursorEventListener(clickEvent, fn) end
    local function position(node)
        return (node.lane - (Layout.lanes + 1) / 2) * Theme.layout.map.columnGap,
            Layout.firstY + (node.floor - 1) * Theme.layout.map.floorGap - self.scroll
    end
    local function observeMap(current)
        if self.map == self.observedMap then return false end
        cancelDrag()
        -- A restarted run can share floor/node ids with the previous run. Identity
        -- resets its presentation and default gate before the host grants access.
        self.observedMap = self.map
        self.observedNodeId, self.observedFloor = current.currentNodeId, current.floor
        self.navigationEnabled, self.time = current.floor == 0, 0
        self.scroll = clamp(Layout.firstY + (math.max(1, current.floor) - 1) *
            Theme.layout.map.floorGap - Layout.focusY, 0, Layout.maxScroll)
        return true
    end
    local function line(control, source, target, taken)
        local x1, y1 = position(source)
        local x2, y2 = position(target)
        -- Clip real graph segments to viewport, with half-stroke padding.
        local low, high = Layout.viewport.bottom + Layout.lineWidth / 2, Layout.viewport.top - Layout.lineWidth / 2
        if y2 < low or y1 > high then control:SetVisible(false) return end
        local a, b = clamp((low - y1) / (y2 - y1), 0, 1), clamp((high - y1) / (y2 - y1), 0, 1)
        local ax, ay = x1 + (x2 - x1) * a, y1 + (y2 - y1) * a
        local bx, by = x1 + (x2 - x1) * b, y1 + (y2 - y1) * b
        local dx, dy = bx - ax, by - ay
        if dy <= 0 then control:SetVisible(false) return end
        control:SetVisible(true)
        control:SetAnchoredPosition((ax + bx) / 2, (ay + by) / 2)
        control:SetSizeDelta(math.sqrt(dx * dx + dy * dy), Layout.lineWidth)
        control.localRotationZ = math.atan(dy, dx) * 180 / math.pi
        tint(control, taken and Theme.color.node.pathTaken or Theme.color.node.path)
    end
    function self:render()
        local current, nodes, taken = Map.view(self.map), {}, {}
        observeMap(current)
        if current.currentNodeId ~= self.observedNodeId or current.floor ~= self.observedFloor then
            self.navigationEnabled = false
        end
        self.observedNodeId, self.observedFloor = current.currentNodeId, current.floor
        for _, node in ipairs(current.nodes) do nodes[node.id] = node end
        for i = 1, #current.path - 1 do taken[current.path[i] .. ":" .. current.path[i + 1]] = true end
        self.slots, self.breathing = {}, {}
        at("title").text = "第一幕 · 第 " .. current.floor .. " 层"
        at("notice").text = current.complete and "已抵达首领宝箱 · 请完成当前房间" or
            (current.floor == 16 and "已抵达首领 · 请完成首领战斗与奖励" or
            (self.navigationEnabled and "上下拖动查看路线 · 点选可前往的节点出发" or "请先完成当前节点")
            )
        at("previous"):SetVisible(self.scroll > 0)
        at("next"):SetVisible(self.scroll < Layout.maxScroll)
        local edge = 0
        for _, node in ipairs(current.nodes) do for _, id in ipairs(node.nextIds) do
            edge = edge + 1
            assert(edge <= Layout.maxEdges, "map UI edge capacity exceeded")
            local target = assert(nodes[id], "map UI dangling route")
            if target.roomKind == "boss_treasure" then at("edge" .. edge):SetVisible(false)
            else line(at("edge" .. edge), node, target, taken[node.id .. ":" .. id]) end
        end end
        for i = edge + 1, Layout.maxEdges do at("edge" .. i):SetVisible(false) end
        assert(#current.nodes <= Layout.maxNodes, "map UI node capacity exceeded")
        for i = 1, Layout.maxNodes do
            local box, node = at("node" .. i), current.nodes[i]
            local visible = false
            if node then
                local size = node.type == "boss" and Theme.layout.map.bossNode or Theme.layout.map.node
                local x, y = position(node)
                -- Native container clipping is not established. Cull whole discs,
                -- including glow/breath extent, so no offscreen hit area can leak.
                local radius = (size + Layout.glowPadding) * Layout.breathScale / 2
                visible = node.roomKind ~= "boss_treasure" and y - radius >= Layout.viewport.bottom and y + radius <= Layout.viewport.top
                box:SetAnchoredPosition(x, y)
                box:SetSizeDelta(size, size)
                box.localScaleX, box.localScaleY = 1, 1
                local state = node.id == current.currentNodeId and "current" or
                    (node.visited and "visited" or (node.available and "available" or "locked"))
                for _, value in ipairs(states) do
                    child(box, value):SetVisible(state == value)
                    child(box, value):SetSizeDelta(size, size)
                end
                local glow = child(box, "glow")
                glow:SetVisible(state == "current")
                glow:SetSizeDelta(size + Layout.glowPadding, size + Layout.glowPadding)
                child(box, "body"):SetSizeDelta(size - Theme.space.border * 2, size - Theme.space.border * 2)
                tint(child(box, "body"), (state == "current" or state == "visited") and Theme.color.panelRaised or Theme.color.panel)
                local icon = child(box, "icon")
                icon:SetSizeDelta(size * .6, size * .6)
                local iconId = assert(Theme.icon.node[node.type], "missing node icon")
                icon:SetImage(imageSource, iconId)
                tint(icon, Theme.color.node[state == "available" and "reachable" or state])
                local hit = child(box, "hit")
                hit:SetSizeDelta(size, size)
                local clickable = visible and state == "available" and self.navigationEnabled and not self.choosing
                hit:SetVisible(clickable)
                hit.canControllerFocus = clickable
                if visible then self.slots[i] = node.id end
                if clickable then self.breathing[#self.breathing + 1] = box end
            end
            box:SetVisible(visible)
        end
        self:update(0)
    end
    function self:resize(width, height)
        if not finite(width) or not finite(height) or width <= 0 or height <= 0 then return false, "invalid_canvas" end
        cancelDrag()
        self.canvasWidth, self.canvasHeight = width, height
        if embedded then self.scale = 1 return true end
        local scale = math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
        stage.localScaleX, stage.localScaleY = scale, scale
        backdrop:SetSizeDelta(width, height)
        self.scale = scale
        return true
    end
    function self:update(dt)
        if not finite(dt) or dt < 0 then return false, "invalid_delta" end
        if not self.visible then return true end
        self.time = (self.time + dt) % Layout.breathSeconds
        local scale = self.reducedMotion and 1 or 1 + (Layout.breathScale - 1) *
            (1 - math.cos(self.time * 2 * math.pi / Layout.breathSeconds)) / 2
        for _, box in ipairs(self.breathing) do box.localScaleX, box.localScaleY = scale, scale end
        return true
    end
    function self:setReducedMotion(value)
        assert(type(value) == "boolean", "reduced motion must be boolean")
        self.reducedMotion = value self:update(0)
    end
    function self:setScroll(value)
        if not finite(value) then return false, "invalid_scroll" end
        self.scroll = clamp(value, 0, Layout.maxScroll) self:render() return true
    end
    function self:scrollBy(delta)
        if not self.visible then return false, "map_hidden" end
        if not finite(delta) then return false, "invalid_scroll" end
        return self:setScroll(self.scroll + delta)
    end
    function self:focusCurrent()
        local current = Map.view(self.map)
        return self:setScroll(Layout.firstY + (math.max(1, current.floor) - 1) * Theme.layout.map.floorGap - Layout.focusY)
    end
    function self:setNavigationEnabled(enabled)
        assert(type(enabled) == "boolean", "navigation enabled must be boolean")
        -- An explicit coordinator grant acknowledges any external map advance.
        local current = Map.view(self.map)
        observeMap(current)
        self.observedNodeId, self.observedFloor = current.currentNodeId, current.floor
        self.navigationEnabled = enabled self:render()
    end
    function self:setVisible(visible)
        assert(type(visible) == "boolean", "map visibility must be boolean")
        if not visible then cancelDrag() end
        self.visible = visible root:SetVisible(visible)
        if visible then self:focusCurrent() end
    end
    function self:choose(nodeId)
        local beforeMap = self.map
        local before = Map.view(beforeMap)
        if observeMap(before) then self:render() end
        if not self.visible or not self.navigationEnabled or self.choosing then return false, "navigation_disabled" end
        if before.complete then return false, "map_complete" end
        if type(nodeId) ~= "string" then return false, "invalid_node" end
        local selected
        for _, node in ipairs(Map.available(self.map)) do if node.id == nodeId then selected = node break end end
        if not selected then
            for _, node in ipairs(before.nodes) do if node.id == nodeId then return false, "node_unavailable" end end
            return false, "invalid_node"
        end
        local expectedFloor = selected.floor
        self.choosing = true
        local called, accepted, reason = pcall(onChoose, selected)
        self.choosing = false
        local after = Map.view(self.map)
        observeMap(after)
        local changed = self.map ~= beforeMap or after.floor ~= before.floor or after.currentNodeId ~= before.currentNodeId
        if changed then self.navigationEnabled = false self:focusCurrent() end
        if not called then return false, "choice_callback_error" end
        if accepted ~= true then return false, reason or "choice_rejected" end
        if self.map ~= beforeMap or after.currentNodeId ~= nodeId or after.floor ~= expectedFloor then return false, "selection_not_committed" end
        self.navigationEnabled = false self:focusCurrent() return true
    end
    -- Dragging the route scrolls it with the finger. A press that moved past the
    -- threshold is a scroll, never a node choice, even if it ends on a node.
    local cursor = options.cursor
    local function pointY(event)
        if not event or type(event.GetUIPos) ~= "function" then return end
        local _, y = event:GetUIPos()
        if type(y) ~= "number" or not finite(y) then return end
        local width, height = self.canvasWidth or Theme.canvas.base[1], self.canvasHeight or Theme.canvas.base[2]
        return y / math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
    end
    local function press(event)
        if not self.visible or drag and event and event.touchId ~= drag.touch then return end
        self.dragged = false
        local y = pointY(event)
        drag = self.visible and y and { touch = event.touchId, startY = y, y = y } or nil
    end
    local function move(event)
        if not self.visible then cancelDrag() return end
        if not drag or not event or event.touchId ~= drag.touch then return end
        local y = pointY(event)
        if not y then return end
        if not drag.moving and math.abs(y - drag.startY) < Layout.dragThreshold then return end
        drag.moving, self.dragged = true, true
        -- UI y grows upward; content follows the finger, so scroll moves the other way.
        self:setScroll(self.scroll - (y - drag.y))
        drag.y = y
    end
    local function release(event)
        if drag and event and event.touchId == drag.touch then move(event) drag = nil end
    end
    local function draggable(control)
        if not (cursor and cursor.CursorDown and cursor.CursorDrag and cursor.CursorUp) then return end
        control:AddCursorEventListener(cursor.CursorDown, press)
        control:AddCursorEventListener(cursor.CursorDrag, move)
        control:AddCursorEventListener(cursor.CursorUp, release)
        if cursor.CursorEndDrag then control:AddCursorEventListener(cursor.CursorEndDrag, release) end
    end
    draggable(at("dragArea"))
    for i = 1, Layout.maxNodes do local slot = i bind("node" .. slot, function()
        if self.dragged then self.dragged = false return false, "dragged" end
        if self.slots[slot] then return self:choose(self.slots[slot]) end
        return false, "node_outside_viewport"
    end) draggable(child(at("node" .. slot), "hit")) end
    bind("previous", function() return self:scrollBy(-Layout.scrollStep) end)
    bind("next", function() return self:scrollBy(Layout.scrollStep) end)
    bind("focus", function() if self.visible then return self:focusCurrent() end return false, "map_hidden" end)
    self:resize(Theme.canvas.base[1], Theme.canvas.base[2])
    self:focusCurrent()
    return self
end
return M
