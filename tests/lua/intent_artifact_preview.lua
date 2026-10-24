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
    eq(compact, "4"); assert(detail:find("使你获得 1 回合虚弱", 1, true))
    assert(u:showStatus(0))
    eq(p:GetChild("statusInfo"):GetChild("name2").text, "虚弱 2147483647")
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
    eq(info:GetChild("name1").text, "人工制品 1")
    eq(info:GetChild("name2").text, "虚弱 2")
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

F.finish("LUA_INTENT_ARTIFACT_PREVIEW")
