-- Menu, character select and battle portrait slots. Placeholder library ids
-- stand in until Dot art arrives; they must not collapse to the Geo icon.
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local Theme = F.Theme
local slots = Theme.icon.heroSlots
local function idOf(entry) return type(entry) == "table" and entry.id or entry end
local seen = {}
local function claim(id, owner)
    assert(type(id) == "number" and id ~= Theme.icon.geo, owner .. " still uses the Geo icon")
    assert(not seen[id] or seen[id] == owner, owner .. " reuses " .. tostring(seen[id]))
    seen[id] = seen[id] or owner
end
claim(slots.menu.id, slots.large.traveler.ironclad.slot)
assert(slots.menu.id == slots.large.traveler.ironclad.id, "menu and traveler key art share one slot")
claim(idOf(Theme.icon.player), Theme.icon.player.slot)
assert(Theme.icon.player.id ~= slots.menu.id, "battle bust is Dot B's own slot")
for character, entry in pairs(slots.large) do
    if entry.id then claim(entry.id, entry.slot)
    else for _, child in pairs(entry) do claim(child.id, child.slot) end end
end
for character, entry in pairs(slots.bust) do
    if entry.id then claim(entry.id, entry.slot)
    else for _, child in pairs(entry) do claim(child.id, child.slot) end end
end
for _, portrait in pairs(Theme.icon.characterPortraits) do
    assert(portrait.placeholder == true and portrait.id ~= Theme.icon.geo)
end

local canvas = F.control({ children = F.Layout })
local root = F.Viewport.apply(canvas, 1280, 720)
local ui = F.GameUI.new(root, F.Data, F.Presentation, "click", {
    seed = 2, campaign = true, campaignProfile = "competition-two-act",
    characterProfile = "production", imageSource = "static",
    color = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end })
root.ui = ui
local menu = root:GetChild("menuPanel")
assert(menu:GetChild("heroArt"), "menu is missing the replaceable hero art")
assert(menu:GetChild("title").text == "杀戮原塔2")
F.click(root, "menuPanel", "start")
assert(ui.characterOpen and not ui.run)
local panel = root:GetChild("characterPanel")
assert(panel:GetChild("details").visible, "production opens on the traveler, not a blank card")
assert(ui.characterSelection.character == "traveler" and ui.characterSelection.element == "ironclad")
local portraits = panel:GetChild("details"):GetChild("portraits")
assert(portraits:GetChild("traveler_ironclad").visible)
assert(portraits:GetChild("traveler_ironclad").imageId == slots.large.traveler.ironclad.id)
for _, name in ipairs({ "traveler_silent", "traveler_defect", "traveler_watcher", "hutao", "arlecchino", "furina", "raiden" }) do
    assert(not portraits:GetChild(name).visible)
    assert(portraits:GetChild(name).imageId ~= slots.large.traveler.ironclad.id)
end
local traveler = panel:GetChild("traveler")
assert(traveler:GetChild("hit"):GetChild("normal"):GetChild("bust").imageId == slots.bust.traveler.ironclad.id)
assert(traveler:GetChild("selected").visible)
assert(panel:GetChild("details"):GetChild("name").text:find("旅行者", 1, true))
assert(panel:GetChild("details"):GetChild("stats").text:find("生命", 1, true))
assert(panel:GetChild("details"):GetChild("gold").text:find("金币", 1, true))
F.click(root, "characterPanel", "confirm")
assert(ui.mode == "node" and ui.run.nodeFlow.event.id == "neow")
assert(ui.run.nodeFlow.event.stage == "neow_intro")
print("HERO_VISUAL_SLOTS_PASS")
