local Bgm = require("abyss_bgm")
local count = 0
local function test(name, fn) fn(); count = count + 1; print("ok native BGM " .. count .. " - " .. name) end
test("scene selection waits for feedback, treats reward and peaceful nodes as exploration", function()
    assert(Bgm.scene("battle", { phase = "combat", nodeFlow = { type = "elite" } }) == "elite")
    assert(Bgm.scene("battle", { phase = "combat", nodeFlow = { type = "boss" } }) == "boss")
    assert(Bgm.scene("battle", { phase = "combat", nodeFlow = { type = "event" } }) == "battle")
    assert(Bgm.scene("battle", { phase = "reward" }, true, "boss") == "boss")
    assert(Bgm.scene("battle", { phase = "reward" }) == "map")
    assert(Bgm.scene("node", { phase = "node" }) == "map")
    assert(Bgm.scene("victory", {}) == "victory" and Bgm.scene("defeat", {}) == "defeat")
    assert(Bgm.scene("menu") == "stop")
end)
test("bridge deduplicates refresh/deck changes and sends stop before restart", function()
    local sent = {}
    local bgm = Bgm.new(function(signal) sent[#sent + 1] = signal end)
    for _, cue in ipairs({ "stop", "map", "map", "battle", "battle", "map", "boss", "victory", "stop", "map" }) do bgm:update(cue) end
    assert(#sent == 8 and sent[1] == "ABYSS_BGM_STOP" and sent[8] == "ABYSS_BGM_MAP")
end)
test("unavailable audio and failed signal never throw or retry each frame", function()
    local attempts = 0
    local bgm = Bgm.new(function() attempts = attempts + 1; error("unavailable") end)
    assert(not bgm:update("map")); assert(not bgm:update("map")); assert(attempts == 1)
    assert(not bgm:update("battle") and attempts == 2)
    assert(not Bgm.new(nil):update("map"))
    assert(not bgm:update("invented"))
end)
print("native BGM: " .. count .. " passed")
