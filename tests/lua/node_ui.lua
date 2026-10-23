package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI, Nodes = require("abyss_node_ui"), require("abyss_nodes")
local Run, Map, Combat = require("abyss_run"), require("abyss_map"), require("abyss_combat")
local data = require("abyss_data")
local Presentation = require("abyss_presentation")
local Layout = require("abyss_ui_layout")
local Theme = require("abyss_theme")
local C = Theme.color
local count = 0
local function test(name, fn) fn() count = count + 1 print("ok node UI " .. count .. " - " .. name) end
local function findSpec(list, name)
    for _, spec in ipairs(list) do
        if spec.name == name then return spec end
        local found = spec.children and findSpec(spec.children, name)
        if found then return found end
    end
end
-- Mock controls are built from the generated native tree, so a renamed control fails here.
local function control(spec, parent)
    local c = { name = spec.name, children = {}, visible = spec.visible ~= false, parent = parent,
        text = spec.text and spec.text.content or "", imageId = spec.image }
    function c:GetChild(key) return self.children[key] end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:SetImage(...)
        assert(select("#", ...) == 2, "SetImage expects exactly source and id")
        local source, id = ...
        assert(source == "static" and type(id) == "number") self.imageId = id
    end
    function c:AddCursorEventListener(event, callback) assert(event == "click" and not self.click) self.click = callback end
    for _, item in ipairs(spec.children or {}) do c.children[item.name] = control(item, c) end
    return c
