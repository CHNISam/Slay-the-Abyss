local GameUI = require("abyss_game_ui")
local Combat = require("abyss_combat")
local Nodes = require("abyss_nodes")
local Data = require("abyss_data")
local Presentation = require("abyss_presentation")
local Layout = require("abyss_ui_layout")
local Templates = require("abyss_ui_templates")
local Viewport = require("abyss_viewport")
local Theme = require("abyss_theme")
local count = 0
local function test(name, fn) fn(); count = count + 1; print("ok game UI " .. count .. " - " .. name) end
local function preview(name, text)
    print("LORE_PREVIEW\t" .. name .. "\t" .. text:gsub("\n", "\\n"))
end
local function control(spec, parent)
    local self = { name = spec.name, children = {}, visible = spec.visible ~= false,
        text = spec.text and spec.text.content or "", parent = parent, interactable = true,
        sizeDeltaX = spec.size and spec.size[1], sizeDeltaY = spec.size and spec.size[2] }
    function self:GetChild(name) return self.children[name] end
    function self:SetVisible(value) assert(type(value) == "boolean"); self.visible = value end
    function self:SetSizeDelta(width, height) self.size = {width, height}; self.sizeDeltaX, self.sizeDeltaY = width, height end
    function self:SetLocalScale(x, y, z) self.scale = {x, y, z}; self.localScaleX, self.localScaleY = x, y end
    function self:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function self:SetImage(...)
        assert(select("#", ...) == 2, "SetImage expects exactly source and id")
        local source, id = ...
        assert(source == "static" and type(id) == "number"); self.imageId = id
    end
    function self:SetAsLastSibling() self.raised = true end
    function self:AddCursorEventListener(event, fn) assert(event == "click" and not self.click); self.click = fn end
    if spec.kind == "grid" then
        self.items, self.indexBase = {}, 0
        function self:recycle(slot, index)
            if not self.items[slot] then self.items[slot] = control(assert(Templates[spec.itemTemplate]), self) end
            self.refreshCallback(self.items[slot], index)
            return self.items[slot]
        end
        function self:flush()
            for i = 0, math.min(self.itemCount, 12) - 1 do self:recycle(i, i + self.indexBase) end
        end
        function self:RefreshItems(amount, fn)
            self.itemCount, self.refreshCallback = amount, fn
            if not self.deferRefresh then self:flush() end
        end
    end
    for _, child in ipairs(spec.children or {}) do self.children[child.name] = control(child, self) end
    return self
end
local function fixture(data, settle)
    local canvas = control({ children = Layout })
    local root = Viewport.apply(canvas, 1280, 720)
    local ui = GameUI.new(root, data or Data, Presentation, "click",
        { imageSource = "static", color = function(r,g,b,a) return { r=r,g=g,b=b,a=a } end, settle = settle })
    root.ui = ui
    return ui, root
end
local function statValue(root, key)
    return root:GetChild("menuPanel"):GetChild("result"):GetChild("stat_" .. key):GetChild("value").text
end
local function resultText(root, name) return root:GetChild("menuPanel"):GetChild("result"):GetChild(name).text end
local function mapControl(panel, name)
    for _, group in pairs(panel.children) do
        if group.children[name] then return group.children[name] end
    end
    error("missing grouped map control " .. name)
end
local function click(root, panel, button)
    local box = panel == "mapPanel" and mapControl(root:GetChild(panel), button) or root:GetChild(panel)
    if panel ~= "mapPanel" then for part in button:gmatch("[^/]+") do box = assert(box:GetChild(part), button) end end
    local target = box.click and box or box:GetChild("hit")
    local parent = target
    while parent do assert(parent.visible, "click on hidden control " .. button); parent = parent.parent end
    if target.interactable then
        local result = target.click()
        for _ = 1, 400 do if not root.ui or not root.ui.battleUI.busy then break end root.ui:update(0.05) end
        assert(not root.ui or not root.ui.battleUI.busy)
        return result
    end
end
local function win(ui, root)
    for _ = 1, 60 do
        if ui.run.phase ~= "combat" then break end
        local battle = ui.run.combat
        for _ = 1, 10 do
            if ui.run.phase ~= "combat" then break end
            local slot
            for i, instance in ipairs(battle.hand) do
                if Combat.canPlay(battle, instance.uid, ui.battleUI.target) then slot = i break end
            end
            if not slot then break end
            click(root, "battlePanel", "card" .. slot)
            local instance = ui.run.phase == "combat" and battle.hand[slot]
            if instance and ui.battleUI.selected == instance.uid then
                local _, reason = Combat.canPlay(battle, instance.uid, nil)
                click(root, "battlePanel", reason == "invalid_target" and "enemy" .. ui.battleUI.target or "card" .. slot)
            end
        end
        if ui.run.phase == "combat" then click(root, "battlePanel", "endTurn") end
    end
    assert(ui.run.phase == "reward")
