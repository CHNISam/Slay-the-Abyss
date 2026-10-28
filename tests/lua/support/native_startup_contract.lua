package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local host,root=F.fixture()
assert(host and root and host.mode=='menu','real host must construct before a player can start')
assert(host:start(),'real host must start with generated controls')
host:disable()
-- Reinsert the exact escaped write without touching the working tree. This
-- negative control must fail in the production constructor, not a fake check.
local mutated=assert(ABYSS_NATIVE_MUTANT,'runner must supply exact production mutation')
local originalBattle,originalGame=package.loaded.abyss_battle_ui,package.loaded.abyss_game_ui
package.loaded.abyss_battle_ui=assert(load(mutated,'@escaped_abyss_battle_ui'))()
package.loaded.abyss_game_ui=nil
local ok,reason=pcall(function()dofile('tests/lua/support/game_ui_fixture.lua').fixture()end)
package.loaded.abyss_battle_ui,package.loaded.abyss_game_ui=originalBattle,originalGame
assert(not ok and tostring(reason):find('cursorArea cannot set interactable',1,true),
    'escaped native startup must fail specifically at cursor capability boundary: '..tostring(reason))
print('NATIVE_STARTUP_CONTRACT_PASS positive host startup + escaped-write negative control')