end
local function entered(kind, source, seed)
    source = source or data
    local run, map = Run.new(source, seed or 42), Map.generate(source, seed or 42)
    while true do
        local choices = Map.available(map)
        for _, node in ipairs(choices) do
            if node.type == kind then assert(Nodes.enter(run, map, node.id)) return run, map end
        end
        assert(#choices > 0) assert(Map.choose(map, choices[1].id))
    end
end
local function colour(r, g, b, a) return { r = r, g = g, b = b, a = a } end
local function same(a, b)
    assert(type(a) == type(b))
    if type(a) ~= "table" then assert(a == b) return end
    for k, v in pairs(a) do same(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil) end
end
local function setup(kind, source, prepare)
    if kind == "event" and not source then
        source = Combat.copy(data); source.rules.events.encounterId = "cleric"
    end
    local run, map = entered(kind, source)
    if prepare then prepare(run) end
    local root, changes = control(findSpec(Layout, "nodePanel")), {}
    local ui = UI.new(root, run, map, Presentation, "click", function(ok, reason, controller)
        assert(controller.root == root)
        changes[#changes + 1] = { ok = ok, reason = reason }
    end, { color = colour, imageSource = "static" })
    local notice = root.children.notice.text
    local width = utf8.len(notice) * Theme.font.body
    assert(math.max(1, math.ceil(width / Theme.layout.nativeNode.notice[3])) * Theme.layout.nativeText.lineHeight
        <= Theme.layout.nativeNode.notice[4], "node notice exceeds existing text capacity")
    ui:setVisible(true) -- the host shows the panel in node mode
    local function get(key)
        local node = root
        for part in key:gmatch("[^/]+") do node = assert(node:GetChild(part), "missing " .. key) end
        return node
    end
    local function shown(key)
        local node = get(key)
        while node do if not node.visible then return false end node = node.parent end
        return true
    end
    -- A player can only press what is on screen.
    local function click(key)
        assert(shown(key), "click on hidden control " .. key)
        return get(key):GetChild("hit").click()
    end
    return ui, get, click, shown, changes
end
local function is(value, expected) return value and value.r == expected.r and value.g == expected.g and value.b == expected.b end
local function upgradeChange()
    for _, card in ipairs(data.cards.cards) do
        local display = Presentation[card.id]
        if display and display.cost ~= display.upgradeCost and card.upgrade and next(card.upgrade)
            and not card.condition and not card.costMode then return card.id, display end
    end
end

test("node resource count includes bottles beyond an empty first slot", function()
    local ui, get = setup("camp", nil, function(run)
        run.potions = { [3] = "regen_potion" }
    end)
    assert(get("potions").text == "药水 1/3")
    local ok, slot = Run.obtainPotion(ui.run, "fire_potion")
    assert(ok and slot == 1) ui:render()
    assert(get("potions").text == "药水 2/3")
    assert(ui.run.potions[3] == "regen_potion")
end)

test("shop shelf shows real card faces with separate core prices and a paged pool", function()
    local ui, get, _, shown = setup("shop", nil, function(run) run.gold = 10000 end)
    local node = Nodes.view(ui.run, ui.map).node
    assert(shown("shopView") and not shown("campView") and not shown("pickerView"))
    assert(get("title").text == "第 " .. node.floor .. " 层 · 商店" and get("gold").text == "10000")
    for i = 1, 5 do
        local offer, box = node.cards[i], get("shopView/card" .. i)
        local display, definition = Presentation[offer.id], nil
        for _, card in ipairs(data.cards.cards) do if card.id == offer.id then definition = card end end
        assert(box.children.name.text == display.name and not box.children.name.text:find("金币", 1, true))
        assert(box.children.cost.text == tostring(display.cost) and box.children.description.text == display.text)
        assert(box.children["art_" .. definition.type].visible and is(box.children.border.imageColor, C.rarity[definition.rarity]))
        assert(get("shopView/price" .. i).children.value.text == tostring(offer.price))
        assert(is(get("shopView/price" .. i).children.value.fontColor, C.goldBright) and not box.children.veil.visible)
    end
    local pages = math.ceil(#node.cards / 5)
    assert(ui.pageCount == pages and get("shopView/page").text:find("1/" .. pages, 1, true))
    assert(not shown("shopView/previous") == (pages == 1) and shown("shopView/next") == (pages > 1))
    assert(get("confirm").children.label.text == "离开商店" and not shown("back"))
end)

test("unaffordable goods turn the price red, grey the card and explain without charging", function()
    local ui, get, click, _, changes = setup("shop")
    local offer = Nodes.view(ui.run, ui.map).node.cards[1]
    ui.run.gold = offer.price - 1 ui:render()
    local box, price = get("shopView/card1"), get("shopView/price1")
    assert(is(price.children.value.fontColor, C.danger) and not box.children.veil.visible)
    assert(is(box.children.border.imageColor, C.line) and is(box.children.description.fontColor, C.textDim))
    local before = Combat.copy(ui.run)
    assert(not click("shopView/card1")) same(ui.run, before)
    assert(get("notice").text == "金币不足：需要 " .. offer.price .. "，还差 1" and is(get("notice").fontColor, C.danger))
    assert(#changes == 0)
    ui.run.gold = offer.price ui:render()
    assert(is(price.children.value.fontColor, C.goldBright) and is(box.children.description.fontColor, C.text))
    local size = #ui.run.deck assert(click("shopView/card1"))
    assert(#ui.run.deck == size + 1 and ui.run.deck[#ui.run.deck].cardId == offer.id and ui.run.gold == 0)
    assert(get("notice").text:find("已购买「" .. Presentation[offer.id].name .. "」", 1, true))
    assert(box.children.stamp.visible and box.children.stamp.text == "已售出" and box.children.veil.visible)
    assert(price.children.value.text == "已售出" and not price.children.coin.visible)
    before = Combat.copy(ui.run) assert(not click("shopView/card1")) same(ui.run, before)
    assert(get("notice").text:find("已售出", 1, true))
end)

test("shop relic row shows sourced effect text and buys through Nodes", function()
    local ui, get, click = setup("shop", nil, function(run) run.gold = 10000 end)
    local node = Nodes.view(ui.run, ui.map).node
    local first = node.relics[1]
    local tile = get("shopView/relic1")
    assert(tile.children.icon.imageId == Theme.icon.relic[first.id])
    local relic for _, item in ipairs(data.relics.relics) do if item.id == first.id then relic = item end end
    assert(tile.children.name.text == relic.name and tile.children.description.text:find("战斗", 1, true))
    local descriptions = {}
    for page = 1, math.ceil(#node.relics / 3) do
        for i = 1, 3 do
            local box = get("shopView/relic" .. i)
            if box.visible then descriptions[box.children.name.text] = box.children.description.text end
        end
        if page * 3 < #node.relics then assert(click("shopView/relicNext") and ui.relicPage == page + 1) end
    end
    assert(descriptions["裂岩杵"] == "战斗开始时，获得 1 层力量。" and descriptions["铜鳞"] == "战斗开始时，获得 3 层荆棘。")
    while ui.relicPage > 1 do assert(click("shopView/relicPrevious")) end
    assert(click("shopView/relic1") and ui.run.relics[#ui.run.relics] == first.id and ui.run.gold == 10000 - first.price)
    assert(tile.children.veil.visible and get("shopView/relicPrice1").children.value.text == "已售出")
    if #node.relics > 3 then
        assert(click("shopView/relicNext") and ui.relicPage == 2)
        assert(get("shopView/relic1").children.name.text == (function()
            for _, item in ipairs(data.relics.relics) do if item.id == node.relics[4].id then return item.name end end
        end)())
    end
end)

test("removal service selects a uid first, confirms with the core price and is spent for the shop", function()
    local ui, get, click, shown = setup("shop", nil, function(run) run.gold = 10000 end)
    local price = Nodes.view(ui.run, ui.map).node.removePrice
    assert(get("shopView/removalPrice").children.value.text == tostring(price))
    assert(get("shopView/removal").children.description.text:find("每家商店限一次", 1, true))
    assert(click("shopView/removal") and shown("pickerView") and not shown("shopView"))
    local second = ui.run.deck[2].uid
    local before = Combat.copy(ui.run)
    assert(not shown("pickerView/target") and get("pickerView/empty").text ~= "")
    assert(not click("confirm")) same(ui.run, before)
    assert(get("notice").text == "请先在上方选择一张卡牌")
    assert(click("pickerView/card2")) same(ui.run, before)
    assert(shown("pickerView/target") and get("pickerView/card2").children.glow.visible)
    assert(get("pickerView/hint").text == "牌组 10 → 9 张")
    assert(get("confirm").children.label.text == "删除 · " .. price .. " 金币")
    assert(click("confirm"))
    assert(#ui.run.deck == 9 and ui.run.gold == 10000 - price and ui.run.shopRemoveCount == 1)
    for _, card in ipairs(ui.run.deck) do assert(card.uid ~= second) end
    assert(shown("shopView") and ui.mode == "main")
    assert(get("shopView/removalPrice").children.value.text == "已使用")
    before = Combat.copy(ui.run)
    assert(not click("shopView/removal")) same(ui.run, before)
    assert(get("notice").text:find("每家商店限一次", 1, true))
end)

test("removal service shows shortfall and last-card protection without opening the picker", function()
    local ui, get, click, shown = setup("shop", nil, function(run) run.gold = 10 end)
    local price = Nodes.view(ui.run, ui.map).node.removePrice
    assert(is(get("shopView/removalPrice").children.value.fontColor, C.danger))
    assert(not click("shopView/removal") and shown("shopView"))
    assert(get("notice").text == "金币不足：需要 " .. price .. "，还差 " .. (price - 10))
    local single, singleGet, singleClick = setup("shop", nil, function(run) while #run.deck > 1 do table.remove(run.deck) end run.gold = 10000 end)
    assert(singleGet("shopView/removal").children.description.text == "牌组仅剩一张")
    local before = Combat.copy(single.run)
    assert(not singleClick("shopView/removal")) same(single.run, before)
end)

test("an external removal invalidates a selected removal before charging gold", function()
    local ui, get, click, _, changes = setup("shop", nil, function(run) run.gold = 10000 end)
    click("shopView/removal") click("pickerView/card2")
    local first, second = ui.run.deck[1].uid, ui.run.deck[2].uid
    assert(Nodes.removeCard(ui.run, first))
    local before = Combat.copy(ui.run)
    assert(not click("confirm")) same(ui.run, before)
    assert(ui.run.deck[1].uid == second and ui.run.shopRemoveCount == 1)
    assert(get("notice").text == "本店删牌服务已使用")
    assert(#changes == 1 and changes[1].reason == "removal_unavailable" and not changes[1].ok)
end)

test("camp shows rest healing projection and forge count; full health disables rest only when forging is possible", function()
    local ui, get, click = setup("camp", nil, function(run) run.hp = 20 end)
    local node = Nodes.view(ui.run, ui.map).node
    local rest = get("campView/rest")
    assert(rest.children.description.text == "回复 " .. node.heal .. " 点生命\n生命 20 → " .. (20 + node.heal))
    assert(get("campView/forge").children.description.text:find("可升级 " .. #node.upgradeCards .. " 张", 1, true))
    assert(rest.children.normal.visible and not rest.children.disabled.visible)
    ui.run.hp = ui.run.maxHp ui:render()
    assert(rest.children.disabled.visible and rest.children.description.text == "生命已满")
    local before = Combat.copy(ui.run)
    assert(not click("campView/rest")) same(ui.run, before)
    assert(get("notice").text:find("生命已满", 1, true))
    for _, card in ipairs(ui.run.deck) do card.upgraded = true end
    ui:render()
    assert(get("campView/forge").children.disabled.visible and rest.children.normal.visible)
    assert(not click("campView/forge")) same(ui.run.nodeFlow, before.nodeFlow)
    assert(click("campView/rest") and ui.run.phase == "map" and ui.run.hp == ui.run.maxHp)
end)

test("camp rest heals once through Nodes and holds the result until continue", function()
    local ui, get, click, shown, changes = setup("camp", nil, function(run) run.hp = 20 end)
    local healing = Nodes.view(ui.run, ui.map).node.heal
    assert(get("notice").text:find("残存的岩灯照亮了短暂的歇脚处。", 1, true))
    assert(get("notice").text:find("休息或锻造，只能选一项", 1, true))
    assert(click("campView/rest")) assert(ui.run.hp == 20 + healing and ui.run.phase == "map")
    assert(ui:holding() and shown("campView") and get("campView/rest").children.selected.visible)
    assert(get("campView/rest").children.description.text:find("已回复 " .. healing, 1, true))
    assert(get("notice").text == "休息完成 · 回复 " .. healing .. " 点生命")
    local before = Combat.copy(ui.run)
    assert(not click("campView/rest") and not click("campView/forge")) same(ui.run, before)
    assert(get("confirm").children.label.text == "继续" and click("confirm"))
    assert(not ui:holding() and changes[#changes].reason == "continue" and #changes == 2)
end)

test("forge previews the real before/after card and commits only the confirmed uid", function()
    local id, display = upgradeChange()
    local ui, get, click, shown = setup("camp", nil, function(run)
        run.deck[3] = { uid = run.deck[3].uid, cardId = id, upgraded = false }
    end)
    assert(click("campView/forge") and shown("pickerView") and get("confirm").children.label.text == "确认升级")
    assert(get("confirm").children.disabled.visible and shown("back"))
    local target = ui.run.deck[3].uid
    local slot for i = 1, 6 do if ui.actions["pickerView/card" .. i] and ui.upgradeRows[i].uid == target then slot = i end end
    local before = Combat.copy(ui.run)
    assert(click("pickerView/card" .. slot)) same(ui.run, before)
    local old, new = get("pickerView/before"), get("pickerView/after")
    assert(shown("pickerView/before") and shown("pickerView/after") and shown("pickerView/arrow"))
    assert(old.children.name.text == display.name and old.children.cost.text == tostring(display.cost))
    assert(old.children.description.text == display.text)
    assert(new.children.name.text == display.name .. "+" and is(new.children.name.fontColor, C.positive))
    assert(new.children.cost.text == tostring(display.upgradeCost) and new.children.description.text == display.upgradeText)
    assert(is(new.children.costDisc.imageColor, C.positive))
    assert(get("pickerView/hint").text == "费用 " .. display.cost .. " → " .. display.upgradeCost)
    assert(click("back") and shown("campView")) same(ui.run, before)
    click("campView/forge") click("pickerView/card" .. slot)
    assert(click("confirm"))
    for _, card in ipairs(ui.run.deck) do assert(card.upgraded == (card.uid == target)) end
    assert(ui.run.phase == "map" and ui:holding() and shown("pickerView"))
    assert(shown("pickerView/after") and get("pickerView/label").text == "已升级" and not shown("pickerView/card1"))
    assert(get("notice").text == "已升级「" .. display.name .. "」→「" .. display.name .. "+」")
    assert(click("confirm") and not ui:holding())
end)

test("forge with two upgrades keeps the committed picker and stamps upgraded instances", function()
    local source = Combat.copy(data) source.rules.camp.upgradeCount = 2
    local ui, get, click, shown = setup("camp", source)
    click("campView/forge")
    assert(ui.pageCount == 2 and get("pickerView/page").text:find("1/2", 1, true))
    local first, second = ui.run.deck[1], ui.run.deck[2]
    click("pickerView/card1") click("confirm")
    assert(first.upgraded and not second.upgraded and ui.run.phase == "node")
    assert(not shown("back") and get("pickerView/card1").children.stamp.text == "已升级")
    local before = Combat.copy(ui.run) assert(not click("pickerView/card1")) same(ui.run, before)
    click("pickerView/next") assert(ui.pickPage == 2 and not shown("pickerView/card5"))
    click("pickerView/card3") click("confirm")
    assert(ui.run.deck[9].upgraded and ui.run.phase == "map")
end)

test("Purifier prays for free through the picker and shows the removal result", function()
    local source = Combat.copy(data); source.rules.player.startingGold = 0
    local ui, get, click, shown = setup("event", source)
    assert(get("eventView/name").text == "净化神龛" and get("eventView/body").text ~= "")
    assert(get("eventView/option1").children.title.text == "［祈祷］")
    assert(get("eventView/option1").children.description.text == "免费从牌组移除一张卡牌")
    assert(get("eventView/option2").children.title.text == "［离开］" and not shown("eventView/option3"))
    assert(click("eventView/option1") and shown("pickerView") and get("confirm").children.label.text == "祈祷 · 移除")
    local second = ui.run.deck[2]
    local name = Presentation[second.cardId].name
    click("pickerView/card2") assert(click("confirm"))
    assert(ui.run.phase == "map" and ui.run.gold == 0 and #ui.run.deck == 9)
    for _, card in ipairs(ui.run.deck) do assert(card.uid ~= second.uid) end
    assert(shown("eventView") and not shown("eventView/option1"))
    assert(get("eventView/body").text:find("「" .. name .. "」已从牌组中移除。", 1, true))
    assert(get("eventView/body").text:find("牌组现有 9 张", 1, true))
    assert(click("confirm") and not ui:holding())
    local leaving, leaveGet, leaveClick = setup("event", source)
    assert(leaveClick("eventView/option2") and leaving.run.phase == "map" and leaving.run.gold == 0)
    assert(leaveGet("eventView/body").text == "你向神龛行了一礼，转身继续赶路。")
end)

test("Cleric options show sourced costs, disabled reasons and the healing result", function()
    local ui, get, click, shown = setup("event", nil, function(run) run.hp, run.gold = 10, 35 end)
    local heal = get("eventView/option1").children.description.text
    assert(heal == "支付 35 金币，回复 20 点生命（生命 10 → 30）")
    local purify = get("eventView/option2")
    assert(purify.children.disabled.visible and purify.children.description.text == "金币不足（需要 50，现有 35）")
    local before = Combat.copy(ui.run)
    assert(not click("eventView/option2")) same(ui.run, before)
    assert(get("notice").text == "金币不足（需要 50，现有 35）")
    assert(click("eventView/option1")) assert(ui.run.gold == 0 and ui.run.hp == 30 and ui.run.phase == "map")
    assert(get("eventView/body").text:find("支付 35 金币，回复 20 点生命（生命 10 → 30）", 1, true))
    assert(not shown("eventView/option1") and get("confirm").children.label.text == "继续")
    local leaving, _, leaveClick = setup("event")
    before = Combat.copy(leaving.run)
    assert(leaveClick("eventView/option3")) assert(leaving.run.gold == before.gold and leaving.run.hp == before.hp)
    same(leaving.run.deck, before.deck) same(leaving.run.potions, before.potions)
end)

test("Cleric purify is cancellable, charges once and leaves shop removal count unchanged", function()
    local ui, get, click, shown = setup("event", nil, function(run) run.gold = 50 end)
    local first, second = ui.run.deck[1].uid, ui.run.deck[2].uid
    local before = Combat.copy(ui.run)
    assert(click("eventView/option2") and ui.mode == "picker" and ui.pageCount == 2)
    assert(get("confirm").children.label.text == "净化 · 50 金币")
    assert(click("pickerView/next") and ui.pickPage == 2)
    assert(click("back") and ui.mode == "main" and shown("eventView")) same(ui.run, before)
    assert(click("eventView/option2") and click("pickerView/card2") and click("confirm"))
    assert(ui.run.gold == 0 and #ui.run.deck == 9 and ui.run.deck[1].uid == first)
    for _, instance in ipairs(ui.run.deck) do assert(instance.uid ~= second) end
    assert((ui.run.shopRemoveCount or 0) == 0 and ui.run.phase == "map")
    assert(get("eventView/body").text:find("支付 50 金币", 1, true))
end)

test("Cleric stale affordability is revalidated by Nodes without consuming the event", function()
    local ui, get, click = setup("event", nil, function(run) run.gold = 50 end)
    assert(click("eventView/option2") and click("pickerView/card1")) ui.run.gold = 49
    local before = Combat.copy(ui.run)
    assert(not click("confirm")) same(ui.run, before)
    assert(get("notice").text == "金币不足" and is(get("notice").fontColor, C.danger))
    assert(click("back") and click("eventView/option3") and ui.run.phase == "map")
end)

test("treasure opens visually first, then grants the actual relic once", function()
    local ui, get, click, shown, changes = setup("treasure")
    local reward = Nodes.view(ui.run, ui.map).node.reward
    assert(shown("treasureView/closed") and shown("treasureView/hint") and not shown("treasureView/take"))
    local before = Combat.copy(ui.run)
    assert(click("treasureView/chest")) same(ui.run, before)
    assert(#changes == 0 and shown("treasureView/open") and shown("treasureView/reward"))
    local row = get("treasureView/reward")
    local relic for _, item in ipairs(data.relics.relics) do if item.id == reward.relicId then relic = item end end
    assert(row.children.name.text == "遗物 · " .. relic.name and row.children.icon.imageId == Theme.icon.relic[relic.id])
    assert(row.children.description.text:find("。", 1, true))
    assert(click("treasureView/take")) assert(ui.run.relics[#ui.run.relics] == reward.relicId)
    assert(get("notice").text == "已获得遗物「" .. relic.name .. "」" and not ui:holding())
    before = Combat.copy(ui.run) assert(not shown("treasureView") and not ui:press("treasureView/take")) same(ui.run, before)
end)

test("gold treasure explains the fallback and is claimed through Nodes", function()
    local run, map = Run.new(data, 42), Map.generate(data, 42)
    while true do
        local choices = Map.available(map) local treasure
        for _, node in ipairs(choices) do if node.type == "treasure" then treasure = node break end end
        if treasure then
            run.relics = {} for _, relic in ipairs(data.relics.relics) do run.relics[#run.relics + 1] = relic.id end
            assert(Nodes.enter(run, map, treasure.id)) break
        end
        assert(Map.choose(map, choices[1].id))
    end
    local ui, get, click = setup("shop")
    ui.run, ui.map = run, map ui:render()
    local gold, reward = run.gold, Nodes.view(run, map).node.reward.gold
    click("treasureView/chest")
    assert(get("treasureView/reward").children.name.text == reward .. " 金币")
    assert(get("treasureView/reward").children.description.text == "遗物已全部持有，改为金币")
    assert(get("treasureView/reward").children.icon.imageId == Theme.icon.gold.id)
    assert(click("treasureView/take")) assert(run.gold == gold + reward)
end)

test("hidden input, external completion and a replaced run reject stale commands", function()
    local ui, get, _, _, changes = setup("shop", nil, function(run) run.gold = 10000 end)
    ui:setVisible(false) local before = Combat.copy(ui.run)
    for _, key in ipairs({ "shopView/card1", "shopView/relic1", "shopView/removal", "shopView/next", "confirm" }) do
        assert(not get(key):GetChild("hit").click())
    end
    assert(not ui:setPage(2)) same(ui.run, before) assert(#changes == 0)
    ui:setVisible(true)
    assert(Nodes.leaveShop(ui.run))
    before = Combat.copy(ui.run) assert(not ui:press("shopView/card1")) same(ui.run, before)
    local oldRun, oldBefore = ui.run, Combat.copy(ui.run) ui.run, ui.map = entered("treasure")
    before = Combat.copy(ui.run) assert(not ui:press("treasureView/chest")) same(ui.run, before) same(oldRun, oldBefore)
    ui:render() assert(ui.page == 1 and ui.mode == "main" and not ui.opened)
    assert(ui:press("treasureView/chest") and ui:press("treasureView/take") and ui.run.phase == "map")
end)

test("a held result belongs to its run; a fresh run renders safely and restart resets navigation", function()
    local ui, get, click, shown = setup("camp", nil, function(run) run.hp = 20 end)
    click("campView/rest") assert(ui:holding())
    ui.run, ui.map = Run.new(data, 42), Map.generate(data, 42)
    local beforeRun, beforeMap = Combat.copy(ui.run), Map.snapshot(ui.map)
    ui:render() ui:render()
    same(ui.run, beforeRun) same(ui.map, beforeMap)
    assert(not ui:holding() and ui.nodeId == nil and not shown("campView") and not shown("confirm"))
    assert(get("title").text == "路线")
    local shop, _, shopClick = setup("shop")
    shopClick("shopView/next") assert(shop.page == 2)
    local previousNode = shop.nodeId
    shop.run, shop.map = entered("shop") shop:render()
    assert(shop.nodeId == previousNode and shop.page == 1 and shop.mode == "main")
end)
print("LUA_NODE_UI_PASS " .. count)
