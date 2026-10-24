local F = dofile("tests/lua/support/intent_artifact_fixture.lua")
local H, Combat, counters = F.H, F.Combat, F.counters
local eq, same, test = F.eq, F.same, F.test
local setup, refresh, rejects, resolve = F.setup, F.refresh, F.rejects, F.resolve

test("stock Fat Gremlin refresh and real end-turn agree at Weak upper bound with Artifact", function()
    local h, u, p, tap, drain = setup()
    local s = h.run.combat
    Combat.addStatus(s.player, "weak", 2147483647)
    Combat.addStatus(s.player, "artifact", 1)
    local copy = Combat.copy(s)
    assert(Combat.endTurn(copy))
    eq(copy.player.statuses.weak, 2147483646); eq(copy.player.statuses.artifact, 0)
    local compact, detail = refresh(h, p, tap)
    eq(compact, "4"); assert(detail:find("使你获得 1 层虚弱", 1, true))
    assert(u:showStatus(0))
    eq(p:GetChild("statusInfo"):GetChild("name2").text, "虚弱 2147483647 · 减益")
    local recoveries = counters.recoveries
    tap("hero", 12); tap("endTurn", 13); drain()
    eq(counters.recoveries, recoveries, "the complete boundary playback must not need recovery")
    eq(s.player.statuses.weak, 2147483646); eq(s.player.statuses.artifact, 0)
    eq(p:GetChild("hero"):GetChild("statusRow"):GetChild("count1").text, "2147483646")
end)

test("ordinary stock values retain status details, card preview and command behavior", function()
    local h, u, p, tap, drain = setup()
    local s = h.run.combat
    Combat.addStatus(s.player, "weak", 2); Combat.addStatus(s.player, "artifact", 1)
    local before = Combat.copy(s)
    eq(refresh(h, p, tap), "4")
    for _, card in ipairs(s.hand) do
        local preview = Combat.cardPreview(s, card)
        eq(preview[1].low, card.cardId == "strike" and 4 or 5)
    end
    assert(u:showStatus(0))
    local info = p:GetChild("statusInfo")
    eq(info:GetChild("name1").text, "人工制品 1 · 增益")
    eq(info:GetChild("name2").text, "虚弱 2 · 减益")
    same(s, before)
    tap("hero", 21); tap("endTurn", 22); drain()
    eq(s.player.statuses.weak, 1); eq(s.player.statuses.artifact, 0)
    eq(p:GetChild("hero"):GetChild("statusRow"):GetChild("count1").text, "1")
end)

test("neighboring boundary and stock non-applying intent remain valid", function()
    local h, _, p, tap = setup()
    Combat.addStatus(h.run.combat.player, "weak", 2147483646)
    Combat.addStatus(h.run.combat.player, "artifact", 1)
    eq(refresh(h, p, tap), "4")
    local jaw, _, panel, _, jawTap = H.setup({"defend"}, {"jaw_worm"})
    Combat.addStatus(jaw.run.combat.player, "weak", 2147483647)
    Combat.addStatus(jaw.run.combat.player, "artifact", 1)
    eq(refresh(jaw, panel, jawTap), "11")
end)

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

test("unblocked true overflow remains visible and leaves the live state untouched", function()
    local h = setup()
    Combat.addStatus(h.run.combat.player, "weak", 2147483647)
    rejects(h, "status stack overflow")
    local ok, why = pcall(Combat.endTurn, Combat.copy(h.run.combat))
    eq(ok, false); assert(tostring(why):find("status stack overflow", 1, true))
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
        if row.tail.op=="block" then assert(detail:find("格挡 "..row.want,1,true)) end
    end
end)

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

F.finish("LUA_INTENT_ARTIFACT_PREVIEW")
