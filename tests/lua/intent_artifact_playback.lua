local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local F = dofile("tests/lua/support/intent_artifact_fixture.lua")
local eq, test, drainChecked = F.eq, F.test, F.drainChecked

test("each enemy keeps its executed face while later enemies still see new statuses", function()
    local h, u, p, _, tap = F.playbackSetup({"defend"}, {"green_louse", "jaw_worm"})
    local s = h.run.combat
    for _, enemy in ipairs(s.enemies) do enemy.ai, enemy.intentIndex = nil, 1 end
    s.enemies[1].intents = {{id="green_louse_2", kind="debuff", effects={{op="applyStatus", status="vulnerable", value=1}}}}
    s.enemies[2].intents = {{id="jaw_worm_1", kind="attack", effects={{op="gainStatus", status="strength", value=2}, {op="damage", value=10}}}}
    h:refresh()
    -- Source createIntent previews the selected base 10 before its future +2;
    -- the ordered tooltip forecast still includes that next self buff.
    eq(monsterControl(p,"enemy2"):GetChild("intent").text, "10")
    eq(F.forecast(s,2),"12")
    tap("endTurn", 31)
    local sawExposed, sawStrength, sawSecondIntent = false, false, false
    drainChecked(h, u, function(entry, frame)
        if entry.kind == "status" and entry.detail.status == "vulnerable" then
            sawExposed = true
            eq(monsterControl(p,"enemy2"):GetChild("intent").text, "15", "source applyPowers uses current strength before future buff")
        elseif entry.kind == "intent" and entry.detail.enemy == s.enemies[2].id then
            sawSecondIntent = true; eq(monsterControl(p,"enemy2"):GetChild("intent").text, "15")
        elseif entry.kind == "status" and entry.detail.status == "strength" then
            sawStrength = true; eq(frame.enemies[2].statuses.strength, 2)
            eq(monsterControl(p,"enemy2"):GetChild("intent").text, "18", "completed self buff must not be forecast twice")
        end
    end)
    assert(sawExposed and sawSecondIntent and sawStrength)
    eq(F.forecast(s,2),"21", "next tooltip still forecasts the future self buff")
    eq(s.player.hp, s.player.maxHp - 18)
    eq(monsterControl(p,"enemy2"):GetChild("intent").text, "18", "new source createIntent uses current Strength once")
    tap("endTurn", 32)
    local sawNextAction = false
    drainChecked(h, u, function(entry)
        if entry.kind == "status" and entry.detail.status == "strength" then
            sawNextAction = true; eq(monsterControl(p,"enemy2"):GetChild("intent").text, "21")
        end
    end)
    assert(sawNextAction)
    eq(s.player.hp, s.player.maxHp - 39)
    eq(monsterControl(p,"enemy2"):GetChild("intent").text, "21")
    eq(F.forecast(s,2),"24")
end)

F.finish("LUA_INTENT_ARTIFACT_PLAYBACK")
