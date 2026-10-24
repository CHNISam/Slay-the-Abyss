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
    assert(Run.startCombat(ui.run,"cultist_solo"))
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
-- Read a unit's statuses the way a player does: open its detail panel, then close it.
local function details(stage, box)
    box.children.statusRow.children.hit.click()
    local info, lines = stage.children.statusInfo, {}
    assert(info.visible)
    for i = 1, Theme.layout.statusInfo.rows do
        if info.children["name" .. i].visible then lines[#lines + 1] = info.children["name" .. i].text end
    end
    info.children.hit.click()
    assert(not info.visible)
    return table.concat(lines, " | ")
end
local count = 0
local function test(name,fn) fn(); count=count+1; print("ok Cultist UI "..count.." - "..name) end

test("Cultist displays Ritual opener, persistent status and next modified attack", function()
    local ui, stage, click = setup()
    local box = stage.children.enemy1
    assert(box.children.intent.text == "")
    assert(box.children.intentIcon.imageId == Theme.icon.intent.buff)
    click("enemy1")
    assert(stage.children.notice.text:find("自身获得 3 层仪式",1,true))
    click("endTurn")
    local text = details(stage, box)
    assert(text:find("仪式 3",1,true))
    assert(not text:find("力量",1,true))
    assert(box.children.intent.text == "6")
    click("endTurn")
    text = details(stage, box)
    assert(text:find("仪式 3",1,true))
    assert(text:find("力量 3",1,true))
    assert(box.children.intent.text == "9")
end)
print("LUA_CULTIST_UI_PASS " .. count)
