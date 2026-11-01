-- Independent queue expectations: TASK-17.2-guardian-death-tail.md.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local data = require("abyss_data")
local passed, failed = 0, 0
local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " guardian death tail - " .. name .. (ok and "" or ": " .. tostring(why)))
end
local function twin(remainingHp)
    -- Legal cards and actions on the real 240-HP boss. Roll Attack takes 9 HP;
    -- choose starting HP so Twin Slam begins at the requested boundary.
    local s = Combat.new(data, {seed=42, hp=remainingHp + 9, enemies={"guardian"}, deck={"bludgeon"}})
    local enemy = s.enemies[1]
    eq(enemy.hp, 240)
    assert(Combat.play(s, s.hand[1].uid, 1)) -- 32 damage crosses the initial 30 budget.
    eq(enemy.hp, 208); eq(Combat.intent(s, 1).id, "guardian_5")
    assert(Combat.endTurn(s)) -- Close Up: Sharp Hide 3.
    assert(Combat.endTurn(s)) -- Roll Attack: 9 damage.
    eq(s.player.hp, remainingHp); eq(Combat.intent(s, 1).id, "guardian_7")
    eq(enemy.statuses.sharp_hide, 3); eq(enemy.statuses.mode_shift, 0)
    return s, enemy
end

for _, hp in ipairs({1, 8, 9, 16}) do
    test("Twin Slam at " .. hp .. " HP stops before queued power removal and reset", function()
        local s, enemy = twin(hp)
        local first = #s.events + 1
        assert(Combat.endTurn(s))
        eq(s.player.hp, 0); eq(s.phase, "defeat"); eq(enemy.hp, 208)
        eq(enemy.statuses.sharp_hide, 3, "dead player's queue never removes Sharp Hide")
        eq(enemy.statuses.mode_shift, 0, "dead player's queue never applies next Mode Shift")
        eq(enemy.aiPhase, "offense", "shell already opened before damage")
        local hits, losses, wins = 0, 0, 0
        for i = first, #s.events do
            local ev = s.events[i]
            if ev.kind == "damage" and ev.detail.source == enemy.id then hits = hits + 1 end
            if ev.kind == "status" and ev.detail.target == enemy.id then error("post-death power tail emitted") end
            if ev.kind == "defeat" then losses = losses + 1 end
            if ev.kind == "victory" then wins = wins + 1 end
        end
        eq(hits, hp <= 8 and 1 or 2); eq(losses, 1); eq(wins, 0)
        local events = #s.events
        eq(Combat.endTurn(s), false); eq(#s.events, events)
    end)
end

test("surviving Twin Slam at 17 HP still removes Hide and resets the next budget", function()
    local s, enemy = twin(17)
    assert(Combat.endTurn(s))
    eq(s.player.hp, 1); eq(s.phase, "player"); eq(enemy.hp, 208)
    eq(enemy.statuses.sharp_hide, 0); eq(enemy.statuses.mode_shift, 40)
    eq(Combat.intent(s, 1).id, "guardian_3")
end)

print("guardian death tail: " .. passed .. " passed, " .. failed .. " failed")
assert(failed == 0, "Guardian death-tail failures")
