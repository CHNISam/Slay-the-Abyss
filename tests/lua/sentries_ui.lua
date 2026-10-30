local Native=dofile('tests/lua/support/current_monster_controls.lua')
local NativeContract = dofile('tests/lua/support/native_ui_contract.lua')
package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local UI=require("abyss_battle_ui")
local C=require("abyss_combat")
local Run=require("abyss_run")
local Data=require("abyss_data")
local Theme=require("abyss_theme")
local inspectDetails=dofile('tests/lua/support/status_detail_fixture.lua')
local Presentation=require("abyss_presentation")
local Layout=require("abyss_ui_layout")
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function same(a,b)
    assert(type(a)==type(b));if type(a)~="table"then assert(a==b);return end
    for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local canvas=F.control({name="root",size={1280,720},children=Layout})
local stage=F.Viewport.apply(canvas,1280,720):GetChild("battlePanel")
local ui=UI.new(stage,Data,Presentation,"click",F.withMonsterActors({imageSource="static",color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end}),{embedded=true})
ui.run=Run.new(Data,42);ui.run.floor=6;assert(Run.startCombat(ui.run,"elite_sentries"));ui:render()
local function click(name)
    local box=F.actorControl(stage,name)
    if box.click then if box.interactable then box.click()end else box:GetChild("hit").click()end
    if ui.feedback and ui.feedback.busy then for _=1,400 do if not ui.busy then break end;ui:update(.05)end;assert(not ui.busy)end
end
local function expect(outerBolt)
    for i=1,3 do local bolt=(i%2==1)==outerBolt;local box=Native.actor(stage,ui.run.combat.enemies[i])
        assert(box:GetChild("intent").text==(bolt and "" or "9"),"Sentry compact intent "..i..": "..box:GetChild("intent").text)
        assert(box:GetChild("intentIcon").imageId==(bolt and Theme.icon.intent.debuff or Theme.icon.intent.attack))
        local chip=Native.power(box,"artifact")
        assert(chip:GetChild("icon").visible and chip:GetChild("icon").imageId==Theme.icon.status.artifact and chip:GetChild("count").text=="1")
    end
end
expect(true)
local before=C.copy(ui.run.combat)
for _=1,4 do
    click("enemy1");assert(inspectDetails(ui,stage):find("放入你的弃牌堆",1,true))
end
same(ui.run.combat,before)
click("endTurn");expect(false);assert(ui.run.combat.player.hp==71)
click("enemy2");assert(inspectDetails(ui,stage):find("放入你的弃牌堆",1,true))
click("endTurn");expect(true);assert(ui.run.combat.player.hp==53)
print("SENTRIES_GENERATED_UI_PASS compact/detail/icons/Artifact/readonly/two real rounds")
