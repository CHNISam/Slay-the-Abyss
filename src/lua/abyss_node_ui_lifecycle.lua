local CardSkin=require('abyss_card_skin')
local Nodes = require("abyss_nodes")
local Theme = require("abyss_theme")
local CardDisplay = require('abyss_card_display')
local Act2Events = require('abyss_act2_events')
local reasons = {
    rest_blocked_by_relic='咖啡滤杯禁止在营地休息',upgrade_blocked_by_relic='聚变之锤禁止在营地升级卡牌',
    card_content_unavailable='这张卡牌的效果尚未接齐，本次未改变资源',
    relic_content_unavailable='这件遗物的效果尚未接齐，本次未改变资源',
    neow_insufficient_selectable_cards='没有足够的可选卡牌，本次未改变资源',
    insufficient_gold = "金币不足", item_unavailable = "商品已售出或不可购买",
    shop_content_unavailable = "商店补货状态异常，本次未付款，请离店或重新开始",
    removal_unavailable = "本店删牌服务已使用",
    invalid_card = "这张卡牌已不在牌组中",
    card_not_upgradeable = "这张卡牌无法继续升级", potion_slots_full = "药水槽已满", potions_blocked = "遗物效果禁止获得药水",
    camp_choice_made = "本次营地已选择升级或休息", no_pending_node = "此节点已经完成",
    wrong_node_type = "当前节点不支持此操作", relic_already_owned = "已持有这件遗物",
    event_obtain_content_unavailable = "当前遗物的获牌效果尚未接齐，本次未改变资源", event_damage_content_unavailable = "当前遗物的事件伤害尚未接齐，本次未改变资源", stale_event_health = "生命上限已变化，请重新查看事件", stale_event_card = "候选卡牌已变化，请重新查看事件", invalid_event_choice = "此事件选项不可用", event_unavailable = "当前没有满足条件的已实现事件", stale_action = "界面已变化，请重新选择",
    event_content_unavailable = "事件所需卡牌数据不可用", invalid_deck_uid = "卡牌编号异常，未领取奖励",
    event_reward_content_unavailable = "当前遗物的无色奖励效果尚未接齐，本次未改变资源",
    panel_hidden = "节点界面未打开", unavailable_action = "此选项当前不可用",
}
-- Keep legacy Act1 pointer ownership unchanged; only the new state machines join.
local addedStaged={dead_adventurer=true,designer=true,face_trader=true,knowing_skull=true,nloth=true}
local function stagedEvent(id)return addedStaged[id] or id=='match_game' or id=='neow' or id=='mysterious_sphere' or id=='mind_bloom' or Act2Events.ids[id]end
local M = {}

