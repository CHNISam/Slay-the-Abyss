local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local ui,root=F.fixture();ui:start();assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id))
local s=ui.run.combat;s.hand={{uid=1000,cardId='strike'},{uid=1001,cardId='defend'}}
assert(Run.obtainPotion(ui.run,'elixir'));ui:refresh();assert(ui.battleUI:usePotion(1))
for _=1,100 do ui:update(.05);if not ui.battleUI.busy then break end end
ui:refresh();assert(ui.deckUI.visible and s.pendingChoice.multiple)
local panel=root:GetChild('deckPanel');local grid=panel:GetChild('grid')
assert(panel:GetChild('close').visible)
assert(panel:GetChild('close'):GetChild('hit'):GetChild('normal'):GetChild('label').text=='确认选择')
grid:flush();ui:update(0);grid:flush();grid.items[0]:GetChild('hit').click()
for _=1,100 do ui:update(.05);if not ui.battleUI.busy then break end end
ui:refresh();grid:flush();ui:update(0);grid:flush()
assert(grid.items[0]:GetChild('uid').text:find('已选',1,true))
panel:GetChild('close'):GetChild('hit').click()
for _=1,100 do ui:update(.05);if not ui.battleUI.busy then break end end
ui:refresh();assert(not s.pendingChoice and #s.exhaust==1 and s.exhaust[1].uid==1000)
assert(not ui.deckUI.visible and #s.hand==1)
print('LUA_POTION_CHOICES_UI_PASS 1')
