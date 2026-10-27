package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local count, failed = 0, 0
local function test(name, fn)
    count = count + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " battle_speed " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local function same(a, b, path)
    path = path or "state"
    assert(type(a) == type(b), path .. " type differs")
    if type(a) ~= "table" then assert(a == b, path .. " value differs") return end
    for key, value in pairs(b) do same(a[key], value, path .. "." .. tostring(key)) end
    for key in pairs(a) do assert(b[key] ~= nil, path .. " unexpected field " .. tostring(key)) end
end
local function hit(root, path)
    local box = root
    for part in path:gmatch("[^/]+") do box = assert(box:GetChild(part), path) end
    return assert(box:GetChild("hit"), path .. "/hit")
end
local function fixture()
    local root = F.Viewport.apply(F.control({children = F.Layout}), 1280, 720)
    local host = F.GameUI.new(root, F.Data, F.Presentation, "click", {
        seed = 1, prologue = false, originalCharacters = true, imageSource = "static",
        color = function(r,g,b,a) return {r=r,g=g,b=b,a=a} end,
    })
    root.ui = host
    return host, root
end
local function nearDuration(actual, expected)
    assert(actual >= expected - 0.000001 and actual <= expected + 0.010001,
        "expected fixed-source gate " .. expected .. ", observed " .. actual)
end
local traces = {}
for _, fast in ipairs({false, true}) do
    test((fast and "fast" or "normal") .. " menu selection reaches the natural first battle and source damage gate", function()
        local host, root = fixture()
        local speed = root:GetChild("menuPanel"):GetChild("battleSpeed")
        assert(host.run == nil and host.map == nil, "speed settings must not create a discarded run")
        local seed = host.seed
        assert(host.fastMode == false and speed:GetChild("label").text == "战斗速度：普通")
        if fast then assert(speed:GetChild("hit").click()) end
        assert(host.fastMode == fast and (host.battleUI.fastMode == true) == fast)
        assert(speed:GetChild("label").text == (fast and "战斗速度：快速" or "战斗速度：普通"))
        assert(host.run == nil and host.map == nil and host.seed == seed, "toggling consumes neither a seed nor run RNG")
        assert(hit(root, "menuPanel/start").click() and host.characterOpen)
        assert(hit(root, "characterPanel/traveler").click())
        assert(host.mode == "map" and host.run.phase == "map")
        host:update(1) -- Finish the ordinary map focus interpolation before its node click.
        local available = F.Nodes.available(host.run, host.map)
        local node = assert(available[1], "the generated first floor has no legal route")
        local slot
        for index, id in pairs(host.mapUI.slots) do if id == node.id then slot = index break end end
        assert(slot, "the legal first-floor node is not visible")
        assert(F.mapControl(root:GetChild("mapPanel"), "node" .. slot):GetChild("hit").click())
        assert(host.mode == "battle" and host.run.phase == "combat" and host.run.nodeFlow,
            "the real menu/map node must enter combat")
        local ui, battle = host.battleUI, host.run.combat
        local cardSlot
        for index, card in ipairs(battle.hand) do if card.cardId == "strike" then cardSlot = index break end end
        assert(cardSlot, "seed 1's genuine starter hand must contain Strike")
        local card = battle.hand[cardSlot]
        root:GetChild("battlePanel"):GetChild("card" .. cardSlot):GetChild("hit").click()
        assert(ui.selected == card.uid)
        root:GetChild("battlePanel"):GetChild("enemy1"):GetChild("hit").click()
        assert(ui.busy and ui.feedback.busy and ui.feedback.playbackFastMode == fast,
            "perform must synchronize the official setting before beginning feedback")
        local committed = F.Combat.copy(battle)
        assert(not host:setFastMode(not fast), "the public setter must reject an active action")
        assert(not speed:GetChild("hit").click(), "a hidden title callback must reject an active battle")
        assert(host.fastMode == fast and (ui.fastMode == true) == fast and ui.feedback.playbackFastMode == fast)
        same(battle, committed)
        for _ = 1, 100 do
            if ui.feedback.current and ui.feedback.current.kind == "damage" then break end
            host:update(0.01)
        end
        local damage = assert(ui.feedback.current)
        assert(damage.kind == "damage")
        local elapsed = 0
        for _ = 1, 100 do
            if not ui.feedback.busy or ui.feedback.current ~= damage then break end
            host:update(0.01)
            elapsed = elapsed + 0.01
        end
        nearDuration(elapsed, fast and 0.1 or 0.2)
        for _ = 1, 100 do if not ui.busy then break end host:update(0.01) end
        assert(not ui.busy and not ui.feedback.busy)
        local result = F.Combat.copy(host.run)
        result.elapsedSeconds = nil -- Animation speed changes elapsed wall time, never combat rules.
        traces[fast and "fast" or "normal"] = {run = result, map = F.Combat.copy(host.map)}
    end)
end
test("normal and fast official menu paths preserve the complete run/map state and all RNG streams", function()
    assert(traces.normal and traces.fast, "both actual entry traces must have completed")
    same(traces.normal, traces.fast)
end)
assert(failed == 0, failed .. " official battle speed regressions failed")
print("LUA_GAME_UI_BATTLE_SPEED_PASS " .. count)
