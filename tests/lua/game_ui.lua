local GameUI = require("abyss_game_ui")
local Combat = require("abyss_combat")
local Nodes = require("abyss_nodes")
local Data = require("abyss_data")
local Presentation = require("abyss_presentation")
local Layout = require("abyss_ui_layout")
local count = 0
local function test(name, fn) fn(); count = count + 1; print("ok game UI " .. count .. " - " .. name) end
local function control(spec, parent)
    local self = { children = {}, visible = true, text = spec.text and spec.text.content or "", parent = parent }
    function self:GetChild(name) return assert(self.children[name], "missing " .. name) end
    function self:SetVisible(value) assert(type(value) == "boolean"); self.visible = value end
    function self:AddCursorEventListener(event, fn) assert(event == "click" and not self.click); self.click = fn end
    for _, child in ipairs(spec.children or {}) do self.children[child.name] = control(child, self) end
    return self
end
local function fixture(data)
    local root = control({ children = Layout })
    return GameUI.new(root, data or Data, Presentation, "click"), root
end
local function click(root, panel, button)
    local target = root:GetChild(panel):GetChild(button):GetChild("hit")
    local parent = target
    while parent do assert(parent.visible, "click on hidden control " .. button); parent = parent.parent end
    return target.click()
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
    root:GetChild("mapPanel"):GetChild("node4"):GetChild("hit").click()
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
                click(root, "nodePanel", "action1")
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

test("native lifecycle loads every composed control from the generated tree", function()
    local root = control({ children = Layout })
    local oldScript, oldEnum, oldStart = script, Enum, OnStart
    script, Enum = { object = root }, { CursorEventType = { CursorClick = "click" } }
    dofile("src/lua/abyss_ui.lua")
    OnStart()
    click(root, "menuPanel", "start")
    assert(root:GetChild("mapPanel").visible and not root:GetChild("menuPanel").visible)
    script, Enum, OnStart = oldScript, oldEnum, oldStart
end)
print("LUA_GAME_UI_PASS " .. count)
