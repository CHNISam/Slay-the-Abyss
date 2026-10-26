-- Shop subview: render the Nodes quote and register actions on the node controller.
-- Transactions and gesture ownership stay with abyss_node_ui / abyss_nodes.
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local number = require("abyss_numbers").integer
local C = Theme.color
local SHOP_PAGE = #Theme.layout.nativeNode.shop.columns
local RELIC_PAGE = #Theme.layout.nativeNode.shop.relics.columns
local typeNames = { attack = "攻击", skill = "技能", power = "能力", status = "状态", curse = "诅咒" }
local rarityNames = {common='普通',uncommon='罕见',rare='稀有',shop='商店专属'}
local priceLabels = { missing = "未实装", sold = "已售出" }
local priceColors = { poor = C.danger, sold = C.textMuted }
local missingReasons = {
    card = "此商品尚未实装，不可购买", relic = "此遗物尚未实装，不可购买", potion = "此药水尚未实装，不可购买",
}
local potionEffectTemplates = {
    damage = "单敌固定伤害{value}",
    damageAll = "全体敌人伤害{value}（不受力量、虚弱、易伤影响）",
    block = "自己固定格挡{value}", energy = "自己能量+{value}（本回合）", draw = "抽{value}张牌",
    upgradeHand = "升级全部可升级手牌（仅本场战斗）", healPercent = "回复最大生命{value}%的生命",
    increaseMaxHp = "最大生命+{value}，并回复{value}生命", exhaustMany = "选择任意张手牌消耗（可不选）",
    discardRedraw = "选择任意张手牌丢弃，再抽等量牌", discardToHand = "选择{value}张弃牌回手，本回合费用为0",
    randomizeHandCost = "手牌战斗费用随机改为0至3", escape = "逃离战斗，不获得奖励（Boss或背袭敌人房间不可用）",
    playTopCards = "免费打出牌堆顶{value}张牌，目标随机",
}
local statusEffectOps = { gainTemporaryStrength = true, gainTemporaryDexterity = true, gainStatus = true, applyStatus = true }
local M = {}

local function find(entries, id)
    for _, item in ipairs(entries or {}) do if item.id == id then return item end end
end

local function priceStatus(offer, poor)
    if offer.unavailable then return "missing" end
    if offer.sold then return "sold" end
    if poor then return "poor" end
    return "ok"
end

local function cardStamp(offer)
    if offer.unavailable then return "未实装" end
    if offer.sold then return "已售出" end
    if offer.sale then return "特价 -50%" end
end

local function statusDuration(status, id)
    if status and status.stack == "duration" then return "回合" end
    if id == "regen" then return "（回合结束回复）" end
    return ""
end

local function statusEffectText(data, effect, value)
    local status = find(data.statuses.statuses, effect.status)
    if effect.op == "gainTemporaryStrength" or effect.op == "gainTemporaryDexterity" then
        return "自己" .. status.name .. "+" .. value .. "，回合结束时失去" .. value
    end
    if effect.op == "gainStatus" or effect.op == "applyStatus" then
        return (effect.op == "applyStatus" and "单敌" or "自己") .. (status and status.name or effect.status)
            .. value .. statusDuration(status, effect.status)
    end
end

local function potionEffectText(data, effect)
    local value = number(effect.value or 0)
    local template = potionEffectTemplates[effect.op]
    if template then return (template:gsub("{value}", value)) end
    if statusEffectOps[effect.op] then return statusEffectText(data, effect, value) end
end

