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
end

function M.new(controller, ui)
    local self = controller
    local show, state, ink, picture = ui.show, ui.state, ui.ink, ui.picture
    local fillCard, cardName = ui.fillCard, ui.cardName
    local relicName, relicText = ui.relicName, ui.relicText
    local action, commit, pageArrows = ui.action, ui.commit, ui.pageArrows
    local selection = ui.selection
    local function purchase(key, category, slot, enabled, handler, name, description, reason, attention)
        local invoke, observe = selection:bind(key, category, slot, handler, name, description)
        -- Disabled goods still receive a fresh click to explain the refusal.
        -- Only enabled purchases arm a quote-owning transaction gesture.
        return action(key, enabled, invoke, reason, attention, enabled and observe or nil)
    end

    local function shortfall(price)
        return "金币不足：需要 " .. number(price) .. "，还差 " .. number(price - self.run.gold)
    end

    -- Price status: ok gold, poor red, sold/missing without a coin.
    local function fillPrice(box, value, status)
        box:SetVisible(true)
        box:GetChild("value").text = priceLabels[status] or number(value)
        ink(box:GetChild("value"), priceColors[status] or C.goldBright)
        show(box:GetChild("coin"), status ~= "sold" and status ~= 'missing')
        show(box:GetChild('sale'),false)
        local price=Theme.layout.nativeNode.price
        box:GetChild('value'):SetAnchoredPosition(price.coin/2,0)
        box:GetChild('value'):SetSizeDelta(price.size[1]-price.coin-Theme.space.s,price.size[2])
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

    local function potionText(id) return require('abyss_potion_text').describe(self.run,id) end

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
        purchase("shopView/card" .. i, 'cards', i, availability.enabled, function()
            if not currentCardShelf(view, flow, shelf) then return false, 'stale_action' end
            return commit("buyCardSlot", i, function(before)
                return "已购买「" .. name .. "」· 支付 " .. number(before.gold - self.run.gold) .. " 金币，加入牌组"
            end)
        end, name, '', offerNotice("card", offer, name), availability.attention)
    end

    local function renderCardSlot(shop, view, offers, i, flow, shelf)
        local offer = offers[(self.page - 1) * SHOP_PAGE + i]
        local box, price = shop:GetChild("card" .. i), shop:GetChild("price" .. i)
        show(box, offer ~= nil) show(price, offer ~= nil)
        if not offer then return end
        local availability = offerState(offer)
        fillCard(box, offer.id, offer.upgraded==true, { dim = offer.sold or availability.poor or offer.unavailable,
            veil = offer.sold, stamp = cardStamp(offer), selected = selection:isSelected('shopView/card' .. i) })
        if offer.unavailable then writeMissingCard(box, offer) end
        fillPrice(price, offer.price, availability.price)
        if offer.sale and not offer.sold and not offer.unavailable then
            local frame=Theme.layout.nativeNode.price.saleValue
            show(price:GetChild('sale'),true)
            price:GetChild('value'):SetAnchoredPosition(frame[1],frame[2])
            price:GetChild('value'):SetSizeDelta(frame[3],frame[4])
        end
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
        shop:GetChild("page").text = ''
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
        purchase("shopView/relic" .. i, 'relics', i, availability.enabled, function()
            return commit("buyRelic", offer.id, function(before)
                return "已购买遗物「" .. name .. "」· 支付 " .. number(before.gold - self.run.gold) .. " 金币"
            end)
        end, name, relicText(offer.id), offerNotice("relic", offer, name), availability.attention)
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
        local definition = find(self.run.data.potions.potions, offer.id)
        purchase('shopView/potion' .. i, 'potions', i, availability.enabled, function()
            return commit('buyPotion', i, function(before)
                return '已购买药水 · 支付 ' .. number(before.gold - self.run.gold) .. ' 金币'
            end)
        end, definition and definition.name or '', potionText(offer.id), offerNotice("potion", offer, nil, full), availability.attention)
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
        selection:begin()
        self.pageCount, self.page, self.relicPage = 1, 1, 1
        renderCards(shop, view, node.cards or {})
        renderRemoval(shop, node)
        renderRelics(shop, node.relics or {})
        renderPotions(shop, node.potions or {})
        selection:paint(0)
        return ''
    end
end

return M
