local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local ui,root=F.fixture();assert(testStart(ui));assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id))
assert(Run.obtainPotion(ui.run,'smoke_bomb'));ui:refresh()
assert(ui.battleUI:usePotion(1))
for _=1,100 do ui:update(.05);if not ui.battleUI.busy then break end end
ui:refresh()
assert(ui.run.phase=='map' and ui.mode=='map' and ui.run.nodeFlow.complete and ui.run.nodeFlow.result=='escaped')
assert(ui.run.rewards==nil and not ui.run.potions[1] and ui.run.victories==0)
assert(ui.mapUI.navigationEnabled and #F.Nodes.available(ui.run,ui.map)>0)
assert(not root:GetChild('battlePanel').visible)
print('LUA_POTION_SMOKE_UI_PASS 1')
