local F = dofile("tests/lua/support/intent_artifact_fixture.lua")
local H, Combat, counters = F.H, F.Combat, F.counters
local eq, same, test = F.eq, F.same, F.test
local setup, refresh, rejects, resolve = F.setup, F.refresh, F.rejects, F.resolve

test("damage between repeated Vulnerable applications observes the consumed copied charge", function()
    local h, _, p, tap = setup({{op="applyStatus", status="vulnerable", value=1},
        {op="damage", value=10}, {op="applyStatus", status="vulnerable", value=1}, {op="damage", value=10}})
    Combat.addStatus(h.run.combat.player, "artifact", 1)
    local compact, detail = refresh(h, p, tap)
    eq(compact, "10")
    assert(detail:find("10 点伤害", 1, true)); assert(detail:find("15 点伤害", 1, true))
    local copy, hits = resolve(h.run.combat), {}
    for _, event in ipairs(copy.events) do if event.kind == "damage" then hits[#hits+1] = event.detail.amount end end
    eq(hits[1], 10); eq(hits[2], 15); eq(copy.player.statuses.vulnerable, 1)
end)

test("self buffs and target debuffs consume only their own actor's Artifact", function()
    local h, _, p, tap = setup({{op="gainStatus", status="weak", value=1},
        {op="applyStatus", status="vulnerable", value=1}, {op="damage", value=10, times=2}})
    local s = h.run.combat
    Combat.addStatus(s.player, "artifact", 1); Combat.addStatus(s.enemies[1], "artifact", 1)
    eq(refresh(h, p, tap), "10×2")
    local copy = resolve(s)
    eq(copy.player.statuses.artifact, 0); eq(copy.enemies[1].statuses.artifact, 0)
    eq(copy.player.hp, s.player.hp - 20)
end)

test("signed power type depends on incoming amount including zero, not current total", function()
    for _, row in ipairs({
        {status="strength", amount=-2, want="15", tail={op="damage", value=10}},
        {status="dexterity", amount=-2, want="15", tail={op="block", value=10}},
        {status="strength", amount=0, second=-2, want="13", tail={op="damage", value=10}},
        {status="dexterity", amount=0, second=-2, want="13", tail={op="block", value=10}},
    }) do
        local effects = {{op="gainStatus", status=row.status, value=row.amount}}
        if row.second then effects[#effects+1] = {op="gainStatus", status=row.status, value=row.second} end
        effects[#effects+1] = row.tail
        local h, _, p, tap = setup(effects, row.tail.op == "block" and "defend" or "attack")
        Combat.addStatus(h.run.combat.enemies[1], row.status, 5)
        Combat.addStatus(h.run.combat.enemies[1], "artifact", 1)
        local compact, detail=refresh(h, p, tap)
        eq(compact, row.tail.op=="block" and "" or row.want)
        if row.tail.op=="block" then assert(detail:find("获得 "..row.want.." 点格挡",1,true)) end
    end
end)

F.finish("LUA_INTENT_ARTIFACT_ORDERED")
