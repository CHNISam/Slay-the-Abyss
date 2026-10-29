local Theme = require("abyss_theme")
local Controller = require('abyss_controller')
local layout = Theme.layout.nativeNode
local SHOP_PAGE, RELIC_PAGE, PICK_PAGE = #layout.shop.columns, #layout.shop.relics.columns, #layout.picker.columns
local OPTIONS = #layout.event.options.rows
local M = {}

-- Installs the input responsibility on one node UI instance.
function M.install(ctx)
    local function buildInputTargets()
        ctx.targets = { "back", "confirm", "shopView/previous", "shopView/next", "shopView/removal",
            "shopView/relicPrevious", "shopView/relicNext", "campView/rest", "campView/forge",
            "pickerView/previous", "pickerView/next", "treasureView/chest", "treasureView/take",
            "treasureView/previous", "treasureView/next" }

        for i=1,4 do ctx.targets[#ctx.targets+1]='treasureView/rewardItem'..i end

        for i=1,12 do ctx.targets[#ctx.targets+1]='pickerView/forgeGrid/card'..i end

        for _,path in ipairs(require('abyss_match_event_ui').inputPaths())do ctx.targets[#ctx.targets+1]=path end

        ctx.targets[#ctx.targets+1]='pickerView/forgePrevious'

        ctx.targets[#ctx.targets+1]='pickerView/forgeNext'

        for i = 1, SHOP_PAGE do ctx.targets[#ctx.targets + 1] = "shopView/card" .. i end

        for i = 1, RELIC_PAGE do ctx.targets[#ctx.targets + 1] = "shopView/relic" .. i end

        for i = 1, 3 do ctx.targets[#ctx.targets+1]='shopView/potion'..i end

        for i = 1, PICK_PAGE do ctx.targets[#ctx.targets + 1] = "pickerView/card" .. i end

        ctx.targets[#ctx.targets+1]='pickerView/before'

        ctx.targets[#ctx.targets+1]='pickerView/after'

        for i = 1, OPTIONS do ctx.targets[#ctx.targets + 1] = "eventView/option" .. i end
    end
    buildInputTargets()
    ctx.cursor = ctx.options.cursorEvents or (Enum and Enum.CursorEventType)

    ctx.dispatch = {}

    function ctx.listen(hit, event, fn)
        local byEvent = ctx.dispatch[hit] or {}
        ctx.dispatch[hit] = byEvent
        local list = byEvent[event]
        if not list then
            list = {}
            byEvent[event] = list
            hit:AddCursorEventListener(event, function(e) for _, f in ipairs(list) do f(e) end end)
        end
        list[#list + 1] = fn
    end

    ctx.rows = {}

    for i = 1, SHOP_PAGE do ctx.rows["shopView/card" .. i] = "shopView/" end

    for i = 1, RELIC_PAGE do ctx.rows["shopView/relic" .. i] = "shopView/relic" end

    for i = 1, PICK_PAGE do ctx.rows["pickerView/card" .. i] = "pickerView/" end

    ctx.self.swipeEnabled = ctx.cursor ~= nil and ctx.cursor.CursorDown ~= nil and ctx.cursor.CursorUp ~= nil

    function ctx.point(event)
        if not event or type(event.GetUIPos) ~= "function" then return end
        local x, y = event:GetUIPos()
        if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y
            or math.abs(x) == math.huge or math.abs(y) == math.huge then return end
        local width, height = ctx.self.canvasWidth or Theme.canvas.base[1], ctx.self.canvasHeight or Theme.canvas.base[2]
        local k = math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
        return x / k, y / k
    end

    function ctx.swipeDown(row, event)
        ctx.swallow = nil -- a new physical sequence
        local x, y = ctx.point(event)
        ctx.swipe = x and { row = row, touch = event.touchId, x = x, y = y } or nil
    end

    function ctx.swipeUp(event)
        local g = ctx.swipe
        if not g or (event and event.touchId) ~= g.touch then return end
        ctx.swipe = nil
        local x, y = ctx.point(event)
        if not x then return end
        local dx, dy = x - g.x, y - g.y
        local limit = layout.swipe.threshold
        if math.abs(dx) < limit and math.abs(dy) < limit then return end
        -- Past the threshold it is a drag, never a purchase; only a horizontal one pages.
        -- Finger moves left to reveal the next page, as on a touch carousel.
        if math.abs(dx) > math.abs(dy) then
            local arrow = (g.row == "shopView/relic") and (dx < 0 and "Next" or "Previous") or (dx < 0 and "next" or "previous")
            ctx.self:press(g.row .. arrow)
        end
        ctx.swallow = { touch = g.touch }
    end

    local function bindControl(key)
        local name = key
        local box = ctx.path(name)
        local hit = box:GetChild("hit")
        ctx.actionInputs[name] = {box=box,hit=hit}
        local input
        Controller.bind(ctx.options.controller,hit,'node',function()return ctx.self:press(name)end,function()
            local entry=ctx.self.actions[name]
            return ctx.self.visible and not ctx.self.busy and entry and entry.enabled
        end,name=='confirm' and 90 or name=='back' and 100 or 10)
        hit:AddCursorEventListener(ctx.clickEvent, function(event)
            if ctx.rewardDetail:consume(name,event)then return false,'inspected' end
            if Controller.pointerBlocked(ctx.options.controller)then return false end
            if ctx.swallow and (event == nil or event.touchId == nil or event.touchId == ctx.swallow.touch) then
                ctx.swallow = nil
                return false, "swiped"
            end
            local function releasedActionOwned()
                if input and input.observed then
                    local gesture = input.released
                    local touch = event and event.touchId
                    -- Click follows Up. Keep its original action until consumption, not
                    -- the action currently rebound to this hit area after a render.
                    if not gesture or touch ~= nil and touch ~= gesture.touch
                        or touch == nil and next(input.active) ~= nil then return false end
                    input.released = nil
                    if not gesture.action or gesture.action ~= ctx.self.actions[name] then return false end
                end

                return true
            end
            if not releasedActionOwned() then return false, "stale_action" end
            -- Hosts that never send Down retain the click-only/accessibility path.
            return ctx.self:press(name)
        end)
        -- A framed button keeps its dynamic children at their existing paths.
        -- Documented pointer events + SetLocalScale scale the complete face;
        -- Shop/picker cards share gesture ownership without framed-button visuals.
        local function bindFramedInput()
            if (box:GetChild("normal") or name:match("^shopView/card%d+$") or name:match('^pickerView/forgeGrid/card%d+$')
                or name:match("^pickerView/card%d+$")) and ctx.cursor and ctx.cursor.CursorEnter and ctx.cursor.CursorExit
                and ctx.cursor.CursorDown and ctx.cursor.CursorUp and ctx.cursor.CursorEndDrag then
                local function bindPointerFeedback()
                    -- Retain only active touches and the next released click, never a
                    -- history of touch IDs. Render/hide and terminal events clear them.
                    input = {active={}}
                    ctx.buttonInputs[box] = input
                    local noTouch = {} -- supports a complete pointer sequence without IDs
                    local function touchKey(event) return event and event.touchId or noTouch end
                    local function cancelInput(event)
                        input.active[touchKey(event)] = nil
                        if input.released and input.released.touch == (event and event.touchId) then input.released = nil end
                    end
                    local function visibleAction()
                        local entry = ctx.self.actions[name]
                        local ok, view = ctx.current()
                        if not ok or ctx.self.view.phase ~= view.phase or ctx.self.view.node.complete ~= view.node.complete then
                            ctx.retireAction(entry) return nil
                        end
                        local parent = box
                        while parent do
                            if not parent.visible then ctx.retireAction(entry) return nil end
                            parent = parent.parent
                        end
                        if entry and not ctx.observeAction(entry) then return nil end
                        return entry
                    end
                    local function available()
                        local entry, look = visibleAction(), ctx.buttonLooks[box]
                        -- Guarded mandatory-picker cards have no framed-button look.
                        -- Keep the legacy feedback path for all other controls unchanged.
                        local plainPicker = not look and entry and entry.retire and name:match("^pickerView/card%d+$") ~= nil
                        local shopCard = not look and (name:match('^shopView/card%d+$') or name:match('^pickerView/forgeGrid/card%d+$')) ~= nil
                        return entry and entry.enabled and (plainPicker or shopCard or look and look.enabled and not look.selected)
                    end
                    local function owned(event)
                        return ctx.buttonPress and ctx.buttonPress.box == box and ctx.buttonPress.touch == (event and event.touchId)
                    end
                    local function release(event)
                        if not owned(event) then return end
                        ctx.buttonPress = nil
                        if not available() then ctx.buttonHover = nil end
                        ctx.paintButton(box)
                    end
                    ctx.listen(hit, ctx.cursor.CursorEnter, function()
                        if not available() or ctx.buttonPress and ctx.buttonPress.box ~= box then return end
                        local previous = ctx.buttonHover
                        ctx.buttonHover = box
                        if previous and previous ~= box then ctx.paintButton(previous) end
                        ctx.paintButton(box)
                    end)
                    ctx.listen(hit, ctx.cursor.CursorDown, function(event)
                        input.observed, input.released = true, nil
                        local gesture = {touch=event and event.touchId, action=visibleAction()}
                        input.active[touchKey(event)] = gesture
                        if not available() or ctx.buttonPress then
                            if gesture.action and gesture.action.observe then gesture.action = nil end
                            return
                        end
                        ctx.buttonPress = {box=box,touch=event and event.touchId}
                        ctx.paintButton(box)
                    end)
                    ctx.listen(hit, ctx.cursor.CursorExit, function(event)
                        cancelInput(event)
                        if ctx.buttonPress and not owned(event) then return end
                        if ctx.buttonHover == box then ctx.buttonHover = nil end
                        if owned(event) then ctx.buttonPress = nil end
                        ctx.paintButton(box)
                    end)
                    ctx.listen(hit, ctx.cursor.CursorUp, function(event)
                        local touchId = touchKey(event)
                        local gesture = input.active[touchId]
                        input.active[touchId] = nil
                        if gesture and gesture.action and gesture.action.observe and not ctx.observeAction(gesture.action) then gesture.action = nil end
                        if gesture then input.released = gesture end
                        release(event)
                    end)
                    ctx.listen(hit, ctx.cursor.CursorEndDrag, function(event)
                        cancelInput(event)
                        if not owned(event) then return end
                        ctx.buttonPress, ctx.buttonHover = nil, nil
                        ctx.paintButton(box)
                    end)
                end
                bindPointerFeedback()

            end
        end
        bindFramedInput()
        local function bindRoomGestures()
            if ctx.self.swipeEnabled and ctx.rows[name] then
                local row = ctx.rows[name]
                ctx.listen(hit, ctx.cursor.CursorDown, function(event) ctx.swipeDown(row, event) end)
                ctx.listen(hit, ctx.cursor.CursorUp, ctx.swipeUp)
                if ctx.cursor.CursorEndDrag then ctx.listen(hit, ctx.cursor.CursorEndDrag, ctx.swipeUp) end
            end
            local function bindRoomHover()
                if name:match('^shopView/card%d+$') or name:match('^shopView/relic%d+$') or name:match('^shopView/potion%d+$') then
                    if ctx.cursor and ctx.cursor.CursorEnter then ctx.listen(hit,ctx.cursor.CursorEnter,function()ctx.shopSelection:enter(name)end) end
                    if ctx.cursor and ctx.cursor.CursorExit then ctx.listen(hit,ctx.cursor.CursorExit,function()ctx.shopSelection:exit(name)end) end
                end
                if name:match('^pickerView/forgeGrid/card%d+$') and ctx.cursor then
                    if ctx.cursor.CursorEnter then ctx.listen(hit,ctx.cursor.CursorEnter,function()ctx.campUI:hover(box,true)end)end
                    if ctx.cursor.CursorExit then ctx.listen(hit,ctx.cursor.CursorExit,function()ctx.campUI:hover(box,false)end)end
                end
                local function bindRewardInspection()
                    if name:match('^treasureView/rewardItem%d+$') and ctx.cursor then
                        if ctx.cursor.CursorEnter then ctx.listen(hit,ctx.cursor.CursorEnter,function()ctx.rewardDetail:enter(name)end)end
                        if ctx.cursor.CursorExit then ctx.listen(hit,ctx.cursor.CursorExit,function()ctx.rewardDetail:exit(name)end)end
                        if ctx.cursor.CursorDown then ctx.listen(hit,ctx.cursor.CursorDown,function(event)ctx.rewardDetail:down(name,event)end)end
                        if ctx.cursor.CursorUp then ctx.listen(hit,ctx.cursor.CursorUp,function(event)ctx.rewardDetail:up(event)end)end
                        if ctx.cursor.CursorEndDrag then ctx.listen(hit,ctx.cursor.CursorEndDrag,function()ctx.rewardDetail:exit(name)end)end
                    end
                end
                bindRewardInspection()

            end
            bindRoomHover()

        end
        bindRoomGestures()
        local function bindCardInspection()
            if ctx.options.onInspectCard and ctx.cursor and ctx.cursor.CursorDown and ctx.cursor.CursorUp
                and (name:match('^shopView/card%d+$') or name:match('^pickerView/card%d+$')
                or name=='pickerView/before' or name=='pickerView/after') then
                ctx.listen(hit,ctx.cursor.CursorDown,function(event)
                    ctx.self.inspectPress=nil
                    if not ctx.self.visible or not ctx.inspectCards[box] or not box.visible then return end
                    local parent=box
                    while parent do if not parent.visible then return end;parent=parent.parent end
                    local x,y=ctx.point(event)
                    ctx.self.inspectPress={box=box,name=name,card=ctx.inspectCards[box],run=ctx.self.run,flow=ctx.self.run.nodeFlow,
                        action=ctx.self.actions[name],touch=event and event.touchId,time=0,x=x,y=y}
                end)
                local function cancelInspect(event)
                    if ctx.self.inspectPress and ctx.self.inspectPress.touch==(event and event.touchId) then ctx.self.inspectPress=nil end
                end
                ctx.listen(hit,ctx.cursor.CursorUp,cancelInspect)
                if ctx.cursor.CursorExit then ctx.listen(hit,ctx.cursor.CursorExit,cancelInspect) end
                if ctx.cursor.CursorEndDrag then ctx.listen(hit,ctx.cursor.CursorEndDrag,cancelInspect) end
                if ctx.cursor.CursorDrag then ctx.listen(hit,ctx.cursor.CursorDrag,function(event)
                        local held=ctx.self.inspectPress;local x,y=ctx.point(event)
                        if held and (not x or not held.x or (x-held.x)^2+(y-held.y)^2>=Theme.layout.cardDrag.threshold^2) then
                            ctx.self.inspectPress=nil
                        end
                    end) end
            end
        end
        bindCardInspection()

    end
    for _, key in ipairs(ctx.targets) do bindControl(key) end
end
return M
