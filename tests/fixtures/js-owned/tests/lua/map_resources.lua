local F = dofile("tests/lua/support/game_ui_fixture.lua")
local ui, root = F.fixture()
assert(ui:start())
local panel = root:GetChild("mapPanel")
local resources = panel:GetChild("resources")
assert(panel.visible and resources.visible)
assert(resources:GetChild("gold").text == tostring(ui.run.gold))
assert(resources:GetChild("hp").text == ui.run.hp .. "/" .. ui.run.maxHp)
-- A return from a room must read current state, including zero gold and low HP.
for _, gold in ipairs({137, 0, 9999}) do
    ui.run.gold, ui.run.hp = gold, 23
    ui:refresh()
    assert(ui.mode == "map" and panel.visible and resources.visible)
    assert(resources:GetChild("gold").text == tostring(gold))
    assert(resources:GetChild("hp").text == "23/" .. ui.run.maxHp)
end
ui.mapUI:scrollBy(100)
ui:refresh()
assert(resources:GetChild("gold").text == "9999")
print("LUA_MAP_RESOURCES_PASS")
