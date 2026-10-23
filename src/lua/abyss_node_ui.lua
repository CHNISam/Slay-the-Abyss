-- Native non-combat node adapter. Nodes owns every gameplay transaction.
-- root is nodePanel from nodeLayout(); the host may replace self.run/self.map.
-- onChange(ok, reason, self) refreshes the host after an attempted command.
local Nodes = require("abyss_nodes")
local Theme = require("abyss_theme")
local M = {}
local kinds = { camp = "营地", shop = "商店", event = "未知事件", treasure = "宝箱" }
local reasons = {
    insufficient_gold = "金币不足", item_unavailable = "商品已售出或不可购买",
    removal_unavailable = "本店删牌服务已使用",
    invalid_card = "这张卡牌已不在牌组中", last_card = "必须保留至少一张卡牌",
    card_not_upgradeable = "这张卡牌无法继续升级", potion_slots_full = "药水槽已满，请选择金币",
    camp_choice_made = "本次营地已选择升级或休息", no_pending_node = "此节点已经完成",
    wrong_node_type = "当前节点不支持此操作", relic_already_owned = "已持有这件遗物",
    invalid_event_choice = "此事件选项不可用", event_unavailable = "当前没有满足条件的已实现事件", stale_action = "界面已变化，请重新选择",
    panel_hidden = "节点界面未打开", unavailable_action = "此选项当前不可用",
}
local function find(entries, id, key)
    for _, item in ipairs(entries or {}) do if item[key or "id"] == id then return item end end
