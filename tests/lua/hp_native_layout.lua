local F=dofile('tests/lua/support/game_ui_fixture.lua')
local ui,root=F.fixture()
assert(F.start(ui,'ironclad'))
for _,hp in ipairs({80,88})do
 ui.run.hp,ui.run.maxHp=hp,hp
 ui:refresh()
 ui.nodeUI:render()
 local expected=tostring(hp)..'/'..tostring(hp)
 assert(root:GetChild('nodePanel'):GetChild('hp').text==expected)
 assert(root:GetChild('mapPanel'):GetChild('resources'):GetChild('hp').text==expected)
end
print('HP_NATIVE_LAYOUT_PASS')
