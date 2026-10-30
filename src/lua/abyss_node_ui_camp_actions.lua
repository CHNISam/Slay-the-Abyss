local CampUI = require('abyss_node_ui_camp')
local Nodes = require("abyss_nodes")
local number = require("abyss_numbers").integer
local M = {}
local Rare=require('abyss_rare_relics')
local function rareResult(ctx,camp,rest,forge,result)
    if result.choice~='lift'and result.choice~='dig'then return false end
    local text=result.choice=='lift'and ('锻炼完成 · 每场战斗开始获得 '..number(ctx.self.run.relicCounters.girya or 0)..' 点力量')or ctx.self.notice
    camp:GetChild('result'):GetChild('name').text=result.choice=='lift'and '锻炼完成'or '挖掘完成'
    camp:GetChild('result'):GetChild('description').text=text
    rest:GetChild('description').text=text;forge:GetChild('description').text='营地行动已完成'
    ctx.state(rest,false);ctx.state(forge,false);return true
end
local function showCampResult(ctx,camp,rest,forge,result)
    if rareResult(ctx,camp,rest,forge,result)then return end
    camp:GetChild('result'):GetChild('name').text=result.choice=='upgrade'and '锻造完成'or '休息完成'
    ctx.state(rest,false,result.choice=='rest');ctx.state(forge,false,result.choice=='upgrade')
    rest:GetChild('description').text=result.choice=='rest'and
        ('已回复 '..number(result.healed)..' 点生命\n生命 '..number(ctx.self.run.hp)..'/'..number(ctx.self.run.maxHp)
        ..(result.rewardText and '\n'..result.rewardText or ''))or '未选择'
    forge:GetChild('description').text=result.choice=='upgrade'and '已升级'or '未选择'
    camp:GetChild('result'):GetChild('description').text=rest:GetChild('description').text
end
local function installRarePicker(ctx)
    if ctx.rarePickerInstalled then return end
    ctx.rarePickerInstalled=true
    local labels,command=ctx.pickerLabels,ctx.pickerCommand
    ctx.pickerLabels=function(n,...)
        if ctx.self.picker=='toke'then return '返回营地','确认移除'end
        return labels(n,...)
    end
    ctx.pickerCommand=function(n,...)
        if ctx.self.picker=='toke'then return 'toke'end
        return command(n,...)
    end
end
local function renderDigReward(ctx,node,rest,forge)
    local offer=node.digReward
    local name=offer.sourceId
    for _,r in ipairs(ctx.self.run.data.relics.relics)do if r.id==offer.id then name=r.name end end
    for _,entry in ipairs({{rest,'rest',true,'领取遗物'},{forge,'forge',false,'跳过遗物'}})do
        local box,key,claim,label=entry[1],entry[2],entry[3],entry[4]
        box:GetChild('name').text=label;box:GetChild('description').text=name;ctx.state(box,true)
        ctx.action('campView/'..key,true,function()
            return ctx.commit('claimDigReward',claim,function()return claim and '已领取「'..name..'」'or '已跳过遗物',{choice='dig'}end)
        end)
    end
    return '挖掘完成 · 选择领取遗物或跳过'
end
local function rareCampChoice(ctx,node,entry,source)
    if entry.id=='toke'then
        ctx.self.mode,ctx.self.picker,ctx.self.selected,ctx.self.pickPage='picker','toke',nil,1
        ctx.self.removeRows=node.purgeCards;ctx.self:render();return true
    elseif entry.id=='recall'then return ctx.commit('recall',source,function()return 'Recall · Ruby',{choice='recall'}end)
    else return ctx.commit(entry.id,nil,function()
        if entry.id=='dig'then return '挖掘完成 · 请选择遗物'end
        return '锻炼完成',{choice=entry.id}
    end)end
end
local function renderRareTiles(ctx,node,rest,forge,extras,page,source)
    local labels={dig='挖掘',lift='锻炼',toke='净化',recall='Recall'}
    local descriptions={dig='挖出一件随机遗物',lift='锻炼后战斗开始获得力量 · 最多3次',toke='从牌组中移除一张非瓶装牌',recall='取得红宝石钥匙'}
    for i,box in ipairs({rest,forge})do
        local entry=extras[(page-2)*2+i];ctx.show(box,entry~=nil)
        if entry then
            box:GetChild('name').text=labels[entry.id];box:GetChild('description').text=descriptions[entry.id];ctx.state(box,entry.enabled)
            ctx.action('campView/'..(i==1 and 'rest'or 'forge'),entry.enabled,function()return rareCampChoice(ctx,node,entry,source)end)
        end
    end
end
local function renderRarePage(ctx,node,rest,forge)
    local extras=Rare.campOptions(ctx.self.run,#(node.purgeCards or {})>0)
    local source=#extras>0 and type(Nodes.recallSource)=='function'and Nodes.recallSource(ctx.self.run,ctx.self.map)or nil
    if #extras>0 and source then extras[#extras+1]={id='recall',enabled=true}end
    if ctx.self.rareCampFlow~=ctx.self.run.nodeFlow then ctx.self.rareCampFlow=ctx.self.run.nodeFlow;ctx.self.rareCampPage=1 end
    local page=ctx.self.rareCampPage or 1
    ctx.rareCampPages=1+math.ceil(#extras/2)
    ctx.rareCampAnyOpen=false;for _,entry in ipairs(extras)do if entry.enabled then ctx.rareCampAnyOpen=true end end
    if page<=1 then return end
    renderRareTiles(ctx,node,rest,forge,extras,page,source)
    return '篝火旁 · 遗物选项 · '..page..' / '..ctx.rareCampPages
end

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
        if result then showCampResult(ctx,camp,rest,forge,result);return end
        rest:GetChild('name').text='休息';forge:GetChild('name').text='锻造'
        installRarePicker(ctx)
        if node.digReward then return renderDigReward(ctx,node,rest,forge)end
        local rareHint=renderRarePage(ctx,node,rest,forge)
        if rareHint then return rareHint end
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
        if not node.digReward and (ctx.rareCampPages or 1)>1 and (not node.canLeaveCamp or ctx.rareCampAnyOpen)then
            return nil,'更多营地选项',true,function()
                ctx.self.rareCampPage=(ctx.self.rareCampPage or 1)%ctx.rareCampPages+1;ctx.self:render();return true
            end
        end
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
