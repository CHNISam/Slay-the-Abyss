local F = dofile("tests/lua/support/intent_artifact_fixture.lua")
local Combat, eq = F.Combat, F.eq
local test, drainChecked = F.test, F.drainChecked

test("two stock applying enemies exhaust exactly two charges without historical-frame recovery", function()
    local h, u, p, _, tap = F.playbackSetup({"defend"}, {"fat_gremlin", "fat_gremlin"})
    local s = h.run.combat
    Combat.addStatus(s.player, "weak", 2147483647); Combat.addStatus(s.player, "artifact", 2)
    h:refresh(); tap("endTurn", 41)
    local blocks = {}
    drainChecked(h, u, function(entry, frame)
        if entry.kind == "status" and entry.detail.status == "artifact" then
            blocks[frame.player.statuses.artifact] = true
            eq(p:GetChild("enemy1"):GetChild("intent").text, "4")
            eq(p:GetChild("enemy2"):GetChild("intent").text, "4")
        end
    end)
    assert(blocks[1] and blocks[0])
    eq(s.player.statuses.artifact, 0); eq(s.player.statuses.weak, 2147483646)
end)

F.finish("LUA_INTENT_ARTIFACT_CHARGES")
