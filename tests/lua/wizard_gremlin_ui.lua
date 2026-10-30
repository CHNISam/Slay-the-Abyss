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
    ui.run.combat = Combat.new(Data,{enemies={"wizard_gremlin"},deck={"defend"},seed=42})
    ui.run.phase = "combat"
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
local ui, stage, click = setup()
local box = Current.actor(stage,ui.run.combat.enemies[1])
for turn=1,11 do
    local attack = turn == 3 or turn == 7 or turn == 11
    assert(box.children.intent.text == (attack and "25" or "") and not box.children.intentLabel.visible, "actual numeric face turn " .. turn)
    if not attack then assert(require('abyss_battle_intent_view').intentView(ui.run.combat,1).label=='蓄能','charge wording turn '..turn)end
    local face=require('abyss_battle_intent_view').intentView(ui.run.combat,1)
    assert(face.sourceEnum==(attack and "ATTACK" or "UNKNOWN"),"original source intent turn "..turn)
    dofile('tests/lua/support/intent_face_assertion.lua')(box,face)
    click(box)
    assert(stage.children.statusInfo.visible and stage.children.statusInfo.children.text1.text:find(attack and "25 点伤害" or "蓄能",1,true), "detail turn " .. turn)
    stage.children.statusInfo.children.hit.click()
    assert(not stage.children.statusInfo.visible)
    click("endTurn")
end
assert(ui.run.combat.player.hp == 5)
print("WIZARD_GENERATED_UI_PASS 11 turns, labels/icons/detail/actual button")
