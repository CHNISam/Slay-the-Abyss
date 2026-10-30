package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local UI = require("abyss_battle_ui")
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Data = require("abyss_data")
local Theme = require("abyss_theme")
local Presentation = require("abyss_presentation")

local Layout = require("abyss_ui_layout")
-- Use the generated full native template engine; actor lookup is by core identity.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Current=dofile('tests/lua/support/current_monster_controls.lua')
local control=F.control
local function setup()
    local root = control({name="root",size={1280,720},children=Layout})
    local stage = root:GetChild("stage"):GetChild("battlePanel")
    local ui = UI.new(stage,Data,Presentation,"click",F.withMonsterActors({
        imageSource="static",color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end
    }),{embedded=true})
    ui.run = Run.new(Data,1)
    assert(Run.startCombat(ui.run,"cultist_solo"))
    ui:render()
    local function click(name)
        local box = type(name)=="string" and stage:GetChild(name) or name
        local hit=box.click and box or box:GetChild("hit")
        assert(hit.raycastTarget~=false,"actual control is not targetable");hit.click()
        if ui.feedback and ui.feedback.busy then
            for _=1,400 do if not ui.busy then break end ui:update(0.05) end
            assert(not ui.busy,"presentation must release input")
        end
    end
    return ui,stage,click
end
-- Read a unit's statuses the way a player does: open its detail panel, then close it.
local function details(stage, box)
    assert(Current.power(box,"ritual").visible,"actual Ritual chip must remain rendered")
    box:GetChild("hit").click()
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
    local box = Current.actor(stage,ui.run.combat.enemies[1])
    assert(box.children.intent.text == "")
    assert(box.children.intentIcon.imageId == Theme.icon.intent.buff)
    click(box)
    assert(stage.children.statusInfo.visible and stage.children.statusInfo.children.text1.text:find("自身获得 3 层仪式",1,true))
    stage.children.statusInfo.children.hit.click()
    assert(not stage.children.statusInfo.visible)
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
