local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local ui,root=F.fixture();testStart(ui);assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id))
assert(Run.obtainPotion(ui.run,'attack_potion'));ui:refresh();assert(ui.battleUI:usePotion(1))
for _=1,100 do ui:update(.05);if not ui.battleUI.busy then break end end
ui:refresh();local s=ui.run.combat;local p=assert(s.pendingChoice)
assert(ui.deckUI.visible and p.op=='discover'and #ui.deckUI.cards==3)
local panel=root:GetChild('deckPanel');local grid=panel:GetChild('grid')
assert(panel:GetChild('title').text:find('本回合费用为0',1,true));assert(not panel:GetChild('close').visible)
grid:flush();ui:update(0);grid:flush();local expected=p.cards[1].cardId;local nextUid=s.nextUid
assert(grid.itemCount==3);assert(grid.items[0]:GetChild('face'):GetChild('name').text~='')
grid.items[0]:GetChild('hit').click()
for _=1,100 do ui:update(.05);if not ui.battleUI.busy then break end end
ui:refresh();assert(not s.pendingChoice and not ui.deckUI.visible)
local found;for _,c in ipairs(s.hand)do if c.uid==nextUid then found=c end end
assert(found and found.cardId==expected and found.costForTurn==0)
print('LUA_POTION_DISCOVERY_UI_PASS 1')
