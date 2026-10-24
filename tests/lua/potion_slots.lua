-- STS1 fixed slot identity and leftmost-empty acquisition. Fixed source methods:
-- docs/reviews/TASK-14.1-potion-slots.md. No invented reward/drop/price rules.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Run, Combat, data = require("abyss_run"), require("abyss_combat"), require("abyss_data")
local count, failures = 0, {}
local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
local function same(a, b)
    equal(type(a), type(b))
    if type(a) ~= "table" then equal(a, b); return end
    for k, v in pairs(a) do same(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil, "unexpected " .. tostring(k)) end
end
local function test(name, fn)
    local ok, reason = pcall(fn)
    if ok then count = count + 1; print("ok potion_slots " .. count .. " - " .. name)
    else failures[#failures + 1] = name .. ": " .. tostring(reason); print("not ok - " .. failures[#failures]) end
end
local function battle(potions)
    local run = Run.new(data, 42)
    run.potions = potions
    assert(Run.startCombat(run, "cultist_solo"))
    return run
end
local function rejected(run, slot, target, reason)
    local before = Combat.copy(run)
    local ok, actual = Run.usePotion(run, slot, target)
    equal(ok, false); equal(actual, reason); same(run, before)
end

test("consuming middle bottle leaves its empty slot and neighbors in place", function()
    local run = battle({ "fire_potion", "strength_potion", "regen_potion" })
    assert(Run.usePotion(run, 2))
    equal(run.potions[1], "fire_potion"); equal(run.potions[2], nil); equal(run.potions[3], "regen_potion")
    equal(run.combat.player.statuses.strength, 2)
    rejected(run, 2, nil, "empty_potion_slot")
    equal(Run.potionCount(run), 2)
end)

test("view and commands retain slot three after slot one is consumed", function()
    local run = battle({ "fire_potion", "energy_potion", "regen_potion" })
    local hp = run.combat.enemies[1].hp
    assert(Run.usePotion(run, 1, 1))
    equal(run.combat.enemies[1].hp, hp - 20)
    local view = Run.potionView(run)
    equal(view[1], nil); equal(view[2].id, "energy_potion"); equal(view[3].slot, 3)
    equal(view[3].id, "regen_potion"); equal(view[3].canUse, true)
    assert(Run.usePotion(run, 3)); equal(run.combat.player.statuses.regen, 5)
    equal(run.potions[2], "energy_potion"); equal(Run.potionCount(run), 1)
end)

test("obtaining fills the leftmost empty slot and full inventory refuses atomically", function()
    local run = Run.new(data, 42)
    run.potions = { [3] = "regen_potion" }
    local ok, slot = Run.obtainPotion(run, "fire_potion"); equal(ok, true); equal(slot, 1)
    ok, slot = Run.obtainPotion(run, "energy_potion"); equal(ok, true); equal(slot, 2)
    equal(run.potions[3], "regen_potion"); equal(Run.potionCount(run), 3)
    local before = Combat.copy(run)
    ok, slot = Run.obtainPotion(run, "block_potion"); equal(ok, false); equal(slot, "potion_slots_full")
    same(run, before)
    ok, slot = Run.obtainPotion(run, "unknown"); equal(ok, false); equal(slot, "unknown_potion")
    same(run, before)
end)

test("refilling a consumed middle slot does not move or replace other bottles", function()
    local run = battle({ "fire_potion", "energy_potion", "regen_potion" })
    assert(Run.usePotion(run, 2)); equal(run.combat.energy, 5)
    local ok, slot = Run.obtainPotion(run, "block_potion"); equal(ok, true); equal(slot, 2)
    same(run.potions, { "fire_potion", "block_potion", "regen_potion" })
    assert(Run.usePotion(run, 2)); equal(run.combat.player.block, 12)
    equal(run.potions[3], "regen_potion"); equal(Run.potionCount(run), 2)
end)

test("invalid target and non-player turn never move or consume sparse inventory", function()
    local run = battle({ [2] = "fire_potion", [3] = "energy_potion" })
    rejected(run, 1, 1, "empty_potion_slot")
    rejected(run, 2, nil, "invalid_target")
    rejected(run, 4, 1, "invalid_potion_slot")
    run.combat.phase = "enemy"
    rejected(run, 3, nil, "not_player_turn")
    run.combat.phase, run.phase = "player", "map"
    rejected(run, 2, 1, "not_in_combat")
end)

test("last-enemy fire kill and defeat preserve untouched slot identity", function()
    local run = battle({ [2] = "fire_potion", [3] = "regen_potion" })
    run.combat.player.hp, run.combat.enemies[1].hp = 40, 20
    assert(Run.usePotion(run, 2, 1))
    equal(run.phase, "reward"); equal(run.hp, 46)
    equal(run.potions[2], nil); equal(run.potions[3], "regen_potion")
    rejected(run, 3, nil, "not_in_combat")
    assert(Run.claimCardReward(run, 0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run); assert(Run.startCombat(run, "cultist_solo"))
    equal(run.potions[3], "regen_potion")
    run.combat.player.hp = 1
    for _ = 1, 10 do if run.phase ~= "combat" then break end; assert(Run.endTurn(run)) end
    equal(run.phase, "defeat")
    rejected(run, 3, nil, "not_in_combat"); equal(run.potions[3], "regen_potion")
end)

if #failures > 0 then error(table.concat(failures, "\n")) end
print("LUA_POTION_SLOTS_PASS " .. count)
