local NativeContract = dofile('tests/lua/support/native_ui_contract.lua')
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI = require("abyss_battle_ui")
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Data = require("abyss_data")
local Theme = require("abyss_theme")
local Presentation = require("abyss_presentation")
local Layout = require("abyss_ui_layout")
local L = Theme.layout
-- Dynamic card numbers and status details on the full generated native tree.
-- The oracle for every preview is the core's own resolution of the same play.
local function control(definition)
    local c = { name = definition.name, visible = definition.visible ~= false, children = {}, text = "",
        sizeDeltaX = definition.size[1], sizeDeltaY = definition.size[2], interactable = true,
        x = definition.position and definition.position[1] or 0, y = definition.position and definition.position[2] or 0 }
    for _, entry in ipairs(definition.children or {}) do c.children[entry.name] = control(entry) end
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:AddCursorEventListener(event, fn) NativeContract.listener(event,fn);
        self.listeners = self.listeners or {}
        self.listeners[event] = fn
        if event == "click" then self.click = fn end
    end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:SetSizeDelta(x, y) NativeContract.sizeDelta(x,y); self.sizeDeltaX, self.sizeDeltaY = x, y end
    function c:SetLocalScale(x, y) self.localScaleX, self.localScaleY = x, y end
    function c:SetImage(...)
        assert(select("#", ...) == 2, "SetImage expects exactly source and id")
        local source, id = ...
        assert(source == "static" and type(id) == "number") self.imageId = id
    end
    function c:SetAsLastSibling() self.raised = true end
    return c
end
local function setup(deck, enemies, drag)
    local root = control({name="root", size={1280,720}, children=Layout})
    local panel = root:GetChild("stage"):GetChild("battlePanel")
    local ui = UI.new(panel, Data, Presentation, "click", {
        imageSource="static", touchScreen=function() return true end, color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end,
        cursorEvents=drag and {CursorDown="down",CursorDrag="drag",CursorUp="up",CursorEndDrag="endDrag"} or nil
    }, {embedded=true})
    ui.run = Run.new(Data, 1)
    assert(Run.startCombat(ui.run, "cultist_solo"))
    ui.run.combat = Combat.new(Data, {deck=deck, enemies=enemies})
    ui:resize(1280, 720) ui:render()
    -- Native listener on a control path such as {"enemy1","statusRow","hit"}.
    local function event(path, kind, x, y, touch, optional)
        local box = panel
        for _, name in ipairs(type(path) == "table" and path or {path}) do box = box:GetChild(name) end
        local hit = box.listeners and box or box:GetChild("hit")
        local callback = hit.listeners and hit.listeners[kind]
        if optional and not callback then return end
        assert(callback, "missing native listener " .. kind)
        callback({touchId=touch or 7, GetUIPos=function() return 640 + (x or 0), 360 + (y or 0) end})
    end
    -- One physical tap: Down/Up where the control listens for them, then Click.
    local function tap(path, touch)
        if drag then event(path, "down", 0, 0, touch) event(path, "up", 0, 0, touch, true) end
        event(path, "click", 0, 0, touch)
    end
    return ui, panel, event, tap
end
local function drain(ui)
    for _ = 1, 600 do if not ui.busy then return end ui:update(0.05) end
    assert(not ui.busy, "feedback must finish")
end
local function eq(a, b, message) assert(a == b, (message or "") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function inline(panel, slot) return panel:GetChild("card" .. (slot or 1)):GetChild("label").text end
-- Existing numerical oracles compare the sentence's values, independently of
-- native colour syntax. New presentation assertions below inspect the raw text.
local function label(panel, slot) return (inline(panel,slot):gsub('<color=#[%x]+>',''):gsub('</color>',''):gsub('↑',''):gsub('↓','')) end
local function battle(deck, enemies)
    local s = Combat.new(Data, {deck=deck, enemies=enemies})
    for _, enemy in ipairs(s.enemies) do enemy.hp, enemy.maxHp = 200, 200 end
    return s
end
-- HP each enemy loses when the core actually plays hand[1] on a copy of the state.
local function resolve(s, target)
    local copy = Combat.copy(s)
    for _, enemy in ipairs(copy.enemies) do enemy.ai = nil end -- reactions are not under test
    local before = {}
    for i, enemy in ipairs(copy.enemies) do before[i] = enemy.hp end
    assert(Combat.play(copy, copy.hand[1].uid, target))
    local lost = {}
    for i, enemy in ipairs(copy.enemies) do lost[i] = before[i] - enemy.hp end
    return lost, copy
end
local count = 0
local function test(name, fn) fn(); count = count + 1; print("ok card preview " .. count .. " - " .. name) end


local ui,panel,event,tap=setup({'strike'},{'jaw_worm','cultist'},true)
local s=ui.run.combat
Combat.addStatus(s.enemies[2],'vulnerable',1)
ui:render()
print('DIAG target_preview initial='..label(panel))
tap('enemy2',71)
assert(ui.target==2 and not ui.selected)
print('DIAG target_preview enemy_locked='..label(panel)..' target='..ui.target)
tap('card1',72)
assert(ui.selected==s.hand[1].uid)
local expected=Combat.cardPreview(s,s.hand[1],2)[1].low
print('DIAG target_preview selected_locked='..label(panel)..' actual_target_preview='..expected)
assert(expected==9 and label(panel)=='对目标造成 6 点伤害。')
local energy,hp=s.energy,s.enemies[2].hp
-- Cancel the selection, then exercise actual touch drag through native listeners.
tap('card1',73)
assert(not ui.selected)
local card=panel:GetChild('card1')
event('card1','down',card.x,card.y,74)
event('card1','drag',L.enemyRow.xTo,L.enemyRow.y,74)
print('DIAG target_preview dragged_aim='..label(panel))
assert(label(panel)=='对目标造成 9 点伤害。')
assert(s.energy==energy and s.enemies[2].hp==hp)
event('card1','up',L.enemyRow.xTo,L.enemyRow.y,74)
drain(ui)
assert(hp-s.enemies[2].hp==9)
print('DIAG target_preview resolved_damage='..(hp-s.enemies[2].hp))
print('MOBILE_TARGET_DIAG_PASS')
