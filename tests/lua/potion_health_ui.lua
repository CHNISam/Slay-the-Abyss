local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local h,r=F.fixture();assert(testStart(h));h.run.hp=20
assert(Run.obtainPotion(h.run,'blood_potion'));h:refresh()
local function tap(panel,name) return assert(r:GetChild(panel):GetChild(name)):GetChild('hit').click() end
assert(tap('potionEntry','open'));assert(tap('potionPanel','slot1'))
assert(tap('potionPanel','use'));assert(h.run.hp==36 and not h.run.potions[1])
assert(not tap('potionPanel','use'))
assert(Run.obtainPotion(h.run,'block_potion'));h:refresh();assert(tap('potionPanel','slot1'))
assert(not tap('potionPanel','use'));assert(h.run.potions[1]=='block_potion')
print('LUA_POTION_HEALTH_UI_PASS 2')
