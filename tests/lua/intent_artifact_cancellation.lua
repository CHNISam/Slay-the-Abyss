local F = dofile("tests/lua/support/intent_artifact_fixture.lua")
local H, Combat, eq = F.H, F.Combat, F.eq
local test, setup, rejects = F.test, F.setup, F.rejects

test("cancelled playback and replacement battle cannot retain an old actor's intent", function()
    local h, u, p, tap = setup({{op="gainStatus", status="strength", value=2}, {op="damage", value=10}})
    h:refresh(); tap("endTurn", 51)
    for _ = 1, 100 do
        if u.feedback.current.kind == "intent" then break end
        h:update(0.05)
    end
    eq(u.feedback.current.kind, "intent")
    eq(p:GetChild("enemy1"):GetChild("intent").text, "12")
    u.feedback:cancel()
    assert(not u.busy)
    eq(p:GetChild("enemy1"):GetChild("intent").text, "14")
    h.run.combat = Combat.new(H.F.Data, {deck={"defend"}, enemies={"fat_gremlin"}})
    Combat.addStatus(h.run.combat.enemies[1], "strength", 3)
    h:refresh(); eq(p:GetChild("enemy1"):GetChild("intent").text, "7")
    Combat.addStatus(h.run.combat.player, "weak", 2147483647)
    rejects(h, "status stack overflow")
end)

F.finish("LUA_INTENT_ARTIFACT_CANCELLATION")
