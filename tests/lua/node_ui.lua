package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI, Nodes = require("abyss_node_ui"), require("abyss_nodes")
local Run, Map, Combat = require("abyss_run"), require("abyss_map"), require("abyss_combat")
local data = require("abyss_data")
local Presentation = require("abyss_presentation")
local Layout = require("abyss_ui_layout")
local Theme = require("abyss_theme")
local Narrative = require("abyss_narrative")
local C = Theme.color
local cursorEvents = { CursorEnter="enter", CursorExit="exit", CursorDown="down", CursorUp="up", CursorEndDrag="endDrag" }
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
        text = spec.text and spec.text.content or "", imageId = spec.image, listeners = {}, scale = {1,1,1} }
    function c:GetChild(key) return self.children[key] end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:SetImage(...)
        assert(select("#", ...) == 2, "SetImage expects exactly source and id")
        local source, id = ...
        assert(source == "static" and type(id) == "number") self.imageId = id
    end
    function c:SetLocalScale(x,y,z) self.scale = {x,y,z} end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:AddCursorEventListener(event, callback)
        assert(not self.listeners[event], "duplicate listener " .. event)
        self.listeners[event] = callback
        if event == "click" then self.click = callback end
    end
    function c:emit(event, touchId)
        return assert(self.listeners[event], "missing listener " .. event)({touchId=touchId})
    end
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
local function setup(kind, source, prepare, events, sound)
    if kind == "event" and not source then
        source = Combat.copy(data); source.rules.events.encounterId = "cleric"
    end
    local run, map = entered(kind, source)
    if prepare then prepare(run) end
    local root, changes = control(findSpec(Layout, "nodePanel")), {}
    local ui = UI.new(root, run, map, Presentation, "click", function(ok, reason, controller)
        assert(controller.root == root)
        changes[#changes + 1] = { ok = ok, reason = reason }
    end, { sound = sound, color = colour, imageSource = "static", cursorEvents = events ~= false and (events or cursorEvents) or nil })
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
        local hit = get(key):GetChild("hit")
        -- A new deliberate click includes a fresh pointer gesture when supported;
        -- it must not reuse a prior cancelled Down in the visual-state tests.
        if hit.listeners.down then hit:emit("down",1) hit:emit("up",1) end
        return hit.click({touchId=1})
    end
    return ui, get, click, shown, changes
end
test("forge sounds only after upgrade succeeds; refresh and repeated confirm are silent", function()
    local sounds = {}
    local ui, get, click = setup("camp", nil, nil, nil, function(cue) sounds[#sounds + 1] = cue end)
    click("campView/forge")
    assert(#sounds == 0)
    click("pickerView/card1")
    assert(#sounds == 0)
    assert(click("confirm"))
    assert(#sounds == 1 and sounds[1] == "forge")
    ui:render(); ui:render()
    assert(#sounds == 1)
    assert(click("confirm")) -- continue, not a second upgrade
    assert(#sounds == 1)
end)
test("rest and treasure sound once per action and audio errors cannot undo a committed action", function()
    local sounds = {}
    local function sound(cue) sounds[#sounds + 1] = cue end
    local ui, get, click = setup("camp", nil, function(run) run.hp = 20 end, nil, sound)
    assert(click("campView/rest") and sounds[1] == "rest")
    ui:render(); assert(not ui:press("campView/rest") and #sounds == 1)
    ui, get, click = setup("treasure", nil, nil, nil, sound)
    assert(click("treasureView/chest") and sounds[2] == "treasure_open")
    ui:render(); assert(not ui:press("treasureView/chest") and #sounds == 2)
    assert(click("treasureView/take") and sounds[3] == "reward")
    ui:render(); assert(not ui:press("treasureView/take") and #sounds == 3)
    ui, get, click = setup("camp", nil, function(run) run.hp = 20 end, nil, function() error("audio unavailable") end)
    assert(click("campView/rest") and ui.run.hp > 20)
end)
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

test("shop shelf shows five colored and two unavailable colorless cards without pages", function()
    local ui, get, _, shown = setup("shop", nil, function(run) run.gold = 10000 end)
    local node = Nodes.view(ui.run, ui.map).node
    assert(shown("shopView") and not shown("campView") and not shown("pickerView"))
    assert(get("title").text == "第 " .. node.floor .. " 层 · 商店" and get("gold").text == "10000")
    for i = 1, 5 do
        local offer, box = node.cards[i], get("shopView/card" .. i)
        local display, definition = Presentation[offer.id], nil
        for _, card in ipairs(data.cards.cards) do if card.id == offer.id then definition = card end end
        assert(box.children.name.text:gsub('\n',' ') == display.name and not box.children.name.text:find("金币", 1, true))
        assert(box.children.cost.text == tostring(display.cost) and box.children.description.text == display.text)
        assert(box.children["art_" .. definition.type].visible and is(box.children.border.imageColor, C.rarity[definition.rarity]))
        assert(get("shopView/price" .. i).children.value.text == tostring(offer.price))
        assert(is(get("shopView/price" .. i).children.value.fontColor, C.goldBright) and not box.children.veil.visible)
    end
    assert(#node.cards==7 and ui.pageCount==1 and not ui:setPage(2))
    assert(not shown('shopView/previous') and not shown('shopView/next'))
    for i=6,7 do assert(shown('shopView/card'..i) and get('shopView/price'..i).children.value.text=='未实装') end
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
    -- The notice states the shortfall; the merchant answers in his own dialogue box.
    assert(get("notice").text == "金币不足：需要 " .. offer.price .. "，还差 1" and is(get("notice").fontColor, C.danger))
    ui:update(5)
    assert(get("merchant/line").text == "「" .. Narrative.merchant.insufficientGold .. "」" and ui.merchant.shake == nil)
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
    local first = node.relics[3]
    local tile = get("shopView/relic3")
    assert(tile.children.icon.imageId == Theme.icon.relic[first.id])
    local relic for _, item in ipairs(data.relics.relics) do if item.id == first.id then relic = item end end
    assert(tile.children.name.text == relic.name and tile.children.description.text=='所有商店商品半价。')
    local descriptions = {}
    for page = 1, math.ceil(#node.relics / 3) do
        for i = 1, 3 do
            local box = get("shopView/relic" .. i)
            if box.visible then descriptions[box.children.name.text] = box.children.description.text end
        end
        if page * 3 < #node.relics then assert(click("shopView/relicNext") and ui.relicPage == page + 1) end
    end
    assert(descriptions['会员卡']=='所有商店商品半价。')
    while ui.relicPage > 1 do assert(click("shopView/relicPrevious")) end
    assert(click("shopView/relic3") and ui.run.relics[#ui.run.relics] == first.id and ui.run.gold == 10000 - first.price)
    assert(tile.children.veil.visible and get("shopView/relicPrice3").children.value.text == "已售出")
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

test("removal service shows shortfall and empty-deck diagnostic without opening the picker", function()
    local ui, get, click, shown = setup("shop", nil, function(run) run.gold = 10 end)
    local price = Nodes.view(ui.run, ui.map).node.removePrice
    assert(is(get("shopView/removalPrice").children.value.fontColor, C.danger))
    assert(not click("shopView/removal") and shown("shopView"))
    assert(get("notice").text == "金币不足：需要 " .. price .. "，还差 " .. (price - 10))
    assert(ui.merchant.current.kind == "poor")
    local single, singleGet, singleClick = setup("shop", nil, function(run) run.deck = {} run.gold = 10000 end)
    assert(singleGet("shopView/removal").children.description.text == "牌组为空")
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

test("merchant opens with the scene narration once per run, then greets, and stays out of the way", function()
    local ui, get, click, shown = setup("shop", nil, function(run) run.gold = 10000 end)
    local m = Narrative.merchant
    assert(shown("merchant") and shown("merchant/portrait") and not shown("merchant/namePlate"))
    assert(get("merchant/line").text == "" and ui.merchant.current.kind == "encounter")
    ui:update(0.5)
    local partial = get("merchant/line").text
    assert(#partial > 0 and #partial < #m.encounter, "narration is typed, not dumped")
    -- Tapping the box first completes the sentence, then moves to the greeting.
    assert(get("merchant/talk/hit").click())
    assert(get("merchant/line").text == m.encounter and is(get("merchant/line").fontColor, C.textDim))
    assert(shown("merchant/next"))
    assert(get("merchant/talk/hit").click() and ui.merchant.current.kind == "greet")
    ui:update(5)
    assert(get("merchant/line").text == "「" .. m.greet .. "」" and shown("merchant/namePlate"))
    assert(get("merchant/name").text == "旧路商人" and not shown("merchant/next"))
    assert(not get("merchant/talk/hit").click(), "nothing left to advance")
    -- Repeated purchases react instantly and never wait for the previous line.
    assert(click("shopView/card1") and ui.merchant.current.kind == "buy" and ui.merchant.nod ~= nil)
    assert(click("shopView/card2") and ui.merchant.current.kind == "buy")
    ui:update(5)
    assert(get("merchant/line").text == "「" .. m.purchaseSuccess .. "」" and ui.merchant.nod == nil)
    assert(get("notice").text:find("已购买「", 1, true) and not get("notice").text:find(m.purchaseSuccess, 1, true))
    -- The merchant steps aside for the removal picker and returns after it.
    assert(click("shopView/removal") and shown("pickerView") and not shown("merchant"))
    assert(click("back") and shown("merchant"))
    -- A lingering player hears the one unprompted remark, once.
    ui:update(Theme.layout.merchant.idle + 1) ui:update(3)
    assert(get("merchant/line").text == "「" .. m.originHint .. "」")
    ui:update(Theme.layout.merchant.idle + 1)
    assert(ui.merchant.current.kind == "idle")
    -- Leaving holds the farewell on screen like a camp/event result; no shelf remains.
    assert(click("confirm") and ui.merchant.current.kind == "leave" and ui:holding())
    ui:update(5)
    assert(shown("merchant") and not shown("shopView") and get("merchant/line").text == "「" .. m.leave .. "」")
    assert(get("confirm").children.label.text == "继续" and get("notice").text ~= "")
    assert(not shown("back"))
    assert(click("confirm") and not ui:holding())
    -- The next shop of the same run skips the narration and greets directly.
    local run = ui.run
    ui.merchantNode = nil ui:render()
    assert(ui.merchant.current.kind == "greet" and ui.run == run)
    -- A restarted run may reach a shop with the same map ID; it must get its own first greeting.
    local nextRun, nextMap = entered("shop")
    ui.run, ui.map = nextRun, nextMap
    ui.merchantNode = Nodes.view(nextRun, nextMap).node.id
    ui:render()
    assert(ui.merchant.current.kind == "encounter", "same-ID shop in a new run restores the narration")
end)

test("merchant reaction sounds are requested only for sales and refusals", function()
    local cues = {}
    local run, map = entered("shop")
    run.gold = 10000
    local root = control(findSpec(Layout, "nodePanel"))
    local ui = UI.new(root, run, map, Presentation, "click", nil, { color = colour, imageSource = "static",
        sound = function(cue) cues[#cues + 1] = cue end })
    ui:setVisible(true)
    assert(#cues == 0, "entering and greeting are silent")
    assert(ui:press("shopView/card1"))
    run.gold = 0 ui:render()
    assert(not ui:press("shopView/card2"))
    assert(cues[1] == "merchant_buy" and cues[2] == "merchant_deny" and #cues == 2)
    assert(Theme.sound.merchant_buy and Theme.sound.merchant_deny)
end)

test("merchant never appears outside a shop", function()
    for _, kind in ipairs({ "camp", "treasure" }) do
        local _, _, _, shown = setup(kind)
        assert(not shown("merchant"), kind)
    end
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
    assert(old.children.name.text:gsub('\n',' ') == display.name and old.children.cost.text == tostring(display.cost))
    assert(old.children.description.text == display.text)
    assert(new.children.name.text:gsub('\n',' ') == display.name .. "＋" and is(new.children.name.fontColor, C.positive))
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
    source.rules.events.encounterId='purifier' -- explicit content fixture, independent of room RNG
    local ui, get, click, shown = setup("event", source)
    assert(get("eventView/name").text == "净化神龛" and get("eventView/body").text == Narrative.eventCopy.purifier.intro:gsub("\n\n", "\n"))
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
    assert(get("eventView/body").text == Narrative.eventCopy.cleric.intro:gsub("\n\n", "\n"))
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
    assert(not shop:press("shopView/next") and shop.page == 1)
    local previousNode = shop.nodeId
    shop.run, shop.map = entered("shop") shop:render()
    assert(shop.nodeId == previousNode and shop.page == 1 and shop.mode == "main")
end)

test("hover down up and exit paint the real framed button without executing a command", function()
    local ui, get, click, _, changes = setup("camp", nil, function(run) run.hp = 20 end)
    local box, before, beforeMap = get("campView/rest"), Combat.copy(ui.run), Map.snapshot(ui.map)
    local hit = box:GetChild("hit")
    hit:emit("enter",7)
    assert(box.children.hover.visible and not box.children.normal.visible and not box.children.pressed.visible)
    assert(is(box.children.hover.imageColor,C.buttonHover))
    hit:emit("down",7)
    assert(box.children.pressed.visible and not box.children.hover.visible)
    assert(box.scale[1] == 0.96 and box.scale[2] == 0.96)
    assert(is(box.children.pressed.imageColor,C.goldDim))
    hit:emit("up",7)
    assert(box.scale[1] == 1 and box.children.hover.visible)
    hit:emit("exit",7)
    assert(box.children.normal.visible and not box.children.hover.visible and box.scale[1] == 1)
    same(ui.run,before) same(ui.map,beforeMap) assert(#changes == 0)
    assert(click("campView/rest") and #changes == 1 and ui:holding())
end)

test("primary press uses white ink and drag-out or end-drag restores the complete button", function()
    local ui, get = setup("shop")
    local box, before = get("confirm"), Combat.copy(ui.run)
    local hit = box:GetChild("hit")
    hit:emit("enter",1)
    assert(box.children.hover.visible and is(box.children.hover.imageColor,C.goldBright))
    hit:emit("down",1)
    assert(box.children.pressed.visible and is(box.children.label.fontColor,C.buttonPressedText))
    assert(box.scale[1] == 0.96)
    hit:emit("exit",1)
    assert(box.scale[1] == 1 and box.children.normal.visible and not box.children.pressed.visible)
    assert(is(box.children.label.fontColor,C.textOnLight))
    hit:emit("up",1)
    assert(box.children.normal.visible)
    hit:emit("down",1) hit:emit("endDrag",1)
    assert(box.scale[1] == 1 and not box.children.pressed.visible)
    same(ui.run,before)
end)

test("disabled and selected results cannot be overridden by hover or retain a pressed scale", function()
    local ui, get, click = setup("camp")
    local box = get("campView/rest")
    local hit, before = box:GetChild("hit"), Combat.copy(ui.run)
    for _, event in ipairs({"enter","down","up","exit","endDrag"}) do hit:emit(event,1) end
    assert(box.children.disabled.visible and not box.children.hover.visible and not box.children.pressed.visible)
    assert(box.scale[1] == 1 and not click("campView/rest"))
    assert(get("notice").text:find("生命已满",1,true)) same(ui.run,before)
    ui.run.hp = 20 ui:render()
    hit:emit("down",1) assert(box.scale[1] == 0.96)
    ui.run.hp = ui.run.maxHp ui:render()
    assert(box.children.disabled.visible and box.scale[1] == 1)
    hit:emit("up",1) assert(not box.children.hover.visible)
    ui.run.hp = 20 ui:render() assert(click("campView/rest"))
    for _, event in ipairs({"enter","down","up"}) do hit:emit(event,1) end
    assert(box.children.selected.visible and not box.children.hover.visible and not box.children.pressed.visible)
    assert(box.scale[1] == 1 and is(box.children.border.imageColor,C.goldBright))
end)

test("rerender and modal hiding cancel pending button visuals", function()
    local ui, get = setup("shop", nil, function(run) run.gold=10000 end)
    local box, before = get("shopView/removal"), Combat.copy(ui.run)
    local hit = box:GetChild("hit")
    hit:emit("enter",1) hit:emit("down",1) assert(box.scale[1] == 0.96)
    ui:render()
    assert(box.scale[1] == 1 and not box.children.pressed.visible and not box.children.hover.visible)
    hit:emit("down",1) assert(box.scale[1] == 0.96)
    ui:setVisible(false)
    assert(box.scale[1] == 1 and not box.children.pressed.visible)
    hit:emit("enter",1) hit:emit("down",1) hit:emit("up",1)
    assert(box.scale[1] == 1 and not box.children.hover.visible)
    ui:setVisible(true)
    assert(box.scale[1] == 1 and not box.children.hover.visible)
    hit:emit("down",1) assert(box.scale[1] == 0.96)
    assert(ui:press("shopView/removal"))
    assert(box.scale[1] == 1 and not get("shopView").visible)
    hit:emit("enter",1) hit:emit("down",1)
    assert(box.scale[1] == 1 and not box.children.hover.visible)
    same(ui.run,before)
end)

test("foreign touches cannot release or move a pressed visual to another button", function()
    local ui, get = setup("camp", nil, function(run) run.hp=20 end)
    local rest, forge = get("campView/rest"), get("campView/forge")
    local a,b = rest:GetChild("hit"),forge:GetChild("hit")
    a:emit("down",7)
    a:emit("down",8) a:emit("up",8) a:emit("exit",8) b:emit("down",8) b:emit("up",8)
    assert(rest.scale[1] == 0.96 and rest.children.pressed.visible and forge.scale[1] == 1)
    a:emit("endDrag",7)
    assert(rest.scale[1] == 1 and not rest.children.pressed.visible)
    a:emit("down",7) ui:render() a:emit("up",7)
    assert(rest.scale[1] == 1 and not rest.children.pressed.visible)
end)

test("button listeners bind once and click-only hosts retain the existing C fallback", function()
    local ui, get = setup("shop")
    get("eventView/option1"):GetChild("hit"):emit("exit",1) -- never-rendered hidden view
    for _=1,5 do ui:render() end
    local listeners = get("confirm"):GetChild("hit").listeners
    local n=0 for _ in pairs(listeners) do n=n+1 end
    assert(n == 6)
    -- Card ownership and row swipes share events without framed-button scaling.
    get("shopView/card1"):GetChild("hit"):emit("down",1)
    assert(get("shopView/card1").scale[1] == 1, "card selection is not a framed-button press")
    get("shopView/card1"):GetChild("hit"):emit("up",1)
    local basic, basicGet, basicClick = setup("camp",nil,function(run) run.hp=20 end,false)
    assert(not basicGet("campView/rest"):GetChild("hit").listeners.down)
    assert(basicClick("campView/rest") and basic:holding())
end)
local function eventSetup(id,prepare)
    local source=Combat.copy(data);source.rules.events.encounterId=id
    return setup('event',source,prepare)
end
test('upgrade shrine picker cancel consumes nothing; confirmation upgrades UID and holds a readable result',function()
    local ui,get,click=eventSetup('upgrade_shrine')
    assert(get('eventView/caption').text:find('受限事件池'))
    local before=Combat.copy(ui.run)
    click('eventView/option1');click('pickerView/card1');click('back');same(ui.run,before)
    click('eventView/option1');click('pickerView/card1');local uid=ui.selected
    click('confirm');assert(ui:holding() and get('eventView/body').text:find('已升级'))
    local found=false;for _,card in ipairs(ui.run.deck) do if card.uid==uid then assert(card.upgraded);found=true end end;assert(found)
    local after=Combat.copy(ui.run);click('confirm');same(ui.run,after)
end)
test('Goop shows real leave loss, applies it once and reports asset changes',function()
    local ui,get,click=eventSetup('goop')
    local gold,loss=ui.run.gold,ui.run.nodeFlow.event.goldLoss
    assert(get('eventView/option2/description').text:find(tostring(loss)))
    click('eventView/option2');assert(ui.run.gold==gold-loss and ui:holding())
    local body=get('eventView/body').text
    if loss>0 then assert(body:find(string.format('金币 %d → %d',gold,gold-loss),1,true))
    else assert(body=='什么也没有发生。','a no-op result must not list unchanged resources') end
    assert(not body:find('生命',1,true))
    assert(not body:find('%d+%.%d+'),'integer gold must not expose a decimal suffix')
    local after=Combat.copy(ui.run);ui:render();same(ui.run,after);click('confirm');same(ui.run,after)
end)
test('Golden Wing commits seven damage before picker; cancel cannot refund or charge it again',function()
    local ui,get,click=eventSetup('golden_wing')
    local hp=ui.run.hp;click('eventView/option1');assert(ui.run.hp==hp-7 and not ui:holding())
    assert(get('eventView/option1/description').text:find('已支付'))
    click('eventView/option1');click('back');assert(ui.run.hp==hp-7)
    click('eventView/option1');click('pickerView/card1');local size=#ui.run.deck
    click('confirm');assert(#ui.run.deck==size-1 and ui.run.hp==hp-7 and ui:holding())
end)
test('Shining Light shows fixed damage and permanent upgraded names in its result',function()
    local ui,get,click=eventSetup('shining_light')
    local hp=ui.run.hp;local damage=ui.run.nodeFlow.event.damage
    assert(get('eventView/option1/description').text:find(tostring(damage)))
    click('eventView/option1');assert(ui.run.hp==hp-damage)
    local body=get('eventView/body').text
    assert(body:find('已升级') and body:find(string.format('生命 %d → %d',hp,hp-damage),1,true))
    assert(not body:find('金币',1,true),'unchanged gold must not be listed')
end)
test('Golden Shrine exposes complete costs, permanent curse result and repeat safety',function()
    local ui,get,click=eventSetup('golden_shrine')
    assert(get('eventView/caption').text:find('7种',1,true))
    assert(get('eventView/option1/description').text:find('100',1,true))
    assert(get('eventView/option2/description').text:find('275',1,true))
    assert(get('eventView/option2/description').text:find('余悔',1,true))
    local gold,size=ui.run.gold,#ui.run.deck
    click('eventView/option2');assert(ui:holding() and ui.run.gold==gold+275 and #ui.run.deck==size+1)
    assert(get('eventView/body').text:find('余悔',1,true),'curse must not be hidden by a gold-only result')
    assert(get('eventView/body').text:find(string.format('金币 %d → %d',gold,gold+275),1,true))
    assert(not get('eventView/body').text:find('生命',1,true),'unchanged HP must not be listed')
    local before=Combat.copy(ui.run);ui:render();click('confirm');same(before,ui.run)
end)
test('shop potion stock buys into a vacancy and rejects full sold and missing slots',function()
    local ui,get,click=setup('shop',nil,function(run)run.gold=10000 end)
    local original=ui.run.nodeFlow.potions[1]
    for _,id in ipairs({'fire_potion','block_potion','energy_potion'}) do
        ui.run.nodeFlow.potions[1]={id=id,price=50};ui:render()
        local text=get('shopView/potion1/description').text
        assert(text:find(id=='fire_potion' and '单敌' or '自己',1,true),'shop must explain potion target before purchase')
    end
    ui.run.nodeFlow.potions[1]=original;ui:render()
    local slot
    for i,o in ipairs(ui.run.nodeFlow.potions) do if not o.unavailable then slot=i;break end end
    assert(slot)
    ui.run.potions={'fire_potion','block_potion','regen_potion'};ui:render()
    local before=Combat.copy(ui.run)
    assert(not click('shopView/potion'..slot));same(before,ui.run)
    assert(get('shopView/potion'..slot..'/description').text=='药水槽已满')
    ui.run.potions[2]=nil;ui:render()
    local offer=Combat.copy(ui.run.nodeFlow.potions[slot]);local gold=ui.run.gold
    assert(click('shopView/potion'..slot));assert(ui.run.potions[2]==offer.id and ui.run.gold==gold-offer.price)
    assert(ui.merchant.current.kind=='buy', 'potion transactions trigger the merchant sale reaction')
    before=Combat.copy(ui.run);assert(not click('shopView/potion'..slot));same(before,ui.run)
    assert(get('shopView/potionPrice'..slot..'/value').text=='已售出')
    for i=6,7 do before=Combat.copy(ui.run);assert(not click('shopView/card'..i));same(before,ui.run) end
    ui.run.gold=0;ui:render()
    assert(not click('shopView/card6') and ui.merchant.current.kind=='buy', 'missing stock is not a gold refusal')
    ui.run.nodeFlow.potions[slot].sold=false;ui.run.potions[2]=nil;ui:render()
    before=Combat.copy(ui.run)
    assert(not click('shopView/potion'..slot));same(before,ui.run)
    assert(ui.merchant.current.kind=='poor', 'available potion shortfall triggers the merchant refusal')
end)
test("integer-valued floating resources never expose decimal suffixes", function()
    for _,kind in ipairs({"shop","camp","event","treasure"}) do
        local ui, get = setup(kind, nil, function(run)
            run.hp, run.maxHp, run.gold = 68.0, 80.0, 129.0
        end)
        assert(get("hp").text == "68/80", "HP must display 68/80, got " .. get("hp").text)
        assert(get("gold").text == "129", "gold must be an integer")
        local before=Combat.copy(ui.run); ui:render(); same(before,ui.run)
        ui.run.hp=68.5
        local ok,reason=pcall(function() ui:render() end)
        assert(not ok and tostring(reason):find("finite integer",1,true),"a real fraction must not be rounded away")
        assert(ui.run.hp==68.5)
    end
end)
test("single-card shop removal completes through the existing picker", function()
    local ui, get, click = setup("shop", nil, function(run)
        run.deck = {run.deck[1]}; run.gold = 10000
    end)
    assert(click("shopView/removal"))
    assert(click("pickerView/card1"))
    assert(get("pickerView/hint").text == "牌组 1 → 0 张")
    assert(click("confirm")); assert(#ui.run.deck == 0)
end)

test("single-card event purification is enabled, empty-deck purification is disabled", function()
    for _, id in ipairs({"cleric", "purifier"}) do
        local source = Combat.copy(data); source.rules.events.encounterId = id
        local ui, get, click = setup("event", source, function(run)
            run.deck = {run.deck[1]}; run.gold = 10000
        end)
        assert(click("eventView/option" .. (id == "cleric" and 2 or 1)))
        assert(click("pickerView/card1")); assert(click("confirm"))
        assert(#ui.run.deck == 0)
        local empty, _, emptyClick = setup("event", source, function(run)
            run.deck = {}; run.gold = 10000
        end)
        local before = Combat.copy(empty.run)
        assert(not emptyClick("eventView/option" .. (id == "cleric" and 2 or 1)))
        same(empty.run, before)
    end
end)
test('repeatable Searing Blow shows its actual before/after levels and damage',function()
    local ui,get,click,shown=setup('camp',nil,function(run)
        run.deck={{uid=1,cardId='searing_blow',upgraded=true,upgrades=2}};run.nextDeckUid=2
    end)
    assert(click('campView/forge'));assert(click('pickerView/card1'))
    local before,after=get('pickerView/before'),get('pickerView/after')
    assert(before.children.name.text:gsub('\n',' ')=='Searing Blow＋2')
    assert(after.children.name.text:gsub('\n',' ')=='Searing Blow＋3')
    assert(before.children.description.text:find('21',1,true));assert(after.children.description.text:find('27',1,true))
    assert(not get('pickerView/card1').children.veil.visible)
    assert(click('confirm'));assert(ui.run.deck[1].upgrades==3)
    assert(before.children.description.text:find('21',1,true));assert(after.children.description.text:find('27',1,true))
end)
print("LUA_NODE_UI_PASS " .. count)
