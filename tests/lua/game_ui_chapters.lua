local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local Map=require('abyss_map')
local Nodes=require('abyss_nodes')
local count=0
local function test(name,fn)fn();count=count+1;print('ok chapter host '..count..' - '..name)end
local function fixture(campaign)
    local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
    local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{
        seed=42,prologue=false,campaign=campaign,imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
    root.ui=ui
    assert(testStart(ui))
    return ui,root
end
local function chest(ui)
    local map=ui.map
    while #Map.available(map)>0 do assert(Map.choose(map,Map.available(map)[1].id))end
    local run=ui.run
    run.floor,run.phase=17,'node'
    run.nodeFlow={id=map.currentNodeId,floor=17,type='treasure',roomKind='boss_treasure',
        mapSeed=map.seed,mapSignature=map.sourceSignature,complete=false,reward={relics={}}}
    ui:refresh()
end
test('campaign remains opt-in and does not replace normal launch rules',function()
    local ordinary=fixture(false)
    assert(not ordinary.run.campaign and ordinary.run.phase=='map')
    local campaign=fixture(true)
    assert(campaign.run.campaign and campaign.run.act==1,'host dropped explicit campaign option')
end)
test('Boss treasure continue advances the same run and map through the real host',function()
    local ui,root=fixture(true)
    local run,map=ui.run,ui.map
    chest(ui)
    run.hp=11
    assert(Nodes.claimBossTreasure(run,0))
    ui:refresh()
    assert(ui.mode=='node' and run.phase=='act_transition','host stranded transition on an empty map')
    local seed,uid,gold=run.runSeed,run.deck[1].uid,run.gold
    assert(ui.nodeUI:press('confirm'))
    assert(ui.run==run and ui.map==map and run.act==2 and run.phase=='map')
    assert(run.hp==run.maxHp and run.runSeed==seed and run.deck[1].uid==uid and run.gold==gold)
    assert(ui.mapUI.map==map and ui.nodeUI.map==map and ui.nodeUI.run==run)
    assert(map.floor==17 and ui.mapUI.navigationEnabled and ui.mapUI.scroll==0)
    assert(F.mapControl(root:GetChild('mapPanel'),'title').text:find('第二幕',1,true))
    assert(not ui:advanceAct(),'a repeated continue advanced another chapter')
end)
test('failed chapter transition leaves owners intact and can be retried explicitly',function()
    local ui=fixture(true)
    chest(ui)
    assert(Nodes.claimBossTreasure(ui.run,0));ui:refresh()
    ui.run.encounters.act=2
    local run,map,hp=ui.run,ui.map,ui.run.hp
    local ok,reason=ui:advanceAct()
    assert(not ok and reason=='encounter_act_mismatch')
    assert(ui.run==run and ui.map==map and map.floor==17 and run.hp==hp and run.act==1)
    assert(ui.mode=='node' and ui.nodeUI.notice~='','failed transition must stay actionable')
    run.encounters.act=1
    assert(ui:advanceAct());assert(run.act==2 and ui.mode=='map')
end)
test('native treasure skip shows its result before continuing into the next chapter',function()
    local ui=fixture(true)
    chest(ui)
    assert(ui.nodeUI:press('treasureView/chest'))
    assert(ui.nodeUI:press('back'))
    assert(ui.run.phase=='act_transition' and ui.mode=='node')
    assert(ui.run.act==1 and ui.nodeUI.notice=='已跳过首领遗物','claim bypassed its completion notice')
    assert(ui.nodeUI.root:GetChild('confirm'):GetChild('label').text=='前往下一幕')
    assert(ui:openExit())
    assert(not ui:advanceAct(),'exit overlay failed to block chapter advancement')
    assert(ui.run.act==1)
    assert(ui:closeExit())
    assert(ui.nodeUI:press('confirm'))
    assert(ui.run.act==2 and ui.mode=='map' and not ui.nodeUI:holding())
end)
print('CHAPTER_HOST_PASS '..count)
