local F = dofile("tests/lua/support/intent_artifact_fixture.lua")
local H, Combat, counters = F.H, F.Combat, F.counters
local eq, same, test = F.eq, F.same, F.test
local setup, refresh, rejects, resolve = F.setup, F.refresh, F.rejects, F.resolve
local drainChecked = F.drainChecked

test("each enemy keeps its executed face while later enemies still see new statuses", function()
    local h, u, p, _, tap = H.setup({"defend"}, {"fat_gremlin", "jaw_worm"})
    local s = h.run.combat
    for _, enemy in ipairs(s.enemies) do enemy.ai, enemy.intentIndex = nil, 1 end
    s.enemies[1].intents = {{id="expose", kind="debuff", effects={{op="applyStatus", status="vulnerable", value=1}}}}
    s.enemies[2].intents = {{id="strike", kind="attack", effects={{op="gainStatus", status="strength", value=2}, {op="damage", value=10}}}}
    h:refresh(); eq(p:GetChild("enemy2"):GetChild("intent").text, "12")
    tap("endTurn", 31)
    local sawExposed, sawStrength, sawSecondIntent = false, false, false
    drainChecked(h, u, function(entry, frame)
        if entry.kind == "status" and entry.detail.status == "vulnerable" then
            sawExposed = true
            eq(p:GetChild("enemy2"):GetChild("intent").text, "18", "unacted enemy must see Vulnerable")
        elseif entry.kind == "intent" and entry.detail.enemy == s.enemies[2].id then
            sawSecondIntent = true; eq(p:GetChild("enemy2"):GetChild("intent").text, "18")
        elseif entry.kind == "status" and entry.detail.status == "strength" then
            sawStrength = true; eq(frame.enemies[2].statuses.strength, 2)
            eq(p:GetChild("enemy2"):GetChild("intent").text, "18", "completed self buff must not be forecast twice")
        end
    end)
    assert(sawExposed and sawSecondIntent and sawStrength)
    eq(s.player.hp, s.player.maxHp - 18)
    eq(p:GetChild("enemy2"):GetChild("intent").text, "21", "new player phase must preview the next action")
    tap("endTurn", 32)
    local sawNextAction = false
    drainChecked(h, u, function(entry)
        if entry.kind == "status" and entry.detail.status == "strength" then
            sawNextAction = true; eq(p:GetChild("enemy2"):GetChild("intent").text, "21")
        end
    end)
    assert(sawNextAction)
    eq(s.player.hp, s.player.maxHp - 39)
    eq(p:GetChild("enemy2"):GetChild("intent").text, "24")
end)

test("two stock applying enemies exhaust exactly two charges without historical-frame recovery", function()
    local h, u, p, _, tap = H.setup({"defend"}, {"fat_gremlin", "fat_gremlin"})
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

F.finish("LUA_INTENT_ARTIFACT_PLAYBACK")
