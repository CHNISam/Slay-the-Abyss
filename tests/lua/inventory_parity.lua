-- Independent STS1 expectations. Sources and the unverified boundaries live in
-- docs/reviews/TASK-14.1-inventory-parity.md; do not derive expectations from data.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Run, Combat = require("abyss_run"), require("abyss_combat")
local data = require("abyss_data")
local count, failures = 0, {}
local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
local function test(name, fn)
    local ok, reason = pcall(fn)
    if ok then count = count + 1; print("ok inventory_parity " .. count .. " - " .. name)
    else failures[#failures + 1] = name .. ": " .. tostring(reason); print("not ok - " .. failures[#failures]) end
end
local function definition(entries, id)
    for _, entry in ipairs(entries) do if entry.id == id then return entry end end
    error("missing definition " .. id)
end
local function battle(relics, hp)
    local run = Run.new(data, 42)
    run.relics, run.hp = relics or { "burning_blood" }, hp or 40
    assert(Run.startCombat(run, "cultist_solo"))
    -- Inventory tests install neutral/attack fixtures, not the Cultist decision state.
    run.combat.enemies[1].ai=nil; run.combat.enemies[1].intentIndex=1
    return run
end

test("Bronze Scales is a common relic granting exactly three Thorns", function()
    equal(definition(data.relics.relics, "bronze_scales").rarity, "common")
    local run = battle({ "bronze_scales" })
    equal(run.combat.player.statuses.thorns, 3)
end)

test("Bronze Scales retaliates against each zero-damage enemy hit", function()
    for _, hits in ipairs({ 1, 3 }) do
        local run = battle({ "bronze_scales" })
        local enemy, player = run.combat.enemies[1], run.combat.player
        -- Isolate a NORMAL attack lowered to zero by Strength. The catalog retains
        -- the real Bronze Scales effect; this fixture is not an enemy-AI oracle.
        enemy.intents = { { effects = { { op = "damage", value = 1, times = hits } } } }
        Combat.addStatus(enemy, "strength", -1)
        local enemyHp = enemy.hp
        assert(Run.endTurn(run))
        equal(player.hp, 40)
        equal(enemy.hp, enemyHp - 3 * hits)
        equal(player.statuses.thorns, 3)
    end
end)

test("zero-damage Thorns kill interrupts multihit and heals Burning Blood once", function()
    local run = battle({ "burning_blood", "bronze_scales" })
    local enemy = run.combat.enemies[1]
    enemy.hp = 3
    enemy.intents = { { effects = { { op = "damage", value = 0, times = 3 } } } }
    assert(Run.endTurn(run))
    equal(enemy.hp, 0); equal(run.phase, "reward"); equal(run.hp, 46)
    local attacks = 0
    for _, event in ipairs(run.combat.events) do
        if event.kind == "damage" and event.detail.source == enemy.id then attacks = attacks + 1 end
    end
    equal(attacks, 1)
    equal(Run.finishCombat(run), false); equal(run.hp, 46)
end)

test("Thorns ignores fixed potion damage even when its amount is zero", function()
    local run = battle()
    run.potions = { "fire_potion" }
    local enemy = run.combat.enemies[1]
    Combat.addStatus(enemy, "thorns", 3)
    Combat.damage(run.combat, run.combat.player, enemy, 0, true)
    equal(run.combat.player.hp, 40)
    assert(Run.usePotion(run, 1, 1)); equal(run.combat.player.hp, 40)
end)

test("six opening relics apply their published amounts once and reset next combat", function()
    local run = battle({ "anchor", "vajra", "bag_of_preparation", "lantern", "oddly_smooth_stone", "bronze_scales" })
    local state = run.combat
    equal(state.player.block, 10); equal(#state.hand, 7); equal(state.energy, 4)
    equal(state.player.statuses.strength, 1); equal(state.player.statuses.dexterity, 1)
    equal(state.player.statuses.thorns, 3)
    -- Neutral enemy action isolates the next player turn's ordinary refresh.
    state.enemies[1].intents = { { effects = {} } }
    assert(Run.endTurn(run))
    equal(state.player.block, 0); equal(#state.hand, 5); equal(state.energy, 3)
    equal(state.player.statuses.strength, 1); equal(state.player.statuses.dexterity, 1)
    equal(state.player.statuses.thorns, 3)
    state.enemies[1].hp = 20; run.potions = { "fire_potion" }
    assert(Run.usePotion(run, 1, 1)); assert(Run.claimCardReward(run, 0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run)
    run.floor = 1
    assert(Run.startCombat(run, "cultist_solo"))
    equal(run.combat.player.block, 10); equal(#run.combat.hand, 7); equal(run.combat.energy, 4)
    equal(run.combat.player.statuses.strength, 1); equal(run.combat.player.statuses.dexterity, 1)
    equal(run.combat.player.statuses.thorns, 3)
end)

test("self potions retain their published values without spending energy or playing cards", function()
    for _, example in ipairs({
        { "block_potion", "block", 12 }, { "strength_potion", "strength", 2 },
        { "dexterity_potion", "dexterity", 2 }, { "energy_potion", "energy", 5 },
        { "regen_potion", "regen", 5 }
    }) do
        local run = battle()
        run.potions = { example[1] }
        assert(Run.usePotion(run, 1))
        local state, field = run.combat, example[2]
        equal(field == "energy" and state.energy or field == "block" and state.player.block
            or state.player.statuses[field], example[3])
        equal(state.energy, field == "energy" and 5 or 3)
        equal(#state.hand, 5); equal(#state.discard, 0); equal(#state.exhaust, 0)
        equal(#run.potions, 0)
    end
end)

test("Block Potion ignores Dexterity and Frail while the next Defend uses both", function()
    local run = battle()
    run.potions = { "dexterity_potion", "block_potion" }
    Combat.addStatus(run.combat.player, "frail", 2)
    assert(Run.usePotion(run, 1)); assert(Run.usePotion(run, 2))
    equal(run.combat.player.block, 12)
    local uid
    for _, card in ipairs(run.combat.hand) do if card.cardId == "defend" then uid = card.uid; break end end
    assert(uid, "seed 42 must include Defend")
    assert(Run.play(run, uid))
    equal(run.combat.player.block, 17) -- floor((5 + 2) * .75) = 5, not a potion modifier.
end)

test("Poison Potion applies six stacks without immediate damage then ticks through block", function()
    local run = battle()
    run.potions = { "poison_potion" }
    local enemy = run.combat.enemies[1]
    local hp = enemy.hp
    enemy.block = 100
    enemy.intents = { { effects = {} } }
    assert(Run.usePotion(run, 1, 1))
    -- usePotion commits a detached candidate; retained enemy tables are stale.
    enemy = run.combat.enemies[1]
    equal(enemy.hp, hp); equal(enemy.statuses.poison, 6)
    assert(Run.endTurn(run))
    equal(enemy.hp, hp - 6); equal(enemy.statuses.poison, 5)
end)

test("two Regen Potions stack to ten then heal before enemy action and decay once", function()
    local run = battle()
    run.potions = { "regen_potion", "regen_potion" }
    assert(Run.usePotion(run, 1)); assert(Run.usePotion(run, 2))
    local state = run.combat
    equal(state.player.hp, 40); equal(state.player.statuses.regen, 10)
    state.enemies[1].intents = { { effects = { { op = "damage", value = 6 } } } }
    assert(Run.endTurn(run))
    equal(state.player.hp, 44); equal(state.player.statuses.regen, 9)
    local healIndex, damageIndex
    for index, event in ipairs(state.events) do
        if event.kind == "heal" and event.detail.status == "regen" then healIndex = index end
        if event.kind == "damage" and event.detail.target == "player" then damageIndex = index end
    end
    assert(healIndex and damageIndex and healIndex < damageIndex)
end)

test("final-enemy potion kill skips Regen turn end and heals only Burning Blood", function()
    local run = battle()
    run.potions = { "regen_potion", "fire_potion" }
    run.combat.enemies[1].hp = 20
    assert(Run.usePotion(run, 1)); assert(Run.usePotion(run, 2, 1))
    equal(run.phase, "reward"); equal(run.hp, 46)
    for _, event in ipairs(run.combat.events) do
        assert(not (event.kind == "heal" and event.detail.status == "regen"))
    end
end)

if #failures > 0 then error(table.concat(failures, "\n")) end
print("LUA_INVENTORY_PARITY_PASS " .. count)
