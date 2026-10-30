-- Native node UI composition root. Nodes retains all gameplay transactions.
-- Each factory gets one private context; ctx.self is the public adapter whose
-- run/map may be replaced by the host. Modules always read ctx.self for live state.
-- Install all services before the first render; input tokens keep their original
-- action identity across refreshes, visibility changes and native reentry.
local Nodes = require("abyss_nodes")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local M = {}
local CardDisplay = require('abyss_card_display')
local EndingUI=require('abyss_node_ui_ending')
local MatchUI=require('abyss_match_event_ui')
local number = require("abyss_numbers").integer
local C = Theme.color
local kinds = { camp = "营地", shop = "商店", event = "未知事件", treasure = "宝箱",ending_proceed='真结局' }
local layout = Theme.layout.nativeNode
local OPTIONS = #layout.event.options.rows
local function snapshotDeck(deck)
    local result = {}
    for _, card in ipairs(deck) do result[#result + 1] = { uid = card.uid, cardId = card.cardId, upgraded = card.upgraded } end
    return result
end
local function iconId(entry) return type(entry) == "table" and entry.id or entry end

function M.new(root, run, map, presentation, clickEvent, onChange, options)
    local ctx = {root=root,run=run,map=map,presentation=presentation,clickEvent=clickEvent,onChange=onChange,options=options}
    ctx.options = ctx.options or {}

    ctx.rootParent = ctx.root.parent

    ctx.self = { root = ctx.root, run = ctx.run, map = ctx.map, presentation = ctx.presentation or {},
        visible = ctx.run ~= nil and ctx.map ~= nil, page = 1, relicPage = 1, mode = "main", actions = {}, notice = "" }

    function ctx.child(name) return assert(ctx.root:GetChild(name), "missing node UI control " .. name) end

    function ctx.path(key)
        local control = ctx.root
        for part in key:gmatch("[^/]+") do control = assert(control:GetChild(part), "missing node UI control " .. key) end
        return control
    end

    function ctx.show(control, value) control:SetVisible(value ~= nil and value ~= false) end

    function ctx.tint(control, colour)
        if ctx.options.color then control.imageColor = ctx.options.color(colour.r, colour.g, colour.b, colour.a) end
    end

    function ctx.ink(control, colour)
        if ctx.options.color then control.fontColor = ctx.options.color(colour.r, colour.g, colour.b, colour.a) end
    end

    function ctx.picture(control, id)
        if ctx.options.imageSource and id then control:SetImage(ctx.options.imageSource, iconId(id)) end
    end

    require("abyss_node_ui_feedback").install(ctx)

    require("abyss_node_ui_faces").install(ctx)

    function ctx.action(key, enabled, handler, reason, poor, observe)
        ctx.self.actions[key] = { enabled = enabled == true, handler = handler, reason = reason, poor = poor == true, observe = observe }
        return enabled == true
    end

    require("abyss_node_ui_event_ownership").install(ctx)

    ctx.commit = nil

    function ctx.pageArrows(view, prefix, page, count)
        local previous = view:GetChild(prefix == "" and "previous" or prefix .. "Previous")
        local next = view:GetChild(prefix == "" and "next" or prefix .. "Next")
        ctx.show(previous, count > 1) ctx.show(next, count > 1)
        ctx.state(previous, page > 1) ctx.state(next, page < count)
        -- Paging is secondary to the goods: keep the arrows' frames quiet.
        if page > 1 then ctx.tint(previous:GetChild("border"), C.goldDim) end
        if page < count then ctx.tint(next:GetChild("border"), C.goldDim) end
    end

    function ctx.renderTopBar(node)
        EndingUI.header(ctx.self,ctx.child,node and node.type=='ending_proceed')
        ctx.child("title").text = node and ("第 " .. node.floor .. " 层 · " ..
        (node.roomKind == "boss_treasure" and "首领宝箱" or kinds[node.type] or "节点")) or "路线"
        ctx.child("hp").text = number(ctx.self.run.hp) .. "/" .. number(ctx.self.run.maxHp)
        ctx.child("gold").text = number(ctx.self.run.gold)
        ctx.child("deck").text = tostring(#ctx.self.run.deck)
        -- TASK-4.7: the shared top-bar disc row and 遗物 N button carry this now.
        ctx.child("relics").text = ""
        ctx.child("potions").text = "药水 " .. Run.potionCount(ctx.self.run) .. "/" .. Run.potionCapacity(ctx.self.run)
    end

    require("abyss_node_ui_shop").install(ctx)

    require("abyss_node_ui_camp_actions").install(ctx)

    require("abyss_node_ui_rewards").install(ctx)

    require("abyss_node_ui_events").install(ctx)

    MatchUI.install(ctx)

    require("abyss_node_ui_treasure").install(ctx)

    function ctx.self:holding()
        local result = self.result
        return result ~= nil and result.run == self.run and result.map == self.map and
        self.run.nodeFlow ~= nil and self.run.nodeFlow.id == result.nodeId and self.run.nodeFlow.complete == true
    end

    function ctx.syncNodeIdentity(node)
        if ctx.self.renderRun ~= ctx.self.run or ctx.self.renderMap ~= ctx.self.map or ctx.self.nodeId ~= (node and node.id) then
            ctx.self.page, ctx.self.relicPage, ctx.self.pickPage, ctx.self.mode, ctx.self.picker = 1, 1, 1, "main", nil
            ctx.self.selected, ctx.self.opened, ctx.self.notice, ctx.self.result, ctx.self.treasureChoice = nil, false, "", nil, 1
            ctx.self.upgradeRows = node and node.upgradeCards or {}
            ctx.self.removeRows = snapshotDeck(node and node.purgeCards or {})
        end
    end

    function ctx.nodeScreen(_view,node,result,active)
        if node and node.type=='ending_proceed' then return 'eventView','确认继续后进入真结局。' end
        local screen, hint = nil, node and "请完成当前节点。" or "请在路线中选择下一个节点。"
        if node and node.complete then hint = "本节点已完成，可以返回路线。" end
        if active and ctx.self.mode == "picker" then screen = "pickerView"
        elseif active then screen = node.type .. "View"
        elseif result then screen = result.view end
        if active and node.type == "camp" and node.campChoice == "upgrade" then ctx.self.mode, ctx.self.picker, screen = "picker", "upgrade", "pickerView" end
        return screen,hint
    end

    function ctx.renderNodePage(view,node,result,active)
        local screen,hint=ctx.nodeScreen(view,node,result,active)
        local recallSource,treasureSource
        for _, name in ipairs({ "shopView", "campView", "pickerView", "eventView", "treasureView" }) do ctx.show(ctx.child(name), name == screen) end
        -- Reset shared card faces before the ordinary picker/camp renderer writes them.
        if not (active and MatchUI.isBoard(node.event)) then ctx.resetMatch() end
        if active and MatchUI.isBoard(node.event) then hint=ctx.renderMatch(view,node)
        elseif screen == "shopView" then hint = ctx.renderShop(view, node)
        elseif screen == "campView" then hint, recallSource = ctx.renderCamp(view, node, result)
        elseif screen == "pickerView" then hint = ctx.renderPicker(view, node, result)
        elseif screen == "eventView" then
            if node.type=='ending_proceed' then hint=EndingUI.render(ctx.child('eventView'),OPTIONS)
            else hint = ctx.renderEvent(view, node, result) end
        elseif screen == "treasureView" then hint, treasureSource = ctx.renderTreasure(view, node) end
        return screen,hint,recallSource,treasureSource
    end

    function ctx.refreshNodeNotice(node,active,hint)
        -- The merchant speaks in his own dialogue box; the notice keeps only shop facts.
        if node and node.type == "shop" and (ctx.self.merchantNode ~= node.id or ctx.self.merchantRun ~= ctx.self.run) then
            ctx.self.merchantNode, ctx.self.merchantRun = node.id, ctx.self.run
            ctx.merchant:enter(ctx.self.run)
        end
        ctx.merchant:setVisible(node ~= nil and node.type == "shop" and ctx.self.mode == "main" and (active or node.complete))
        ctx.child("notice").text = ctx.self.notice ~= "" and ctx.self.notice or hint
        ctx.ink(ctx.child("notice"), ctx.self.failed and ctx.self.notice ~= "" and C.danger or C.text)

    end

    function ctx.completedFooter(view)
        local confirmLabel,confirmOk,confirmFn
        confirmLabel, confirmOk = view.phase == 'act_transition' and "前往下一幕" or "返回路线", true
        confirmFn = function() if ctx.onChange then ctx.onChange(true, "complete", ctx.self) end return true, "complete" end
        return nil,confirmLabel,confirmOk,confirmFn,nil,nil
    end

    function ctx.resultFooter()
        local confirmLabel,confirmOk,confirmFn
        confirmLabel, confirmOk = "继续", true
        confirmFn = function()
            ctx.self.result, ctx.self.notice = nil, ""
            ctx.self:render() if ctx.onChange then ctx.onChange(true, "continue", ctx.self) end
            return true, "continue"
        end
        return nil,confirmLabel,confirmOk,confirmFn,nil,nil
    end

    function ctx.chooseFooter(result,node,view,screen,recallSource,treasureSource,confirm)
        local backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve
        if view.phase=='ending_proceed' and node and node.type=='ending_proceed' then
            return EndingUI.footer(ctx.self,confirm,ctx.commit)
        elseif result then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=ctx.resultFooter()
        elseif node and node.complete then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=ctx.completedFooter(view)
        elseif screen == "shopView" then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=ctx.shopFooter()
        elseif screen == "campView" then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=ctx.campFooter(node,recallSource,confirm)
        elseif screen == "treasureView" and treasureSource then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=ctx.treasureFooter(treasureSource, confirm)
        elseif screen == "pickerView" then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=ctx.pickerFooter(node)
        end
        return backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve
    end

    function ctx.bindFooter(back,confirm,backLabel,confirmLabel,confirmOk,skipRestReward)
        local position = ctx.shopSelection.selected and layout.shop.cancel or layout.back
        back:SetAnchoredPosition(position[1],position[2])
        ctx.show(back, backLabel ~= nil) ctx.show(confirm, confirmLabel ~= nil)
        if backLabel then back:GetChild("label").text = backLabel ctx.state(back, true) end
        if confirmLabel then confirm:GetChild("label").text = confirmLabel ctx.state(confirm, confirmOk, false, true) end
        ctx.action("back", backLabel ~= nil, function()
            if ctx.shopSelection:cancel() then return true end
            if ctx.options.enhancedRooms and ctx.self.picker=='upgrade' and ctx.self.selected then
                ctx.self.selected=nil;ctx.self:render();return true
            end
            if skipRestReward then return skipRestReward() end
            ctx.self.mode, ctx.self.picker, ctx.self.selected, ctx.self.notice = "main", nil, nil, "" ctx.self:render() return true
        end)
    end

    function ctx.clearUnusedNativeArt(previous)
        for box in pairs(previous)do if not ctx.artFaces[box]then CardDisplay.clearNativeArt(box)end end
    end

    function ctx.self:render()
        if not self.run then ctx.root:SetVisible(false);return false, "node_unbound" end
        ctx.resetButtons();local previousArt=ctx.artFaces;ctx.artFaces={}
        ctx.inspectCards={}
        if ctx.renderRelicPending()then ctx.clearUnusedNativeArt(previousArt);return true end
        local view = Nodes.view(self.run, self.map)
        local node = view.node
        ctx.syncNodeIdentity(node)
        self.renderRun, self.renderMap, self.nodeId = self.run, self.map, node and node.id
        self.view, self.actions = view, {}
        local result = self:holding() and self.result or nil
        local active = node and kinds[node.type] and not node.complete and view.phase == "node"
        if active then self.removeRows=snapshotDeck(node.purgeCards) end
        ctx.syncNodePicker(node,active)
        if not active or node.type ~= 'shop' or self.mode ~= 'main' then ctx.shopSelection:clear() end
        ctx.renderTopBar(node)
        local screen,hint,recallSource,treasureSource=ctx.renderNodePage(view,node,result,active)
        ctx.refreshNodeNotice(node,active,hint)
        local back, confirm = ctx.child("back"), ctx.child("confirm")
        local backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve
        backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=ctx.chooseFooter(result,node,view,screen,recallSource,treasureSource,confirm)
        ctx.bindFooter(back,confirm,backLabel,confirmLabel,confirmOk,skipRestReward)
        ctx.bindTreasureBack(back,node,active)
        ctx.action("confirm", confirmOk, confirmFn, screen == "pickerView" and "请先在上方选择一张卡牌" or nil, nil, recallObserve)
        ctx.bindStagedEventActions(node);ctx.clearUnusedNativeArt(previousArt)
        self.failed = false
        ctx.roomMotion:paint()
    end

    require('abyss_relic_pending_ui').install(ctx)

    require("abyss_node_ui_lifecycle").install(ctx)

    require("abyss_node_ui_input").install(ctx)

    ctx.self:render()

    return ctx.self
end
return M
