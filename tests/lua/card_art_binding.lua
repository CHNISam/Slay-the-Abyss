local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local Theme = require("abyss_theme")
local Display = require("abyss_card_display")
local host, ui, panel, _, _, _, _, root = H.setup({"strike"})
-- A card-specific native asset must take precedence over the generic attack glyph.
Theme.icon.cardPortraits = {strike={id=102035, status="test-native-asset"}}
ui:render()
assert(panel:GetChild("card1"):GetChild("art").imageId == 102035,
    "battle card ignores its card-ID artwork binding")
host.run.deck = {{uid=91,cardId="strike",upgraded=true}}
assert(host.deckUI:open(host.run))
local grid = root:GetChild("deckPanel"):GetChild("grid")
assert(grid.items[0]:GetChild("face"):GetChild("art").imageId == 102035,
    "deck card uses a different artwork pipeline")
local Run, Map, Nodes = require("abyss_run"), require("abyss_map"), require("abyss_nodes")
local run, map = Run.new(H.F.Data,42), Map.generate(H.F.Data,42)
for _=1,17 do
    local choices, found = Map.available(map), false
    for _,node in ipairs(choices) do
        if node.type == "shop" then assert(Nodes.enter(run,map,node.id)); found=true; break end
    end
    if found then break end
    assert(choices[1]); assert(Map.choose(map,choices[1].id))
end
local offer = assert(Nodes.view(run,map).node.cards[1])
Theme.icon.cardPortraits[offer.id] = {id=102035,status="test-native-asset"}
host.nodeUI.run,host.nodeUI.map = run,map
host.nodeUI:render()
local shown = 0
for name,control in pairs(root:GetChild("nodePanel"):GetChild("shopView"):GetChild("card1").children) do
    if name:match("^art_") and control.visible then
        assert(control.imageId == 102035,"node card ignores the shared artwork binding")
        shown = shown+1
    end
end
assert(shown==1,"node card duplicated the artwork")
local id, status = Display.art({id="unbound",type="skill"})
assert(id == Theme.icon.cardArt.skill and status == "placeholder-type-icon")
id, status = Display.art({id="unbound",type="unknown"})
assert(id == Theme.icon.cardArt.status and status == "placeholder-type-icon")
Theme.icon.cardPortraits.strike.id = "https://example.invalid/card.png"
assert(not pcall(Display.art,{id="strike",type="attack"}), "external image path was accepted")
print("LUA_CARD_ART_BINDING_PASS 6")
