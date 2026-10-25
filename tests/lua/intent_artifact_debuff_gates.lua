local F = dofile("tests/lua/support/intent_artifact_fixture.lua")
local H, Combat, counters = F.H, F.Combat, F.counters
local eq, same, test = F.eq, F.same, F.test
local setup, refresh, rejects, resolve = F.setup, F.refresh, F.rejects, F.resolve

test("Artifact gates each supported ordinary debuff before either recipient's stack arithmetic", function()
    for _, status in ipairs({"weak", "vulnerable", "frail", "poison", "entangled"}) do
        for _, op in ipairs({"applyStatus", "gainStatus"}) do
            local h, _, p, tap = setup({{op=op, status=status, value=1}}, "debuff")
            local s = h.run.combat
            local actor = op == "gainStatus" and s.enemies[1] or s.player
            Combat.addStatus(actor, status, 2147483647); Combat.addStatus(actor, "artifact", 1)
            refresh(h, p, tap)
            local copy = resolve(s)
            local after = op == "gainStatus" and copy.enemies[1] or copy.player
            eq(after.statuses[status], 2147483647); eq(after.statuses.artifact, 0)
        end
    end
end)

test("repeated applications spend separate Artifact charges and expose overflow when exhausted", function()
    for _, charges in ipairs({1, 2}) do
        local h, _, p, tap = setup({{op="applyStatus", status="weak", value=1},
            {op="applyStatus", status="weak", value=1}}, "debuff")
        Combat.addStatus(h.run.combat.player, "weak", 2147483647)
        Combat.addStatus(h.run.combat.player, "artifact", charges)
        if charges == 1 then rejects(h, "status stack overflow")
        else refresh(h, p, tap); eq(resolve(h.run.combat).player.statuses.artifact, 0) end
    end
end)

test("Artifact does not suppress invalid power amounts before core validation", function()
    for _, value in ipairs({-1, 0.5, math.huge}) do
        local h = setup({{op="applyStatus", status="weak", value=value}}, "debuff")
        Combat.addStatus(h.run.combat.player, "artifact", 1)
        rejects(h, "invalid status amount")
    end
end)

F.finish("LUA_INTENT_ARTIFACT_DEBUFF_GATES")
