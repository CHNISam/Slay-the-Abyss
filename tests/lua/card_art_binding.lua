local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local Theme = require("abyss_theme")
local Display = require("abyss_card_display")
local function picture(control,id) control:SetImage("static",id) end
local host, ui, panel, _, tap, _, _, root = H.setup({"strike"})
-- A card-specific native asset must take precedence over the generic attack glyph.
Theme.icon.cardPortraits = {strike={id=102035, status="test-native-asset", size={288,128}}}
ui:render()
assert(panel:GetChild("card1"):GetChild("art").imageId == 102035,
    "battle card ignores its card-ID artwork binding")
assert(panel:GetChild("card1"):GetChild("art").sizeDeltaX == 144 and panel:GetChild("card1"):GetChild("art").sizeDeltaY == 64,
    "battle portrait did not use its full aperture without distortion")
host.run.deck = {{uid=91,cardId="strike",upgraded=true}}
assert(host.deckUI:open(host.run))
local grid = root:GetChild("deckPanel"):GetChild("grid")
assert(grid.items[0]:GetChild("face"):GetChild("art").imageId == 102035,
    "deck card uses a different artwork pipeline")
assert(grid.items[0]:GetChild("face"):GetChild("art").sizeDeltaX == 144 and grid.items[0]:GetChild("face"):GetChild("art").sizeDeltaY == 64,
    "deck portrait geometry diverged")
assert(host.deckUI:close())
-- Completing an encounter and opening its real reward picker reuses the hand face.
for _,enemy in ipairs(host.run.combat.enemies) do enemy.hp=0 end
assert(H.Run.finishCombat(host.run));host:refresh();tap("cardReward",3)
local rewardId=host.run.rewards.cards[1]
Theme.icon.cardPortraits[rewardId]={id=102035,status="test-native-asset",size={288,128}}
ui:render()
local rewardArt=panel:GetChild("card1"):GetChild("art")
assert(rewardArt.imageId==102035 and rewardArt.sizeDeltaX==144 and rewardArt.sizeDeltaY==64,
    "reward card bypassed shared portrait sizing")
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
Theme.icon.cardPortraits[offer.id] = {id=102035,status="test-native-asset",size={288,128}}
host.nodeUI.run,host.nodeUI.map = run,map
host.nodeUI:render()
local shown = 0
for name,control in pairs(root:GetChild("nodePanel"):GetChild("shopView"):GetChild("card1").children) do
    if name:match("^art_") and control.visible then
        assert(control.imageId == 102035,"node card ignores the shared artwork binding")
        assert(control.sizeDeltaX==144 and control.sizeDeltaY==64,"shop portrait geometry diverged")
        shown = shown+1
    end
end
assert(shown==1,"node card duplicated the artwork")
local id, status = Display.art({id="unbound",type="skill"})
assert(id == Theme.icon.cardArt.skill and status == "placeholder-type-icon")
id, status = Display.art({id="unbound",type="unknown"})
assert(id == Theme.icon.cardArt.status and status == "placeholder-type-icon")
-- Recycle the same rendered control through landscape, square, portrait and
-- explicit/missing placeholders: no stale geometry and no stretched type icon.
local art=panel:GetChild("card1"):GetChild("art")
for _,case in ipairs({
    {{id=102035,status="test-native-asset",size={288,128}},144,64},
    {{id=102035,status="test-native-asset",size={100,100}},64,64},
    {{id=102035,status="test-native-asset",size={100,200}},32,64},
    {{id=102035,status="placeholder-native-icon",size={288,128}},40,40},
    {{id=102035,status="legacy-native-asset"},40,40},
}) do
    Theme.icon.cardPortraits.strike=case[1]
    Display.writeArt(art,{id="strike",type="attack"},picture)
    assert(art.sizeDeltaX==case[2] and art.sizeDeltaY==case[3],"portrait aspect ratio or placeholder was stretched")
end
Theme.icon.cardPortraits.strike=nil
Display.writeArt(art,{id="strike",type="attack"},picture)
assert(art.imageId==Theme.icon.cardArt.attack and art.sizeDeltaX==40 and art.sizeDeltaY==40,"missing portrait did not reset square fallback")
-- Missing native resize support is a broken fixture/adapter, never permission
-- for production to silently leave an icon at stale or stretched dimensions.
local resize,methods=art.SetSizeDelta,getmetatable(art)
art.SetSizeDelta=nil
setmetatable(art,nil) -- Remove the shared mock method inherited through __index too.
assert(art.SetSizeDelta==nil,"negative control did not remove native resize API")
local ok,reason=pcall(Display.writeArt,art,{id="strike",type="attack"},picture)
art.SetSizeDelta=resize
setmetatable(art,methods)
assert(not ok and tostring(reason):find('SetSizeDelta',1,true),"missing native resize API was silently bypassed")
Display.writeArt(art,{id="strike",type="attack"},picture)
assert(art.sizeDeltaX==40 and art.sizeDeltaY==40,"restored native resize API did not record geometry")
Theme.icon.cardPortraits.strike={id=102035,status="test-native-asset",size={0,128}}
assert(not pcall(Display.writeArt,art,{id="strike",type="attack"},picture),"invalid portrait dimensions were accepted")
Theme.icon.cardPortraits.strike.id = "https://example.invalid/card.png"
assert(not pcall(Display.art,{id="strike",type="attack"}), "external image path was accepted")
print("LUA_CARD_ART_BINDING_PASS 6")
