local F = dofile("tests/lua/support/game_ui_fixture.lua")
local Nodes, Theme, preview, click, fixture = F.Nodes, F.Theme, F.preview, F.click, F.fixture
local Prologue = require("abyss_prologue")
local Narrative = require("abyss_narrative")
local P = Theme.layout.prologue
local count = 0
local function test(name, fn) fn(); count = count + 1; print("ok prologue " .. count .. " - " .. name) end
local function panel(root) return root:GetChild("prologuePanel") end
local function part(root, name) return panel(root):GetChild(name) end
local function tap(root) return part(root, "advance").click() end
local function run(ui, seconds, step)
    step = step or 0.05
    for _ = 1, math.ceil(seconds / step) do ui:update(step) end
end
local function opened(cursorEvents, sound)
    local ui, root = fixture(nil, nil, nil, cursorEvents, true, sound)
    click(root, "menuPanel", "start")
    return ui, root
end

test("intro splits into sentences without changing one character of the approved copy", function()
    local beats = Prologue.beats(Narrative.flow.intro.full)
    assert(#beats == 3 and #P.cameras == 3)
    assert(table.concat(beats) == Narrative.flow.intro.full)
    assert(beats[1] == "岩层深处传来了异常的共鸣。")
    assert(beats[2] == "古老的封印正在崩解……")
    assert(beats[3] == "旅行者，深入遗迹，阻止深渊的侵蚀。")
    for i, beat in ipairs(beats) do preview("intro" .. i, beat) end
    assert(table.concat(Prologue.chars("岩脉A……")) == "岩脉A……" and #Prologue.chars("岩脉A……") == 5)
end)

test("the title screen shows the game name once; start opens the cinematic over a hidden map", function()
    local ui, root = fixture(nil, nil, nil, nil, true)
    assert(root:GetChild("menuPanel"):GetChild("title").text == "杀戮原塔2")
    assert(root:GetChild("menuPanel"):GetChild("tagline").text == Narrative.title)
    assert(not panel(root).visible)
    click(root, "menuPanel", "start")
    assert(ui.mode == "prologue" and panel(root).visible and ui.run ~= nil)
    assert(not root:GetChild("menuPanel").visible and not root:GetChild("mapPanel").visible)
    assert(not root:GetChild("deckEntry").visible and root:GetChild("exitEntry").visible)
    assert(part(root, "chapter").text == "序 · " .. Narrative.title)
    -- Typed from empty, starting black; the run clock does not run during the story.
    assert(part(root, "line").text == "" and part(root, "fade").visible)
    run(ui, 0.4)
    local partial = part(root, "line").text
    assert(#partial > 0 and #partial < #"岩层深处传来了异常的共鸣。")
    assert(ui.run.elapsedSeconds == 0)
    assert(not ui:openDeck(), "deck stays closed during the cinematic")
end)

test("a tap first completes the sentence, then advances; a too-early tap does nothing", function()
    local ui, root = opened()
    assert(not tap(root), "the press that opened the cinematic cannot skip its first line")
    run(ui, P.minBeat + 0.05)
    assert(tap(root) and part(root, "line").text == "岩层深处传来了异常的共鸣。")
    assert(part(root, "hint").visible and part(root, "hint").text == "点击继续")
    assert(tap(root) and ui.prologue.beat.index == 2 and part(root, "line").text == "")
    assert(not tap(root), "the same burst of taps cannot also skip the new line")
    run(ui, P.minBeat + 0.05)
    assert(tap(root) and part(root, "line").text == "古老的封印正在崩解……")
    assert(tap(root) and ui.prologue.beat.index == 3 and part(root, "hero").visible)
    run(ui, P.minBeat + 0.05)
    assert(tap(root) and part(root, "hint").text == "点击进入遗迹")
    assert(tap(root) and ui.prologue.phase == "outro" and ui.mode == "prologue")
    assert(not tap(root) and not part(root, "skip"):GetChild("hit").click(), "the fade out ignores input")
end)

test("unattended playback moves through the story and waits on the last line", function()
    local ui, root = opened()
    run(ui, 30)
    assert(ui.prologue.phase == "beats" and ui.prologue.beat.index == 3)
    assert(part(root, "line").text == "旅行者，深入遗迹，阻止深渊的侵蚀。" and ui.mode == "prologue")
end)

test("the last fade uncovers an inert map, then hands over cleanly with no overlay left", function()
    local ui, root = opened()
    run(ui, 30) -- reach the last sentence, where the traveller's mark is on screen
    assert(part(root, "hero").visible)
    assert(part(root, "skip"):GetChild("hit").click() and ui.prologue.phase == "outro")
    assert(not part(root, "skip"):GetChild("hit").click(), "skip is not repeatable")
    run(ui, P.fadeOut + 0.05)
    assert(ui.prologue.phase == "reveal" and ui.mode == "map")
    assert(root:GetChild("mapPanel").visible and panel(root).visible and part(root, "fade").visible)
    assert(not part(root, "line").visible and not part(root, "vista").visible and not part(root, "skip").visible)
    assert(not ui.mapUI.navigationEnabled and not root:GetChild("deckEntry").visible)
    run(ui, P.reveal / 2)
    assert(not part(root, "hero").visible and not part(root, "hint").visible and not part(root, "flash").visible,
        "no cinematic layer reappears over the uncovering map")
    run(ui, P.reveal / 2 + 0.05)
    assert(not ui.prologue.playing and not panel(root).visible)
    assert(ui.mode == "map" and ui.mapUI.navigationEnabled and root:GetChild("deckEntry").visible)
    assert(#Nodes.available(ui.run, ui.map) == 3)
    click(root, "mapPanel", "node1")
    assert(ui.mode == "battle", "the map takes input once the cinematic is gone")
    ui:update(1)
    assert(ui.run.elapsedSeconds > 0, "the run clock starts with play")
end)

test("the exit dialog pauses the cinematic and owns input; leaving cancels it", function()
    local ui, root = opened(nil)
    run(ui, 0.6)
    local beat = ui.prologue.beat
    local shown = beat.shown
    click(root, "exitEntry", "open")
    assert(ui.exitOpen and root:GetChild("exitPanel").visible)
    run(ui, 2)
    assert(ui.prologue.beat.shown == shown, "paused while the dialog is open")
    assert(not ui.prologue:advance() and not ui.prologue:skip())
    click(root, "exitPanel", "cancel")
    run(ui, 0.2)
    assert(ui.prologue.beat.shown > shown and ui.mode == "prologue")
    -- Confirming the exit settles the run; the cinematic must not stay on top.
    local settled
    local ui2, root2 = fixture(nil, function(victory) settled = victory return true end, nil, nil, true)
    click(root2, "menuPanel", "start")
    click(root2, "exitEntry", "open")
    click(root2, "exitPanel", "confirm")
    assert(settled == false and ui2.settlementRequested)
    assert(not ui2.prologue.playing and not panel(root2).visible)
end)

test("restarting after a result goes straight to the map; the story plays once per session", function()
    local ui, root = opened()
    assert(part(root, "skip"):GetChild("hit").click())
    run(ui, P.fadeOut + P.reveal + 0.2)
    ui.run.phase = "defeat" ui:refresh()
    assert(ui.mode == "defeat" and root:GetChild("menuPanel").visible)
    assert(root:GetChild("menuPanel"):GetChild("title").text ~= "杀戮原塔2", "results name the outcome, not the game")
    click(root, "menuPanel", "start")
    assert(ui.mode == "map" and not panel(root).visible and ui.mapUI.navigationEnabled)
end)

test("with pointer events a tap must be pressed inside the cinematic", function()
    local events = { CursorClick = "click", CursorDown = "down", CursorUp = "up", CursorExit = "exit", CursorEndDrag = "endDrag" }
    local ui, root = fixture(nil, nil, nil, events, true)
    root:GetChild("menuPanel"):GetChild("start"):GetChild("hit").listeners.down({})
    root:GetChild("menuPanel"):GetChild("start"):GetChild("hit").listeners.up({})
    root:GetChild("menuPanel"):GetChild("start"):GetChild("hit").click({})
    assert(ui.mode == "prologue")
    run(ui, P.minBeat + 0.1)
    local advance = part(root, "advance")
    assert(not advance.click({}), "a click without its own press is a leftover")
    advance.listeners.down({}) advance.listeners.exit({})
    assert(not advance.click({}), "an interrupted touch is ignored")
    advance.listeners.down({})
    assert(advance.click({}) and part(root, "line").text == "岩层深处传来了异常的共鸣。")
end)

test("each sentence requests its own sound cue from the theme", function()
    local cues = {}
    local ui, root = opened(nil, function(cue) cues[#cues + 1] = cue end)
    run(ui, P.minBeat + 0.05) tap(root) tap(root)
    run(ui, P.minBeat + 0.05) tap(root) tap(root)
    assert(cues[1] == "prologue_rumble" and cues[2] == "prologue_crack" and cues[3] == "prologue_rise")
    for _, cue in ipairs(cues) do assert(Theme.sound[cue], cue) end
end)

test("hosts can opt out and start on the map directly", function()
    local ui, root = fixture()
    click(root, "menuPanel", "start")
    assert(ui.mode == "map" and not panel(root).visible and ui.prologue == nil)
end)

print("LUA_GAME_UI_PROLOGUE_PASS " .. count)
