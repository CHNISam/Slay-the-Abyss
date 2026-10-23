package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI = require("abyss_battle_ui")
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Data = require("abyss_data")
local Theme = require("abyss_theme")
local Presentation = require("abyss_presentation")

local Layout = require("abyss_ui_layout")
-- Separate file keeps the existing battle UI suite inside its unchanged timeout.
-- This is the actual generated full native tree, not a permissive UI mock.
local function control(definition)
    local c = { name = definition.name, visible = definition.visible ~= false, children = {}, text = "",
        sizeDeltaX = definition.size[1], sizeDeltaY = definition.size[2], interactable = true,
        x = definition.position and definition.position[1] or 0, y = definition.position and definition.position[2] or 0 }
    for _, entry in ipairs(definition.children or {}) do c.children[entry.name] = control(entry) end
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:AddCursorEventListener(event, fn)
        self.listeners = self.listeners or {}
        self.listeners[event] = fn
        if event == "click" then self.click = fn end
    end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:SetSizeDelta(x, y) self.sizeDeltaX, self.sizeDeltaY = x, y end
    function c:SetLocalScale(x, y) self.localScaleX, self.localScaleY = x, y end
    function c:SetImage(...)
        assert(select("#", ...) == 2, "SetImage expects exactly source and id")
        local source, id = ...
        assert(source == "static" and type(id) == "number") self.imageId = id
    end
    function c:SetAsLastSibling() self.raised = true end
    return c
end
local function setup()
    local root = control({name="root",size={1280,720},children=Layout})
    local stage = root:GetChild("stage"):GetChild("battlePanel")
    local ui = UI.new(stage,Data,Presentation,"click",{
        imageSource="static",color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end
    },{embedded=true})
    ui.run = Run.new(Data,1)
    ui.run.combat = Combat.new(Data,{enemies={"wizard_gremlin"},deck={"defend"},seed=42})
    ui.run.phase = "combat"
    ui:render()
    local function click(name)
        local box = stage:GetChild(name)
        if box.click then if box.interactable then box.click() end else box:GetChild("hit").click() end
        if ui.feedback and ui.feedback.busy then
            for _=1,400 do if not ui.busy then break end ui:update(0.05) end
            assert(not ui.busy,"presentation must release input")
        end
    end
    return ui,stage,click
end
local ui, stage, click = setup()
local box = stage.children.enemy1
for turn=1,11 do
    local attack = turn == 3 or turn == 7 or turn == 11
    assert(box.children.intent.text == (attack and "25" or "蓄能"), "actual label turn " .. turn)
    assert(box.children.intentIcon.imageId == (attack and Theme.icon.intent.attack or Theme.icon.intent.unknown), "actual icon turn " .. turn)
    click("enemy1")
    assert(stage.children.notice.text:find(attack and "25 点伤害" or "蓄能",1,true), "detail turn " .. turn)
    click("endTurn")
end
assert(ui.run.combat.player.hp == 5)
print("WIZARD_GENERATED_UI_PASS 11 turns, labels/icons/detail/actual button")
