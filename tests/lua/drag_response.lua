local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local Combat = require("abyss_combat")
local passed = 0
local function test(name, fn)
    fn()
    passed = passed + 1
    print("ok drag response " .. passed .. " - " .. name)
end
local function previewWork(fn)
    local original, calls = Combat.cardPreview, 0
    Combat.cardPreview = function(...)
        calls = calls + 1
        return original(...)
    end
    local ok, why = pcall(fn)
    Combat.cardPreview = original
    assert(ok, why)
    return calls
end

test("free dragging follows every pointer sample without recalculating the hand", function()
    local host, ui, panel, event = H.setup({"defend", "defend", "defend", "defend", "defend"})
    local battle, card = host.run.combat, panel:GetChild("card1")
    event("card1", "down", 7)
    event("card1", "drag", 7, 0, 0)
    local calls = previewWork(function()
        for i = 1, 40 do
            event("dragLayer", "drag", 7, i * 2, i)
            assert(card.x == i * 2 and card.y == i, "card lagged behind the pointer")
            assert(card:GetChild("glow").visible, "valid release lost its highlight")
        end
    end)
    assert(calls == 0, "pointer-only movement recalculated " .. calls .. " card previews")
    event("dragLayer", "up", 7, 80, 40)
    event("card1", "endDrag", 7, 80, 40)
    assert(battle.energy == 2 and battle.player.block == 5 and #battle.hand == 4)
    assert(ui.gesture == nil)
end)

test("aiming updates damage only when the pointed enemy changes and restores it off target", function()
    local host, ui, panel, event = H.setup({"strike", "defend"}, {"cultist", "jaw_worm"})
    local battle, card = host.run.combat, panel:GetChild("card1")
    battle.enemies[2].statuses.vulnerable = 2
    ui:render()
    local e1, e2 = panel:GetChild("enemy1"), panel:GetChild("enemy2")
    local function body() return card:GetChild("label").text end
    event("card1", "down", 7)
    event("card1", "drag", 7, e1.x, e1.y)
    local base = body()
    local calls = previewWork(function()
        for i = 1, 30 do event("dragLayer", "drag", 7, e1.x + i / 10, e1.y) end
    end)
    assert(calls == 0, "unchanged aim recalculated the hand")
    event("dragLayer", "drag", 7, e2.x, e2.y)
    assert(body() ~= base, "changing target did not update Vulnerable damage")
    assert(panel:GetChild("dragLayer"):GetChild("reticle").x == e2.x)
    event("dragLayer", "drag", 7, -285, 0)
    assert(body() == base and not card:GetChild("glow").visible, "leaving target retained stale damage")
    event("dragLayer", "up", 7, -285, 0)
    assert(battle.energy == 3 and #battle.hand == 2 and ui.selected == nil)
end)

test("dragging back cancels and changed battle identity never uses the fast path", function()
    local host, ui, panel, event = H.setup()
    local old = host.run.combat
    event("card1", "down", 7)
    event("card1", "drag", 7, 0, 0)
    event("dragLayer", "drag", 7, 0, -240)
    assert(not panel:GetChild("card1"):GetChild("glow").visible)
    event("dragLayer", "up", 7, 0, -240)
    assert(old.energy == 3 and old.player.block == 0)
    event("card1", "down", 7)
    event("card1", "drag", 7, 0, 0)
    local replacement = Combat.new(H.F.Data, {deck={"defend"}, enemies={"cultist"}})
    host.run.combat = replacement
    event("dragLayer", "drag", 7, 10, 10)
    event("dragLayer", "up", 7, 10, 10)
    assert(replacement.energy == 3 and replacement.player.block == 0 and #replacement.hand == 1)
    assert(ui.gesture == nil)
end)

print("LUA_DRAG_RESPONSE_PASS " .. passed)
