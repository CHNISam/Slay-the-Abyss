-- Read Map.view/available, issue a synchronous choice command to the coordinator.
-- The coordinator owns Map.choose / Nodes.enter and resolving the chosen node.
-- No camp/shop/event/combat/run rules live in this module.
local Map = require("abyss_map")
local Theme = require("abyss_theme")
local Layout = require("abyss_map_layout")
local Acts = require("abyss_acts")
local Controller = require("abyss_controller")
local M = {}
local states = { "locked", "visited", "current", "available" }
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function clamp(n, low, high) return math.max(low, math.min(high, n)) end
local function child(control, name) return assert(control:GetChild(name), "missing map UI control " .. name) end
-- Chapter metadata is presentation context, not permission to enter new content.
-- Legacy Act 1 intentionally has no act/firstFloor/terminalFloor fields.
local function chapterFor(map)
    if type(map) ~= "table" then return end
    local ok, chapter = pcall(Acts.get, map.act or 1)
    if not ok or not finite(map.floor) or map.floor % 1 ~= 0
        or map.floor < chapter.first - 1 or map.floor > chapter.last
        or type(map.sourceSignature) ~= "string" or map.sourceSignature == "" then return end
    if chapter.act == 1 then
        if map.version ~= 3 or map.act ~= nil or map.firstFloor ~= nil or map.terminalFloor ~= nil
            or map.sourceSignature:sub(1,7) ~= "map-v3:" then return end
    else
        local prefix = "map-v4:sts-a0-319009d5:" .. chapter.id .. ":"
        if map.version ~= 4 or map.firstFloor ~= chapter.first or map.terminalFloor ~= chapter.last
            or map.sourceSignature:sub(1,#prefix) ~= prefix then return end
    end
    if type(map.nodes) ~= "table" then return end
    for _, node in ipairs(map.nodes) do
        if type(node) ~= "table" or not finite(node.floor) or node.floor % 1 ~= 0 or node.floor < chapter.first or node.floor > chapter.last
            or node.localFloor ~= nil and node.localFloor ~= node.floor - chapter.first + 1 then return end
    end
    return chapter
end
local function sameContext(a, b)
    for _, key in ipairs({"act", "version", "firstFloor", "terminalFloor", "sourceSignature", "seed", "runSeed", "mapSeed"}) do
        if a[key] ~= b[key] then return false end
    end
    return true
end
local function localFloor(map, floor) return floor - (map.firstFloor or 1) + 1 end
local function atStart(map) return map.floor == (map.firstFloor or 1) - 1 end

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
    -- The title host binds real owners only after Start succeeds.
    if map ~= nil then assert(chapterFor(map), "invalid map chapter context") end
    local view = map and Map.view(map)
    local self = { root = root, map = map, visible = map ~= nil, navigationEnabled = view and atStart(view) or false,
        scroll = 0, slots = {}, time = 0, breathing = {}, stage = stage, panel = panel,
        embedded = embedded, scale = 1, observedMap = map, observedContext = view,
        observedNodeId = view and view.currentNodeId, observedFloor = view and view.floor }
    local drag, released, pointerObserved, scrollAnimation
    local buttonHover, buttonPress
    local function cancelSelection()
        if drag then drag.selection = nil end
        released = nil
    end
    local function cancelDrag()
        if drag then self.dragged = true end
        cancelSelection()
        drag = nil
        scrollAnimation, buttonHover, buttonPress = nil, nil, nil
    end
    local controlCache = {}
    local function at(name)
        if controlCache[name] then return controlCache[name] end
        local i = 1
        while true do
            local group = panel:GetChild("mapGroup" .. i)
            if not group then break end
            local found = group:GetChild(name)
            if found then controlCache[name] = found return found end
            i = i + 1
        end
        error("missing map UI control " .. name)
    end
    local function tint(control, c) control.imageColor = colour(c.r, c.g, c.b, c.a) end
    local function pathColour(ink, opacity)
        return colour(ink.r, ink.g, ink.b, math.floor(ink.a * opacity))
    end
    local visual = Theme.layout.map.presentation
    local pathColours = {
        taken = pathColour(Theme.color.node.pathTaken, visual.takenOpacity),
        next = pathColour(Theme.color.node.path, visual.nextOpacity),
        future = pathColour(Theme.color.node.path, visual.futureOpacity),
    }
    local function controllerContextReady()
        return chapterFor(self.map) ~= nil and self.map == self.observedMap
            and sameContext(self.map,self.observedContext)
            and self.map.floor == self.observedFloor and self.map.currentNodeId == self.observedNodeId
    end
    local function bind(name, fn)
        local hit=child(at(name),"hit")
        hit:AddCursorEventListener(clickEvent,function(event)
            if Controller.pointerBlocked(options.controller)then return false end
            return fn(event)
        end)
        Controller.bind(options.controller,hit,"map",function()
            local slot=tonumber(name:match("^node(%d+)$"))
            if slot then
                if scrollAnimation then return false,"map_scrolling" end
                cancelDrag()
                return self.slots[slot] and self:choose(self.slots[slot])
            end
            return fn()
        end,controllerContextReady,name:match("^node") and tonumber(name:match("%d+")) or 100)
    end
    local function buttonEnabled(name)
        return self.visible and chapterFor(self.map) ~= nil and (name == "focus" or name == "previous" and self.scroll > 0
            or name == "next" and self.scroll < Layout.maxScroll)
    end
    local function paintButton(name)
        local box, enabled = at(name), buttonEnabled(name)
        local pressed = enabled and buttonPress and buttonPress.name == name
        local hover = enabled and buttonHover == name and not pressed
        -- Pointer users pan the route directly. Compact hints only appear while
        -- a controller is active, retaining native focus access to the whole map.
        box:SetVisible(Controller.isController(options.controller))
        child(box,"hit"):SetVisible(enabled)
        child(box,"hit").canControllerFocus = enabled
        tint(child(box,"frame"), not enabled and Theme.color.line
            or (pressed or hover) and Theme.color.goldBright or Theme.color.goldDim)
        tint(child(box,"body"), pressed and Theme.color.goldDim
            or hover and Theme.color.buttonHover or Theme.color.panel)
        local ink = not enabled and Theme.color.textMuted
            or pressed and Theme.color.buttonPressedText or Theme.color.text
        child(box,"label").fontColor = colour(ink.r,ink.g,ink.b,ink.a)
        local scale = pressed and Theme.layout.nativeNode.buttonStates.pressedScale
            or Theme.layout.nativeNode.buttonStates.normalScale
        box:SetLocalScale(scale,scale,1)
    end
    local function position(node)
        return (node.lane - (Layout.lanes + 1) / 2) * Theme.layout.map.columnGap,
            Layout.firstY + (localFloor(self.map, node.floor) - 1) * Theme.layout.map.floorGap - self.scroll
    end
    local function observeMap(current)
        if self.map == self.observedMap and sameContext(current,self.observedContext) then return false end
        cancelDrag()
        -- A restarted run can share floor/node ids with the previous run. Identity
        -- resets its presentation and default gate before the host grants access.
        self.observedMap, self.observedContext = self.map, current
        self.entryError=nil
        self.observedNodeId, self.observedFloor = current.currentNodeId, current.floor
        self.navigationEnabled, self.time = atStart(current), 0
        self.scroll = clamp(Layout.firstY + (math.max(1, localFloor(current, current.floor)) - 1) *
            Theme.layout.map.floorGap - Layout.focusY, 0, Layout.maxScroll)
        return true
    end
    local function line(control, source, target, taken, reachable)
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
        control.imageColor = taken and pathColours.taken or reachable and pathColours.next or pathColours.future
    end
    function self.render(_)
        if not self.map then return false, "map_unbound" end
        local context = chapterFor(self.map)
        if not context then
            cancelDrag()
            self.navigationEnabled, self.slots, self.breathing = false, {}, {}
            at("title").text, at("notice").text = "", "地图章节信息无效 · 请重新启程"
            for i = 1, Layout.maxNodes do at("node" .. i):SetVisible(false) end
            for i = 1, Layout.maxEdges do at("edge" .. i):SetVisible(false) end
            for _, name in ipairs({"previous","next","focus"}) do paintButton(name) end
            return
        end
        local current, nodes, taken = Map.view(self.map), {}, {}
        observeMap(current)
        if current.currentNodeId ~= self.observedNodeId or current.floor ~= self.observedFloor then
            cancelDrag()
            self.navigationEnabled = false
        end
        self.observedNodeId, self.observedFloor = current.currentNodeId, current.floor
        for _, node in ipairs(current.nodes) do nodes[node.id] = node end
        for i = 1, #current.path - 1 do taken[current.path[i] .. ":" .. current.path[i + 1]] = true end
        self.slots, self.breathing = {}, {}
        local chapter = Acts.get(current.act or 1)
        local terminal = chapter.terminal == 'boss_treasure' and "已抵达首领宝箱 · 请完成当前房间"
            or current.act == 4 and "已抵达终幕首领 · 请完成最终战斗与结算"
            or "已抵达终点 · 请完成当前房间"
        at("title").text = chapter.name .. " · 第 " .. current.floor .. " 层"
        at("notice").text = self.entryError or (current.complete and terminal or
            (current.floor == chapter.boss and (self.navigationEnabled
                and (chapter.terminal == 'boss_treasure' and "首领奖励已处理 · 请选择首领宝箱" or "首领奖励已处理 · 请前往终点")
                or "已抵达首领 · 请完成首领战斗与奖励") or
            (self.navigationEnabled and (Controller.isController(options.controller)
                and "摇杆选择路线 · 确认出发 · 返回菜单" or "上下拖动查看路线 · 点选可前往的节点出发") or "请先完成当前节点")
            ))
        local notice=current.emeraldSelection and Theme.layout.map.emeraldNotice or Theme.layout.map.notice
        at('notice'):SetAnchoredPosition(notice[1],notice[2]);at('notice'):SetSizeDelta(notice[3],Theme.layout.map.presentation.noticeHeight)
        if current.emeraldSelection then at('notice').text=at('notice').text..' · 绿字节点为燃烧精英，胜利可另领绿钥匙'end
        buttonHover, buttonPress = nil, nil
        for _, name in ipairs({"previous","next","focus"}) do paintButton(name) end
        local edge = 0
        for _, node in ipairs(current.nodes) do for _, id in ipairs(node.nextIds) do
            edge = edge + 1
            assert(edge <= Layout.maxEdges, "map UI edge capacity exceeded")
            local target = assert(nodes[id], "map UI dangling route")
            line(at("edge" .. edge), node, target, taken[node.id .. ":" .. id], node.id == current.currentNodeId and target.available)
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
                if node.hasEmeraldKey then radius=math.max(radius,math.abs(Theme.layout.map.emeraldLabel[2])+Theme.layout.map.emeraldLabel[4]/2)end
                visible = y - radius >= Layout.viewport.bottom and y + radius <= Layout.viewport.top
                -- Hidden rows have no slots or focus targets. Avoid rewriting
                -- every child of all 17 floors during each pan animation frame.
                if visible then
                box:SetAnchoredPosition(x, y)
                box:SetSizeDelta(size, size)
                box.localScaleX, box.localScaleY = 1, 1
                local state = node.id == current.currentNodeId and "current" or
                    (node.visited and "visited" or (node.available and "available" or "locked"))
                for _, value in ipairs(states) do
                    child(box, value):SetVisible(state == value)
                    child(box, value):SetSizeDelta(size, size)
                end
                local token = child(box, "positionToken")
                token:SetVisible(state == "current")
                child(box, "body"):SetSizeDelta(size - Theme.space.border * 2, size - Theme.space.border * 2)
                tint(child(box, "body"), (state == "current" or state == "visited") and Theme.color.panelRaised or Theme.color.panel)
                child(box, "locked"):SetVisible(false)
                child(box, "body"):SetVisible(state ~= "locked")
                local icon = child(box, "icon")
                icon:SetSizeDelta(size * .6, size * .6)
                local iconId = assert(Theme.icon.node[node.type], "missing node icon")
                icon:SetImage(imageSource, iconId)
                local palette = Theme.color.mapCanvas
                tint(icon, state == 'locked' and palette.far or state == 'visited' and palette.visited or palette.kind[node.type])
                icon:SetAnchoredPosition(0,node.hasEmeraldKey and Theme.layout.map.emeraldIconY or 0)
                if node.hasEmeraldKey then tint(icon,Theme.color.positive)end
                child(box,'emeraldLabel'):SetVisible(node.hasEmeraldKey==true)
                local hit = child(box, "hit")
                hit:SetSizeDelta(size, size)
                local clickable = visible and state == "available" and self.navigationEnabled
                    and not self.choosing and not scrollAnimation
                hit:SetVisible(clickable)
                hit.canControllerFocus = clickable
                if visible then self.slots[i] = node.id end
                if clickable then self.breathing[#self.breathing + 1] = box end
                else
                    child(box, 'hit'):SetVisible(false)
                    child(box, 'hit').canControllerFocus = false
                end
            end
            box:SetVisible(visible)
        end
        self:update(0)
    end
    function self.resize(_, width, height)
        if not finite(width) or not finite(height) or width <= 0 or height <= 0 then return false, "invalid_canvas" end
        cancelDrag()
        for _, name in ipairs({"previous","next","focus"}) do paintButton(name) end
        self.canvasWidth, self.canvasHeight = width, height
        if embedded then self.scale = 1 return true end
        local scale = math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
        stage.localScaleX, stage.localScaleY = scale, scale
        backdrop:SetSizeDelta(width, height)
        self.scale = scale
        return true
    end
    function self.update(_, dt)
        if not finite(dt) or dt < 0 then return false, "invalid_delta" end
        if not self.visible then return true end
        local usingController = Controller.isController(options.controller)
        if self.usingController ~= usingController then
            self.usingController = usingController
            for _, name in ipairs({"previous","next","focus"}) do paintButton(name) end
        end
        if not chapterFor(self.map) or self.map ~= self.observedMap or not sameContext(self.map,self.observedContext) then
            self:render()
            return true
        end
        self.time = (self.time + dt) % Layout.breathSeconds
        if scrollAnimation and dt > 0 then
            -- A coordinator may replace/advance the map before the next render.
            if self.map ~= self.observedMap or self.map.floor ~= self.observedFloor
                or self.map.currentNodeId ~= self.observedNodeId then
                cancelDrag()
            else
                scrollAnimation.elapsed = scrollAnimation.elapsed + dt
                local t = clamp(scrollAnimation.elapsed / Layout.scrollSeconds,0,1)
                local from, target = scrollAnimation.from, scrollAnimation.target
                self.scroll = clamp(from + (target - from) * (1 - (1 - t)^3),0,Layout.maxScroll)
                if t == 1 then self.scroll, scrollAnimation = target, nil end
            end
            -- render's update(0) only paints breathing; it cannot advance/recurse.
            self:render()
            return true
        end
        local scale = self.reducedMotion and 1 or 1 + (Layout.breathScale - 1) *
            (1 - math.cos(self.time * 2 * math.pi / Layout.breathSeconds)) / 2
        for _, box in ipairs(self.breathing) do box.localScaleX, box.localScaleY = scale, scale end
        return true
    end
    function self.setReducedMotion(_, value)
        assert(type(value) == "boolean", "reduced motion must be boolean")
        self.reducedMotion = value
        if value and scrollAnimation then return self:setScroll(scrollAnimation.target) end
        self:update(0)
    end
    function self.setScroll(_, value)
        if not finite(value) then return false, "invalid_scroll" end
        value = clamp(value, 0, Layout.maxScroll)
        if value ~= self.scroll or scrollAnimation then cancelSelection() end
        scrollAnimation = nil
        self.scroll = value self:render() return true
    end
    local function animateScrollTo(value)
        if not self.visible then return false,"map_hidden" end
        value = clamp(value,0,Layout.maxScroll)
        if scrollAnimation and scrollAnimation.target == value then return true end
        cancelDrag()
        if value == self.scroll or self.reducedMotion then return self:setScroll(value) end
        scrollAnimation = {from=self.scroll,target=value,elapsed=0}
        self:render()
        return true
    end
    function self.scrollBy(_, delta)
        if not self.visible then return false, "map_hidden" end
        if not finite(delta) then return false, "invalid_scroll" end
        return self:setScroll(self.scroll + delta)
    end
    function self.focusCurrent(_, animated)
        if not self.map then return false, "map_unbound" end
        if not chapterFor(self.map) then self:render() return false,"invalid_map_context" end
        local current = Map.view(self.map)
        observeMap(current)
        local target = Layout.firstY + (math.max(1,localFloor(current,current.floor)) - 1) * Theme.layout.map.floorGap - Layout.focusY
        if animated then return animateScrollTo(target) end
        return self:setScroll(target)
    end
    function self.setNavigationEnabled(_, enabled)
        if not self.map then return false, "map_unbound" end
        assert(type(enabled) == "boolean", "navigation enabled must be boolean")
        if not enabled then cancelDrag() end
        -- An explicit coordinator grant acknowledges any external map advance.
        if not chapterFor(self.map) then self:render() return false,"invalid_map_context" end
        local current = Map.view(self.map)
        observeMap(current)
        self.observedNodeId, self.observedFloor = current.currentNodeId, current.floor
        self.navigationEnabled = enabled self:render()
    end
    function self.setVisible(_, visible)
        assert(type(visible) == "boolean", "map visibility must be boolean")
        if visible and not self.map then return false, "map_unbound" end
        if not visible then cancelDrag() end
        self.visible = visible root:SetVisible(visible)
        if visible then self:focusCurrent() end
    end
    function self.choose(_, nodeId)
        if not self.map then return false, "map_unbound" end
        if not chapterFor(self.map) then self:render() return false,"invalid_map_context" end
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
        if not chapterFor(self.map) then self:render() return false,"invalid_map_context" end
        local after = Map.view(self.map)
        observeMap(after)
        local changed = self.map ~= beforeMap or not sameContext(after,before)
            or after.floor ~= before.floor or after.currentNodeId ~= before.currentNodeId
        if changed then self.navigationEnabled = false self:focusCurrent() end
        if not called or accepted~=true then
            local messages={event_pool_exhausted='受限事件池已用尽，或剩余事件条件不足；请选择其他路线或重新启程。',
                event_not_implemented='此事件尚未实现；请选择其他路线。',combat_unavailable='此层没有可用遭遇；请选择其他路线。'}
            local failure=called and (reason or 'choice_rejected') or 'choice_callback_error'
            self.entryError=messages[failure] or '暂时无法进入，请完成当前操作后重试。'
            self:render()
            return false,failure
        end
        self.entryError=nil
        if self.map ~= beforeMap or not sameContext(after,before) or after.currentNodeId ~= nodeId or after.floor ~= expectedFloor then return false, "selection_not_committed" end
        self.navigationEnabled = false self:focusCurrent() return true
    end
    -- Dragging the route scrolls it with the finger. A press that moved past the
    -- threshold is a scroll, never a node choice, even if it ends on a node.
    local cursor = options.cursor
    local pointerInput = cursor and cursor.CursorDown and cursor.CursorUp
    local function touch(event) return event and event.touchId end
    local function selectionFor(slot, event)
        if not slot or not self.visible or not self.navigationEnabled then return end
        local nodeId = self.slots[slot]
        for _, node in ipairs(Map.available(self.map)) do
            if node.id == nodeId then
                return {slot=slot, nodeId=nodeId, map=self.map, floor=self.map.floor,
                    currentNodeId=self.map.currentNodeId, context=self.observedContext, touch=touch(event)}
            end
        end
    end
    local function validSelection(selection, slot)
        return selection and chapterFor(self.map) ~= nil and selection.slot == slot and selection.map == self.map
            and sameContext(selection.context,self.map)
            and selection.floor == self.map.floor and selection.currentNodeId == self.map.currentNodeId
            and selection.nodeId == self.slots[slot] and self.visible and self.navigationEnabled
    end
    local function pointY(event)
        if not event or type(event.GetUIPos) ~= "function" then return end
        local _, y = event:GetUIPos()
        if type(y) ~= "number" or not finite(y) then return end
        local width, height = self.canvasWidth or Theme.canvas.base[1], self.canvasHeight or Theme.canvas.base[2]
        return y / math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
    end
    local function press(event, slot)
        pointerObserved = true
        -- Down is idempotent until the owner releases or is cancelled. A repeated
        -- callback cannot rearm a selection that already exited or began scrolling.
        if not self.visible or not self.map then return end
        if not chapterFor(self.map) then self:render() return end
        if observeMap(Map.view(self.map)) then self:render() end
        if drag then return end
        cancelSelection()
        self.dragged = false
        local y = pointY(event)
        local wasAnimating = scrollAnimation ~= nil
        scrollAnimation = nil
        -- Position is optional for a tap. Ownership must still work on hosts
        -- that supply Down/Up but omit drag events or pointer coordinates.
        drag = {touch=touch(event), startY=y, y=y,
            selection=not wasAnimating and selectionFor(slot,event) or nil, slot=slot}
        if wasAnimating then self:render() end
    end
    local function move(event, slot)
        if not self.visible then cancelDrag() return end
        if not drag or touch(event) ~= drag.touch or slot ~= drag.slot then return end
        local y = pointY(event)
        if not y or not drag.startY then return end
        if not drag.moving and math.abs(y - drag.startY) < Layout.dragThreshold then return end
        drag.moving, self.dragged = true, true
        -- UI y grows upward; content follows the finger, so scroll moves the other way.
        local delta = y - drag.y
        drag.y = y
        -- Rendering may observe a replaced/advanced map and cancel this drag.
        self:setScroll(self.scroll - delta)
    end
    local function release(event, slot)
        if not drag or touch(event) ~= drag.touch or slot ~= drag.slot then return end
        move(event, slot)
        if drag and not drag.moving and validSelection(drag.selection, slot) then
            released = drag.selection
        end
        drag = nil
    end
    local function cancelPointer(event, slot, terminal)
        if released and touch(event) == released.touch and slot == released.slot then released = nil end
        if drag and touch(event) == drag.touch and slot == drag.slot then
            drag.selection = nil
            if terminal then cancelDrag() end
        end
    end
    local function draggable(control, slot)
        if not pointerInput then return end
        control:AddCursorEventListener(cursor.CursorDown, function(event) press(event, slot) end)
        if cursor.CursorDrag then control:AddCursorEventListener(cursor.CursorDrag, function(event) move(event, slot) end) end
        control:AddCursorEventListener(cursor.CursorUp, function(event) release(event, slot) end)
        if cursor.CursorExit then control:AddCursorEventListener(cursor.CursorExit, function(event) cancelPointer(event, slot) end) end
        if cursor.CursorEndDrag then control:AddCursorEventListener(cursor.CursorEndDrag, function(event) cancelPointer(event, slot, true) end) end
    end
    draggable(at("dragArea"))
    for i = 1, Layout.maxNodes do local slot = i bind("node" .. slot, function(event)
        if scrollAnimation then return false,"map_scrolling" end
        if pointerInput and (pointerObserved or touch(event) ~= nil) then
            -- Up grants only its original map/node one Click. A foreign callback
            -- cannot consume that grant or borrow a newer active gesture.
            local selection = released
            if drag or not selection or touch(event) ~= nil and touch(event) ~= selection.touch then
                return false, "stale_gesture"
            end
            if selection.slot ~= slot then return false, "stale_gesture" end
            released = nil
            if not validSelection(selection, slot) then return false, "stale_gesture" end
            return self:choose(selection.nodeId)
        end
        -- Click-only/accessibility hosts retain the existing intentional click path.
        if self.dragged then self.dragged = false return false, "dragged" end
        if self.slots[slot] then return self:choose(self.slots[slot]) end
        return false, "node_outside_viewport"
    end) draggable(child(at("node" .. slot), "hit"), slot) end
    local function step(name,delta)
        if not buttonEnabled(name) then return false,self.visible and "scroll_boundary" or "map_hidden" end
        -- Queue same-direction steps; an opposite click must reverse what is
        -- actually displayed, even when many earlier clicks queued a far target.
        local target = self.scroll
        if scrollAnimation and (scrollAnimation.target - self.scroll) * delta > 0 then
            target = scrollAnimation.target
        end
        return animateScrollTo(target + delta)
    end
    bind("previous", function() return step("previous",-Layout.scrollStep) end)
    bind("next", function() return step("next",Layout.scrollStep) end)
    bind("focus", function() if self.visible then return self:focusCurrent(true) end return false,"map_hidden" end)
    -- Reuse existing faces and documented events; no extra controls or timers.
    for _, key in ipairs({"previous","next","focus"}) do
        local name, hit = key, child(at(key),"hit")
        local function listen(event,callback) if event then hit:AddCursorEventListener(event,callback) end end
        local function clear(event,terminal)
            if buttonPress and buttonPress.name == name and (terminal or touch(event) == buttonPress.touch) then buttonPress = nil end
            if buttonHover == name then buttonHover = nil end
            paintButton(name)
        end
        listen(cursor and cursor.CursorEnter,function(event)
            if buttonEnabled(name) and touch(event) == nil then buttonHover = name paintButton(name) end
        end)
        listen(cursor and cursor.CursorDown,function(event)
            if buttonEnabled(name) then buttonPress = {name=name,touch=touch(event)} paintButton(name) end
        end)
        listen(cursor and cursor.CursorUp,clear)
        listen(cursor and cursor.CursorExit,function(event) clear(event,true) end)
        listen(cursor and cursor.CursorEndDrag,function(event) clear(event,true) end)
    end
    self:resize(Theme.canvas.base[1], Theme.canvas.base[2])
    if map then self:focusCurrent() else root:SetVisible(false) end
    return self
end
return M
