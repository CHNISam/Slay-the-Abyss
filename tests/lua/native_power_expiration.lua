package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Run, data = require("abyss_run"), require("abyss_data")
local Schedule, PowerOrder = require("abyss_power_schedule"), require("abyss_power_order")

-- Public acquisition and combat commands only. Seed 42 naturally draws the
-- expiring card on turn 1, Metallicize on turn 2, and lone Flame Barrier again
-- on turn 5. Never install statuses, move cards, or change HP/energy/RNG here.
-- Removing the native Schedule.remove call must fail the three gameplay paths.
local count, failed = 0, 0
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function test(name, fn)
    count = count + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " native_power_expiration " .. count .. " - " .. name
        .. (ok and "" or ": " .. tostring(reason)))
end
local function findCard(run, id)
    for _, card in ipairs(run.combat.hand) do if card.cardId == id then return card end end
end
local function battle(ids, relic)
    local run = Run.new(data, 42)
    if relic then assert(Run.obtainRelic(run, relic)) end
    for _, id in ipairs(ids) do assert(Run.obtainCard(run, id)) end
    assert(Run.startCombat(run, "cultist_solo"))
    equal(run.combat.experimentalMechanics, true, "ordinary complete-catalog combat path")
    equal(run.combat.turn, 1)
    return run
end
local function play(run, id)
    local card = assert(findCard(run, id), id .. " must be naturally drawn")
    assert(Run.play(run, card.uid, 1))
    return card
end
local function scheduled(run)
    return Schedule.list(run.combat.player, PowerOrder.ids)
end
local function metallicizeAfter(id, amount, relic)
    local run = battle({id, "metallicize"}, relic)
    play(run, id)
    equal(run.combat.player.statuses[id], amount, "Power applied")
    local before = scheduled(run)
    assert(Run.endTurn(run))
    equal(run.combat.turn, 2)
    equal(run.combat.player.statuses[id], nil, "temporary Power expired")
    play(run, "metallicize")
    equal(run.combat.player.statuses.metallicize, 3, "later Power applied")
    local after = scheduled(run)
    equal(#after, relic and 2 or 1, "only active scheduled Powers remain")
    equal(after[#after].id, "metallicize")
    assert(after[#after].order > before[#before].order, "later Power gets a new acquisition slot")
    assert(Run.endTurn(run))
    equal(run.combat.phase, "player", "later Power can resolve a normal turn")
    equal(run.combat.player.statuses.metallicize, 3, "persistent Power survives")
    return run, before, after
end

test("expired Flame Barrier allows next-turn naturally drawn Metallicize", function()
    metallicizeAfter("flame_barrier", 4)
end)

test("expired Rage allows next-turn naturally drawn Metallicize", function()
    metallicizeAfter("rage", 3)
end)

test("expired Flame Barrier can be naturally redrawn and reapplied", function()
    local run = battle({"flame_barrier"})
    local first = play(run, "flame_barrier")
    local firstOrder = scheduled(run)[1].order
    for _ = 1, 4 do assert(Run.endTurn(run)) end
    equal(run.combat.turn, 5)
    equal(run.combat.player.statuses.flame_barrier, nil)
    local second = play(run, "flame_barrier")
    equal(second.uid, first.uid, "same naturally reshuffled combat card")
    equal(run.combat.player.statuses.flame_barrier, 4, "reapplied amount does not stack with expired Power")
    local entries = scheduled(run)
    equal(#entries, 1)
    equal(entries[1].id, "flame_barrier")
    assert(entries[1].order > firstOrder, "reapplication gets a new acquisition slot")
    assert(Run.endTurn(run))
    equal(run.combat.player.statuses.flame_barrier, nil, "reapplied Power also expires")
    equal(#scheduled(run), 0)
end)

test("Double Tap still expires without becoming a scheduled Power", function()
    local run = battle({"double_tap", "metallicize"})
    play(run, "double_tap")
    equal(run.combat.player.statuses.double_tap, 1)
    equal(#scheduled(run), 0, "Double Tap is not scheduled")
    assert(Run.endTurn(run))
    equal(run.combat.player.statuses.double_tap, nil)
    play(run, "metallicize")
    local entries = scheduled(run)
    equal(#entries, 1)
    equal(entries[1].id, "metallicize")
end)

test("expiring Flame Barrier preserves an earlier permanent Thorns Power", function()
    local run, before, after = metallicizeAfter("flame_barrier", 4, "bronze_scales")
    equal(before[1].id, "thorns")
    equal(before[2].id, "flame_barrier")
    equal(after[1].id, "thorns")
    equal(after[1].order, before[1].order, "permanent Power keeps its acquisition slot")
    equal(run.combat.player.statuses.thorns, 3)
end)

assert(failed == 0, failed .. "/" .. count .. " native Power expiration tests failed")
print("LUA_NATIVE_POWER_EXPIRATION_PASS " .. count)
