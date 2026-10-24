local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local ui,root=F.fixture()
ui:start();assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id))
local s=ui.run.combat
s.player.statuses.corruption=1
s.hand={{uid=101,cardId='burning_pact',upgraded=false},{uid=102,cardId='sentinel',upgraded=true},{uid=103,cardId='defend',upgraded=false}}
s.draw={{uid=104,cardId='strike',upgraded=false},{uid=105,cardId='strike',upgraded=false}}
s.discard={};s.exhaust={};s.nextUid=106;s.energy=3
assert(Run.play(ui.run,101));ui:refresh();ui:update(0)
assert(ui.deckUI.visible and ui.deckUI.choiceToken==s.pendingChoice.token)
assert(not root:GetChild('deckPanel'):GetChild('close').visible)
assert(not ui:closeDeck());assert(not ui.battleUI.active)
local grid=root:GetChild('deckPanel'):GetChild('grid');grid:flush();ui:update(0);grid:flush()
assert(grid.itemCount==2)
local first=grid.items[0];assert(first:GetChild('uid').text=='UID 102')
assert(first:GetChild('face'):GetChild('name').text=='Sentinel＋')
assert(first:GetChild('face'):GetChild('cost').text=='0','choice must show Corruption combat cost')
assert(first:GetChild('hit').visible and first:GetChild('hit').click,'native cursor-area listener required')
local stale=first:GetChild('hit').click
stale()
for _=1,500 do ui:update(.05);if not ui.battleUI.busy then break end end
ui:refresh()
assert(not s.pendingChoice and not ui.deckUI.visible)
assert(s.energy==6 and #s.hand==3 and #s.exhaust==2 and s.exhaust[1].uid==102 and s.exhaust[2].uid==101)
local energy=s.energy;stale();assert(s.energy==energy and #s.exhaust==2)
assert(ui.battleUI.active)
print('Choice UI: real virtualized grid selects the eligible UID, resumes queue, restores battle input, rejects old closed callback.')
