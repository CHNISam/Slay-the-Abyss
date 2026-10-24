-- Native non-combat node adapter. Nodes owns every gameplay transaction; this module only
-- reads Nodes.view, draws the approved PR19 node screens and sends commands.
-- root is nodePanel from nodeLayout(); the host may replace self.run/self.map.
-- onChange(ok, reason, self) refreshes the host after an attempted command.
-- options.color/options.imageSource are the platform Color constructor and picture source;
-- without them states are still shown through visibility layers.
-- options.cursorEvents may inject Enum.CursorEventType; the native host defaults
-- to that documented global. Missing pointer events retain ordinary click input.
local Nodes = require("abyss_nodes")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local Narrative = require("abyss_narrative")
local Merchant = require("abyss_merchant")
local M = {}
local number = require("abyss_numbers").integer
local C = Theme.color
local kinds = { camp = "营地", shop = "商店", event = "未知事件", treasure = "宝箱" }
local typeNames = { attack = "攻击", skill = "技能", power = "能力", status = "状态", curse = "诅咒" }
local rarityNames = {common='普通',uncommon='罕见',rare='稀有',shop='商店专属'}
local reasons = {
    insufficient_gold = "金币不足", item_unavailable = "商品已售出或不可购买",
    shop_content_unavailable = "商店补货状态异常，本次未付款，请离店或重新开始",
    removal_unavailable = "本店删牌服务已使用",
    invalid_card = "这张卡牌已不在牌组中", last_card = "必须保留至少一张卡牌",
    card_not_upgradeable = "这张卡牌无法继续升级", potion_slots_full = "药水槽已满", potions_blocked = "遗物效果禁止获得药水",
    camp_choice_made = "本次营地已选择升级或休息", no_pending_node = "此节点已经完成",
    wrong_node_type = "当前节点不支持此操作", relic_already_owned = "已持有这件遗物",
    invalid_event_choice = "此事件选项不可用", event_unavailable = "当前没有满足条件的已实现事件", stale_action = "界面已变化，请重新选择",
    event_content_unavailable = "事件所需卡牌数据不可用", invalid_deck_uid = "卡牌编号异常，未领取奖励",
    panel_hidden = "节点界面未打开", unavailable_action = "此选项当前不可用",
}
-- Presentation copy only; every option and outcome below comes from Nodes and data/rules.json.
local events = {
    purifier = { name = "净化神龛", body = Narrative.eventCopy.purifier.intro:gsub("\n\n", "\n"),
        leave = "你向神龛行了一礼，转身继续赶路。" },
    cleric = { name = "圣职者", body = Narrative.eventCopy.cleric.intro:gsub("\n\n", "\n"),
        leave = "你婉拒了圣职者的服务，继续赶路。" },
    goop = {name="黏液金币",body="湿滑的泥潭中露出几枚金币。要取回它们，就得忍受黏液的侵蚀；绕道离开也会丢失部分盘缠。",leave="你收好剩下的盘缠，绕过泥潭。"},
    upgrade_shrine = {name="升级神龛",body="一道微光停在石龛上。你可以在此精进一式招数。",leave="你将这次机会留在身后。"},
    golden_wing = {name="金翼雕像",body="残破的金翼守着山道。献出生命可以舍弃一式招数；足够强的攻击也能击碎外壳，取出金币。",leave="你绕过了雕像。"},
    shining_light = {name="闪耀之光",body="石隙间涌出耀眼的光。靠近它会灼伤身体，也会让尚未精进的招数获得提升。",leave="你避开了光芒。"},
    golden_shrine = {name="鎏金石龛",body="石龛中存着一份馈赠。你可以收下少量金币，也可以取走更多，但未散的执念会随你同行。",leave="你没有取走石龛中的金币。"},
}
local triggers = { combat_start = "战斗开始时，", combat_end = "战斗结束时，" }
local layout = Theme.layout.nativeNode
local SHOP_PAGE, RELIC_PAGE, PICK_PAGE = #layout.shop.columns, #layout.shop.relics.columns, #layout.picker.columns
local OPTIONS = #layout.event.options.rows

local function find(entries, id, key)
    for _, item in ipairs(entries or {}) do if item[key or "id"] == id then return item end end
