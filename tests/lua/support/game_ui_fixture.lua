local GameUI = require("abyss_game_ui")
local Combat = require("abyss_combat")
local Nodes = require("abyss_nodes")
local Data = require("abyss_data")
local Presentation = require("abyss_presentation")
local Layout = require("abyss_ui_layout")
local Templates = require("abyss_ui_templates")
local Viewport = require("abyss_viewport")
local Theme = require("abyss_theme")
local EnemyView = require("abyss_battle_enemy_view")
local function preview(name, text)
    print("LORE_PREVIEW\t" .. name .. "\t" .. text:gsub("\n", "\\n"))
end
-- These methods capture no node state. Keep them as own fields so overrides
-- and pairs/rawget see the same control shape without per-node closures.
local Control = {}
function Control:GetChild(name) return self.children[name] end
function Control:SetVisible(value) assert(type(value) == "boolean"); self.visible = value end
function Control:SetSizeDelta(width, height) self.size = {width, height}; self.sizeDeltaX, self.sizeDeltaY = width, height end
function Control:SetLocalScale(x, y, z) self.scale = {x, y, z}; self.localScaleX, self.localScaleY = x, y end
function Control:SetAnchoredPosition(x, y) self.x, self.y = x, y end
function Control:SetImage(...)
    assert(select("#", ...) == 2, "SetImage expects exactly source and id")
    local source, id = ...
    assert(source == "static" and type(id) == "number"); self.imageId = id
end
function Control:SetAsLastSibling() self.raised = true end
function Control:AddCursorEventListener(event, fn)
    assert(self.kind~='container','Native containers do not support AddCursorEventListener; use a cursorArea')
    self.listeners = self.listeners or {}
    assert(not self.listeners[event], "duplicate cursor listener: " .. tostring(event))
    self.listeners[event] = fn
    if event == "click" then self.click = fn end
end
function Control:AddKeyEventListener(event, fn)
    self.keyListeners = self.keyListeners or {}
    assert(not self.keyListeners[event], 'duplicate key listener')
    self.keyListeners[event] = fn
end

local function control(spec, parent)
    local self = { name = spec.name, kind=spec.kind, children = {}, visible = spec.visible ~= false,
        text = spec.text and spec.text.content or "", parent = parent, interactable = true,
        sizeDeltaX = spec.size and spec.size[1], sizeDeltaY = spec.size and spec.size[2] }
    self.GetChild = Control.GetChild
    self.AddKeyEventListener = Control.AddKeyEventListener
    self.SetVisible = Control.SetVisible
    self.SetSizeDelta = Control.SetSizeDelta
    self.SetLocalScale = Control.SetLocalScale
    self.SetAnchoredPosition = Control.SetAnchoredPosition
    self.SetImage = Control.SetImage
    self.SetAsLastSibling = Control.SetAsLastSibling
    self.AddCursorEventListener = Control.AddCursorEventListener
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
-- Rule and gesture suites start on the map directly; prologue suites pass prologue = true.
local function fixture(data, settle, music, cursorEvents, prologue, sound, pointer)
    local canvas = control({ children = Layout })
    local root = Viewport.apply(canvas, 1280, 720)
    local ui = GameUI.new(root, data or Data, Presentation, "click",
        { seed = 1, imageSource = "static", color = function(r,g,b,a) return { r=r,g=g,b=b,a=a } end, settle = settle, music = music, cursorEvents = cursorEvents,
          prologue = prologue == true, sound = sound, cursorPosition = pointer and pointer.position,
          touchScreen = pointer and pointer.touchScreen, keyEvents = pointer and pointer.keyEvents })
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
                local button = "playArea"
                if reason == "invalid_target" then
                    local screenSlot
                    for i, entry in ipairs(EnemyView.slots(battle)) do
                        if entry.index == ui.battleUI.target then
                            assert(entry.actor == battle.enemies[entry.index] and entry.id == entry.actor.id)
                            screenSlot = i break
                        end
                    end
                    assert(screenSlot, "live target has no displayed enemy slot")
                    button = "enemy" .. screenSlot
                end
                click(root, "battlePanel", button)
            end
        end
        if ui.run.phase == "combat" then click(root, "battlePanel", "endTurn") end
    end
    assert(ui.run.phase == "reward")
end

return {
    GameUI = GameUI,
    Combat = Combat,
    Nodes = Nodes,
    Data = Data,
    Presentation = Presentation,
    Layout = Layout,
    Templates = Templates,
    Viewport = Viewport,
    Theme = Theme,
    preview = preview,
    control = control,
    fixture = fixture,
    statValue = statValue,
    resultText = resultText,
    mapControl = mapControl,
    click = click,
    win = win,
}
