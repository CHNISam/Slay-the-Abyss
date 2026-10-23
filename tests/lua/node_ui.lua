package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI, Nodes = require("abyss_node_ui"), require("abyss_nodes")
local Run, Map, Combat = require("abyss_run"), require("abyss_map"), require("abyss_combat")
local data = require("abyss_data")
local Theme = require("abyss_theme")
local count = 0
local function test(name, fn) fn() count = count + 1 print("ok node UI " .. count .. " - " .. name) end
local function control(name)
    local c = { name = name, children = {}, visible = true, text = "" }
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. key) end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:AddCursorEventListener(event, callback) assert(event == "click" and not self.click) self.click = callback end
    return c
end
local function entered(kind, source)
    source = source or data
    local run, map = Run.new(source, 42), Map.generate(source, 42)
    while true do
        local choices = Map.available(map)
        for _, node in ipairs(choices) do
            if node.type == kind then assert(Nodes.enter(run, map, node.id)) return run, map end
        end
        assert(#choices > 0) assert(Map.choose(map, choices[1].id))
    end
end
local function setup(kind, source, prepare)
    if kind == "event" and not source then
        source = Combat.copy(data); source.rules.events.encounterId = "cleric"
    end
    local run, map = entered(kind, source)
    if prepare then prepare(run) end
    local root, presentation, changes = control("nodePanel"), {}, {}
    for _, name in ipairs({ "title", "resources", "notice", "page", "previous", "next", "leave", "tab1", "tab2", "tab3" }) do root.children[name] = control(name) end
    for i = 1, 8 do root.children["action" .. i] = control("action" .. i) end
    for i = 1, Theme.layout.nativeNode.shop.pageSize do root.children["shop" .. i] = control("shop" .. i) end
    for _, c in pairs(root.children) do
        for _, name in ipairs({ "normal", "disabled", "selected", "label", "hit", "name", "description", "price", "unavailablePrice" }) do c.children[name] = control(name) end
        for kind in pairs(Theme.icon.cardArt) do
            c.children["art_" .. kind] = control("art_" .. kind)
            c.children["artPlate_" .. kind] = control("artPlate_" .. kind)
        end
        c.children.art_relic = control("art_relic")
    end
    for _, card in ipairs(data.cards.cards) do presentation[card.id] = { name = "展示_" .. card.id } end
    local ui = UI.new(root, run, map, presentation, "click", function(ok, reason, controller)
        assert(controller.root == root)
        changes[#changes + 1] = { ok = ok, reason = reason }
    end)
    local notice = root.children.notice.text
    local width = utf8.len(notice) * Theme.font.body
    assert(math.max(1, math.ceil(width / Theme.layout.nativeNode.notice[3])) * Theme.layout.nativeText.lineHeight
        <= Theme.layout.nativeNode.notice[4], "node notice exceeds existing text capacity")
    local function click(name) return root:GetChild(name):GetChild("hit").click() end
    local function label(name)
        local slot = name:match("^action(%d+)$")
        local item = slot and root.children["shop" .. slot]
        if item and item.visible then
            return item.children.name.text .. "\n" .. item.children.description.text .. "\n" .. item.children.price.text
        end
        return root:GetChild(name):GetChild("label").text
    end
    return ui, root, click, label, changes
end
local function same(a, b)
    assert(type(a) == type(b))
    if type(a) ~= "table" then assert(a == b) return end
    for k, v in pairs(a) do same(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil) end
end

test("node resource count includes bottles beyond an empty first slot", function()
    local ui, root = setup("camp", nil, function(run)
        run.potions = { [3] = "regen_potion" }
    end)
    assert(root.children.resources.text:find("药水 1/3", 1, true))
    local ok, slot = Run.obtainPotion(ui.run, "fire_potion")
    assert(ok and slot == 1) ui:render()
    assert(root.children.resources.text:find("药水 2/3", 1, true))
    assert(ui.run.potions[3] == "regen_potion")
end)

test("camp click heals via real rules once, reports result, and completes", function()
    local ui, root, click, label, changes = setup("camp", nil, function(run) run.hp = 20 end)
    local healing = Nodes.view(ui.run, ui.map).node.heal
    assert(root.children.notice.text:find("残存的岩灯照亮了短暂的歇脚处。", 1, true))
    assert(root.children.notice.text:find("两种选择只能选一种", 1, true))
    assert(label("action1"):find(tostring(healing), 1, true))
    assert(click("action1")) assert(ui.run.hp == 20 + healing and ui.run.phase == "map")
    assert(root.children.notice.text:find("休息完成", 1, true))
    local before = Combat.copy(ui.run)
    assert(not click("action1")) same(ui.run, before)
    assert(#changes == 1 and changes[1].ok)
    assert(click("leave") and #changes == 2)
end)

test("default Purifier permits zero-gold leave and free UID removal through the same UI", function()
    local source = Combat.copy(data); source.rules.player.startingGold = 0
    local ui, _, click, label = setup("event", source)
    assert(label("action1"):find("免费", 1, true))
    assert(click("action1") and ui.mode == "purify")
    local second = ui.run.deck[2].uid
    assert(click("action2") and ui.run.phase == "map" and ui.run.gold == 0 and #ui.run.deck == 9)
    for _, card in ipairs(ui.run.deck) do assert(card.uid ~= second) end
    local leaving, _, leaveClick = setup("event", source)
    assert(leaveClick("action2") and leaving.run.phase == "map" and leaving.run.gold == 0)
end)
test("camp upgrade paginates uid instances and cannot upgrade the next uid on duplicate click", function()
    local source = Combat.copy(data) source.rules.camp.upgradeCount = 2
    local ui, root, click, label = setup("camp", source)
    click("action2")
    assert(ui.mode == "upgrade" and ui.pageCount == 2 and label("action1"):find("展示_", 1, true))
    local first, second = ui.run.deck[1], ui.run.deck[2]
    click("action1") assert(first.upgraded and not second.upgraded)
    assert(label("action1"):find("已升级", 1, true))
    local before = Combat.copy(ui.run) assert(not click("action1")) same(ui.run, before)
    click("next") assert(ui.page == 2 and not root.children.action3.visible)
    click("action1") assert(ui.run.deck[9].upgraded and ui.run.phase == "map")
end)
test("camp upgrade menu can return before committing; exhausted choices are disabled", function()
    local ui, _, click = setup("camp")
    click("action2") click("leave") assert(ui.mode == "main" and ui.run.phase == "node")
    for _, card in ipairs(ui.run.deck) do card.upgraded = true end
    ui:render() assert(not ui.slots[2].enabled)
    local before = Combat.copy(ui.run) assert(not click("action2")) same(ui.run, before)
end)
test("shop displays presentation, current prices, insufficient gold, and sold state", function()
    local ui, root, click, label = setup("shop")
    local offer = Nodes.view(ui.run, ui.map).node.cards[1]
    ui.run.gold = offer.price - 1 ui:render()
    assert(root.children.shop1.visible and not root.children.action1.visible)
    assert(root.children.shop1.children.unavailablePrice.visible and not root.children.shop1.children.price.visible)
    assert(not root.children.shop1.children.name.text:find("金币", 1, true))
    assert(label("action1"):find("金币不足", 1, true) and label("action1"):find("展示_", 1, true))
    local before = Combat.copy(ui.run) assert(not click("action1")) same(ui.run, before)
    ui.run.gold = offer.price ui:render()
    assert(not root.children.shop1.children.unavailablePrice.visible and root.children.shop1.children.price.visible)
    local size = #ui.run.deck assert(click("action1"))
    assert(#ui.run.deck == size + 1 and ui.run.deck[#ui.run.deck].cardId == offer.id and ui.run.gold == 0)
    assert(label("action1"):find("已售出", 1, true))
    before = Combat.copy(ui.run) assert(not click("action1")) same(ui.run, before)
    click("next") assert(ui.page == 2) click("tab2") assert(ui.page == 1 and ui.category == "relics")
    local relic = Nodes.view(ui.run, ui.map).node.relics[1]
    ui.run.gold = relic.price ui:render() assert(click("action1"))
    assert(ui.run.relics[#ui.run.relics] == relic.id and ui.run.gold == 0)
    assert(click("leave") and ui.run.phase == "map")
end)
test("shop remove targets uid and disables the spent service for every remaining card", function()
    local ui, _, click, label = setup("shop", nil, function(run) run.gold = 10000 end)
    click("tab3") local first, second = ui.run.deck[1].uid, ui.run.deck[2].uid
    local price = Nodes.view(ui.run, ui.map).node.removePrice
    assert(click("action1")) assert(ui.run.deck[1].uid == second and ui.run.gold == 10000 - price)
    assert(label("action1"):find("已删除", 1, true) and ui.slots[1].argument == first)
    local before = Combat.copy(ui.run) assert(not click("action1")) same(ui.run, before)
    local nextPrice = Nodes.view(ui.run, ui.map).node.removePrice
    assert(label("action2"):find(tostring(nextPrice), 1, true))
    assert(label("action2"):find("本店服务已使用", 1, true) and not ui.slots[2].enabled)
    assert(not click("action2")) same(ui.run, before)
    assert(ui.run.deck[1].uid == second and ui.run.shopRemoveCount == 1)
    click("tab1") assert(ui.category == "cards" and click("action1"))
    click("tab3") assert(not ui.slots[2].enabled)
    assert(not click("action2") and ui.run.shopRemoveCount == 1)
end)
test("last card and empty action slot never execute a command", function()
    local ui, _, click, label = setup("shop", nil, function(run)
        while #run.deck > 1 do table.remove(run.deck) end run.gold = 10000
    end)
    click("tab3") assert(label("action1"):find("仅剩一张", 1, true))
    local before = Combat.copy(ui.run)
    assert(not click("action1")) assert(not click("action8")) same(ui.run, before)
end)

test("an external removal invalidates a still-enabled UI action before charging gold", function()
    local ui, root, click, _, changes = setup("shop", nil, function(run) run.gold = 10000 end)
    click("tab3")
    local first, second = ui.run.deck[1].uid, ui.run.deck[2].uid
    assert(ui.slots[2].enabled)
    assert(Nodes.removeCard(ui.run, first))
    local before = Combat.copy(ui.run)
    assert(not click("action2")) same(ui.run, before)
    assert(ui.run.deck[1].uid == second and ui.run.shopRemoveCount == 1)
    assert(root.children.notice.text == "本店删牌服务已使用")
    assert(#changes == 1 and changes[1].reason == "removal_unavailable" and not changes[1].ok)
end)
test("Cleric healing and leaving show sourced costs and execute once through Nodes", function()
    local ui, _, click, label = setup("event", nil, function(run) run.hp, run.gold = 10, 35 end)
    assert(label("action1"):find("35", 1, true) and label("action1"):find("20", 1, true))
    assert(label("action2"):find("50", 1, true) and not ui.slots[2].enabled)
    local before = Combat.copy(ui.run)
    assert(not click("action2")) same(ui.run, before)
    assert(click("action1")) assert(ui.run.gold == 0 and ui.run.hp == 30 and ui.run.phase == "map")
    before = Combat.copy(ui.run) assert(not click("action1")) same(ui.run, before)
    local leaving, _, leaveClick = setup("event")
    before = Combat.copy(leaving.run)
    assert(leaveClick("action3")) assert(leaving.run.gold == before.gold and leaving.run.hp == before.hp)
    same(leaving.run.deck, before.deck) same(leaving.run.potions, before.potions)
end)

test("Cleric Purify opens a cancellable UID menu and leaves shop removal count unchanged", function()
    local ui, root, click, label = setup("event", nil, function(run) run.gold = 50 end)
    local first, second = ui.run.deck[1].uid, ui.run.deck[2].uid
    local before = Combat.copy(ui.run)
    assert(click("action2") and ui.mode == "purify" and ui.pageCount == 2)
    assert(root.children.leave.visible and label("action1"):find("#" .. first, 1, true))
    assert(click("next") and ui.page == 2)
    assert(click("leave") and ui.mode == "main" and ui.page == 1) same(ui.run, before)
    assert(click("action2") and click("action2"))
    assert(ui.run.gold == 0 and #ui.run.deck == 9 and ui.run.deck[1].uid == first)
    for _, instance in ipairs(ui.run.deck) do assert(instance.uid ~= second) end
    assert((ui.run.shopRemoveCount or 0) == 0 and ui.run.phase == "map")
    before = Combat.copy(ui.run) assert(not click("action2")) same(ui.run, before)
end)

test("Cleric stale affordability is revalidated without consuming the event", function()
    local ui, root, click = setup("event", nil, function(run) run.gold = 50 end)
    assert(click("action2")) ui.run.gold = 49
    local before = Combat.copy(ui.run)
    assert(not click("action1")) same(ui.run, before)
    assert(root.children.notice.text == "金币不足")
    assert(click("leave") and click("action3") and ui.run.phase == "map")
end)
test("treasure grants actual relic once and displays its result", function()
    local ui, root, click = setup("treasure")
    local reward = Nodes.view(ui.run, ui.map).node.reward
    assert(click("action1")) assert(ui.run.relics[#ui.run.relics] == reward.relicId)
    assert(root.children.notice.text:find("宝箱已开启", 1, true))
    local before = Combat.copy(ui.run) assert(not click("action1")) same(ui.run, before)
end)
test("hidden input, external completion, and replaced run reject stale commands", function()
    local ui, _, click = setup("shop", nil, function(run) run.gold = 10000 end)
    ui:setVisible(false) local before = Combat.copy(ui.run)
    for _, name in ipairs({ "action1", "tab2", "next", "previous", "leave" }) do assert(not click(name)) end
    assert(not ui:activate(1) and not ui:setCategory("relics") and not ui:setPage(2) and not ui:leave())
    same(ui.run, before) ui:setVisible(true)
    local oldRun, oldBefore = ui.run, Combat.copy(ui.run) ui.run, ui.map = entered("treasure")
    before = Combat.copy(ui.run) assert(not click("action1")) same(ui.run, before) same(oldRun, oldBefore)
    ui:render() assert(ui.page == 1 and ui.mode == "main")
    assert(click("action1") and ui.run.phase == "map")
end)
test("fresh run without a node renders safely and same-id restart resets navigation", function()
    local ui, root, click = setup("shop")
    click("next") assert(ui.page == 2)
    local previousNode = ui.nodeId
    ui.run, ui.map = Run.new(data, 42), Map.generate(data, 42)
    local beforeRun, beforeMap = Combat.copy(ui.run), Map.snapshot(ui.map)
    ui:render() ui:render()
    same(ui.run, beforeRun) same(ui.map, beforeMap)
    assert(ui.nodeId == nil and ui.page == 1 and not root.children.action1.visible)
    assert(not click("action1") and not click("leave"))
    ui.run, ui.map = entered("shop") ui:render()
    assert(ui.nodeId == previousNode and ui.category == "cards" and ui.page == 1)
    assert(root.children.shop1.visible and not root.children.action1.visible)
end)
test("external node completion blocks old purchase and gold treasure is claimed through Nodes", function()
    local ui, _, click = setup("shop", nil, function(run) run.gold = 10000 end)
    assert(Nodes.leaveShop(ui.run))
    local before = Combat.copy(ui.run) assert(not click("action1")) same(ui.run, before)
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
    ui.run, ui.map = run, map ui:render()
    local gold, reward = run.gold, Nodes.view(run, map).node.reward.gold
    assert(click("action1")) assert(run.gold == gold + reward)
end)
test("a changed balance is revalidated by Nodes and yields a readable error", function()
    local ui, root, click, _, changes = setup("shop", nil, function(run) run.gold = 10000 end)
    ui.run.gold = 0 local before = Combat.copy(ui.run)
    assert(not click("action1")) same(ui.run, before)
    assert(root.children.notice.text == "金币不足" and #changes == 1 and not changes[1].ok)
end)
test("shop and camp show real generated card cost and effect before commitment", function()
    local presentation = require("abyss_presentation")
    local ui, _, click, label = setup("shop")
    ui.presentation = presentation ui:render()
    local before = Combat.copy(ui.run)
    for page = 1, ui.pageCount do
        assert(ui:setPage(page))
        for i, action in ipairs(ui.slots) do
            local card = assert(presentation[action.argument])
            assert(label("action" .. i):find("费用 " .. card.cost .. " 能量", 1, true))
            assert(label("action" .. i):find(card.text, 1, true))
            assert(label("action" .. i):find("\n", 1, true))
        end
    end
    same(ui.run, before)
    local camp, _, campClick, campLabel = setup("camp")
    camp.presentation = presentation camp:render()
    before = Combat.copy(camp.run) assert(campClick("action2"))
    for page = 1, camp.pageCount do
        assert(camp:setPage(page))
        for i, action in ipairs(camp.slots) do
            local instance = assert((function()
                for _, item in ipairs(camp.run.deck) do if item.uid == action.argument then return item end end
            end)())
            local card = assert(presentation[instance.cardId])
            assert(campLabel("action" .. i):find("升级后 · 费用 " .. card.upgradeCost .. " 能量", 1, true))
            assert(campLabel("action" .. i):find(card.upgradeText, 1, true))
        end
    end
    same(camp.run, before)
end)
print("LUA_NODE_UI_PASS " .. count)