end
local function snapshotDeck(deck)
    local result = {}
    for _, card in ipairs(deck) do result[#result + 1] = { uid = card.uid, cardId = card.cardId, upgraded = card.upgraded } end
    return result
end
local function iconId(entry) return type(entry) == "table" and entry.id or entry end

function M.new(root, run, map, presentation, clickEvent, onChange, options)
    options = options or {}
    local self = { root = root, run = run, map = map, presentation = presentation or {},
        visible = true, page = 1, relicPage = 1, mode = "main", actions = {}, notice = "" }
    local function child(name) return assert(root:GetChild(name), "missing node UI control " .. name) end
    local function path(key)
        local control = root
        for part in key:gmatch("[^/]+") do control = assert(control:GetChild(part), "missing node UI control " .. key) end
        return control
    end
    local function show(control, value) control:SetVisible(value ~= nil and value ~= false) end
    local function tint(control, colour)
        if options.color then control.imageColor = options.color(colour.r, colour.g, colour.b, colour.a) end
    end
    local function ink(control, colour)
        if options.color then control.fontColor = options.color(colour.r, colour.g, colour.b, colour.a) end
    end
    local function picture(control, id)
        if options.imageSource and id then control:SetImage(options.imageSource, iconId(id)) end
    end
    local merchant = Merchant.new(child("merchant"), { color = options.color, sound = options.sound })
    child("merchant"):GetChild("talk"):GetChild("hit"):AddCursorEventListener(clickEvent, function() return merchant:tap() end)
    self.merchant = merchant
    local buttonLooks, buttonHover, buttonPress = {}, nil, nil
    local function paintButton(box)
        local look = buttonLooks[box]
        if not look then return end -- a never-shown view can still receive a late native exit
        local enabled = look.enabled and not look.selected
        local pressed = enabled and buttonPress and buttonPress.box == box
        local hover = enabled and buttonHover == box and not pressed
        box:GetChild("normal"):SetVisible(look.enabled and not look.selected and not pressed and not hover)
        box:GetChild("hover"):SetVisible(hover == true)
        box:GetChild("pressed"):SetVisible(pressed == true)
        box:GetChild("disabled"):SetVisible(not look.enabled)
        box:GetChild("selected"):SetVisible(look.selected == true)
        tint(box:GetChild("hover"), look.primary and C.goldBright or C.buttonHover)
        tint(box:GetChild("pressed"), C.goldDim)
        tint(box:GetChild("border"), look.selected and C.goldBright or not look.enabled and C.line
            or (pressed or hover or look.primary) and C.goldBright or C.gold)
        local label = box:GetChild("label")
        if label then ink(label, not look.enabled and C.textMuted or pressed and C.buttonPressedText
            or look.primary and C.textOnLight or C.goldBright) end
        local scale = pressed and layout.buttonStates.pressedScale or layout.buttonStates.normalScale
        box:SetLocalScale(scale, scale, 1)
    end
    local buttonInputs = {}
    -- One horizontal row drag at a time; swallow eats the Click that ends a swipe.
    local swipe, swallow = nil, nil
    local function resetButtons()
        buttonHover, buttonPress, swipe = nil, nil, nil
        for _, input in pairs(buttonInputs) do input.active, input.released = {}, nil end
        for box in pairs(buttonLooks) do paintButton(box) end
    end
    -- Selected/disabled presentation always takes priority over pointer feedback.
    local function state(box, enabled, selected, primary)
        buttonLooks[box] = {enabled=enabled == true, selected=selected == true, primary=primary == true}
        paintButton(box)
    end
    local function card(id) return find(self.run.data.cards.cards, id) end
    local function cardName(id, upgraded)
        local display, definition = self.presentation[id], card(id)
        return (display and display.name or (definition and definition.name) or id) .. (upgraded and "+" or "")
    end
    local function relicName(id)
        local definition = find(self.run.data.relics.relics, id)
        return definition and definition.name or id
    end
    local function potionText(id)
        local definition=find(self.run.data.potions.potions,id)
        local parts={}
        for _,effect in ipairs(definition and definition.effects or {}) do
            local value=number(effect.value)
            if effect.op=='damage' then parts[#parts+1]='造成'..value..'点伤害'
            elseif effect.op=='block' then parts[#parts+1]='获得'..value..'点格挡'
            elseif effect.op=='energy' then parts[#parts+1]='获得'..value..'点能量'
            elseif effect.op=='draw' then parts[#parts+1]='抽'..value..'张牌'
            elseif effect.op=='gainStatus' or effect.op=='applyStatus' then
                local status=find(self.run.data.statuses.statuses,effect.status)
                parts[#parts+1]=(effect.op=='applyStatus' and '施加' or '获得')..value..'层'..(status and status.name or effect.status)
            end
        end
        return table.concat(parts,'，')
    end
    -- Relic data has no prose; describe its sourced trigger and effects.
    local function relicText(id)
        if id=='membership_card' then return '所有商店商品半价。' end
        if id=='courier' then return '商店商品八折，购买后补货。' end
        if id=='smiling_mask' then return '商店删牌服务固定为50金币。' end
        local definition = find(self.run.data.relics.relics, id)
        if not definition then return "" end
        if definition.description then return definition.description end
        local parts = {}
        for _, effect in ipairs(definition.effects or {}) do
            local value = number(effect.value)
            if effect.op == "heal" then parts[#parts + 1] = "回复 " .. value .. " 点生命"
            elseif effect.op == "block" then parts[#parts + 1] = "获得 " .. value .. " 点格挡"
            elseif effect.op == "draw" then parts[#parts + 1] = "抽 " .. value .. " 张牌"
            elseif effect.op == "energy" then parts[#parts + 1] = "获得 " .. value .. " 点能量"
            elseif effect.op == "gainStatus" then
                local status = find(self.run.data.statuses.statuses, effect.status)
                parts[#parts + 1] = "获得 " .. value .. " 层" .. (status and status.name or effect.status)
            end
        end
        if #parts == 0 then return "" end
        return (triggers[definition.trigger] or "") .. table.concat(parts, "，") .. "。"
    end
    -- Approved card face. look: dim (greyed but readable), veil (sold/removed), selected (glow),
    -- stamp (overlay word), changed (cost highlight).
    local function fillCard(box, id, upgraded, look)
        look = look or {}
        local definition, display = card(id) or {}, self.presentation[id] or {}
        local kind = Theme.icon.cardArt[definition.type] and definition.type or "status"
        box:GetChild("name").text = cardName(id, upgraded)
        ink(box:GetChild("name"), look.dim and C.textMuted or upgraded and C.positive or C.text)
        box:GetChild("type").text = typeNames[definition.type] or ""
        local text = upgraded and display.upgradeText or display.text
        box:GetChild("description").text = type(text) == "string" and text or ""
        ink(box:GetChild("description"), look.dim and C.textDim or C.text)
        -- Presentation costs can be strings; format the numeric rule value.
        local cost = definition.cost
        if upgraded and definition.upgrade and definition.upgrade.cost ~= nil then cost = definition.upgrade.cost end
        box:GetChild("cost").text = definition.cost == -2 and "" or definition.costMode == "all_energy" and "X" or cost ~= nil and number(cost) or ""
        tint(box:GetChild("costDisc"), look.dim and C.energyEmpty or look.changed and C.positive or C.energy)
        for art in pairs(Theme.icon.cardArt) do box:GetChild("art_" .. art):SetVisible(art == kind) end
        tint(box:GetChild("artPlate"), look.dim and C.panelSunken or C.cardType[kind] or C.panelRaised)
        tint(box:GetChild("border"), look.selected and C.goldBright or look.dim and C.line or C.rarity[definition.rarity] or C.line)
        show(box:GetChild("glow"), look.selected)
        show(box:GetChild("veil"), look.veil)
        show(box:GetChild("stampPlate"), look.stamp ~= nil)
        show(box:GetChild("stamp"), look.stamp ~= nil)
        box:GetChild("stamp").text = look.stamp or ""
    end
    -- price status: "ok" gold, "poor" red (cannot afford), "sold" muted without a coin.
    local function fillPrice(box, value, status)
        box:SetVisible(true)
        box:GetChild("value").text = status == 'missing' and '未实装' or status == "sold" and "已售出" or number(value)
        ink(box:GetChild("value"), status == "poor" and C.danger or status == "sold" and C.textMuted or C.goldBright)
        show(box:GetChild("coin"), status ~= "sold" and status ~= 'missing')
    end
    -- poor marks an offer refused only for lack of gold, so the merchant can answer it.
    local function action(key, enabled, handler, reason, poor)
        self.actions[key] = { enabled = enabled == true, handler = handler, reason = reason, poor = poor == true }
        return enabled == true
    end
    local function shortfall(price) return "金币不足：需要 " .. number(price) .. "，还差 " .. number(price - self.run.gold) end

    local commit -- forward declaration; renders and notifies
    local function pageArrows(view, prefix, page, count)
        local previous = view:GetChild(prefix == "" and "previous" or prefix .. "Previous")
        local next = view:GetChild(prefix == "" and "next" or prefix .. "Next")
        show(previous, count > 1) show(next, count > 1)
        state(previous, page > 1) state(next, page < count)
        -- Paging is secondary to the goods: keep the arrows' frames quiet.
        if page > 1 then tint(previous:GetChild("border"), C.goldDim) end
        if page < count then tint(next:GetChild("border"), C.goldDim) end
    end

    local function renderTopBar(node)
        child("title").text = node and ("第 " .. node.floor .. " 层 · " ..
            (node.roomKind == "boss_treasure" and "首领宝箱" or kinds[node.type] or "节点")) or "路线"
        child("hp").text = number(self.run.hp) .. "/" .. number(self.run.maxHp)
        child("gold").text = number(self.run.gold)
        child("deck").text = tostring(#self.run.deck)
        child("relics").text = "遗物 " .. #self.run.relics
        child("potions").text = "药水 " .. Run.potionCount(self.run) .. "/" .. self.run.data.rules.player.potionSlots
    end

    local function renderShop(view, node)
        local shop = child("shopView")
        local offers, relics = node.cards or {}, node.relics or {}
        local flow, shelf = self.run.nodeFlow, self.run.nodeFlow.cards
        self.pageCount, self.page, self.relicPage = 1, 1, 1
        local relicPages = 1
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
        shop:GetChild("page").text = '职业牌：2攻击 / 2技能 / 1能力　无色牌：罕见 / 稀有'

        local removal, removalPrice = shop:GetChild("removal"), shop:GetChild("removalPrice")
        local poor = node.removeAvailable and self.run.gold < node.removePrice
        local open = node.removeAvailable and #self.run.deck > 1 and not poor
        local reason = not node.removeAvailable and "本店删牌服务已使用，每家商店限一次" or
            (#self.run.deck <= 1 and "牌组仅剩一张，必须保留至少一张卡牌" or shortfall(node.removePrice))
        state(removal, open)
        removal:GetChild("description").text = not node.removeAvailable and "本店已使用" or
            (#self.run.deck <= 1 and "牌组仅剩一张" or ("每家商店限一次\n之后的商店 +" .. self.run.data.rules.shop.removeCardIncrement))
        ink(removal:GetChild("name"), open and C.text or C.textMuted)
        fillPrice(removalPrice, node.removePrice, not node.removeAvailable and "sold" or poor and "poor" or "ok")
        if not node.removeAvailable then removalPrice:GetChild("value").text = "已使用" end
        action("shopView/removal", open, function()
            self.mode, self.picker, self.pickPage, self.selected, self.notice = "picker", "remove", 1, nil, ""
            self:render() return true
        end, reason, poor)

        for i = 1, RELIC_PAGE do
            local offer = relics[(self.relicPage - 1) * RELIC_PAGE + i]
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
        for i,offer in ipairs(node.potions or {}) do
            local tile,price=shop:GetChild('potion'..i),shop:GetChild('potionPrice'..i)
            local definition=find(self.run.data.potions.potions,offer.id)
            local full=Run.potionCount(self.run)>=self.run.data.rules.player.potionSlots
            local poor=self.run.gold<offer.price
            local enabled=not offer.sold and not offer.unavailable and not poor and not full
            state(tile,enabled)
            picture(tile:GetChild('icon'),Theme.icon.potion[offer.id])
            tile:GetChild('name').text=definition and definition.name or (rarityNames[offer.rarity] or '')..'药水'
            tile:GetChild('description').text=offer.unavailable and '此稀有度暂无可售内容' or offer.sold and '已售出' or full and '药水槽已满' or potionText(offer.id)
            show(tile:GetChild('veil'),offer.sold)
            fillPrice(price,offer.price,offer.unavailable and 'missing' or offer.sold and 'sold' or poor and 'poor' or 'ok')
            action('shopView/potion'..i,enabled,function()
                return commit('buyPotion',i,function(before) return '已购买药水 · 支付 '..number(before.gold-self.run.gold)..' 金币' end)
            end,offer.unavailable and '此药水尚未实装，不可购买' or offer.sold and '药水已售出' or full and '药水槽已满' or shortfall(offer.price),poor and not full and not offer.sold and not offer.unavailable)
        end
        return "点选商品购买 · 未实装槽位不可购买"
    end

    local function renderCamp(view, node, result)
        local camp = child("campView")
        local rest, forge = camp:GetChild("rest"), camp:GetChild("forge")
        if result then
            state(rest, false, result.choice == "rest") state(forge, false, result.choice == "upgrade")
            rest:GetChild("description").text = result.choice == "rest" and
                ("已回复 " .. number(result.healed) .. " 点生命\n生命 " .. number(self.run.hp) .. "/" .. number(self.run.maxHp)) or "未选择"
            forge:GetChild("description").text = result.choice == "upgrade" and "已升级" or "未选择"
            return
        end
        local forgeable = #node.upgradeCards > 0
        -- Approved: resting at full health is disabled, unless it is the only way out of the camp.
        local restOpen = node.heal > 0 or not forgeable
        state(rest, restOpen) state(forge, forgeable)
        rest:GetChild("description").text = node.heal > 0 and
            ("回复 " .. number(node.heal) .. " 点生命\n生命 " .. number(self.run.hp) .. " → " .. number(self.run.hp + node.heal)) or
            (forgeable and "生命已满" or "生命已满 · 休息后继续前进")
        forge:GetChild("description").text = forgeable and
            ("升级一张卡牌\n可升级 " .. #node.upgradeCards .. " 张") or "没有可升级的卡牌"
        action("campView/rest", restOpen, function()
            return commit("rest", nil, function(before)
                local healed = self.run.hp - before.hp
                return "休息完成 · 回复 " .. number(healed) .. " 点生命", { choice = "rest", healed = healed }
            end)
        end, "生命已满，休息不会回复；可以选择锻造")
        action("campView/forge", forgeable, function()
            self.mode, self.picker, self.pickPage, self.selected, self.notice = "picker", "upgrade", 1, nil, ""
            self:render() return true
        end, "牌组中没有可升级的卡牌")
        return "篝火旁，旅行者稍作停留 · 休息或锻造，只能选一项"
    end

    local function renderPicker(view, node, result)
        local picker = child("pickerView")
        local before, after, target = picker:GetChild("before"), picker:GetChild("after"), picker:GetChild("target")
        local upgrade = self.picker == "upgrade"
        local rows = upgrade and self.upgradeRows or self.removeRows
        local selected = result and result.card or self.selected and find(rows, self.selected, "uid")
        local pageCount = math.max(1, math.ceil(#rows / PICK_PAGE))
        self.pickPage = math.max(1, math.min(self.pickPage or 1, pageCount))
        self.pageCount = pageCount
        for i = 1, PICK_PAGE do
            local instance = not result and rows[(self.pickPage - 1) * PICK_PAGE + i]
            local box = picker:GetChild("card" .. i)
            show(box, instance)
            if instance then
                local owned = find(self.run.deck, instance.uid, "uid")
                local available = owned ~= nil and (not upgrade or find(node.upgradeCards, instance.uid, "uid") ~= nil)
                local stamp = not owned and "已移除" or (upgrade and owned.upgraded and "已升级") or nil
                fillCard(box, instance.cardId, owned and owned.upgraded or instance.upgraded,
                    { dim = not available, veil = stamp ~= nil, stamp = stamp, selected = self.selected == instance.uid })
                local uid = instance.uid
                action("pickerView/card" .. i, available, function()
                    self.selected, self.notice = uid, "" self:render() return true
                end, stamp and ("这张卡牌" .. stamp) or "这张卡牌无法升级")
            end
        end
        pageArrows(picker, "", self.pickPage, result and 1 or pageCount)
        action("pickerView/previous", self.pickPage > 1, function()
            self.pickPage, self.notice = self.pickPage - 1, "" self:render() return true end)
        action("pickerView/next", self.pickPage < pageCount, function()
            self.pickPage, self.notice = self.pickPage + 1, "" self:render() return true end)
        picker:GetChild("page").text = not result and pageCount > 1 and ("第 " .. self.pickPage .. "/" .. pageCount .. " 页 · 共 " .. #rows .. " 张"
            .. (self.swipeEnabled and " · 左右拖动翻页" or "")) or ""
        show(before, upgrade and selected) show(after, upgrade and selected)
        show(picker:GetChild("arrow"), upgrade and selected) show(target, not upgrade and selected)
        picker:GetChild("empty").text = selected and "" or (upgrade and "点选上方卡牌，查看升级前后对比" or "点选上方要移除的卡牌")
        picker:GetChild("label").text, picker:GetChild("hint").text = "", ""
        if selected and upgrade then
            local display = self.presentation[selected.cardId] or {}
            local changed = display.cost ~= nil and display.upgradeCost ~= nil and display.cost ~= display.upgradeCost
            fillCard(before, selected.cardId, false)
            fillCard(after, selected.cardId, true, { changed = changed })
            picker:GetChild("label").text = result and "已升级" or "升级预览"
            picker:GetChild("hint").text = changed and ("费用 " .. display.cost .. " → " .. display.upgradeCost) or "效果增强"
        elseif selected then
            fillCard(target, selected.cardId, selected.upgraded, { stamp = result and "已移除" or nil, dim = result ~= nil, veil = result ~= nil })
            picker:GetChild("label").text = result and "已移除" or "将从牌组移除"
            picker:GetChild("hint").text = "牌组 " .. (#self.run.deck + (result and 1 or 0)) .. " → " ..
                (#self.run.deck - (result and 0 or 1)) .. " 张"
        end
        if upgrade then return "选择一张卡牌升级 · 剩余 " .. (result and 0 or node.upgradesLeft) .. " 次" end
        if self.picker == "remove" then return "选择要移除的卡牌 · 本店删牌服务限一次" end
        return "选择要净化的卡牌"
    end

    local function renderEvent(view, node, result)
        local event = child("eventView")
        local id = node.event and node.event.id or (result and result.eventId)
        local copy = events[id] or { name = kinds.event, body = "", leave = "你离开了。" }
        event:GetChild("name").text = copy.name
        local mode=self.run.data.rules.events.poolMode
        event:GetChild("caption").text = mode=='restricted-seven' and "未知事件 · 受限事件池（7种）"
            or mode=='restricted-six' and "未知事件 · 受限事件池（6种）" or kinds.event
        event:GetChild("body").text = result and result.text or copy.body
        local rows = {}
        if not result then
            local info, gold, deckOk = node.event, self.run.gold, #self.run.deck > 1
            local function need(cost) return "金币不足（需要 " .. cost .. "，现有 " .. gold .. "）" end
            local function purify(cost)
                return function()
                    self.mode, self.picker, self.pickPage, self.selected, self.notice = "picker", "purify", 1, nil, ""
                    self:render() return true
                end
            end
            if id ~= 'cleric' and id ~= 'purifier' then
                for _,option in ipairs(info.options) do
                    local selected=option
                    rows[#rows+1]={title='［'..selected.title..'］',description=selected.description..
                        (not selected.enabled and '（当前条件不足）' or ''),enabled=selected.enabled,handler=function()
                        if selected.picker then
                            self.mode,self.picker,self.pickPage,self.selected,self.notice='picker',
                                selected.picker=='event_upgrade' and 'upgrade' or selected.picker,1,nil,''
                            self:render();return true
                        end
                        return commit('chooseEvent',selected.choice,function(before)
                            local outcome=self.run.nodeFlow.event
                            -- 只列出实际变化的资源，未变化的生命/金币不显示
                            local lines,changes={},{}
                            if self.run.hp~=before.hp then changes[#changes+1]='生命 '..number(before.hp)..' → '..number(self.run.hp) end
                            if self.run.gold~=before.gold then changes[#changes+1]='金币 '..number(before.gold)..' → '..number(self.run.gold) end
                            if #changes>0 then lines[1]=table.concat(changes,'；') end
                            if outcome.upgradedUids and #outcome.upgradedUids>0 then
                                local names={}
                                for _,uid in ipairs(outcome.upgradedUids) do
                                    local card=find(self.run.deck,uid,'uid');names[#names+1]=cardName(card.cardId,true)
                                end
                                lines[#lines+1]='已升级：'..table.concat(names,'、')
                            end
                            if outcome.obtainedCardUid then
                                local obtained=find(self.run.deck,outcome.obtainedCardUid,'uid')
                                lines[#lines+1]='已获得诅咒：'..cardName(obtained.cardId,false)
                            end
                            local text=#lines>0 and table.concat(lines,'\n') or '什么也没有发生。'
                            return text,{text=text}
                        end)
                    end}
                end
            elseif id == "cleric" then
                local healOk = gold >= info.healCost
                rows[1] = { title = "［治疗］", enabled = healOk, handler = function()
                        return commit("chooseEvent", "heal", function(before)
                            local healed = self.run.hp - before.hp
                            return "治疗完成 · 回复 " .. number(healed) .. " 点生命", { text = "圣职者的祝祷落在你身上，伤口渐渐愈合。\n支付 " ..
                                number(before.gold - self.run.gold) .. " 金币，回复 " .. number(healed) .. " 点生命（生命 " .. number(before.hp) .. " → " .. number(self.run.hp) .. "）。" }
                        end)
                    end,
                    description = not healOk and need(info.healCost) or (info.heal > 0 and
                        ("支付 " .. number(info.healCost) .. " 金币，回复 " .. number(info.heal) .. " 点生命（生命 " .. number(self.run.hp) .. " → " .. number(self.run.hp + info.heal) .. "）")
                        or ("支付 " .. info.healCost .. " 金币；生命已满，不会回复")) }
                local purifyOk = gold >= info.removeCost and deckOk
                rows[2] = { title = "［净化］", enabled = purifyOk, handler = purify(info.removeCost),
                    description = gold < info.removeCost and need(info.removeCost) or
                        (deckOk and ("支付 " .. info.removeCost .. " 金币，从牌组移除一张卡牌") or "牌组仅剩一张，无法移除") }
            else
                rows[1] = { title = "［祈祷］", enabled = deckOk, handler = purify(info.removeCost),
                    description = deckOk and (info.removeCost > 0 and ("支付 " .. info.removeCost .. " 金币，从牌组移除一张卡牌")
                        or "免费从牌组移除一张卡牌") or "牌组仅剩一张，无法移除" }
            end
            if id=='cleric' or id=='purifier' then rows[#rows + 1] = { title = "［离开］", enabled = true, description = "什么也不会发生。", handler = function()
                return commit("chooseEvent", "leave", function() return "已离开" .. copy.name, { text = copy.leave } end)
            end } end
        end
        for i = 1, OPTIONS do
            local row, box = rows[i], event:GetChild("option" .. i)
            show(box, row)
            if row then
                state(box, row.enabled)
                box:GetChild("title").text = row.title
                box:GetChild("description").text = row.description
                ink(box:GetChild("title"), row.enabled and C.goldBright or C.textMuted)
                ink(box:GetChild("description"), row.enabled and C.textDim or C.textMuted)
                action("eventView/option" .. i, row.enabled, row.handler, row.description)
            end
        end
        return result and copy.name or (copy.name .. " · 选择一项，或直接离开")
    end

    local function renderTreasure(view, node)
        local chest = child("treasureView")
        local reward = node.reward
        local boss = node.roomKind == "boss_treasure"
        local choices = boss and reward.relics or nil
        self.treasureChoice = math.min(self.treasureChoice or 1, choices and #choices or 1)
        local relicId = boss and choices[self.treasureChoice] or reward.relicId
        local opened = self.opened == true
        show(chest:GetChild("closed"), not opened) show(chest:GetChild("open"), opened)
        show(chest:GetChild("hint"), not opened)
        tint(chest:GetChild("glow"), opened and C.gold or C.goldDim)
        local row, take = chest:GetChild("reward"), chest:GetChild("take")
        local hasReward = not boss or #choices > 0
        show(row, opened and hasReward) show(take, opened and hasReward)
        local name = relicId and relicName(relicId) or (not boss and (number(reward.gold) .. " 金币") or "")
        for _, key in ipairs({"previous", "next", "page", "bossDescription"}) do show(chest:GetChild(key), opened and boss) end
        take:GetChild("label").text = boss and "领取这件遗物" or "拿取并离开"
        if opened and hasReward then
            state(row, true) state(take, true, false, true)
            picture(row:GetChild("icon"), relicId and (Theme.icon.relic[relicId] or Theme.icon.node.treasure) or Theme.icon.gold)
            row:GetChild("name").text = relicId and ("遗物 · " .. name) or name
            row:GetChild("description").text = boss and "使用左右按钮查看，领取其中一件" or relicId and relicText(relicId) or "遗物已全部持有，改为金币"
            if boss then
                chest:GetChild("page").text = "首领遗物 · " .. self.treasureChoice .. " / " .. #choices .. " · 选择一件"
                chest:GetChild("bossDescription").text = relicText(relicId)
                state(chest:GetChild("previous"), self.treasureChoice > 1)
                state(chest:GetChild("next"), self.treasureChoice < #choices)
            end
        end
        if boss and not hasReward then
            show(chest:GetChild("previous"), false) show(chest:GetChild("next"), false)
            chest:GetChild("page").text = "没有可领取的首领遗物"
            chest:GetChild("bossDescription").text = "可用遗物已持有或不满足领取条件，请跳过奖励。"
        end
        for _, step in ipairs({{key="previous", delta=-1}, {key="next", delta=1}}) do
            local choice = self.treasureChoice + step.delta
            action("treasureView/" .. step.key, opened and boss and choice >= 1 and choice <= #choices, function()
                self.treasureChoice, self.notice = choice, "" self:render() return true
            end)
        end
        action("treasureView/chest", not opened, function()
            self.opened, self.notice = true, "" self:render() return true
        end)
        action("treasureView/take", opened and hasReward, function()
            return commit(boss and "claimBossTreasure" or "claimTreasure", boss and self.treasureChoice or nil,
                function() return "已获得" .. (relicId and ("遗物「" .. name .. "」") or name) end)
        end)
        return opened and (boss and "选择一件首领遗物，或跳过奖励后完成本局" or
            ("宝箱已打开 · 获得" .. (relicId and "遗物" or "金币"))) or "宝箱就在眼前"
    end

    function self:holding()
        local result = self.result
        return result ~= nil and result.run == self.run and result.map == self.map and
            self.run.nodeFlow ~= nil and self.run.nodeFlow.id == result.nodeId and self.run.nodeFlow.complete == true
    end

    function self:render()
        resetButtons()
        local view = Nodes.view(self.run, self.map)
        local node = view.node
        if self.renderRun ~= self.run or self.renderMap ~= self.map or self.nodeId ~= (node and node.id) then
            self.page, self.relicPage, self.pickPage, self.mode, self.picker = 1, 1, 1, "main", nil
            self.selected, self.opened, self.notice, self.result, self.treasureChoice = nil, false, "", nil, 1
            self.upgradeRows = node and node.upgradeCards or {}
            self.removeRows = snapshotDeck(self.run.deck)
        end
        self.renderRun, self.renderMap, self.nodeId = self.run, self.map, node and node.id
        self.view, self.actions = view, {}
        local result = self:holding() and self.result or nil
        local active = node and kinds[node.type] and not node.complete and view.phase == "node"
        renderTopBar(node)
        local screen, hint = nil, node and "请完成当前节点。" or "请在路线中选择下一个节点。"
        if node and node.complete then hint = "本节点已完成，可以返回路线。" end
        if active and self.mode == "picker" then screen = "pickerView"
        elseif active then screen = node.type .. "View"
        elseif result then screen = result.view end
        if active and node.type == "camp" and node.campChoice == "upgrade" then self.mode, self.picker, screen = "picker", "upgrade", "pickerView" end
        for _, name in ipairs({ "shopView", "campView", "pickerView", "eventView", "treasureView" }) do show(child(name), name == screen) end
        if screen == "shopView" then hint = renderShop(view, node)
        elseif screen == "campView" then hint = renderCamp(view, node, result)
        elseif screen == "pickerView" then hint = renderPicker(view, node, result)
        elseif screen == "eventView" then hint = renderEvent(view, node, result)
        elseif screen == "treasureView" then hint = renderTreasure(view, node) end
        -- The merchant speaks in his own dialogue box; the notice keeps only shop facts.
        if node and node.type == "shop" and (self.merchantNode ~= node.id or self.merchantRun ~= self.run) then
            self.merchantNode, self.merchantRun = node.id, self.run
            merchant:enter(self.run)
        end
        merchant:setVisible(node ~= nil and node.type == "shop" and self.mode == "main" and (active or node.complete))
        child("notice").text = self.notice ~= "" and self.notice or hint
        ink(child("notice"), self.failed and self.notice ~= "" and C.danger or C.text)

        local back, confirm = child("back"), child("confirm")
        local backLabel, confirmLabel, confirmOk, confirmFn
        if result then
            confirmLabel, confirmOk = "继续", true
            confirmFn = function()
                self.result, self.notice = nil, ""
                self:render() if onChange then onChange(true, "continue", self) end
                return true, "continue"
            end
        elseif node and node.complete then
            confirmLabel, confirmOk = "返回路线", true
            confirmFn = function() if onChange then onChange(true, "complete", self) end return true, "complete" end
        elseif screen == "shopView" then
            confirmLabel, confirmOk = "离开商店", true
            confirmFn = function()
                -- The farewell stays on screen like a camp/event result, so it is actually seen.
                return commit("leaveShop", nil, function() return "", {} end)
            end
        elseif screen == "pickerView" then
            local selected = self.selected
            if self.picker == "upgrade" then
                confirmLabel = "确认升级"
                if not node.campChoice then backLabel = "返回" end
            elseif self.picker == "remove" then
                confirmLabel, backLabel = "删除 · " .. node.removePrice .. " 金币", "返回"
            else
                confirmLabel, backLabel = node.event.removeCost > 0 and ("净化 · " .. node.event.removeCost .. " 金币") or "祈祷 · 移除", "返回"
            end
            confirmOk = selected ~= nil
            confirmFn = function()
                local instance = find(self.upgradeRows, selected, "uid") or find(self.removeRows, selected, "uid")
                local name = instance and cardName(instance.cardId, instance.upgraded) or ""
                local command = self.picker == "upgrade" and (node.type=='event' and 'upgradeEvent' or "upgrade")
                    or self.picker=='wing_purge' and 'purgeWing' or self.picker == "remove" and "removeCard" or "purifyEvent"
                return commit(command, selected, function(before)
                    if command == "upgrade" or command=='upgradeEvent' then
                        local base = cardName(instance.cardId)
                        local text="已升级「" .. base .. "」→「" .. base .. "+」"
                        return text, { choice = "upgrade", card = instance, text=text }
                    end
                    local paid = before.gold - self.run.gold
                    local text = "已移除「" .. name .. "」" .. (paid > 0 and (" · 支付 " .. number(paid) .. " 金币") or "")
                    return text, { card = instance, text = "「" .. name .. "」已从牌组中移除" ..
                        (paid > 0 and ("，支付 " .. number(paid) .. " 金币。") or "。") .. "\n牌组现有 " .. #self.run.deck .. " 张。" }
                end)
            end
        end
        show(back, backLabel ~= nil) show(confirm, confirmLabel ~= nil)
        if backLabel then back:GetChild("label").text = backLabel state(back, true) end
        if confirmLabel then confirm:GetChild("label").text = confirmLabel state(confirm, confirmOk, false, true) end
        action("back", backLabel ~= nil, function()
            self.mode, self.picker, self.selected, self.notice = "main", nil, nil, "" self:render() return true
        end)
        if active and node.roomKind == "boss_treasure" and self.opened then
            show(back, true) back:GetChild("label").text = "跳过遗物" state(back, true)
            action("back", true, function()
                return commit("claimBossTreasure", 0, function() return "已跳过首领遗物" end)
            end)
        end
        action("confirm", confirmOk, confirmFn, screen == "pickerView" and "请先在上方选择一张卡牌" or nil)
        self.failed = false
    end

    -- Actual canvas pixels; swipe distances are converted back to design units.
    function self:resize(width, height)
        resetButtons()
        self.canvasWidth, self.canvasHeight = width, height
    end
    function self:update(dt)
        if self.visible then merchant:update(dt) end
    end
    function self:setVisible(value)
        assert(type(value) == "boolean", "node visibility must be boolean")
        if not value then resetButtons() end
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
    -- describe(before) returns the success notice and, for camp/event, the result screen to hold.
    commit = function(command, argument, describe)
        local node = self.view.node
        local before = { hp = self.run.hp, gold = self.run.gold }
        self.busy = true
        local called, accepted, reason = pcall(Nodes[command], self.run, argument)
        self.busy = false
        if not called then error(accepted) end
        if accepted then
            local notice, hold = describe(before)
            if command == "buyCardSlot" or command == "buyRelic" or command == "buyPotion" or command == "removeCard" then
                merchant:react("buy")
            elseif command == "leaveShop" then merchant:react("leave") end
            self.notice, self.failed = notice, false
            if command == "removeCard" then self.mode, self.picker, self.selected = "main", nil, nil end
            local flow = self.run.nodeFlow
            if hold and flow and flow.complete and (node.type == "camp" or node.type == "event" or node.type == "shop") then
                hold.run, hold.map, hold.nodeId = self.run, self.map, flow.id
                -- A shop farewell shows no shelf: only the merchant and 继续 remain.
                hold.view = node.type == "event" and "eventView" or node.type == "shop" and "farewell"
                    or (hold.choice == "upgrade" and "pickerView" or "campView")
                hold.eventId = node.event and node.event.id
                self.result = hold
            end
        else
            self.notice, self.failed = reasons[reason] or "操作未完成，请重新选择", true
        end
        self:render()
        self.failed = false
        return notify(accepted, reason)
    end

    -- Every clickable control is addressed by its path, e.g. "shopView/card1".
    function self:press(key)
        local ok, view = current()
        if not ok then return false, view end
        local entry = self.actions[key]
        if not entry then return false, "unavailable_action" end
        if not entry.enabled then
            if entry.poor then merchant:react("poor") end
            if entry.reason then self.notice, self.failed = entry.reason, true self:render() end
            return false, "unavailable_action"
        end
        return entry.handler()
    end
    function self:setPage(page)
        local ok, reason = current() if not ok then return false, reason end
        if type(page) ~= "number" or page % 1 ~= 0 or page < 1 or page > (self.pageCount or 1) then return false, "invalid_page" end
        if self.mode == "picker" then self.pickPage = page else self.page = page end
        self.notice = "" self:render() return true
    end

    local targets = { "back", "confirm", "shopView/previous", "shopView/next", "shopView/removal",
        "shopView/relicPrevious", "shopView/relicNext", "campView/rest", "campView/forge",
        "pickerView/previous", "pickerView/next", "treasureView/chest", "treasureView/take",
        "treasureView/previous", "treasureView/next" }
    for i = 1, SHOP_PAGE do targets[#targets + 1] = "shopView/card" .. i end
    for i = 1, RELIC_PAGE do targets[#targets + 1] = "shopView/relic" .. i end
    for i = 1, 3 do targets[#targets+1]='shopView/potion'..i end
    for i = 1, PICK_PAGE do targets[#targets + 1] = "pickerView/card" .. i end
    for i = 1, OPTIONS do targets[#targets + 1] = "eventView/option" .. i end
    local cursor = options.cursorEvents or (Enum and Enum.CursorEventType)
    -- Native hits accept one listener per event; framed feedback and row swipes share it.
    local dispatch = {}
    local function listen(hit, event, fn)
        local byEvent = dispatch[hit] or {}
        dispatch[hit] = byEvent
        local list = byEvent[event]
        if not list then
            list = {}
            byEvent[event] = list
            hit:AddCursorEventListener(event, function(e) for _, f in ipairs(list) do f(e) end end)
        end
        list[#list + 1] = fn
    end
    -- A row swipe presses that row's existing arrow, so paging rules stay in one place.
    local rows = {}
    for i = 1, SHOP_PAGE do rows["shopView/card" .. i] = "shopView/" end
    for i = 1, RELIC_PAGE do rows["shopView/relic" .. i] = "shopView/relic" end
    for i = 1, PICK_PAGE do rows["pickerView/card" .. i] = "pickerView/" end
    self.swipeEnabled = cursor ~= nil and cursor.CursorDown ~= nil and cursor.CursorUp ~= nil
    local function point(event)
        if not event or type(event.GetUIPos) ~= "function" then return end
        local x, y = event:GetUIPos()
        if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y
            or math.abs(x) == math.huge or math.abs(y) == math.huge then return end
        local width, height = self.canvasWidth or Theme.canvas.base[1], self.canvasHeight or Theme.canvas.base[2]
        local k = math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
        return x / k, y / k
    end
    local function swipeDown(row, event)
        swallow = nil -- a new physical sequence
        local x, y = point(event)
        swipe = x and { row = row, touch = event.touchId, x = x, y = y } or nil
    end
    local function swipeUp(event)
        local g = swipe
        if not g or (event and event.touchId) ~= g.touch then return end
        swipe = nil
        local x, y = point(event)
        if not x then return end
        local dx, dy = x - g.x, y - g.y
        local limit = layout.swipe.threshold
        if math.abs(dx) < limit and math.abs(dy) < limit then return end
        -- Past the threshold it is a drag, never a purchase; only a horizontal one pages.
        -- Finger moves left to reveal the next page, as on a touch carousel.
        if math.abs(dx) > math.abs(dy) then
            local arrow = (g.row == "shopView/relic") and (dx < 0 and "Next" or "Previous") or (dx < 0 and "next" or "previous")
            self:press(g.row .. arrow)
        end
        swallow = { touch = g.touch }
    end

    for _, key in ipairs(targets) do
        local name = key
        local box = path(name)
        local hit = box:GetChild("hit")
        local input
        hit:AddCursorEventListener(clickEvent, function(event)
            if swallow and (event == nil or event.touchId == nil or event.touchId == swallow.touch) then
                swallow = nil
                return false, "swiped"
            end
            if input and input.observed then
                local gesture = input.released
                local touch = event and event.touchId
                -- Click follows Up. Keep its original action until consumption, not
                -- the action currently rebound to this hit area after a render.
                if not gesture or touch ~= nil and touch ~= gesture.touch
                    or touch == nil and next(input.active) ~= nil then return false, "stale_action" end
                input.released = nil
                if not gesture.action or gesture.action ~= self.actions[name] then return false, "stale_action" end
            end
            -- Hosts that never send Down retain the click-only/accessibility path.
            return self:press(name)
        end)
        -- A framed button keeps its dynamic children at their existing paths.
        -- Documented pointer events + SetLocalScale scale the complete face;
        -- Shop/picker cards share gesture ownership without framed-button visuals.
        if (box:GetChild("normal") or name:match("^shopView/card%d+$")
            or name:match("^pickerView/card%d+$")) and cursor and cursor.CursorEnter and cursor.CursorExit
            and cursor.CursorDown and cursor.CursorUp and cursor.CursorEndDrag then
            -- Retain only active touches and the next released click, never a
            -- history of touch IDs. Render/hide and terminal events clear them.
            input = {active={}}
            buttonInputs[box] = input
            local noTouch = {} -- supports a complete pointer sequence without IDs
            local function touchKey(event) return event and event.touchId or noTouch end
            local function cancelInput(event)
                input.active[touchKey(event)] = nil
                if input.released and input.released.touch == (event and event.touchId) then input.released = nil end
            end
            local function visibleAction()
                local ok, view = current()
                if not ok then return nil end
                if self.view.phase ~= view.phase or self.view.node.complete ~= view.node.complete then return nil end
                local parent = box
                while parent do if not parent.visible then return nil end parent = parent.parent end
                return self.actions[name]
            end
            local function available()
                local entry, look = visibleAction(), buttonLooks[box]
                return entry and entry.enabled and look and look.enabled and not look.selected
            end
            local function owned(event)
                return buttonPress and buttonPress.box == box and buttonPress.touch == (event and event.touchId)
            end
            local function release(event)
                if not owned(event) then return end
                buttonPress = nil
                if not available() then buttonHover = nil end
                paintButton(box)
            end
            listen(hit, cursor.CursorEnter, function()
                if not available() or buttonPress and buttonPress.box ~= box then return end
                local previous = buttonHover
                buttonHover = box
                if previous and previous ~= box then paintButton(previous) end
                paintButton(box)
            end)
            listen(hit, cursor.CursorDown, function(event)
                input.observed, input.released = true, nil
                input.active[touchKey(event)] = {touch=event and event.touchId, action=visibleAction()}
                if not available() or buttonPress then return end
                buttonPress = {box=box,touch=event and event.touchId}
                paintButton(box)
            end)
            listen(hit, cursor.CursorExit, function(event)
                cancelInput(event)
                if buttonPress and not owned(event) then return end
                if buttonHover == box then buttonHover = nil end
                if owned(event) then buttonPress = nil end
                paintButton(box)
            end)
            listen(hit, cursor.CursorUp, function(event)
                local key = touchKey(event)
                local gesture = input.active[key]
                input.active[key] = nil
                if gesture then input.released = gesture end
                release(event)
            end)
            listen(hit, cursor.CursorEndDrag, function(event)
                cancelInput(event)
                if not owned(event) then return end
                buttonPress, buttonHover = nil, nil
                paintButton(box)
            end)
        end
        if self.swipeEnabled and rows[name] then
            local row = rows[name]
            listen(hit, cursor.CursorDown, function(event) swipeDown(row, event) end)
            listen(hit, cursor.CursorUp, swipeUp)
            if cursor.CursorEndDrag then listen(hit, cursor.CursorEndDrag, swipeUp) end
        end
    end
    self:render()
    return self
end
return M
