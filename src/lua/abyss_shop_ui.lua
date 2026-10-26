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
local M = {}

local function find(entries, id)
    for _, item in ipairs(entries or {}) do if item.id == id then return item end end
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
        box:GetChild("value").text = status == 'missing' and '未实装' or status == "sold" and "已售出" or number(value)
        ink(box:GetChild("value"), status == "poor" and C.danger or status == "sold" and C.textMuted or C.goldBright)
        show(box:GetChild("coin"), status ~= "sold" and status ~= 'missing')
    end

    local function potionText(id) return require('abyss_potion_text').describe(self.run,id) end

    local function renderCards(shop, view, offers)
        local flow, shelf = self.run.nodeFlow, self.run.nodeFlow.cards
        for i = 1, SHOP_PAGE do
            local offer = offers[(self.page - 1) * SHOP_PAGE + i]
            local box, price = shop:GetChild("card" .. i), shop:GetChild("price" .. i)
            show(box, offer ~= nil) show(price, offer ~= nil)
            if offer then
                local poor = not offer.sold and self.run.gold < offer.price
                fillCard(box, offer.id, false, { dim = offer.sold or poor or offer.unavailable, veil = offer.sold,
                    stamp = offer.unavailable and '未实装' or offer.sold and "已售出" or offer.sale and '特价 -50%' or nil })
                if offer.unavailable then
                    box:GetChild('name').text=(offer.color=='colorless' and '无色' or '')..(rarityNames[offer.rarity] or '')..'牌 · 缺口'
                    box:GetChild('description').text='此类别与稀有度尚无可售内容'
                    box:GetChild('cost').text=''
                    box:GetChild('type').text=typeNames[offer.type] or ''
                end
                fillPrice(price, offer.price, offer.unavailable and 'missing' or offer.sold and "sold" or poor and "poor" or "ok")
                local name = cardName(offer.id)
                action("shopView/card" .. i, not offer.sold and not poor and not offer.unavailable, function()
                    -- A slot means the current offer, not a reusable quote. Keep
                    -- this render bound to its run, node and transaction shelf;
                    -- an old callback must never purchase Courier's replacement.
                    if not self.visible or self.view~=view or self.renderRun~=self.run or self.renderMap~=self.map
                        or self.run.nodeFlow~=flow or flow.cards~=shelf then return false,'stale_action' end
                    return commit("buyCardSlot", i, function(before)
                        return "已购买「" .. name .. "」· 支付 " .. number(before.gold - self.run.gold) .. " 金币，加入牌组"
                    end)
                end, offer.unavailable and '此商品尚未实装，不可购买' or offer.sold and "「" .. name .. "」已售出" or shortfall(offer.price), poor and not offer.sold and not offer.unavailable)
            end
        end
        pageArrows(shop, "", self.page, self.pageCount)
        action("shopView/previous", self.page > 1, function() return self:setPage(self.page - 1) end)
        action("shopView/next", self.page < self.pageCount, function() return self:setPage(self.page + 1) end)
        shop:GetChild("page").text = self.run.data.originalV4Role
            and '职业牌：2攻击 / 3技能　无色牌：罕见 / 稀有'
            or '职业牌：2攻击 / 2技能 / 1能力　无色牌：罕见 / 稀有'
    end

    local function renderRemoval(shop, node)
        local removal, removalPrice = shop:GetChild("removal"), shop:GetChild("removalPrice")
        local poor = node.removeAvailable and self.run.gold < node.removePrice
        local open = node.removeAvailable and #node.purgeCards > 0 and not poor
        local reason = not node.removeAvailable and "本店删牌服务已使用，每家商店限一次" or
            (#node.purgeCards == 0 and "没有可移除的卡牌" or shortfall(node.removePrice))
        state(removal, open)
        removal:GetChild("description").text = not node.removeAvailable and "本店已使用" or
            (#node.purgeCards == 0 and "没有可移除的卡牌" or ("每家商店限一次\n之后的商店 +" .. self.run.data.rules.shop.removeCardIncrement))
        ink(removal:GetChild("name"), open and C.text or C.textMuted)
        fillPrice(removalPrice, node.removePrice, not node.removeAvailable and "sold" or poor and "poor" or "ok")
        if not node.removeAvailable then removalPrice:GetChild("value").text = "已使用" end
        action("shopView/removal", open, function()
            self.mode, self.picker, self.pickPage, self.selected, self.notice = "picker", "remove", 1, nil, ""
            self:render() return true
        end, reason, poor)
    end

    local function renderRelics(shop, offers)
        local relicPages = 1
        for i = 1, RELIC_PAGE do
            local offer = offers[(self.relicPage - 1) * RELIC_PAGE + i]
            local tile, price = shop:GetChild("relic" .. i), shop:GetChild("relicPrice" .. i)
            show(tile, offer ~= nil) show(price, offer ~= nil)
            if offer then
                local relicPoor = not offer.sold and self.run.gold < offer.price
                state(tile, not offer.sold and not relicPoor and not offer.unavailable)
                picture(tile:GetChild("icon"), Theme.icon.relic[offer.id])
                tile:GetChild("name").text = offer.unavailable and (rarityNames[offer.rarity] or '')..'遗物' or relicName(offer.id) .. (offer.sold and " · 已售出" or "")
                tile:GetChild("description").text = offer.unavailable and '此稀有度暂无可售内容' or relicText(offer.id)
                ink(tile:GetChild("name"), (offer.sold or relicPoor) and C.textMuted or C.text)
                show(tile:GetChild("veil"), offer.sold)
                fillPrice(price, offer.price, offer.unavailable and 'missing' or offer.sold and "sold" or relicPoor and "poor" or "ok")
                local name = relicName(offer.id)
                action("shopView/relic" .. i, not offer.sold and not relicPoor and not offer.unavailable, function()
                    return commit("buyRelic", offer.id, function(before)
                        return "已购买遗物「" .. name .. "」· 支付 " .. number(before.gold - self.run.gold) .. " 金币"
                    end)
                end, offer.unavailable and '此遗物尚未实装，不可购买' or offer.sold and "「" .. name .. "」已售出" or shortfall(offer.price), relicPoor and not offer.sold and not offer.unavailable)
            end
        end
        pageArrows(shop, "relic", self.relicPage, relicPages)
        action("shopView/relicPrevious", self.relicPage > 1, function()
            self.relicPage, self.notice = self.relicPage - 1, "" self:render() return true end)
        action("shopView/relicNext", self.relicPage < relicPages, function()
            self.relicPage, self.notice = self.relicPage + 1, "" self:render() return true end)
    end

    local function renderPotions(shop, offers)
        for i,offer in ipairs(offers) do
            local tile,price=shop:GetChild('potion'..i),shop:GetChild('potionPrice'..i)
            local definition=find(self.run.data.potions.potions,offer.id)
            local full=Run.potionCount(self.run)>=Run.potionCapacity(self.run)
            local potionPoor=self.run.gold<offer.price
            local enabled=not offer.sold and not offer.unavailable and not potionPoor and not full
            state(tile,enabled)
            picture(tile:GetChild('icon'),Theme.icon.potion[offer.id])
            tile:GetChild('name').text=definition and definition.name or (rarityNames[offer.rarity] or '')..'药水'
            tile:GetChild('description').text=offer.unavailable and '此稀有度暂无可售内容' or offer.sold and '已售出' or full and '药水槽已满' or potionText(offer.id)
            show(tile:GetChild('veil'),offer.sold)
            fillPrice(price,offer.price,offer.unavailable and 'missing' or offer.sold and 'sold' or potionPoor and 'poor' or 'ok')
            action('shopView/potion'..i,enabled,function()
                return commit('buyPotion',i,function(before) return '已购买药水 · 支付 '..number(before.gold-self.run.gold)..' 金币' end)
            end,offer.unavailable and '此药水尚未实装，不可购买' or offer.sold and '药水已售出' or full and '药水槽已满' or shortfall(offer.price),potionPoor and not full and not offer.sold and not offer.unavailable)
        end
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
