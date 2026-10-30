local F=dofile('tests/lua/support/game_ui_fixture.lua')
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local created,ticks,settled,paused=0,0,0,0
local owner={sync=function(_,mode)if mode=='node'then paused=paused+1 end end,
 tick=function()ticks=ticks+1 end,status=function()return {phase='ready'}end,onEngineDestroy=function()end}
local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=1,imageSource='static',color=function(...)return {...}end,
 createEasterEggArt=function()created=created+1;return owner end,settle=function()settled=settled+1;return true end})
local menu=root:GetChild('menuPanel')
local button=menu:GetChild('result'):GetChild('viewEasterEgg'):GetChild('hit')
assert(created==0 and not button.click())
assert(F.start(ui));assert(created==0 and not button.click())
ui.run.phase='defeat';ui:refresh();assert(not button.click() and created==0,'defeat exposed the victory egg')
ui.run.phase='victory';ui.run.nodeFlow={complete=true,result='boss_treasure_complete'};ui:refresh()
assert(menu:GetChild('result'):GetChild('viewEasterEgg').visible and created==0)
local run=ui.run
assert(button.click() and created==1 and ui.easterEggOpen and not menu.visible)
assert(not ui:start() and not ui:settle() and not ui:openMenu() and settled==0,'egg leaked commands to results')
ui:update(.016);assert(ticks==1)
assert(root:GetChild('victoryEasterEgg'):GetChild('close'):GetChild('hit').click())
assert(not ui.easterEggOpen and menu.visible and ui.run==run and paused==1)
ui:update(.016);assert(ticks==1,'closed egg kept loading')
assert(button.click() and created==1,'reopening rebuilt the cached illustration')
assert(ui.easterEgg:close() and ui:settle() and settled==1)
ui:onEngineDestroy()
print('VICTORY_EASTER_EGG_INTEGRATION_PASS')
