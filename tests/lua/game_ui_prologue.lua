-- The camera opening was cancelled. These cases keep the approved sentence
-- splitter (the merchant still types with it) and prove the host no longer
-- covers the map or Neow with that cinematic or its skip control.
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local preview, fixture = F.preview, F.fixture
local Prologue = require("abyss_prologue")
local Narrative = require("abyss_narrative")
local count = 0
local function test(name, fn) fn(); count = count + 1; print("ok prologue " .. count .. " - " .. name) end
local function panel(root) return root:GetChild("prologuePanel") end

test("intro splits into sentences without changing one character of the approved copy", function()
    local beats = Prologue.beats(Narrative.flow.intro.full)
    assert(#beats == 3)
    assert(table.concat(beats) == Narrative.flow.intro.full)
    assert(beats[1] == "岩层深处传来了异常的共鸣。")
    assert(beats[2] == "古老的封印正在崩解……")
    assert(beats[3] == "旅行者，深入遗迹，阻止深渊的侵蚀。")
    for i, beat in ipairs(beats) do preview("intro" .. i, beat) end
    assert(table.concat(Prologue.chars("岩脉A……")) == "岩脉A……" and #Prologue.chars("岩脉A……") == 5)
end)

test("requesting the old cinematic flag does not show or arm it", function()
    local ui, root = fixture(nil, nil, nil, nil, true)
    assert(F.start(ui))
    assert(ui.prologue == nil and not panel(root).visible and ui.mode == "map")
    assert(panel(root):GetChild("skip"):GetChild("hit").click == nil)
    assert(not panel(root).visible and ui.mode == "map")
end)

test("the title still shows the game name and the start button is not a cinematic", function()
    local ui, root = fixture()
    assert(root:GetChild("menuPanel"):GetChild("title").text == "杀戮原塔2")
    assert(root:GetChild("menuPanel"):GetChild("tagline").text == Narrative.title)
    assert(root:GetChild("menuPanel"):GetChild("heroArt"))
    assert(not panel(root).visible)
    assert(F.start(ui))
    assert(ui.mode == "map" and not panel(root).visible)
end)

test("a competition start opens Neow instead of the camera", function()
    local canvas = F.control({ children = F.Layout })
    local root = F.Viewport.apply(canvas, 1280, 720)
    local ui = F.GameUI.new(root, F.Data, F.Presentation, "click", {
        seed = 42, campaign = true, campaignProfile = "competition-two-act",
        characterProfile = "production", imageSource = "static",
        color = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end })
    root.ui = ui
    assert(F.start(ui))
    assert(ui.mode == "node" and ui.run.nodeFlow.event.id == "neow" and ui.run.nodeFlow.event.stage == "neow_intro")
    local event = root:GetChild("nodePanel"):GetChild("eventView")
    assert(event:GetChild("neowFigure").visible and not event:GetChild("art").visible)
    assert(event:GetChild("caption").text == "七天神像")
    assert(not panel(root).visible and ui.prologue == nil)
end)

test("the blessing figure is not the shop merchant", function()
    local canvas = F.control({ children = F.Layout })
    local root = F.Viewport.apply(canvas, 1280, 720)
    local ui = F.GameUI.new(root, F.Data, F.Presentation, "click", {
        seed = 42, campaign = true, campaignProfile = "competition-two-act",
        characterProfile = "production", imageSource = "static",
        color = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end })
    root.ui = ui
    assert(F.start(ui))
    local merchant = root:GetChild("nodePanel"):GetChild("merchant")
    assert(merchant:GetChild("name").text == "旧路商人" and not merchant.visible)
    assert(root:GetChild("nodePanel"):GetChild("eventView"):GetChild("caption").text == "七天神像")
end)

test("finishing the first blessing enters the map and leaves no mask", function()
    local canvas = F.control({ children = F.Layout })
    local root = F.Viewport.apply(canvas, 1280, 720)
    local ui = F.GameUI.new(root, F.Data, F.Presentation, "click", {
        seed = 42, campaign = true, campaignProfile = "competition-two-act",
        characterProfile = "production", imageSource = "static",
        color = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end })
    root.ui = ui
    assert(F.start(ui))
    assert(F.click(root, "nodePanel", "eventView/option1"))
    assert(ui.run.nodeFlow.event.stage == "neow_blessing" and #ui.run.nodeFlow.event.rewards == 2)
    assert(F.click(root, "nodePanel", "eventView/option2"))
    assert(F.click(root, "nodePanel", "eventView/option1"))
    assert(ui.mode == "map" and ui.mapUI.navigationEnabled and ui.run.neowStatus == "complete")
    assert(not panel(root).visible)
end)

test("decline path still leaves through the existing continue choice", function()
    local canvas = F.control({ children = F.Layout })
    local root = F.Viewport.apply(canvas, 1280, 720)
    local ui = F.GameUI.new(root, F.Data, F.Presentation, "click", {
        seed = 42, campaign = true, campaignProfile = "competition-two-act",
        characterProfile = "production", imageSource = "static",
        color = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end })
    root.ui = ui
    assert(F.start(ui))
    assert(F.click(root, "nodePanel", "eventView/option1"))
    local rewards = ui.run.nodeFlow.event.rewards
    assert(#rewards == 2)
    assert(F.click(root, "nodePanel", "eventView/option1"))
    if ui.run.nodeFlow.event.stage == "neow_result" then
        assert(F.click(root, "nodePanel", "eventView/option1"))
    end
    assert(ui.mode == "map" and ui.run.neowStatus == "complete")
end)

test("a later run in the same host still does not play the camera", function()
    local ui, root = fixture(nil, nil, nil, nil, true)
    assert(F.start(ui))
    ui.run.phase = "defeat"
    ui:refresh()
    assert(F.start(ui))
    assert(ui.prologue == nil and not panel(root).visible)
end)

test("exit during the blessing does not reveal the retired panel", function()
    local canvas = F.control({ children = F.Layout })
    local root = F.Viewport.apply(canvas, 1280, 720)
    local ui = F.GameUI.new(root, F.Data, F.Presentation, "click", {
        seed = 42, campaign = true, campaignProfile = "competition-two-act",
        characterProfile = "production", imageSource = "static",
        color = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end })
    root.ui = ui
    assert(F.start(ui))
    assert(ui:openExit())
    ui:update(1)
    assert(not panel(root).visible)
    assert(ui:closeExit() and ui.mode == "node")
end)

test("hosts without a blessing record still reach the map directly", function()
    local ui, root = fixture()
    assert(F.start(ui))
    assert(ui.mode == "map" and not panel(root).visible and ui.prologue == nil)
    assert(ui.run.neowStatus == "unavailable")
end)

print("LUA_GAME_UI_PROLOGUE_PASS " .. count)