end
local function snapshotDeck(deck)
    local result = {}
    for _, card in ipairs(deck) do result[#result + 1] = { uid = card.uid, cardId = card.cardId, upgraded = card.upgraded } end
    return result
end
function M.new(root, run, map, presentation, clickEvent, onChange)
    local self = { root = root, run = run, map = map, presentation = presentation or {},
        visible = true, page = 1, category = "cards", mode = "main", slots = {}, notice = "" }
    local function child(name) return assert(root:GetChild(name), "missing node UI control " .. name) end
    local function text(name, value) child(name).text = value end
    local function state(name, enabled, selected)
        local box = child(name)
        box:GetChild("normal"):SetVisible(enabled and not selected)
        box:GetChild("disabled"):SetVisible(not enabled)
        box:GetChild("selected"):SetVisible(selected == true)
    end
    local function named(category, id, upgraded)
        if category == "cards" then
            local card = self.presentation[id]
            local definition = find(self.run.data.cards.cards, id)
            return (card and card.name or (definition and definition.name) or id) .. (upgraded and "+" or "")
        end
        local definition = find(self.run.data[category][category], id)
        return definition and definition.name or id
    end
    local function details(category, id, upgraded)
        if category == "cards" then
            local card = self.presentation[id]
            if not card then return "" end
            local cost = upgraded and card.upgradeCost or card.cost
            local effect = upgraded and card.upgradeText or card.text
            local line = cost ~= nil and ("费用 " .. cost .. " 能量") or ""
            if type(effect) == "string" and effect ~= "" then line = line .. (line ~= "" and " · " or "") .. effect end
            return line ~= "" and ("\n" .. (upgraded and "升级后 · " or "") .. line) or ""
        end
        local definition = find(self.run.data[category][category], id)
        local effect = definition and (definition.description or definition.text)
        return type(effect) == "string" and effect ~= "" and ("\n" .. effect) or ""
    end
    local function descriptor(label, command, argument, enabled, success)
        return { label = label, command = command, argument = argument, enabled = enabled ~= false, success = success }
    end
    function self:render()
        local view = Nodes.view(self.run, self.map)
        local node = view.node
        if self.renderRun ~= self.run or self.renderMap ~= self.map or self.nodeId ~= (node and node.id) then
            self.page, self.category, self.mode, self.notice = 1, "cards", "main", ""
            self.upgradeRows = node and node.upgradeCards or {}
            self.removeRows = snapshotDeck(self.run.deck)
        end
        self.renderRun, self.renderMap, self.nodeId = self.run, self.map, node and node.id
        self.view = view
        local active = node and kinds[node.type] and not node.complete and view.phase == "node"
        text("title", node and ("第 " .. node.floor .. " 层 · " .. (kinds[node.type] or "节点")) or "节点")
        text("resources", "生命 " .. self.run.hp .. "/" .. self.run.maxHp .. "    金币 " .. self.run.gold ..
            "    牌组 " .. #self.run.deck .. "    遗物 " .. #self.run.relics ..
            "    药水 " .. #self.run.potions .. "/" .. self.run.data.rules.player.potionSlots)
        local rows, hint = {}, node and "请完成当前节点。" or "请在路线中选择下一个节点。"
        if node and node.complete then hint = "本节点已完成，可以返回路线。" end
        if active and node.type == "camp" then
            hint = "休息或升级卡牌；两种选择只能选一种。"
            if self.mode == "main" and node.campChoice ~= "upgrade" then
                rows = {
                    descriptor("休息 · 回复 " .. node.heal .. " 点生命", "rest", nil, true, "休息完成，生命已恢复"),
                    descriptor("升级卡牌 · 可升级 " .. #node.upgradeCards .. " 张", "upgradeMenu", nil, #node.upgradeCards > 0),
                }
            else
                self.mode = "upgrade"
                hint = "选择要升级的卡牌 · 剩余升级次数 " .. node.upgradesLeft
                for _, instance in ipairs(self.upgradeRows) do
                    local available = find(node.upgradeCards, instance.uid, "uid") ~= nil
                    rows[#rows + 1] = descriptor(named("cards", instance.cardId) .. " · #" .. instance.uid ..
                        (available and " · 升级" or " · 已升级 / 不可用") .. details("cards", instance.cardId, true),
                        "upgrade", instance.uid, available, "卡牌升级完成")
                end
            end
        elseif active and node.type == "shop" then
            hint = "点选商品购买 · 红色价格表示金币不足 · 可随时离开商店"
            if self.category == "remove" then
                for _, instance in ipairs(self.removeRows) do
                    local owned = find(self.run.deck, instance.uid, "uid")
                    local allowed = node.removeAvailable and owned ~= nil and #self.run.deck > 1 and self.run.gold >= node.removePrice
                    local status = not owned and "已删除" or (not node.removeAvailable and "本店服务已使用" or
                        (#self.run.deck <= 1 and "仅剩一张" or (self.run.gold < node.removePrice and "金币不足" or "删除")))
                    rows[#rows + 1] = descriptor(named("cards", instance.cardId, instance.upgraded) .. " · #" .. instance.uid ..
                        " · " .. node.removePrice .. " 金币 · " .. status, "removeCard", instance.uid, allowed, "卡牌已删除")
                    local row = rows[#rows]
                    row.name = named("cards", instance.cardId, instance.upgraded)
                    row.description = "移除牌组中的这张卡牌 · 编号 " .. instance.uid .. details("cards", instance.cardId, instance.upgraded)
                    row.price = node.removePrice .. " 金币 · " .. status
                    row.unaffordable = owned ~= nil and self.run.gold < node.removePrice
                    row.art = (find(self.run.data.cards.cards, instance.cardId) or {}).type or "status"
                end
            else
                for _, offer in ipairs(node[self.category]) do
                    local status = offer.sold and "已售出" or (self.run.gold < offer.price and "金币不足" or "购买")
                    rows[#rows + 1] = descriptor(named(self.category, offer.id) .. " · " .. offer.price .. " 金币 · " .. status .. details(self.category, offer.id),
                        self.category == "cards" and "buyCard" or "buyRelic", offer.id,
                        not offer.sold and self.run.gold >= offer.price, "购买成功，已加入本局收藏")
                    local row = rows[#rows]
                    row.name = named(self.category, offer.id)
                    row.description = details(self.category, offer.id):gsub("^\n", "")
                    row.price = offer.price .. " 金币 · " .. status
                    row.unaffordable = not offer.sold and self.run.gold < offer.price
                    row.art = self.category == "relics" and "relic" or ((find(self.run.data.cards.cards, offer.id) or {}).type or "status")
                end
            end
        elseif active and node.type == "event" then
            local event = node.event
            local eventName = event.id == "cleric" and "圣职者" or "净化神龛"
            hint = eventName .. " · 选择一项，或直接离开。"
            if self.mode == "purify" then
                hint = "选择要净化的卡牌 · " .. event.removeCost .. " 金币"
                for _, instance in ipairs(self.removeRows) do
                    local owned = find(self.run.deck, instance.uid, "uid")
                    local allowed = owned ~= nil and #self.run.deck > 1 and self.run.gold >= event.removeCost
                    local status = not owned and "已删除" or (#self.run.deck <= 1 and "仅剩一张" or
                        (self.run.gold < event.removeCost and "金币不足" or "净化"))
                    rows[#rows + 1] = descriptor(named("cards", instance.cardId, instance.upgraded) .. " · #" .. instance.uid ..
                        " · " .. event.removeCost .. " 金币 · " .. status .. details("cards", instance.cardId, instance.upgraded),
                        "purifyEvent", instance.uid, allowed, "净化完成，卡牌已删除")
                end
            elseif event.id == "cleric" then
                rows = {
                    descriptor("治疗 · " .. event.healCost .. " 金币 · 回复 " .. event.heal .. " 点生命", "chooseEvent", "heal",
                        self.run.gold >= event.healCost, "治疗完成，生命已恢复"),
                    descriptor("净化 · " .. event.removeCost .. " 金币 · 删除一张卡牌", "purifyMenu", nil,
                        self.run.gold >= event.removeCost and #self.run.deck > 1),
                    descriptor("离开", "chooseEvent", "leave", true, "已离开圣职者"),
                }
            else
                rows = {
                    descriptor("祈祷 · 免费删除一张卡牌", "purifyMenu", nil, #self.run.deck > 1),
                    descriptor("离开", "chooseEvent", "leave", true, "已离开净化神龛"),
                }
            end
        elseif active and node.type == "treasure" then
            hint = "打开宝箱，领取本节点的收获。"
            local reward = node.reward.relicId and named("relics", node.reward.relicId) or (node.reward.gold .. " 金币")
            rows[1] = descriptor("打开宝箱 · " .. reward .. (node.reward.relicId and details("relics", node.reward.relicId) or ""),
                "claimTreasure", nil, true, "宝箱已开启 · 获得 " .. reward)
        end
        local shop = active and node.type == "shop" or false
        local pageSize = shop and Theme.layout.nativeNode.shop.pageSize or 8
        self.pageCount = math.max(1, math.ceil(#rows / pageSize))
        self.page = math.max(1, math.min(self.page, self.pageCount))
        text("page", (#rows == 0 and "暂无可用选项" or "第 " .. self.page .. "/" .. self.pageCount .. " 页"))
        text("notice", self.notice ~= "" and self.notice or hint)
        self.slots = {}
        for i = 1, 8 do
            local row = rows[(self.page - 1) * pageSize + i]
            if i > pageSize then row = nil end
            child("action" .. i):SetVisible(not shop and row ~= nil)
            if i <= Theme.layout.nativeNode.shop.pageSize then
                local item = child("shop" .. i)
                item:SetVisible(shop and row ~= nil)
                if shop and row then
                    item:GetChild("label"):SetVisible(false)
                    item:GetChild("name").text = row.name
                    item:GetChild("description").text = row.description
                    item:GetChild("price").text = row.price
                    item:GetChild("unavailablePrice").text = row.price
                    item:GetChild("price"):SetVisible(not row.unaffordable)
                    item:GetChild("unavailablePrice"):SetVisible(row.unaffordable == true)
                    for kind in pairs(Theme.icon.cardArt) do
                        item:GetChild("art_" .. kind):SetVisible(row.art == kind)
                        item:GetChild("artPlate_" .. kind):SetVisible(row.art == kind)
                    end
                    item:GetChild("art_relic"):SetVisible(row.art == "relic")
                    state("shop" .. i, row.enabled)
                end
            end
            if row then
                self.slots[i] = row
                child("action" .. i):GetChild("label").text = row.label
                state("action" .. i, row.enabled)
            end
        end
        for i, category in ipairs({ "cards", "relics", "remove" }) do
            child("tab" .. i):SetVisible(active and node.type == "shop" or false)
            state("tab" .. i, true, self.category == category)
        end
        child("previous"):SetVisible(self.page > 1)
        child("next"):SetVisible(self.page < self.pageCount)
        child("leave"):SetVisible((node and node.complete) or (active and (node.type == "shop" or self.mode == "upgrade" and not node.campChoice
            or node.type == "event" and self.mode == "purify")) or false)
        child("leave"):GetChild("label").text = active and node.type == "camp" and "返回营地" or
            (active and node.type == "event" and self.mode == "purify" and "返回事件" or
                (active and node.type == "shop" and "离开商店" or "返回路线"))
        state("leave", true)
    end
    function self:setVisible(value)
        assert(type(value) == "boolean", "node visibility must be boolean")
        self.visible = value root:SetVisible(value)
    end
    local function current()
        if not self.visible then return false, "panel_hidden" end
        if self.busy then return false, "unavailable_action" end
        local view = Nodes.view(self.run, self.map)
        if self.renderRun ~= self.run or self.renderMap ~= self.map or not view.node or view.node.id ~= self.nodeId then
            return false, "stale_action"
        end
        return true, view
    end
    local function notify(ok, reason)
        if onChange then onChange(ok, reason, self) end
        return ok, reason
    end
    function self:activate(slot)
        local ok, view = current()
        if not ok then return false, view end
        local action = self.slots[slot]
        if not action or not action.enabled or view.node.complete or view.phase ~= "node" then return false, "unavailable_action" end
        if action.command == "upgradeMenu" then self.mode, self.page, self.notice = "upgrade", 1, "" self:render() return true end
        if action.command == "purifyMenu" then self.mode, self.page, self.notice = "purify", 1, "" self:render() return true end
        self.busy = true
        local called, accepted, reason = pcall(Nodes[action.command], self.run, action.argument)
        self.busy = false
        if not called then error(accepted) end
        self.notice = accepted and action.success or (reasons[reason] or "操作未完成，请重新选择")
        self:render()
        return notify(accepted, reason)
    end
    function self:setPage(page)
        local ok, reason = current() if not ok then return false, reason end
        if type(page) ~= "number" or page % 1 ~= 0 or page < 1 or page > self.pageCount then return false, "invalid_page" end
        self.page, self.notice = page, "" self:render() return true
    end
    function self:setCategory(category)
        local ok, view = current() if not ok then return false, view end
        if view.node.complete or view.node.type ~= "shop" or (category ~= "cards" and category ~= "relics" and category ~= "remove") then return false, "unavailable_action" end
        self.category, self.page, self.notice = category, 1, "" self:render() return true
    end
    function self:leave()
        local ok, view = current() if not ok then return false, view end
        if view.node.complete then return notify(true, "complete") end
        if view.node.type == "camp" and self.mode == "upgrade" and not view.node.campChoice then
            self.mode, self.page, self.notice = "main", 1, "" self:render() return true
        end
        if view.node.type == "event" and self.mode == "purify" then
            self.mode, self.page, self.notice = "main", 1, "" self:render() return true
        end
        if view.node.type ~= "shop" then return false, "unavailable_action" end
        local accepted, reason = Nodes.leaveShop(self.run)
        self.notice = accepted and "已离开商店" or (reasons[reason] or "暂时无法离开")
        self:render() return notify(accepted, reason)
    end
    local function bind(name, fn) child(name):GetChild("hit"):AddCursorEventListener(clickEvent, fn) end
    for i = 1, 8 do local slot = i bind("action" .. i, function() return self:activate(slot) end) end
    for i = 1, Theme.layout.nativeNode.shop.pageSize do local slot = i bind("shop" .. i, function() return self:activate(slot) end) end
    for i, value in ipairs({ "cards", "relics", "remove" }) do local category = value bind("tab" .. i, function() return self:setCategory(category) end) end
    bind("previous", function() return self:setPage(self.page - 1) end)
    bind("next", function() return self:setPage(self.page + 1) end)
    bind("leave", function() return self:leave() end)
    self:render()
    return self
end
return M
