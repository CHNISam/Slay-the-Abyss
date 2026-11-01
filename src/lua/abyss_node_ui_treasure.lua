local Nodes = require("abyss_nodes")
local Theme = require("abyss_theme")
local number = require("abyss_numbers").integer
local C = Theme.color
local M = {}

-- Installs the treasure responsibility on one node UI instance.
function M.install(ctx)
    function ctx.bindTreasureChoice(key, box, source, choice, name)
        local sourceRun, sourceMap, sourceFlow, sourceView = ctx.self.run, ctx.self.map, ctx.self.run.nodeFlow, ctx.self.view
        local sourceReward, sourceParent = sourceFlow.reward, box.parent
        local sourceLink, sourceItems = sourceReward.sapphireKey, sourceReward.items
        local handler
        local function owned()
            local control, links, hostAttached, look, parent
            local function attachedTreasureControls()
                control, links = ctx.root, {}
                for part in key:gmatch("[^/]+") do
                    local owner = control
                    control = owner and owner:GetChild(part)
                    links[#links + 1] = { child = control, owner = owner }
                end
                hostAttached = not ctx.rootParent or ctx.rootParent:GetChild("nodePanel") == ctx.root
                -- Revalidate the entire captured ancestry AFTER the final native read.
                for _, link in ipairs(links) do
                    if not link.child or link.child.parent ~= link.owner then return false end
                end
                look, parent = ctx.buttonLooks[box], box
                if control ~= box or box.parent ~= sourceParent or not look or not look.enabled or look.selected then return false end
                while parent do
                    if not parent.visible then return false end
                    parent = parent.parent
                end
            end
            if attachedTreasureControls() == false then return false end
            -- GetChild may reenter a host render. All owner/action tests follow its last read.
            local entry = ctx.self.actions[key]
            local function sameRoom() return ctx.self.run == sourceRun and ctx.self.map == sourceMap and ctx.self.view == sourceView
                    and ctx.self.mode == "main" and ctx.self.opened == true and ctx.self.run.nodeFlow == sourceFlow
                    and ctx.self.run.roomGeneration == source.roomGeneration and ctx.self.run.act == source.act end
            local function sameReward() return sourceFlow.reward == sourceReward and sourceReward.sapphireKey == sourceLink and sourceReward.items == sourceItems
                    and sourceReward.relicId == source.relicId and sourceLink and sourceLink.relicId == source.relicId
                    and entry and entry.enabled and entry.handler == handler end
            return hostAttached and ctx.root.parent == ctx.rootParent and ctx.self.root == ctx.root and ctx.self.visible and not ctx.self.busy
                and sameRoom()
                and sameReward()
        end
        local function observe()
            if not owned() or type(Nodes.treasureSource) ~= "function" or type(Nodes.chooseTreasure) ~= "function" then return false end
            local currentSource = Nodes.treasureSource(sourceRun, sourceMap)
            if type(currentSource) ~= "table" then return false end
            for field, value in pairs(source) do if currentSource[field] ~= value then return false end end
            return owned()
        end
        handler = function()
            if not owned() or type(Nodes.chooseTreasure) ~= "function" then return false, "stale_action" end
            return ctx.commit("chooseTreasure", source, function()
                return choice == "sapphire" and ("已获得蓝钥匙 · 已放弃遗物「" .. name .. "」") or ("已获得遗物「" .. name .. "」")
            end, choice)
        end
        return handler, observe
    end

    function ctx.renderTreasure(_view, node)
        if node.chest then return require('abyss_treasure_ui').render({self=ctx.self,node=node,child=ctx.child,
                show=ctx.show,tint=ctx.tint,state=ctx.state,picture=ctx.picture,action=ctx.action,commit=ctx.commit,relicName=ctx.relicName,relicText=ctx.relicText,
                list=ctx.options.enhancedRooms==true,details=ctx.rewardDetail}) end
        local chest = ctx.child("treasureView")
        local reward = node.reward
        local boss = node.roomKind == "boss_treasure"
        local choices = boss and reward.relics or nil
        ctx.self.treasureChoice = math.min(ctx.self.treasureChoice or 1, choices and #choices or 1)
        local relicId = boss and choices[ctx.self.treasureChoice] or reward.relicId
        local opened = ctx.self.opened == true
        local source
        local function treasureSource()
            source = opened and not boss and type(Nodes.treasureSource) == "function" and type(Nodes.chooseTreasure) == "function"
                and Nodes.treasureSource(ctx.self.run, ctx.self.map) or nil
            if type(source) ~= "table" or source.relicId ~= relicId then source = nil end
        end
        treasureSource()
        local function showChestState()
            ctx.show(chest:GetChild("closed"), not opened) ctx.show(chest:GetChild("open"), opened)
            ctx.show(chest:GetChild("hint"), not opened)
            ctx.tint(chest:GetChild("glow"), opened and C.gold or C.goldDim)
        end
        showChestState()
        local row, take = chest:GetChild("reward"), chest:GetChild("take")
        local hasReward = not boss or #choices > 0
        ctx.show(row, opened and hasReward) ctx.show(take, opened and hasReward)
        local name
        local function describeChest()
            name = relicId and ctx.relicName(relicId) or (not boss and (number(reward.gold) .. " 金币") or "")
            for _, key in ipairs({"previous", "next", "page", "bossDescription"}) do ctx.show(chest:GetChild(key), opened and boss) end
            take:GetChild("label").text = source and "领取遗物" or boss and "领取这件遗物" or "拿取并离开"
        end
        describeChest()
        local function renderTreasureReward()
            if opened and hasReward then
                ctx.state(row, true) ctx.state(take, true, false, true)
                ctx.picture(row:GetChild("icon"), relicId and (Theme.icon.relic[relicId] or Theme.icon.node.treasure) or Theme.icon.gold)
                row:GetChild("name").text = relicId and ("遗物 · " .. name) or name
                row:GetChild("description").text = boss and "使用左右按钮查看，领取其中一件" or relicId and ctx.relicText(relicId) or "遗物已全部持有，改为金币"
                if boss then
                    chest:GetChild("page").text = "首领遗物 · " .. ctx.self.treasureChoice .. " / " .. #choices .. " · 选择一件"
                    chest:GetChild("bossDescription").text = ctx.relicText(relicId)
                    ctx.state(chest:GetChild("previous"), ctx.self.treasureChoice > 1)
                    ctx.state(chest:GetChild("next"), ctx.self.treasureChoice < #choices)
                end
            end
        end
        renderTreasureReward()
        if boss and not hasReward then
            ctx.show(chest:GetChild("previous"), false) ctx.show(chest:GetChild("next"), false)
            chest:GetChild("page").text = "没有可领取的首领遗物"
            chest:GetChild("bossDescription").text = "可用遗物已持有或不满足领取条件，请跳过奖励。"
        end
        local function bindTreasurePaging()
            for _, step in ipairs({{key="previous", delta=-1}, {key="next", delta=1}}) do
                local choice = ctx.self.treasureChoice + step.delta
                ctx.action("treasureView/" .. step.key, opened and boss and choice >= 1 and choice <= #choices, function()
                    ctx.self.treasureChoice, ctx.self.notice = choice, "" ctx.self:render() return true
                end)
            end
        end
        bindTreasurePaging()
        ctx.action("treasureView/chest", not opened, function()
            ctx.self.opened, ctx.self.notice = true, ""
            if ctx.options.sound then pcall(ctx.options.sound, "treasure_open") end
            ctx.self:render() return true
        end)
        local takeFn, takeObserve = nil, nil
        local function bindTreasureTake()
            if source then takeFn, takeObserve = ctx.bindTreasureChoice("treasureView/take", take, source, "relic", name)
            else takeFn = function()
                    return ctx.commit(boss and "claimBossTreasure" or "claimTreasure", boss and ctx.self.treasureChoice or nil,
                    function() return "已获得" .. (relicId and ("遗物「" .. name .. "」") or name) end)
                end end
            ctx.action("treasureView/take", opened and hasReward, takeFn, nil, nil, takeObserve)
        end
        bindTreasureTake()
        local function treasureHint()
            if source then return "遗物与蓝钥匙只能选一项 · 选择蓝钥匙将放弃遗物「" .. name .. "」", source end
            return opened and (boss and "选择一件首领遗物，或跳过奖励后完成本局" or
            ("宝箱已打开 · 获得" .. (relicId and "遗物" or "金币"))) or "宝箱就在眼前"
        end
        return treasureHint()

    end

    function ctx.treasureFooter(treasureSource, confirm)
        local confirmLabel,confirmOk,confirmFn,recallObserve
        confirmLabel, confirmOk = "蓝钥匙", true
        confirmFn, recallObserve = ctx.bindTreasureChoice("confirm", confirm, treasureSource, "sapphire", ctx.relicName(treasureSource.relicId))
        return nil,confirmLabel,confirmOk,confirmFn,nil,recallObserve
    end

    function ctx.bindTreasureBack(back,node,active)
        if active and node.type=='treasure' and node.chest then
            ctx.show(back,true);back:GetChild('label').text=node.roomKind=='boss_treasure' and '跳过遗物' or '离开宝箱';ctx.state(back,true)
            ctx.action('back',true,function()return ctx.commit('leaveTreasure',nil,function()return '已离开宝箱' end)end)
        elseif active and node.roomKind == "boss_treasure" and ctx.self.opened then
            ctx.show(back, true) back:GetChild("label").text = "跳过遗物" ctx.state(back, true)
            ctx.action("back", true, function()
                return ctx.commit("claimBossTreasure", 0, function() return "已跳过首领遗物" end)
            end)
        end
    end
end
return M
