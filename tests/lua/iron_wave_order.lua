-- STS1 IronWave.use queues GainBlockAction before DamageAction, base 5/5,
-- upgraded 7/7. Fixed mirror and evidence limits: docs/reviews/TASK-16-iron-wave.md.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, data = require("abyss_combat"), require("abyss_data")
local count, failures = 0, {}
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function test(name, fn)
    local ok, reason = pcall(fn)
    if ok then count = count + 1; print("ok iron_wave " .. count .. " - " .. name)
    else failures[#failures + 1] = name .. ": " .. tostring(reason); print("not ok - " .. failures[#failures]) end
end
local function battle(upgraded)
    local state = Combat.new(data, { seed = 42, enemies = { "jaw_worm" },
        deck = { { cardId = "iron_wave", upgraded = upgraded } } })
    state.player.hp = 80
    local enemy = state.enemies[1]
    enemy.hp, enemy.maxHp = 100, 100
    return state, state.hand[1], enemy
end
local function play(state, card)
    assert(Combat.play(state, card.uid, 1))
    equal(state.energy, 2, "one energy")
    equal(#state.hand, 0); equal(#state.discard, 1); equal(state.discard[1].uid, card.uid)
    equal(#state.exhaust, 0)
end
local function orderedFrames(state, blockAmount, damageAmount, thornsBlocked, thornsLost)
    local blockIndex, damageIndex, thornsIndex
    for index, event in ipairs(state.events) do
        if event.kind == "block" and event.detail.target == "player" then
            blockIndex = index
            equal(event.detail.amount, blockAmount, "block event")
            equal(event.frame.player.block, blockAmount, "block frame")
        elseif event.kind == "damage" and event.detail.source == "player" then
            damageIndex = index; equal(event.detail.amount, damageAmount, "attack event")
        elseif event.kind == "status_damage" and event.detail.status == "thorns" then
            thornsIndex = index
            equal(event.detail.blocked, thornsBlocked, "retaliation absorbed")
            equal(event.detail.amount, thornsLost, "retaliation HP lost")
        end
    end
    assert(blockIndex and damageIndex and thornsIndex and blockIndex < damageIndex and damageIndex < thornsIndex,
        "block must be committed before attack and retaliation")
end

for _, variant in ipairs({ { name = "base", upgraded = false, amount = 5 },
    { name = "upgraded", upgraded = true, amount = 7 } }) do
    local function scenario(name, fn) test(variant.name .. " " .. name, function() fn(variant.upgraded, variant.amount) end) end
    scenario("new block absorbs Thorns before any HP is lost", function(upgraded, amount)
        local state, card, enemy = battle(upgraded)
        Combat.addStatus(enemy, "thorns", 3)
        play(state, card)
        equal(state.player.hp, 80); equal(state.player.block, amount - 3)
        equal(enemy.hp, 100 - amount); equal(state.phase, "player")
        orderedFrames(state, amount, amount, 3, 0)
    end)
    scenario("lethal last-enemy hit survives retaliation at one HP", function(upgraded, amount)
        local state, card, enemy = battle(upgraded)
        state.player.hp, enemy.hp = 1, 1
        Combat.addStatus(enemy, "thorns", 3)
        play(state, card)
        equal(enemy.hp, 0); equal(state.player.hp, 1); equal(state.player.block, amount - 3)
        equal(state.phase, "victory")
        orderedFrames(state, amount, 1, 3, 0)
    end)
    scenario("partial protection applies before lethal Thorns", function(upgraded, amount)
        local state, card, enemy = battle(upgraded)
        state.player.hp = 3
        Combat.addStatus(enemy, "thorns", 10)
        play(state, card)
        equal(state.player.hp, 0); equal(state.player.block, 0); equal(state.phase, "defeat")
        equal(enemy.hp, 100 - amount)
        orderedFrames(state, amount, amount, amount, 3)
    end)
    scenario("zero attack still uses the new block against Thorns", function(upgraded, amount)
        local state, card, enemy = battle(upgraded)
        Combat.addStatus(state.player, "strength", -100)
        Combat.addStatus(enemy, "thorns", 3)
        play(state, card)
        equal(enemy.hp, 100); equal(state.player.hp, 80); equal(state.player.block, amount - 3)
        orderedFrames(state, amount, 0, 3, 0)
    end)
    scenario("enemy block does not suppress retaliation", function(upgraded, amount)
        local state, card, enemy = battle(upgraded)
        enemy.block = 100
        Combat.addStatus(enemy, "thorns", 3)
        play(state, card)
        equal(enemy.hp, 100); equal(enemy.block, 100 - amount)
        equal(state.player.hp, 80); equal(state.player.block, amount - 3)
        orderedFrames(state, amount, 0, 3, 0)
    end)
    scenario("Dexterity and Frail modify the block before the attack", function(upgraded, amount)
        local state, card, enemy = battle(upgraded)
        Combat.addStatus(state.player, "dexterity", 3)
        Combat.addStatus(state.player, "frail", 1)
        Combat.addStatus(enemy, "thorns", 6)
        play(state, card)
        local gained = upgraded and 7 or 6 -- floor((7 + 3) * .75) or floor((5 + 3) * .75)
        equal(state.player.hp, 80); equal(state.player.block, gained - 6)
        equal(enemy.hp, 100 - amount)
        orderedFrames(state, gained, amount, 6, 0)
    end)
end

if #failures > 0 then error(table.concat(failures, "\n")) end
print("LUA_IRON_WAVE_PASS " .. count)
