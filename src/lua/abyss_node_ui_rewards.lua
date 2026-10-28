local Theme = require("abyss_theme")
local CampUI = require('abyss_node_ui_camp')
local Combat = require('abyss_combat')
local Act2Events = require('abyss_act2_events')
local number = require("abyss_numbers").integer
local layout = Theme.layout.nativeNode
local PICK_PAGE = #layout.picker.columns
local function find(entries, id, key)
    for _, item in ipairs(entries or {}) do if item[key or "id"] == id then return item end end
end
local function snapshotDeck(deck)
    local result = {}
    for _, card in ipairs(deck) do result[#result + 1] = { uid = card.uid, cardId = card.cardId, upgraded = card.upgraded } end
    return result
end
local M = {}

-- Installs the rewards responsibility on one node UI instance.
function M.install(ctx)
    function ctx.renderPicker(_view, node, result)
        if ctx.enhancedForge(node) then return ctx.campUI:render(node,result) end
        local picker, before, after, target
        local function resetPickerLayout()
            picker = ctx.child("pickerView")
            ctx.show(picker:GetChild('forgeGrid'),false)
            ctx.show(picker:GetChild('forgePrevious'),false);ctx.show(picker:GetChild('forgeNext'),false)
            for _,name in ipairs({'before','after'})do
                picker:GetChild(name):SetLocalScale(1,1,1)
                picker:GetChild(name):SetAnchoredPosition(layout.picker[name],layout.picker.previewY)
            end
            for _,name in ipairs({'label','hint','page','arrow'})do
                local values=layout.picker[name]
                picker:GetChild(name):SetAnchoredPosition(values[1],values[2])
            end
            before, after, target = picker:GetChild("before"), picker:GetChild("after"), picker:GetChild("target")
        end
        resetPickerLayout()
        local upgrade, transform, dream, library, acquiring
        local function pickerModes()
            upgrade = ctx.self.picker == "upgrade" or ctx.self.picker=='living_grow' or ctx.self.picker=='act1_forge'
                or ctx.self.picker=='neow_card' and node.event.selection.forUpgrade
            transform = ctx.self.picker=='living_change' or ctx.self.picker=='act1_change'
                or ctx.self.picker=='neow_card' and node.event.selectedType:match('^TRANSFORM')~=nil
            dream=ctx.self.picker=='dream_catcher'
            library=ctx.self.picker=='library_offer'
            acquiring=dream or library
        end
        pickerModes()
        local rows
        local function pickerRows()
            rows = library and ctx.self.offerRows or dream and ctx.self.restRows or upgrade and ctx.self.upgradeRows or ctx.self.removeRows
        end
        pickerRows()
        local selected
        local function selectedPickerCard()
            selected = result and result.card or ctx.self.selected and find(rows, ctx.self.selected, library and 'offerToken' or 'uid')
        end
        selectedPickerCard()
        local pageCount = math.max(1, math.ceil(#rows / PICK_PAGE))
        ctx.self.pickPage = math.max(1, math.min(ctx.self.pickPage or 1, pageCount))
        ctx.self.pageCount = pageCount
        for i = 1, PICK_PAGE do
            local function renderPickerSlot()
                local instance = not result and rows[(ctx.self.pickPage - 1) * PICK_PAGE + i]
                local box = picker:GetChild("card" .. i)
                ctx.show(box, instance)
                if instance then
                    local owned, ambiguous
                    local function resolveOwnedCard()
                        owned = not acquiring and find(ctx.self.run.deck, instance.uid, "uid") or nil
                        ambiguous = false
                        if ctx.self.picker=='beggar_purge' or ctx.self.picker=='basics_purge' then
                            local matches=0
                            for _, candidate in ipairs(ctx.self.run.deck) do if candidate.uid==instance.uid then matches=matches+1 end end
                            ambiguous=matches~=1
                            if ambiguous then owned=nil end
                        end
                    end
                    resolveOwnedCard()
                    local available, stamp
                    local function pickerAvailability()
                        available = not ambiguous and (acquiring or owned ~= nil and (not upgrade or find(node.upgradeCards, instance.uid, "uid") ~= nil))
                        stamp = ambiguous and "编号异常" or not acquiring and (not owned and "已移除" or (upgrade and owned.upgraded and not ctx.card(instance.cardId).repeatable and "已升级")) or nil
                    end
                    pickerAvailability()
                    ctx.fillCard(box, instance.cardId, owned and owned.upgraded or instance.upgraded,
                    { dim = not available, veil = stamp ~= nil, stamp = stamp, selected = ctx.self.selected == (library and instance.offerToken or instance.uid),instance=owned or instance })
                    local uid = library and instance.offerToken or instance.uid
                    ctx.action("pickerView/card" .. i, available, function()
                        ctx.self.selected, ctx.self.notice = uid, "" ctx.self:render() return true
                    end, stamp and ("这张卡牌" .. stamp) or "这张卡牌无法升级")
                end
            end
            renderPickerSlot()

        end
        local function bindPickerPaging()
            ctx.pageArrows(picker, "", ctx.self.pickPage, result and 1 or pageCount)
            ctx.action("pickerView/previous", ctx.self.pickPage > 1, function()
                ctx.self.pickPage, ctx.self.notice = ctx.self.pickPage - 1, "" ctx.self:render() return true end)
            ctx.action("pickerView/next", ctx.self.pickPage < pageCount, function()
                ctx.self.pickPage, ctx.self.notice = ctx.self.pickPage + 1, "" ctx.self:render() return true end)
            picker:GetChild("page").text = not result and pageCount > 1 and ("第 " .. ctx.self.pickPage .. "/" .. pageCount .. " 页 · 共 " .. #rows .. " 张"
            .. (ctx.self.swipeEnabled and " · 左右拖动翻页" or "")) or ""
        end
        bindPickerPaging()
        ctx.show(before, upgrade and selected) ctx.show(after, upgrade and selected)
        ctx.show(picker:GetChild("arrow"), upgrade and selected) ctx.show(target, not upgrade and selected)
        local function writePickerPrompt()
            picker:GetChild("empty").text = selected and "" or (library and '点选一张卡牌加入牌组，不能跳过' or dream and '点选一张卡牌加入牌组，也可以跳过' or upgrade and "点选上方卡牌，查看升级前后对比" or transform and '点选上方要变换的卡牌' or "点选上方要移除的卡牌")
        end
        writePickerPrompt()
        picker:GetChild("label").text, picker:GetChild("hint").text = "", ""
        if selected and upgrade then
            local function renderUpgradePreview()
                local display = ctx.self.presentation[selected.cardId] or {}
                local changed = display.cost ~= nil and display.upgradeCost ~= nil and display.cost ~= display.upgradeCost
                local nextInstance=Combat.copy(selected)
                nextInstance.upgrades=(selected.upgrades or (selected.upgraded and 1 or 0))+1
                nextInstance.upgraded=true
                ctx.fillCard(before, selected.cardId, selected.upgraded,{instance=selected,inspectOnly=true})
                ctx.fillCard(after, selected.cardId, true, { changed = changed,instance=nextInstance,inspectOnly=true })
                picker:GetChild("label").text = result and "已升级" or "升级预览"
                picker:GetChild("hint").text = changed and ("费用 " .. display.cost .. " → " .. display.upgradeCost) or "效果增强"
            end
            renderUpgradePreview()

        elseif selected then
            local function renderRemovalPreview()
                ctx.fillCard(target, selected.cardId, selected.upgraded, { stamp = result and "已移除" or nil, dim = result ~= nil, veil = result ~= nil,instance=selected })
                picker:GetChild("label").text = acquiring and '将加入牌组' or transform and "将变换为随机的新卡牌" or result and "已移除" or "将从牌组移除"
                local function describeDeckChange()
                    picker:GetChild("hint").text = acquiring and ('牌组 '..#ctx.self.run.deck..' → '..(#ctx.self.run.deck+1)..' 张') or transform and "新卡牌不会保留原来的升级" or "牌组 " .. (#ctx.self.run.deck + (result and 1 or 0)) .. " → " ..
                    (#ctx.self.run.deck - (result and 0 or 1)) .. " 张"
                end
                describeDeckChange()

            end
            renderRemovalPreview()

        end
        local function pickerHint()
            if ctx.self.picker=='neow_card'then return '开局恩赐 · 还需选择 '..node.event.selection.count..' 张卡牌，不能取消' end
            if ctx.self.picker=='basics_purge' then return '优雅 · 免费移除一张非瓶装、可清除的永久牌' end
            if ctx.self.picker=='beggar_purge' then
                if node.event.pendingBoundary then
                    picker:GetChild("empty").text='没有可清除的卡牌；强制选牌保持待处理，不能跳过或退款。'
                end
                return '已支付75金币 · 必须移除一张非瓶装、可清除的永久牌，不能取消'
            end
            if library then return '图书馆 · 从20张不同的卡牌中选择一张，不能跳过' end
            if dream then return '捕梦网 · 选择一张卡牌加入牌组，或跳过奖励' end
            if upgrade then return "选择一张卡牌升级 · 剩余 " .. (result and 0 or node.upgradesLeft) .. " 次" end
            if transform then return '选择一张卡牌变换' end
            if ctx.self.picker == "remove" then return "选择要移除的卡牌 · 本店删牌服务限一次" end
            return "选择要净化的卡牌"
        end
        return pickerHint()

    end

    function ctx.syncLivingPicker(node,active)
        if active and node.type=='event' and node.event.id=='living_wall' and node.event.stage=='choose_card' then
            ctx.self.mode,ctx.self.picker='picker','living_'..node.event.choice
            ctx.self.removeRows=snapshotDeck(node.event.purgeCards)
            ctx.self.upgradeRows=node.upgradeCards
        end
    end

    function ctx.syncLibraryPicker(node)
        ctx.self.mode,ctx.self.picker='picker','library_offer'
        ctx.self.offerRows=Combat.copy(node.event.offers)
        if not find(ctx.self.offerRows,ctx.self.selected,'offerToken')then ctx.self.selected=nil end
    end

    function ctx.syncAct2PurgePicker(node)
        ctx.self.mode,ctx.self.picker='picker',node.event.id=='beggar' and 'beggar_purge' or 'basics_purge'
        ctx.self.removeRows=Combat.copy(node.event.purgeCards)
        local matches=0
        for _, instance in ipairs(ctx.self.run.deck) do if instance.uid==ctx.self.selected then matches=matches+1 end end
        if matches~=1 or not find(ctx.self.removeRows,ctx.self.selected,'uid') then ctx.self.selected=nil end
    end

    function ctx.syncAct2Picker(node,active)
        if active and node.type=='event' and Act2Events.ids[node.event.id] then
            if node.event.id=='the_library' and node.event.stage=='choose_offer' then
                ctx.syncLibraryPicker(node)
            elseif (node.event.id=='beggar' or node.event.id=='back_to_basics') and node.event.stage=='choose_card' then
                ctx.syncAct2PurgePicker(node)
            else ctx.self.mode,ctx.self.picker,ctx.self.selected='main',nil,nil end
        end
    end

    function ctx.syncNeowPicker(node,active)
        if active and node.type=='event' and node.event.id=='neow'then
            if node.event.stage=='neow_choose_card'then
                ctx.self.mode,ctx.self.picker='picker','neow_card'
                ctx.self.removeRows,ctx.self.upgradeRows=Combat.copy(node.event.purgeCards),Combat.copy(node.event.purgeCards)
                if not find(ctx.self.removeRows,ctx.self.selected,'uid')then ctx.self.selected=nil end
            else ctx.self.mode,ctx.self.picker,ctx.self.selected='main',nil,nil end
        end
    end

    function ctx.syncRestPicker(node,active)
        if active and node.type=='camp' and node.restReward and not node.restReward.resolved then
            ctx.self.mode,ctx.self.picker='picker','dream_catcher';ctx.self.restRows={}
            for i,id in ipairs(node.restReward.cards)do ctx.self.restRows[i]={uid=i,cardId=id,upgraded=node.restReward.cardUpgrades and node.restReward.cardUpgrades[i]==true}end
        end
    end

    function ctx.syncAct1Picker(node,active)
        if active and node.type=='event' and (node.event.id=='accursed_blacksmith' or node.event.id=='bonfire' or node.event.id=='transmogrifier' or node.event.id=='wheel') then
            if node.event.stage=='choose_card' then
                ctx.self.mode,ctx.self.picker='picker','act1_'..node.event.choice
                ctx.self.removeRows=snapshotDeck(node.event.purgeCards or {})
                ctx.self.upgradeRows=node.upgradeCards
            else ctx.self.mode,ctx.self.picker,ctx.self.selected='main',nil,nil end
        end
    end

    function ctx.syncNodePicker(node,active)
        ctx.syncLivingPicker(node,active)
        ctx.syncAct2Picker(node,active)
        ctx.syncNeowPicker(node,active)
        ctx.syncRestPicker(node,active)
        ctx.syncAct1Picker(node,active)
    end

    function ctx.eventPickerLabel(living,act1)
        local confirmLabel
        if act1 then
            confirmLabel=ctx.self.picker=='act1_forge' and '确认升级' or ctx.self.picker=='act1_change' and '确认变换' or ctx.self.picker=='act1_purge' and '确认移除' or '确认献祭'
        elseif living then
            confirmLabel=ctx.self.picker=='living_grow' and '确认升级' or ctx.self.picker=='living_change' and '确认变换' or '确认移除'
        end
        return confirmLabel
    end

    function ctx.pickerLabels(node,living,act1,dream,restReward)
        if ctx.enhancedForge(node) then return CampUI.labels(ctx.self.selected,node,ctx.self.run) end
        local backLabel,confirmLabel,skipRestReward
        if dream then
            confirmLabel,backLabel='选择此牌','跳过卡牌'
            skipRestReward=function()return restReward(0)end
        elseif ctx.self.picker=='neow_card' or ctx.self.picker=='library_offer'then
            confirmLabel='确认选择'
        elseif ctx.self.picker=='beggar_purge' or ctx.self.picker=='basics_purge' then
            confirmLabel='确认移除'
        elseif act1 or living then
            confirmLabel=ctx.eventPickerLabel(living,act1)
        elseif ctx.self.picker == "upgrade" then
            confirmLabel = "确认升级"
            if not node.campChoice then backLabel = "返回" end
        elseif ctx.self.picker == "remove" then
            confirmLabel, backLabel = "删除 · " .. node.removePrice .. " 金币", "返回"
        else
            confirmLabel, backLabel = node.event.removeCost > 0 and ("净化 · " .. node.event.removeCost .. " 金币") or "祈祷 · 移除", "返回"
        end
        return backLabel,confirmLabel,skipRestReward
    end

    function ctx.pickerCommand(node,act1,living)
        local command = act1 and 'chooseAct1EventCard' or living and "chooseLivingWallCard" or ctx.self.picker == "upgrade" and (node.type=="event" and "upgradeEvent" or "upgrade")
            or ctx.self.picker=='wing_purge' and 'purgeWing' or ctx.self.picker == "remove" and "removeCard" or "purifyEvent"
        return command
    end

    function ctx.pickerFooter(node)
        local backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward
        local selected = ctx.self.selected
        local living=node.type=='event' and node.event.id=='living_wall'
        local act1=node.type=='event' and (node.event.id=='accursed_blacksmith' or node.event.id=='bonfire' or node.event.id=='transmogrifier' or node.event.id=='wheel')
        local dream=ctx.self.picker=='dream_catcher'
        local function restReward(choice)
            local id=node.restReward.cards[choice]
            return ctx.commit('claimRestReward',choice,function()
                local obtained=ctx.self.run.deck[#ctx.self.run.deck]
                local text=choice==0 and '已跳过卡牌奖励' or ('已获得「'..ctx.cardName(id,obtained.upgraded,obtained.upgrades)..'」')
                ctx.self.mode,ctx.self.picker,ctx.self.selected='main',nil,nil
                return text,{choice='rest',healed=ctx.self.run.nodeFlow.restHealed,rewardText=text}
            end)
        end
        backLabel,confirmLabel,skipRestReward=ctx.pickerLabels(node,living,act1,dream,restReward)
        confirmOk = selected ~= nil
        confirmFn = function()
            if dream then return restReward(selected) end
            if ctx.self.picker=='neow_card' or ctx.self.picker=='library_offer'then
                return ctx.commit('chooseEvent','select',function()
                    ctx.self.selected=nil;return ctx.self.run.nodeFlow.event.body
                end,selected)
            end
            if ctx.self.picker=='beggar_purge' or ctx.self.picker=='basics_purge' then
                return ctx.commit('chooseEvent','purge',function()return '已移除所选卡牌' end,selected)
            end
            local instance = find(ctx.self.upgradeRows, selected, "uid") or find(ctx.self.removeRows, selected, "uid")
            local name = instance and ctx.cardName(instance.cardId, instance.upgraded,instance.upgrades) or ""
            local command=ctx.pickerCommand(node,act1,living)
            return ctx.commit(command, selected, function(before)
                if act1 then
                    local text=ctx.self.run.nodeFlow.event.body or '选择完成。'
                    return text,{text=text}
                end
                if living then
                    local event=ctx.self.run.nodeFlow.event
                    local text
                    if event.choice=='grow' then text='已升级「'..name..'」'
                    elseif event.choice=='forget' then text='已移除「'..name..'」'
                    else
                        local obtainedCard=find(ctx.self.run.deck,event.obtainedCardUid,'uid')
                        text='「'..name..'」已变换为「'..ctx.cardName(obtainedCard.cardId,obtainedCard.upgraded)..'」'
                    end
                    return text,{text=text}
                end
                if command == "upgrade" or command=='upgradeEvent' then
                    local upgraded=find(ctx.self.run.deck,selected,'uid')
                    local text="已升级「"..name.."」→「"..ctx.cardName(instance.cardId,true,upgraded.upgrades).."」"
                    return text, { choice = "upgrade", card = instance, text=text }
                end
                local paid = before.gold - ctx.self.run.gold
                local text = "已移除「" .. name .. "」" .. (paid > 0 and (" · 支付 " .. number(paid) .. " 金币") or "")
                return text, { card = instance, text = "「" .. name .. "」已从牌组中移除" ..
                    (paid > 0 and ("，支付 " .. number(paid) .. " 金币。") or "。") .. "\n牌组现有 " .. #ctx.self.run.deck .. " 张。" }
            end)
        end
        return backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,nil
    end
end
return M
