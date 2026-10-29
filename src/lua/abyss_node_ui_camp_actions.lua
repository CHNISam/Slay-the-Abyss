local CampUI = require('abyss_node_ui_camp')
local Nodes = require("abyss_nodes")
local number = require("abyss_numbers").integer
local M = {}

-- Installs the camp actions responsibility on one node UI instance.
function M.install(ctx)
    ctx.campUI=CampUI.new(ctx.self,{child=ctx.child,show=ctx.show,state=ctx.state,fillCard=ctx.fillCard,action=ctx.action})

    function ctx.enhancedForge(node)return ctx.options.enhancedRooms and node.type=='camp' and ctx.self.picker=='upgrade'end

    function ctx.bindCampChoices(node,rest,forge,restOpen,forgeable)
        if node.canRest==false then rest:GetChild('description').text='咖啡滤杯：无法休息' end
        if node.canForge==false and #node.upgradeCards>0 then forge:GetChild('description').text='聚变之锤：无法锻造' end
        ctx.action("campView/rest", restOpen, function()
            return ctx.commit("rest", nil, function(before)
                local healed = ctx.self.run.hp - before.hp
                if ctx.self.run.nodeFlow.restReward and not ctx.self.run.nodeFlow.restReward.resolved then
                    ctx.self.mode,ctx.self.picker,ctx.self.pickPage,ctx.self.selected='picker','dream_catcher',1,nil
                    return '休息完成 · 回复 '..number(healed)..' 点生命；请选择卡牌或跳过'
                end
                return "休息完成 · 回复 " .. number(healed) .. " 点生命", { choice = "rest", healed = healed }
            end)
        end, node.canRest==false and '咖啡滤杯禁止休息' or "生命已满，休息不会回复；可以选择锻造")
        ctx.action("campView/forge", forgeable, function()
            ctx.self.mode, ctx.self.picker, ctx.self.pickPage, ctx.self.selected, ctx.self.notice = "picker", "upgrade", 1, nil, ""
            ctx.self:render() return true
        end, node.canForge==false and #node.upgradeCards>0 and '聚变之锤禁止锻造' or "牌组中没有可升级的卡牌")
    end

    function ctx.renderCamp(_view, node, result)
        local camp = ctx.child("campView")
        local rest, forge = camp:GetChild("rest"), camp:GetChild("forge")
        local outcome=ctx.options.enhancedRooms and result~=nil
        ctx.show(rest,not outcome);ctx.show(forge,not outcome);ctx.show(camp:GetChild('result'),outcome)
        local function showCampResult()
            if result then
                ctx.state(rest, false, result.choice == "rest") ctx.state(forge, false, result.choice == "upgrade")
                rest:GetChild("description").text = result.choice == "rest" and
                ("已回复 " .. number(result.healed) .. " 点生命\n生命 " .. number(ctx.self.run.hp) .. "/" .. number(ctx.self.run.maxHp)
                ..(result.rewardText and '\n'..result.rewardText or '')) or "未选择"
                forge:GetChild("description").text = result.choice == "upgrade" and "已升级" or "未选择"
                camp:GetChild('result'):GetChild('description').text=rest:GetChild('description').text
                return
            end
        end
        showCampResult()
        if result then return end
        local forgeable = node.canForge~=false and #node.upgradeCards > 0
        -- Full-health rest remains available for Dream Catcher's real reward,
        -- or when the camp has no forgeable card and needs an exit.
        local restOpen = node.canRest~=false and (node.heal > 0 or node.dreamCatcher or not forgeable)
        ctx.state(rest, restOpen) ctx.state(forge, forgeable)
        local function describeCampChoices()
            rest:GetChild("description").text = node.heal > 0 and
            ("回复 " .. number(node.heal) .. " 点生命\n生命 " .. number(ctx.self.run.hp) .. " → " .. number(ctx.self.run.hp + node.heal)) or
            (node.dreamCatcher and "生命已满\n捕梦网：可选一张牌" or forgeable and "生命已满" or "生命已满 · 休息后继续前进")
            if node.dreamCatcher and node.heal>0 then rest:GetChild('description').text=rest:GetChild('description').text..'\n捕梦网：可选一张牌' end
            forge:GetChild("description").text = forgeable and
            ("升级一张卡牌\n可升级 " .. #node.upgradeCards .. " 张") or "没有可升级的卡牌"
        end
        describeCampChoices()
        ctx.bindCampChoices(node,rest,forge,restOpen,forgeable)
        -- Recall is the last action: reuse the existing footer, never derive eligibility here.
        local source = type(Nodes.recallSource) == "function" and type(Nodes.recall) == "function"
            and Nodes.recallSource(ctx.self.run, ctx.self.map) or nil
        if type(source) ~= "table" then source = nil end
        return source and "篝火旁 · 休息、锻造或 Recall，只能选一项"
            or "篝火旁，旅行者稍作停留 · 休息或锻造，只能选一项", source
    end

    function ctx.campFooter(node,source,confirm)
        if source then return ctx.recallFooter(source,confirm) end
        if node.canLeaveCamp then
            return nil,'继续前进',true,function()
                return ctx.commit('leaveCamp',nil,function()return '营地没有可用操作，继续前进'end)
            end
        end
    end

    function ctx.recallFooter(recallSource, confirm)
        local confirmLabel,confirmOk,confirmFn,recallObserve
        local sourceRun, sourceMap, sourceFlow = ctx.self.run, ctx.self.map, ctx.self.run.nodeFlow
        confirmLabel, confirmOk = "Recall", true
        local function attachedControls()
            local attached = ctx.root:GetChild("confirm") == confirm
            local hostAttached = not ctx.rootParent or ctx.rootParent:GetChild("nodePanel") == ctx.root
            local look, parent = ctx.buttonLooks[confirm], confirm
            if not attached or confirm.parent ~= ctx.root or not look or not look.enabled or look.selected then return false end
            while parent do
                if not parent.visible then return false end
                parent = parent.parent
            end
            return true,hostAttached
        end
        local function owned()
            local valid,hostAttached=attachedControls()
            if not valid then return false end
            -- Final ownership check follows the last native read: GetChild can reenter a host render.
            local entry = ctx.self.actions.confirm
            return hostAttached and ctx.root.parent == ctx.rootParent and ctx.self.root == ctx.root and ctx.self.visible and not ctx.self.busy
                and ctx.self.run == sourceRun and ctx.self.map == sourceMap
                and ctx.self.run.nodeFlow == sourceFlow and ctx.self.run.roomGeneration == recallSource.roomGeneration
                and ctx.self.run.act == recallSource.act and entry and entry.enabled and entry.handler == confirmFn
        end
        recallObserve = function()
            if not owned() or type(Nodes.recallSource) ~= "function" or type(Nodes.recall) ~= "function" then return false end
            local currentSource = Nodes.recallSource(sourceRun, sourceMap)
            if type(currentSource) ~= "table" then return false end
            for key, value in pairs(recallSource) do if currentSource[key] ~= value then return false end end
            return owned()
        end
        confirmFn = function()
            -- Never adopt a fresh token at Click, even after a repaired context.
            if not owned() or type(Nodes.recall) ~= "function" then return false, "stale_action" end
            return ctx.commit("recall", recallSource, function() return "Recall · Ruby", { choice = "recall" } end)
        end
        return nil,confirmLabel,confirmOk,confirmFn,nil,recallObserve
    end
end
return M
