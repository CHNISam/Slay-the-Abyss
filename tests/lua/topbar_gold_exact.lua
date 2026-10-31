local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local ui,root=F.fixture()
assert(F.start(ui,'ironclad'))
assert(Run.startCombat(ui.run,'cultist_solo'))
ui:refresh()
local panel=root:GetChild('battlePanel')
for _,gold in ipairs({180,7,406,0})do
 local run=ui.run
 run.combat.player.gold=gold
 local savedRunGold=run.gold
 ui.battleUI:render()
 assert(panel:GetChild('piles').text==tostring(gold),'one render must show exact current combat gold')
 for _=1,3 do ui:update(1/60)end
 assert(panel:GetChild('piles').text==tostring(gold),'idle updates must not leave an intermediate balance')
 assert(run.gold==savedRunGold and run.combat.player.gold==gold,'HUD cannot mutate either rule gold owner')
end
local prior=ui.run
prior.phase='defeat';ui:refresh()
for _=1,80 do ui:update(1/60)end
assert(ui.mode=='defeat' and F.start(ui,'ironclad'))
assert(ui.run~=prior)
local gold=ui.run.gold
ui:refresh()
assert(panel:GetChild('piles').text==tostring(gold),'replacement run must not inherit old displayed gold')
assert(ui.battleUI.topPanelDisplayGold==nil,'exact HUD needs no cross-run display balance cache')
ui:disable()
print('TOPBAR_GOLD_EXACT_PASS')
