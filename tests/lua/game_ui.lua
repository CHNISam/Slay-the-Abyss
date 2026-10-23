local GameUI = require("abyss_game_ui")
local Combat = require("abyss_combat")
local Nodes = require("abyss_nodes")
local Data = require("abyss_data")
local Presentation = require("abyss_presentation")
local Layout = require("abyss_ui_layout")
local Viewport = require("abyss_viewport")
local count = 0
local function test(name, fn) fn(); count = count + 1; print("ok game UI " .. count .. " - " .. name) end
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
local function mapControl(panel, name)
    for _, group in pairs(panel.children) do
        if group.children[name] then return group.children[name] end
    end
    error("missing grouped map control " .. name)
end
local function click(root, panel, button)
    local box = panel == "mapPanel" and mapControl(root:GetChild(panel), button) or root:GetChild(panel):GetChild(button)
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
    click(root, "menuPanel", "start")
    assert(ui.mode == "map" and ui.run ~= previous and ui.map.floor == 0)
    assert(ui.run.gold == Data.rules.player.startingGold and #ui.run.deck == 10 and #ui.run.potions == 0)
    assert(#ui.run.relics == #Data.rules.player.startingRelics and ui.run.nodeFlow == nil)
end)

test("all seven node panels compose through fifteen floors and Boss result then restart", function()
    -- Keep the real rules, commands and UI. Low-HP fixture isolates routing from balance.
    local data = Combat.copy(Data)
    for _, enemy in ipairs(data.enemies.enemies) do enemy.hp = 1 end
    local ui, root = fixture(data)
    click(root, "menuPanel", "start")
    local seen = {}
    for floor = 1, data.rules.map.floors do
        local node = Nodes.available(ui.run, ui.map)[1]
        assert(node and node.floor == floor)
        local slot
        for i, id in pairs(ui.mapUI.slots) do if id == node.id then slot = i break end end
        assert(slot, "next layer missing from focused map page")
        click(root, "mapPanel", "node" .. slot)
        seen[node.type] = true
        if ui.mode == "battle" then
            win(ui, root)
            click(root, "battlePanel", "skip")
        elseif node.type == "shop" then
            if ui.nodeUI.slots[1] and ui.nodeUI.slots[1].enabled then
                local before = ui.run.gold
                click(root, "nodePanel", "shop1")
                assert(ui.run.gold < before)
            end
            click(root, "nodePanel", "leave")
        else
            assert(ui.mode == "node")
            click(root, "nodePanel", "action1")
        end
        assert(ui.map.floor == floor and ui.run.nodeFlow.complete)
        assert(ui.mode == (floor == data.rules.map.bossFloor and "victory" or "map"))
    end
    for _, kind in ipairs(data.rules.map.nodeTypes) do assert(seen[kind], "missing panel " .. kind) end
    assert(root:GetChild("menuPanel"):GetChild("summary").text:find("首领已击败", 1, true))
    click(root, "menuPanel", "start")
    assert(ui.mode == "map" and ui.map.floor == 0 and #ui.run.deck == 10)
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
        assert(root:GetChild("menuPanel"):GetChild("summary").text:find("结算请求失败", 1, true))
    end
    assert(click(root, "menuPanel", "settle") and attempts == 3)
    assert(root:GetChild("menuPanel"):GetChild("settle"):GetChild("label").text == "已发送结算请求")
    assert(ui.mode == "defeat", "sending a signal is not official settlement confirmation")
    local unavailable = fixture()
    unavailable:start() unavailable.run.phase = "defeat" unavailable:refresh()
    local ok, reason = unavailable:settle()
    assert(not ok and reason == "settlement_unavailable" and not unavailable.settlementRequested)
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
print("LUA_GAME_UI_PASS " .. count)
