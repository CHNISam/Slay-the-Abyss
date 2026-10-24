local F = dofile("tests/lua/support/intent_artifact_fixture.lua")
local H, Combat, counters = F.H, F.Combat, F.counters
local eq, same, test = F.eq, F.same, F.test
local setup, refresh, rejects, resolve = F.setup, F.refresh, F.rejects, F.resolve

test("positive self buff preserves Artifact for the later debuff", function()
    local h, _, p, tap = setup({{op="gainStatus", status="strength", value=2},
        {op="gainStatus", status="weak", value=1}, {op="damage", value=10}})
    Combat.addStatus(h.run.combat.enemies[1], "strength", -4)
    Combat.addStatus(h.run.combat.enemies[1], "artifact", 1)
    eq(refresh(h, p, tap), "8")
    local copy = resolve(h.run.combat)
    eq(copy.enemies[1].statuses.strength, -2); eq(copy.enemies[1].statuses.artifact, 0)
end)

test("without Artifact ordered status modifiers still reach later damage and block", function()
    local h, _, p, tap = setup({{op="gainStatus", status="strength", value=-2},
        {op="gainStatus", status="weak", value=1}, {op="damage", value=10},
        {op="gainStatus", status="dexterity", value=3}, {op="gainStatus", status="frail", value=1},
        {op="block", value=10}})
    local compact, detail = refresh(h, p, tap)
    eq(compact, "6"); assert(detail:find("获得 9 点格挡", 1, true))
    eq(resolve(h.run.combat).enemies[1].block, 9)
end)

test("Artifact does not suppress invalid power amounts before core validation", function()
    for _, value in ipairs({-1, 0.5, math.huge}) do
        local h = setup({{op="applyStatus", status="weak", value=value}}, "debuff")
        Combat.addStatus(h.run.combat.player, "artifact", 1)
        rejects(h, "invalid status amount")
    end
end)

F.finish("LUA_INTENT_ARTIFACT_VALIDATION")