end

test("menu starts real map, enters actual encounter, consumes reward and unlocks next layer", function()
    local ui, root = fixture()
    assert(ui.mode == "menu" and not root:GetChild("mapPanel").visible)
    local intro = root:GetChild("menuPanel"):GetChild("tagline").text
    local guide = root:GetChild("menuPanel"):GetChild("summary").text
    assert(intro == "岩脉失序，封印将破。循着共鸣，深入遗迹。")
    assert(guide:find(ui.battleUI.instructions, 1, true))
    assert(not (intro .. guide):find("十五", 1, true) and not (intro .. guide):find("十七", 1, true))
    preview("intro", intro) preview("menu", guide)
    click(root, "menuPanel", "start")
    assert(ui.mode == "map" and ui.map.floor == 0 and #Nodes.available(ui.run, ui.map) == 3)
    local original = ui.run
    assert(ui:start() == false and ui.run == original)
    click(root, "mapPanel", "node1")
    assert(ui.mode == "battle" and ui.map.floor == 1 and not ui.mapUI.navigationEnabled)
    assert(not root:GetChild("mapPanel").visible and not root:GetChild("nodePanel").visible)
    local floor = ui.map.floor
    mapControl(root:GetChild("mapPanel"), "node4"):GetChild("hit").click()
    assert(ui.map.floor == floor)
    win(ui, root)
    assert(ui.mode == "battle" and ui.run.nodeFlow.complete == false)
    local chosen = ui.run.rewards.cards[1]
    click(root, "battlePanel", "card1")
    assert(ui.mode == "map" and ui.run.nodeFlow.complete and #ui.run.deck == 11)
    assert(ui.run.deck[11].cardId == chosen and ui.mapUI.navigationEnabled)
    local before = #ui.run.deck
    root:GetChild("battlePanel"):GetChild("card1"):GetChild("hit").click()
    assert(#ui.run.deck == before)
    local nextNode = Nodes.available(ui.run, ui.map)[1]
    assert(ui.mapUI:choose(nextNode.id))
    assert(ui.map.floor == 2 and ui.run.floor == 2)
end)

test("defeat returns to menu and restart replaces the complete same-run state", function()
    local ui, root = fixture()
    click(root, "menuPanel", "start") click(root, "mapPanel", "node1")
    local previous = ui.run
    previous.combat.player.hp = 1
    click(root, "battlePanel", "endTurn")
    assert(ui.mode == "defeat" and root:GetChild("menuPanel").visible)
    local ending = resultText(root, "subtitle")
    assert(ending == "封印尚未修复，旅途仍可重启。")
    preview("defeat", ending)
    click(root, "menuPanel", "start")
    assert(ui.mode == "map" and ui.run ~= previous and ui.map.floor == 0)
    assert(ui.run.gold == Data.rules.player.startingGold and #ui.run.deck == 10 and #ui.run.potions == 0)
    assert(#ui.run.relics == #Data.rules.player.startingRelics and ui.run.nodeFlow == nil)
end)

test("node panels compose through fifteen generated rows and Boss16 then restart", function()
    -- Keep the real rules, commands and UI. Low-HP fixture isolates routing from balance.
    local data = Combat.copy(Data)
    for _, enemy in ipairs(data.enemies.enemies) do enemy.hp = 1 end
    local ui, root = fixture(data)
    click(root, "menuPanel", "start")
    local seen = {}
    for floor = 1, data.rules.map.bossFloor do
        local node = Nodes.available(ui.run, ui.map)[1]
        assert(node and node.floor == floor)
        local slot
        for i, id in pairs(ui.mapUI.slots) do if id == node.id then slot = i break end end
        assert(slot, "next layer missing from focused map page")
        click(root, "mapPanel", "node" .. slot)
        seen[node.type] = true
        if node.type == "boss" then
            local notice = root:GetChild("battlePanel"):GetChild("notice")
            assert(notice.text == "昔日的封印守卫，已被深渊侵蚀。")
            preview("boss", notice.text)
            notice.text = "操作提示优先"
            ui:refresh()
            assert(notice.text == "操作提示优先", "entry copy must not overwrite interaction notices")
        end
        if ui.mode == "battle" then
            win(ui, root)
            click(root, "battlePanel", "skip")
        elseif node.type == "shop" then
            if ui.nodeUI.actions["shopView/card1"].enabled then
                local before = ui.run.gold
                click(root, "nodePanel", "shopView/card1")
                assert(ui.run.gold < before)
            end
            click(root, "nodePanel", "confirm")
        else
            assert(ui.mode == "node")
            if node.type == "event" then
                local leaveSlot
                for i = 1, 3 do
                    local option = root:GetChild("nodePanel"):GetChild("eventView"):GetChild("option" .. i)
                    if option.visible and option:GetChild("title").text == "［离开］" then leaveSlot = i end
                end
                assert(leaveSlot); click(root, "nodePanel", "eventView/option" .. leaveSlot)
            elseif node.type == "treasure" then
                click(root, "nodePanel", "treasureView/chest"); click(root, "nodePanel", "treasureView/take")
            elseif ui.nodeUI.actions["campView/rest"].enabled then click(root, "nodePanel", "campView/rest")
            else
                click(root, "nodePanel", "campView/forge"); click(root, "nodePanel", "pickerView/card1")
                click(root, "nodePanel", "confirm")
            end
            if node.type == "camp" or node.type == "event" then
                -- The result stays on the node panel until the player continues.
                assert(ui.mode == "node" and ui.run.phase == "map" and not ui.mapUI.navigationEnabled)
                click(root, "nodePanel", "confirm")
            end
        end
        assert(ui.map.floor == floor and ui.run.nodeFlow.complete)
        assert(ui.mode == (floor == data.rules.map.bossFloor and "victory" or "map"))
    end
    -- Optional shop/event/elite rooms are no longer artificially forced on every route.
    for _, kind in ipairs({"combat", "treasure", "camp", "boss"}) do assert(seen[kind], "missing mandatory panel " .. kind) end
    assert(root:GetChild("menuPanel"):GetChild("title").text == "深渊已被封印")
    assert(statValue(root, "floor") == data.rules.map.bossFloor .. " / " .. data.rules.map.bossFloor)
    assert(resultText(root, "subtitle") == "封印重燃，深渊退去。旅行者继续前行。")
    preview("victory", resultText(root, "subtitle"))
    click(root, "menuPanel", "start")
    assert(ui.mode == "map" and ui.map.floor == 0 and #ui.run.deck == 10)
end)

test("same-run result records active time and victories, freezes on results and resets on restart", function()
    local ui, root = fixture()
    ui:update(100)
    assert(ui:start())
    assert(ui.run.elapsedSeconds == 0 and ui.run.victories == 0)
    ui:update(60.5) ui:update(1.75)
    assert(ui.run.elapsedSeconds == 62.25)
    for _, dt in ipairs({-1, math.huge, -math.huge, 0/0, "1", false}) do
        local ok, reason = ui:update(dt)
        assert(not ok and reason == "invalid_delta" and ui.run.elapsedSeconds == 62.25)
    end
    assert(not ui:update(nil))
    assert(ui.mapUI:choose(Nodes.available(ui.run, ui.map)[1].id))
    local battle = ui.run.combat
    for _, enemy in ipairs(battle.enemies) do enemy.hp = 0 end
    assert(require("abyss_run").finishCombat(ui.run))
    assert(ui.run.victories == 1)
    assert(not require("abyss_run").finishCombat(ui.run) and ui.run.victories == 1)
    assert(require("abyss_run").claimCardReward(ui.run, 0))
    ui:refresh() ui:update(1)
    assert(ui.run.elapsedSeconds == 63.25)
    ui.run.phase = "defeat" ui:refresh()
    assert(statValue(root, "time") == "01:03" and statValue(root, "victories") == "1")
    ui:update(100)
    assert(ui.run.elapsedSeconds == 63.25)
    assert(ui:start() and ui.run.elapsedSeconds == 0 and ui.run.victories == 0)
    ui:update(3)
    ui.run.nodeFlow = {complete=true, result="boss_victory"}
    ui:refresh() ui:update(100)
    assert(ui.run.elapsedSeconds == 3)
    assert(statValue(root, "time") == "00:03")
end)

test("result settlement sends each outcome once and cannot restart while official settlement is pending", function()
    local outcomes = {}
    local ui, root = fixture(nil, function(victory) outcomes[#outcomes + 1] = victory end)
    assert(not ui:settle() and #outcomes == 0)
    assert(not root:GetChild("menuPanel"):GetChild("settle").visible)
    assert(ui:start()) assert(not ui:settle())
    ui.run.phase = "defeat" ui:refresh()
    assert(ui:start() and not ui.settlementRequested)
    ui.run.phase = "defeat" ui:refresh()
    assert(root:GetChild("menuPanel"):GetChild("start").x < 0)
    assert(root:GetChild("menuPanel"):GetChild("settle").visible)
    assert(click(root, "menuPanel", "settle"))
    assert(#outcomes == 1 and outcomes[1] == false and ui.settlementRequested)
    assert(root:GetChild("menuPanel"):GetChild("settle"):GetChild("disabled").visible)
    assert(not ui:settle() and #outcomes == 1)
    assert(not ui:start() and not root:GetChild("menuPanel"):GetChild("start").visible)
    ui, root = fixture(nil, function(victory) outcomes[#outcomes + 1] = victory end)
    assert(ui:start())
    ui.run.phase = "map"
    ui.run.nodeFlow = {complete=true, result="boss_victory"}
    ui:refresh() assert(ui.mode == "victory")
    assert(click(root, "menuPanel", "settle"))
    assert(#outcomes == 2 and outcomes[2] == true)
    assert(not ui:settle() and #outcomes == 2)
end)

test("settlement callback failure is visible and retryable without claiming official completion", function()
    local attempts, ui = 0, nil
    local root
    ui, root = fixture(nil, function()
        attempts = attempts + 1
        assert(not ui:settle(), "reentrant settlement must be rejected")
        if attempts == 1 then error("injected send failure") end
        if attempts == 2 then return false end
    end)
    ui:start() ui.run.phase = "defeat" ui:refresh()
    for _ = 1, 2 do
        assert(not click(root, "menuPanel", "settle"))
        assert(not ui.settlementRequested and not ui.settlementBusy)
        assert(resultText(root, "status"):find("结算请求失败", 1, true))
        preview("settlementError", resultText(root, "status"))
    end
    assert(click(root, "menuPanel", "settle") and attempts == 3)
    assert(root:GetChild("menuPanel"):GetChild("settle"):GetChild("label").text == "已发送结算请求")
    assert(ui.mode == "defeat", "sending a signal is not official settlement confirmation")
    local unavailable = fixture()
    unavailable:start() unavailable.run.phase = "defeat" unavailable:refresh()
    local ok, reason = unavailable:settle()
    assert(not ok and reason == "settlement_unavailable" and not unavailable.settlementRequested)
    assert(resultText(root, "status") ~= nil)
    local line = unavailable.root:GetChild("menuPanel"):GetChild("result"):GetChild("status").text
    assert(line:find("暂不可用", 1, true) and not unavailable.root:GetChild("menuPanel"):GetChild("settle"):GetChild("normal").visible)
end)

test("menu copy follows the current map rules instead of the legacy fifteen-floor line", function()
    local ui, root = fixture()
    local menu, rules = root:GetChild("menuPanel"), Data.rules.map
    assert(ui.mode == "menu" and menu:GetChild("tagline").visible and not menu:GetChild("result").visible)
    local route = menu:GetChild("summary").text
    assert(route:find(rules.generatedRows .. " 层岔路", 1, true) and route:find("第 " .. rules.bossFloor .. " 层", 1, true))
    for _, name in ipairs({"title", "tagline", "summary"}) do
        assert(not menu:GetChild(name).text:find("十五层", 1, true), name .. " keeps the stale floor count")
    end
    assert(menu:GetChild("summary").text:find(ui.battleUI.instructions, 1, true))
    assert(menu:GetChild("start"):GetChild("label").text == "启程" and not menu:GetChild("settle").visible)
end)

test("result page shows only the recorded run stats in the approved four cells", function()
    local ui, root = fixture(nil, function() end)
    assert(ui:start())
    ui.run.victories, ui.run.elapsedSeconds, ui.run.gold, ui.run.hp = 7, 3725.9, 211, 33
    ui.run.phase = "defeat" ui:refresh()
    local menu = root:GetChild("menuPanel")
    assert(menu:GetChild("result").visible and not menu:GetChild("summary").visible and not menu:GetChild("tagline").visible)
    assert(menu:GetChild("title").text == "旅途在此中断")
    assert(resultText(root, "subtitle") == "封印尚未修复，旅途仍可重启。")
    assert(statValue(root, "floor") == ui.map.floor .. " / " .. Data.rules.map.bossFloor)
    assert(statValue(root, "victories") == "7" and statValue(root, "time") == "62:05")
    assert(statValue(root, "deck") == tostring(#ui.run.deck))
    local labels = {}
    for _, key in ipairs({"floor", "victories", "time", "deck"}) do
        labels[#labels + 1] = menu:GetChild("result"):GetChild("stat_" .. key):GetChild("label").text
    end
    assert(table.concat(labels, "|") == "抵达层数|战斗胜场|用时|卡组张数")
    -- Defeat always reports 0 HP; untracked prototype figures (enemies slain, gold earned) never appear.
    assert(resultText(root, "detail") == "生命 0 / " .. ui.run.maxHp .. " · 金币 211 · 遗物 " .. #ui.run.relics .. " 件")
    for _, name in ipairs({"subtitle", "detail", "status"}) do
        assert(not resultText(root, name):find("击败敌人", 1, true) and not resultText(root, name):find("获得金币", 1, true))
    end
    assert(menu:GetChild("start"):GetChild("label").text == "重新启程")
    assert(resultText(root, "status"):find("不会提交", 1, true))
    ui.run.phase = "map" ui.run.nodeFlow = {complete=true, result="boss_victory"} ui:refresh()
    assert(menu:GetChild("title").text == "深渊已被封印" and resultText(root, "detail"):find("生命 33 / ", 1, true))
    assert(resultText(root, "subtitle") == "封印重燃，深渊退去。旅行者继续前行。")
end)

test("repeated settlement clicks, clicks during reveal and restart attempts submit exactly once", function()
    local outcomes = {}
    local ui, root = fixture(nil, function(victory) outcomes[#outcomes + 1] = victory return true end)
    local menu = root:GetChild("menuPanel")
    assert(ui:start()) ui.run.phase = "defeat" ui:refresh()
    assert(ui.motion.t == 0, "reveal has just begun")
    local hit = menu:GetChild("settle"):GetChild("hit")
    assert(menu:GetChild("settle").visible and menu:GetChild("start").visible, "reveal never hides result actions")
    assert(hit.click() == true)
    for _ = 1, 5 do assert(hit.click() == false) end
    ui:update(0.05) assert(hit.click() == false)
    assert(menu:GetChild("start"):GetChild("hit").click() == false and ui.mode == "defeat")
    assert(#outcomes == 1 and outcomes[1] == false)
    assert(menu:GetChild("settle"):GetChild("disabled").visible and not menu:GetChild("settle"):GetChild("normal").visible)
    assert(resultText(root, "status"):find("已发送", 1, true))
    ui:refresh() ui:update(1) ui:refresh()
    assert(#outcomes == 1, "refresh and animation frames never resend")
    -- A fresh host (platform Retry reloads the stage) may settle its own result once.
    ui, root = fixture(nil, function(victory) outcomes[#outcomes + 1] = victory return true end)
    hit = root:GetChild("menuPanel"):GetChild("settle"):GetChild("hit")
    assert(ui:start()) ui.run.phase = "map" ui.run.nodeFlow = {complete=true, result="boss_victory"} ui:refresh()
    assert(hit.click() == true and hit.click() == false)
    assert(#outcomes == 2 and outcomes[2] == true)
end)

test("result reveal settles exactly on approved frames and feedback motion never hides controls", function()
    local L, T = Theme.layout.nativeMenu, Theme.motion
    local fail = true
    local ui, root = fixture(nil, function() return not fail end)
    local menu = root:GetChild("menuPanel")
    local result, emblem, settle = menu:GetChild("result"), menu:GetChild("emblem"), menu:GetChild("settle")
    assert(ui:start()) ui.run.phase = "defeat" ui:refresh()
    assert(math.abs(emblem.scale[1] - L.reveal.emblemFrom) < 1e-9)
    assert(menu:GetChild("title").y < L.title[2])
    local card = result:GetChild("stat_deck")
    assert(card.scale[1] < 1 and card.visible)
    ui:update(T.slow / 2)
    assert(card.scale[1] < 1 and result:GetChild("stat_floor").scale[1] > card.scale[1], "cards reveal in order")
    ui:update(1)
    assert(emblem.scale[1] == 1 and menu:GetChild("title").y == L.title[2] and result:GetChild("subtitle").y == L.subtitle[2])
    for i, key in ipairs({"floor", "victories", "time", "deck"}) do
        local stat = result:GetChild("stat_" .. key)
        assert(stat.scale[1] == 1 and stat.x == L.stats.origin[1] + (i - 1) * L.stats.step and stat.y == L.stats.origin[2])
    end
    assert(menu:GetChild("start").x == L.resultRestart[1] and settle.x == L.settle[1])
    assert(not ui:settle())
    assert(settle.x == L.settle[1] and ui.motion.shake == 0)
    ui:update(T.shake / 3)
    assert(settle.x ~= L.settle[1] and settle.visible, "failure shakes the button in place")
    ui:update(1)
    assert(settle.x == L.settle[1] and settle:GetChild("normal").visible)
    fail = false
    assert(ui:settle())
    ui:update(T.base / 2)
    assert(settle.x > 0 and settle.x < L.settle[1], "requested button slides toward centre")
    ui:update(1)
    assert(settle.x == 0 and settle.visible and not menu:GetChild("start").visible)
    local glow = emblem:GetChild("glow")
    ui:update(L.reveal.breathe / 4)
    assert(glow.scale[1] > 1 and glow.scale[1] <= 1 + L.reveal.breatheScale + 1e-9)
end)

test("viewport scales each device uniformly and covers wider canvas outside the stage", function()
    local root = control({ children = Layout })
    for _, device in ipairs({{1280,720,1}, {1600,900,1.25}, {1920,1080,1.5}, {2340,1080,1.5}}) do
        local stage, scale = Viewport.apply(root, device[1], device[2])
        assert(scale == device[3] and stage.scale[1] == scale and stage.scale[2] == scale)
        assert(root:GetChild("canvasBackdrop").size[1] == device[1])
        assert(root:GetChild("canvasBackdrop").size[2] == device[2])
    end
    assert(not pcall(Viewport.apply, root, 0, 720))
end)

test("host defers defeat routing until the final feedback banner and releases result input once", function()
    local ui, root = fixture()
    assert(ui:start()) assert(ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id))
    ui.run.combat.player.hp = 1 ui.battleUI:render()
    ui.battleUI:endTurn()
    assert(ui.run.phase == "defeat" and ui.battleUI.busy)
    ui:refresh()
    assert(ui.mode == "battle" and not root:GetChild("menuPanel").visible)
    local sawDefeat = false
    for _ = 1, 200 do
        if not ui.battleUI.busy then break end
        if ui.battleUI.feedback.current.kind == "defeat" then
            sawDefeat = true assert(ui.mode == "battle" and root:GetChild("battlePanel").visible)
        end
        ui:update(0.05)
    end
    assert(sawDefeat and ui.mode == "defeat" and root:GetChild("menuPanel").visible)
    assert(not ui.battleUI.busy)
end)

test("native lifecycle loads every composed control and registers its listeners only once", function()
    local canvas = control({ children = Layout })
    local root = canvas:GetChild("stage")
    local oldScript, oldEnum, oldStart, oldUpdate, oldGame, oldColor = script, Enum, OnStart, OnUpdate, game, Color
    script = { object = canvas, EnableUpdate = function(self, value) self.updating = value end }
    Enum = { CursorEventType = { CursorClick = "click" }, ImageSource = { StaticReference = "static" } }
    Color = setmetatable({ FromRGB = function() end }, {
        __call = function(_,r,g,b,a) return {r=r,g=g,b=b,a=a} end,
    })
    local width, height = 1600, 900
    game = { GetUICanvasSize = function() return width, height end }
    dofile("src/lua/abyss_ui.lua")
    OnStart()
    OnStart()
    assert(root.scale[1] == 1.25)
    assert(script.updating)
    click(root, "menuPanel", "start")
    assert(root:GetChild("mapPanel").visible and not root:GetChild("menuPanel").visible)
    width, height = 2340, 1080
    OnUpdate(0.25)
    assert(root.scale[1] == 1.5 and canvas:GetChild("canvasBackdrop").size[1] == width)
    assert(root:GetChild("mapPanel").localScaleX == nil or root:GetChild("mapPanel").localScaleX == 1)
    script, Enum, OnStart, OnUpdate, game, Color = oldScript, oldEnum, oldStart, oldUpdate, oldGame, oldColor
end)
test("startup failure is visible without log subscription and hides the dead start button", function()
    local canvas = control({ children = Layout })
    local oldScript, oldEnum, oldStart, oldUpdate, oldGame, oldColor = script, Enum, OnStart, OnUpdate, game, Color
    local originalNew = GameUI.new
    GameUI.new = function() error("INJECTED_STARTUP_FAILURE") end
    script = {object=canvas, EnableUpdate=function(self,value) self.updating=value end}
    Enum = {CursorEventType={CursorClick="click"},ImageSource={StaticReference="static"}}
    game = {GetUICanvasSize=function() return 1280,720 end,IsTestPlay=function() return true end}
    dofile("src/lua/abyss_ui.lua")
    OnStart()
    local stage = canvas:GetChild("stage")
    local menu = stage:GetChild("menuPanel")
    assert(menu.visible and menu:GetChild("summary").text:match("INJECTED_STARTUP_FAILURE"))
    assert(not menu:GetChild("start").visible and script.updating == false)
    assert(not stage:GetChild("mapPanel").visible and not stage:GetChild("battlePanel").visible)
    OnStart() OnUpdate(0.1)
    GameUI.new = originalNew
    script, Enum, OnStart, OnUpdate, game, Color = oldScript, oldEnum, oldStart, oldUpdate, oldGame, oldColor
end)

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for key, value in pairs(a) do if not same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function deckGrid(root) return root:GetChild("deckPanel"):GetChild("grid") end
local function openDeck(ui, root)
    assert(root:GetChild("deckEntry").visible)
    assert(root:GetChild("deckEntry"):GetChild("open"):GetChild("hit").click())
    ui:update(0)
    assert(root:GetChild("deckPanel").visible)
    return deckGrid(root)
end
local function closeDeck(root) return root:GetChild("deckPanel"):GetChild("close"):GetChild("hit").click() end

test("deck overlay reads permanent UID and upgraded text and never changes the run or route", function()
    local ui, root = fixture()
    assert(not ui:openDeck() and not root:GetChild("deckEntry").visible)
    ui:start()
    ui.run.deck[1].upgraded = true
    for i = 11, 40 do ui.run.deck[i] = {uid=100+i,cardId=ui.run.deck[1].cardId,upgraded=i%2==0} end
    local beforeRun, beforeMap = Combat.copy(ui.run), Combat.copy(ui.map)
    local grid = openDeck(ui, root)
    assert(grid.itemCount == 40 and grid.scrollProgress == 0)
    local first = grid.items[0]
    assert(first:GetChild("uid").text == "UID " .. ui.run.deck[1].uid)
    local face = first:GetChild("face")
    local display = Presentation[ui.run.deck[1].cardId]
    assert(face:GetChild("name").text == display.name .. "＋")
    assert(face:GetChild("label").text == display.upgradeText)
    local last = grid:recycle(0, 39)
    assert(last == first and last:GetChild("uid").text == "UID 140")
    assert(last:GetChild("face"):GetChild("label").text == display.upgradeText)
    assert(not ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id))
    local scroll = ui.mapUI.scroll
    assert(root:GetChild("mapPanel").visible and not ui.mapUI.visible)
    assert(not ui.mapUI:scrollBy(100) and ui.mapUI.scroll == scroll)
    mapControl(root:GetChild("mapPanel"),"focus"):GetChild("hit").click()
    assert(ui.mapUI.scroll == scroll)
    assert(not ui:start() and not ui:settle())
    assert(same(beforeRun,ui.run) and same(beforeMap,ui.map), "view changed rules or RNG")
    local delayed = grid.refreshCallback
    assert(closeDeck(root))
    delayed(first,0) -- old virtualized callbacks must not repopulate a closed overlay
    assert(not root:GetChild("deckPanel").visible and grid.itemCount == 0)
    assert(ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id), "map input did not resume")
end)

test("grid discovers runtime index origin, including deferred callbacks, and reopens with fresh ownership", function()
    local ui, root = fixture()
    ui:start()
    local grid = deckGrid(root)
    grid.indexBase, grid.deferRefresh = 1, true
    assert(ui:openDeck())
    local calibration = grid.refreshCallback
    ui:update(0)
    assert(grid.itemCount == 1)
    grid:flush() ui:update(0) grid:flush()
    assert(grid.itemCount == #ui.run.deck)
    assert(grid.items[0]:GetChild("uid").text == "UID " .. ui.run.deck[1].uid)
    local oldUid = grid.items[1]:GetChild("uid").text
    calibration(grid.items[1],1)
    assert(not ui.deckUI.pending and grid.items[1]:GetChild("uid").text == oldUid)
    local stale = grid.refreshCallback
    assert(closeDeck(root))
    table.remove(ui.run.deck,1)
    assert(ui:openDeck()) grid:flush() ui:update(0) grid:flush()
    local card = grid.items[0]
    local text = card:GetChild("uid").text
    stale(card,1)
    assert(card:GetChild("uid").text == text and text == "UID " .. ui.run.deck[1].uid)
    assert(not ui:openDeck(), "duplicate open must not reset the scroller")
    assert(closeDeck(root))
end)

test("battle overlay cancels pending drag and blocks cards, potions, turn and reward commands", function()
    local ui, root = fixture()
    ui:start() assert(ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id))
    local battle = ui.run.combat
    local instance = battle.hand[1]
    ui.battleUI.gesture = {run=ui.run,battle=battle,turn=battle.turn,uid=instance.uid}
    ui.battleUI.selected = instance.uid
    local before = Combat.copy(ui.run)
    openDeck(ui,root)
    assert(not ui.battleUI.gesture and not ui.battleUI.selected)
    assert(root:GetChild("battlePanel").visible and not ui.battleUI.active)
    ui.battleUI:playSlot(1) ui.battleUI:playSelected(1) ui.battleUI:endTurn() ui.battleUI:usePotion(1)
    root:GetChild("battlePanel"):GetChild("skip").click()
    assert(same(before,ui.run))
    assert(closeDeck(root) and ui.battleUI.active)
    ui.battleUI:endTurn()
    assert(ui.battleUI.busy and not ui:openDeck(), "feedback must finish before deck opens")
    for _ = 1, 200 do if not ui.battleUI.busy then break end ui:update(0.05) end
    if ui.run.phase == "combat" then assert(ui:openDeck()) end
    ui.run.phase = "defeat" ui:refresh()
    assert(not root:GetChild("deckPanel").visible and not ui:openDeck())
end)

test("node overlay preserves the node presentation while preventing underlying transactions", function()
    local ui, root = fixture()
    ui:start()
    ui.run.hp = 20 -- Rest is enabled only below full health in the approved camp UI.
    local available = Nodes.available(ui.run,ui.map)[1]
    for _, node in ipairs(ui.map.nodes) do if node.id == available.id then node.type = "camp" end end
    assert(ui.mapUI:choose(available.id) and ui.mode == "node")
    local before = Combat.copy(ui.run)
    openDeck(ui,root)
    assert(root:GetChild("nodePanel").visible and not ui.nodeUI.visible)
    assert(not ui.nodeUI:press("campView/rest") and not ui.nodeUI:press("confirm"))
    assert(same(before,ui.run))
    assert(closeDeck(root) and ui.nodeUI:press("campView/rest"))
    assert(ui.mode == "node" and ui.nodeUI:holding())
    assert(ui.nodeUI:press("confirm"))
    assert(ui.mode == "map")
end)

test("deck costs and descriptions use permanent upgraded instances instead of temporary hand growth", function()
    local ui, root = fixture()
    ui:start()
    ui.run.deck = {
        {uid=101,cardId="barricade",upgraded=true}, {uid=102,cardId="whirlwind",upgraded=true},
        {uid=103,cardId="rampage",upgraded=true}, {uid=104,cardId="rampage",upgraded=false},
    }
    assert(ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id))
    for _, card in ipairs(ui.run.combat.hand) do if card.cardId == "rampage" then card.damageBonus = 123 end end
    local before = Combat.copy(ui.run)
    local grid = openDeck(ui,root)
    local face = grid.items[0]:GetChild("face")
    assert(face:GetChild("cost").text == "2" and face:GetChild("label").text == Presentation.barricade.upgradeText)
    assert(grid.items[1]:GetChild("face"):GetChild("cost").text == "X")
    assert(grid.items[2]:GetChild("face"):GetChild("label").text == Presentation.rampage.upgradeText)
    assert(grid.items[3]:GetChild("face"):GetChild("label").text == Presentation.rampage.text)
    assert(same(before,ui.run))
    assert(closeDeck(root))
    ui.run.phase = "map" ui.run.deck = {} ui:refresh()
    grid = openDeck(ui,root)
    assert(grid.itemCount == 0 and not ui.deckUI.pending)
    assert(closeDeck(root))
end)

test("reward view cannot claim or skip beneath the deck overlay and resumes after closing", function()
    local ui, root = fixture()
    ui:start() assert(ui.mapUI:choose(Nodes.available(ui.run,ui.map)[1].id))
    win(ui,root)
    local before = Combat.copy(ui.run)
    local grid = openDeck(ui,root)
    assert(grid.itemCount == #ui.run.deck and grid.itemCount ~= #ui.run.rewards.cards)
    ui.battleUI:playSlot(1)
    root:GetChild("battlePanel"):GetChild("skip").click()
    assert(same(before,ui.run))
    assert(closeDeck(root))
    click(root,"battlePanel","skip")
    assert(ui.mode == "map" and #ui.run.deck == #before.deck)
end)
print("LUA_GAME_UI_PASS " .. count)