function M.new(controller, ui)
    local self = controller
    local show, state, ink, picture = ui.show, ui.state, ui.ink, ui.picture
    local fillCard, cardName = ui.fillCard, ui.cardName
    local relicName, relicText = ui.relicName, ui.relicText
    local action, commit, pageArrows = ui.action, ui.commit, ui.pageArrows

    local function shortfall(price)
        return "金币不足：需要 " .. number(price) .. "，还差 " .. number(price - self.run.gold)
    end

    -- Price status: ok gold, poor red, sold/missing without a coin.
    local function fillPrice(box, value, status)
        box:SetVisible(true)
        box:GetChild("value").text = priceLabels[status] or number(value)
        ink(box:GetChild("value"), priceColors[status] or C.goldBright)
        show(box:GetChild("coin"), status ~= "sold" and status ~= 'missing')
    end

    local function offerState(offer, full)
        local poor = self.run.gold < offer.price
        return {
            poor = poor,
            enabled = not offer.sold and not poor and not offer.unavailable and not full,
            attention = poor and not offer.sold and not offer.unavailable and not full,
            price = priceStatus(offer, poor),
        }
    end

    local function offerNotice(kind, offer, name, full)
        if offer.unavailable then return missingReasons[kind] end
        if offer.sold then
            if kind == "potion" then return "药水已售出" end
            return "「" .. name .. "」已售出"
        end
        if full then return "药水槽已满" end
        return shortfall(offer.price)
    end

    local function potionText(id)
        local definition=find(self.run.data.potions.potions,id)
        local parts={}
        for _,effect in ipairs(definition and definition.effects or {}) do
            local text = potionEffectText(self.run.data, effect)
            if text then parts[#parts+1] = text end
        end
        return table.concat(parts,'，')
    end

    local function writeMissingCard(box, offer)
        box:GetChild('name').text=(offer.color=='colorless' and '无色' or '')..(rarityNames[offer.rarity] or '')..'牌 · 缺口'
        box:GetChild('description').text='此类别与稀有度尚无可售内容'
        box:GetChild('cost').text=''
        box:GetChild('type').text=typeNames[offer.type] or ''
    end

    local function currentCardShelf(view, flow, shelf)
        -- A slot means the current offer, not a reusable quote. Keep this render
        -- bound to its run, node and shelf so it cannot buy Courier's replacement.
        return self.visible and self.view == view and self.renderRun == self.run and self.renderMap == self.map
            and self.run.nodeFlow == flow and flow.cards == shelf
    end

    local function bindCard(view, flow, shelf, i, offer, availability)
        local name = cardName(offer.id)
        action("shopView/card" .. i, availability.enabled, function()
            if not currentCardShelf(view, flow, shelf) then return false, 'stale_action' end
            return commit("buyCardSlot", i, function(before)
                return "已购买「" .. name .. "」· 支付 " .. number(before.gold - self.run.gold) .. " 金币，加入牌组"
            end)
        end, offerNotice("card", offer, name), availability.attention)
    end

    local function renderCardSlot(shop, view, offers, i, flow, shelf)
        local offer = offers[(self.page - 1) * SHOP_PAGE + i]
        local box, price = shop:GetChild("card" .. i), shop:GetChild("price" .. i)
        show(box, offer ~= nil) show(price, offer ~= nil)
        if not offer then return end
        local availability = offerState(offer)
        fillCard(box, offer.id, false, { dim = offer.sold or availability.poor or offer.unavailable,
            veil = offer.sold, stamp = cardStamp(offer) })
        if offer.unavailable then writeMissingCard(box, offer) end
        fillPrice(price, offer.price, availability.price)
        bindCard(view, flow, shelf, i, offer, availability)
    end

    local function renderCards(shop, view, offers)
        local flow, shelf = self.run.nodeFlow, self.run.nodeFlow.cards
        for i = 1, SHOP_PAGE do
            renderCardSlot(shop, view, offers, i, flow, shelf)
        end
        pageArrows(shop, "", self.page, self.pageCount)
        action("shopView/previous", self.page > 1, function() return self:setPage(self.page - 1) end)
        action("shopView/next", self.page < self.pageCount, function() return self:setPage(self.page + 1) end)
        shop:GetChild("page").text = self.run.data.originalV4Role
            and '职业牌：2攻击 / 3技能　无色牌：罕见 / 稀有'
            or '职业牌：2攻击 / 2技能 / 1能力　无色牌：罕见 / 稀有'
    end

    local function removalReason(node)
        if not node.removeAvailable then return "本店删牌服务已使用，每家商店限一次" end
        if #node.purgeCards == 0 then return "没有可移除的卡牌" end
        return shortfall(node.removePrice)
    end

    local function removalDescription(node)
        if not node.removeAvailable then return "本店已使用" end
        if #node.purgeCards == 0 then return "没有可移除的卡牌" end
        return "每家商店限一次\n之后的商店 +" .. self.run.data.rules.shop.removeCardIncrement
    end

    local function renderRemovalPrice(removalPrice, node, poor)
        fillPrice(removalPrice, node.removePrice, not node.removeAvailable and "sold" or poor and "poor" or "ok")
        if not node.removeAvailable then removalPrice:GetChild("value").text = "已使用" end
    end

    local function renderRemoval(shop, node)
        local removal, removalPrice = shop:GetChild("removal"), shop:GetChild("removalPrice")
        local poor = node.removeAvailable and self.run.gold < node.removePrice
        local open = node.removeAvailable and #node.purgeCards > 0 and not poor
        local reason = removalReason(node)
        state(removal, open)
        removal:GetChild("description").text = removalDescription(node)
        ink(removal:GetChild("name"), open and C.text or C.textMuted)
        renderRemovalPrice(removalPrice, node, poor)
        action("shopView/removal", open, function()
            self.mode, self.picker, self.pickPage, self.selected, self.notice = "picker", "remove", 1, nil, ""
            self:render() return true
        end, reason, poor)
    end

    local function relicTitle(offer)
        if offer.unavailable then return (rarityNames[offer.rarity] or '') .. '遗物' end
        return relicName(offer.id) .. (offer.sold and " · 已售出" or "")
    end

    local function writeRelic(tile, offer, availability)
        state(tile, availability.enabled)
        picture(tile:GetChild("icon"), Theme.icon.relic[offer.id])
        tile:GetChild("name").text = relicTitle(offer)
        tile:GetChild("description").text = offer.unavailable and '此稀有度暂无可售内容' or relicText(offer.id)
        ink(tile:GetChild("name"), (offer.sold or availability.poor) and C.textMuted or C.text)
        show(tile:GetChild("veil"), offer.sold)
    end

    local function bindRelic(i, offer, availability)
        local name = relicName(offer.id)
        action("shopView/relic" .. i, availability.enabled, function()
            return commit("buyRelic", offer.id, function(before)
                return "已购买遗物「" .. name .. "」· 支付 " .. number(before.gold - self.run.gold) .. " 金币"
            end)
        end, offerNotice("relic", offer, name), availability.attention)
    end

    local function renderRelicSlot(shop, offers, i)
        local offer = offers[(self.relicPage - 1) * RELIC_PAGE + i]
        local tile, price = shop:GetChild("relic" .. i), shop:GetChild("relicPrice" .. i)
        show(tile, offer ~= nil) show(price, offer ~= nil)
        if not offer then return end
        local availability = offerState(offer)
        writeRelic(tile, offer, availability)
        fillPrice(price, offer.price, availability.price)
        bindRelic(i, offer, availability)
    end

    local function renderRelics(shop, offers)
        local relicPages = 1
        for i = 1, RELIC_PAGE do
            renderRelicSlot(shop, offers, i)
        end
        pageArrows(shop, "relic", self.relicPage, relicPages)
        action("shopView/relicPrevious", self.relicPage > 1, function()
            self.relicPage, self.notice = self.relicPage - 1, "" self:render() return true end)
        action("shopView/relicNext", self.relicPage < relicPages, function()
            self.relicPage, self.notice = self.relicPage + 1, "" self:render() return true end)
    end

    local function potionDescription(offer, full)
        if offer.unavailable then return '此稀有度暂无可售内容' end
        if offer.sold then return '已售出' end
        if full then return '药水槽已满' end
        return potionText(offer.id)
    end

    local function writePotion(tile, offer, definition, availability, full)
        state(tile, availability.enabled)
        picture(tile:GetChild('icon'), Theme.icon.potion[offer.id])
        tile:GetChild('name').text = definition and definition.name or (rarityNames[offer.rarity] or '') .. '药水'
        tile:GetChild('description').text = potionDescription(offer, full)
        show(tile:GetChild('veil'), offer.sold)
    end

    local function bindPotion(i, offer, availability, full)
        action('shopView/potion' .. i, availability.enabled, function()
            return commit('buyPotion', i, function(before)
                return '已购买药水 · 支付 ' .. number(before.gold - self.run.gold) .. ' 金币'
            end)
        end, offerNotice("potion", offer, nil, full), availability.attention)
    end

    local function renderPotionSlot(shop, i, offer)
        local tile, price = shop:GetChild('potion' .. i), shop:GetChild('potionPrice' .. i)
        local definition = find(self.run.data.potions.potions, offer.id)
        local full = Run.potionCount(self.run) >= Run.potionCapacity(self.run)
        local availability = offerState(offer, full)
        writePotion(tile, offer, definition, availability, full)
        fillPrice(price, offer.price, availability.price)
        bindPotion(i, offer, availability, full)
    end

    local function renderPotions(shop, offers)
        for i, offer in ipairs(offers) do renderPotionSlot(shop, i, offer) end
    end

    return function(view, node)
        local shop = ui.child("shopView")
        self.pageCount, self.page, self.relicPage = 1, 1, 1
        renderCards(shop, view, node.cards or {})
        renderRemoval(shop, node)
        renderRelics(shop, node.relics or {})
        renderPotions(shop, node.potions or {})
        return "点选商品购买 · 未实装槽位不可购买"
    end
end

return M
