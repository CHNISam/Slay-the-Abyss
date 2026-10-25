local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local ui,root=F.fixture();assert(ui:start());assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id))
local s=ui.run.combat;s.draw={{cardId='defend',uid=3703},{cardId='defend',uid=3702},{cardId='defend',uid=3701}}
s.discard={};assert(Run.obtainPotion(ui.run,'distilled_chaos'));ui:refresh();assert(ui.battleUI:usePotion(1))
for _=1,500 do ui:update(.05);if not ui.battleUI.busy then break end end
ui:refresh();assert(not ui.battleUI.busy and ui.battleUI.active and ui.run.phase=='combat')
assert(s.player.block==15 and s.energy==3 and #s.exhaust==0 and #s.discard==3 and not s.cardActions)
assert(not ui.run.potions[1])
print('LUA_POTION_CHAOS_UI_PASS 1')