-- Installs the lifecycle responsibility on one node UI instance.
function M.install(ctx)
    function ctx.self:resize(width, height)
        ctx.resetButtons()
        ctx.shopSelection:clear()
        ctx.roomMotion:cancel()
        self.canvasWidth, self.canvasHeight = width, height
        if self.pendingOwner then self:render();return end
        if self.view and self.view.node and (self.view.node.type=='shop' or ctx.options.enhancedRooms) then self:render() end
        if self.view and self.view.node and self.view.node.type=='event' and stagedEvent(self.view.node.event.id) then self:render() end
    end

    function ctx.self:update(dt)
        for box in pairs(ctx.skinFaces)do CardSkin.tick(box,dt)end
        ctx.roomMotion:update(dt)
        ctx.rewardDetail:update(dt)
        ctx.shopSelection:update(dt)
        ctx.updateMatch(dt)
        if self.visible then ctx.merchant:update(dt) end
        local function observeActiveGestures()
            for _, input in pairs(ctx.buttonInputs) do
                for _, gesture in pairs(input.active) do
                    if gesture.action and gesture.action.observe and not ctx.observeAction(gesture.action) then gesture.action = nil end
                end
                local released = input.released
                if released and released.action and released.action.observe and not ctx.observeAction(released.action) then released.action = nil end
            end
        end
        observeActiveGestures()
        local held=self.inspectPress
        local function updateCardInspection()
            if held then
                if not self.visible or held.run~=self.run or held.flow~=self.run.nodeFlow
                    or held.card~=ctx.inspectCards[held.box] or held.action~=self.actions[held.name] then self.inspectPress=nil
                else
                    held.time=held.time+dt
                    if held.time>=Theme.layout.statusInfo.delay then
                        self.inspectPress=nil;ctx.swipe=nil;ctx.swallow={touch=held.touch}
                        if ctx.options.onInspectCard then ctx.options.onInspectCard(held.card.definition,held.card.upgraded) end
                    end
                end
            end
        end
        updateCardInspection()

    end

    function ctx.self:setVisible(value)
        assert(type(value) == "boolean", "node visibility must be boolean")
        if value and not self.run then return false, "node_unbound" end
        if not value then ctx.resetButtons();ctx.shopSelection:clear();ctx.roomMotion:cancel();for box in pairs(ctx.artFaces)do CardDisplay.clearNativeArt(box)end;ctx.artFaces={} end
        local wasVisible = self.visible
        if not value then self.pendingGeneration=(self.pendingGeneration or 0)+1 end
        self.visible = value ctx.root:SetVisible(value)
        if value and not wasVisible and require('abyss_relic_pending').owner(self.run)then self:render()end
        -- Let Match's own visibility guard retire its clock, retaining a failed
        -- pair's explicit-retry state across modal hide/show.
        if not value then ctx.updateMatch(0) end
        local function refreshVisibility()
            local function stagedVisibleEvent() return self.view.node.type=='event' and stagedEvent(self.view.node.event.id) end
            if not value and self.view and self.view.node and stagedVisibleEvent() then
                for _, entry in pairs(self.actions) do if entry.observe then entry.observe() end end
            elseif value and not wasVisible and self.view and self.view.node and (ctx.options.enhancedRooms or self.view.node.type=='shop'
                or self.view.node.type=='event' and stagedEvent(self.view.node.event.id)) then
                self:render()
            end
        end
        refreshVisibility()

    end

    function ctx.current()
        if not ctx.self.visible then return false, "panel_hidden" end
        if ctx.self.busy or ctx.self.presentationBusy then return false, "unavailable_action" end
        if ctx.self.pendingOwner then
            if ctx.self.renderRun~=ctx.self.run or ctx.self.renderMap~=ctx.self.map
                or require('abyss_relic_pending').owner(ctx.self.run)~=ctx.self.pendingOwner then return false,'stale_action'end
            return true,ctx.self.view
        end
        local view = Nodes.view(ctx.self.run, ctx.self.map)
        if ctx.self.renderRun ~= ctx.self.run or ctx.self.renderMap ~= ctx.self.map or not view.node or view.node.id ~= ctx.self.nodeId then
            return false, "stale_action"
        end
        return true, view
    end

    function ctx.notify(ok, reason)
        if ctx.onChange then ctx.onChange(ok, reason, ctx.self) end
        return ok, reason
    end

    ctx.commit = function(command, argument, describe, choice)
        local node = ctx.self.view.node
        local before = { hp = ctx.self.run.hp, gold = ctx.self.run.gold }
        ctx.self.busy = true
        local called, accepted, reason = nil, nil, nil
        local function dispatchNodeCommand()
            called, accepted, reason = nil, nil, nil
            if command == "recall" then called, accepted, reason = pcall(Nodes.recall, ctx.self.run, ctx.self.map, argument)
            elseif command == 'proceedEnding' then called, accepted, reason = pcall(Nodes.proceedEnding,ctx.self.run,ctx.self.map,argument)
            elseif command == "chooseTreasure" then called, accepted, reason = pcall(Nodes.chooseTreasure, ctx.self.run, ctx.self.map, argument, choice)
            elseif command == "chooseEvent" then called, accepted, reason = pcall(Nodes.chooseEvent, ctx.self.run, argument, choice)
            else called, accepted, reason = pcall(Nodes[command], ctx.self.run, argument) end
        end
        dispatchNodeCommand()
        ctx.self.busy = false
        if not called then error(accepted) end
        if accepted then
            -- Sound confirms a committed action, never a preview or a refresh.
            local function playCommitSound()
                local cue
                local function commitSoundCue()
                    cue = ({upgrade="forge",openTreasure="treasure_open",upgradeEvent="reward",rest="rest"})[command]
                        or (command == "claimTreasure" or command == "claimBossTreasure" or command == "chooseTreasure" or command=="claimTreasureReward") and argument ~= 0 and "reward"
                        or (command == "removeCard" or command == "purifyEvent" or command == "purgeWing") and "card_remove"
                end
                commitSoundCue()
                if cue and ctx.options.sound and not (ctx.options.enhancedRooms and
                (command=='openTreasure' or command=='rest' or command=='upgrade')) then pcall(ctx.options.sound, cue) end
            end
            playCommitSound()
            local notice, hold = describe(before)
            local function reactToShopTransaction()
                if command == "buyCardSlot" or command == "buyRelic" or command == "buyPotion" or command == "removeCard" then
                    ctx.merchant:react("buy")
                elseif command == "leaveShop" then ctx.merchant:react("leave") end
            end
            reactToShopTransaction()
            ctx.self.notice, ctx.self.failed = notice, false
            if command == "removeCard" then ctx.self.mode, ctx.self.picker, ctx.self.selected = "main", nil, nil end
            local function holdCompletedResult()
                local flow = ctx.self.run.nodeFlow
                if hold and flow and flow.complete and (node.type == "camp" or node.type == "event" or node.type == "shop") then
                    hold.run, hold.map, hold.nodeId = ctx.self.run, ctx.self.map, flow.id
                    -- A shop farewell shows no shelf: only the merchant and 继续 remain.
                    hold.view = node.type == "event" and "eventView" or node.type == "shop" and "farewell"
                        or (hold.choice == "upgrade" and "pickerView" or "campView")
                    hold.eventId = node.event and node.event.id
                    ctx.self.result = hold
                end
            end
            holdCompletedResult()

        else
            ctx.self.notice, ctx.self.failed = reasons[reason] or "操作未完成，请重新选择", true
        end
        ctx.self:render()
        if accepted then ctx.roomMotion:start(command,before) end
        ctx.self.failed = false
        return ctx.notify(accepted, reason)
    end

    function ctx.self:press(key)
        local ok, view = ctx.current()
        if not ok then
            local entry = self.actions[key]
            if entry and entry.retire then entry.retire() end
            return false, view
        end
        local entry = self.actions[key]
        if not entry then return false, "unavailable_action" end
        if not entry.enabled then
            if entry.poor then ctx.merchant:react("poor") end
            if entry.reason then self.notice, self.failed = entry.reason, true self:render() end
            return false, "unavailable_action"
        end
        return entry.handler()
    end

    function ctx.self:setPage(page)
        local ok, reason = ctx.current() if not ok then return false, reason end
        if type(page) ~= "number" or page % 1 ~= 0 or page < 1 or page > (self.pageCount or 1) then return false, "invalid_page" end
        if self.pendingOwner then self.pendingPage=page
        elseif self.mode == "picker" then self.pickPage = page else self.page = page end
        self.notice = "" self:render() return true
    end
end
return M
