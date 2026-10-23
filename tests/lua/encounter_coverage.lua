-- TASK-15 supporting local evidence only: configured content, not STS1 AI parity,
-- encounter balance, an original-data winning run, or platform acceptance.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local Map = require("abyss_map")
local data = require("abyss_data")
local count, intentCount = 0, 0
local function equal(actual, expected, name)
    assert(actual == expected, name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function same(actual, expected, name)
    if type(expected) ~= "table" then return equal(actual, expected, name) end
    equal(type(actual), "table", name .. " type")
    for key, value in pairs(expected) do same(actual[key], value, name .. "." .. tostring(key)) end
    for key in pairs(actual) do assert(expected[key] ~= nil, name .. " added field " .. tostring(key)) end
end
local function test(name, action)
    action()
    count = count + 1
    print("ok " .. count .. " - " .. name)
end
local function events(state, kind)
    local result = {}
    for _, event in ipairs(state.events) do
        if event.kind == kind then result[#result + 1] = event.detail end
    end
    return result
end

-- Each declared intent starts from neutral statuses. Selecting its index and
-- seeding Block are explicit fixtures; all enemy HP/effects and player HP are real.
-- Oracle reads the source JSON contract without calling production arithmetic.
for _, definition in ipairs(data.enemies.enemies) do
    for index, intent in ipairs(definition.intents) do
        intentCount = intentCount + 1
        for _, startingBlock in ipairs({ 0, 5 }) do
            test(definition.id .. "/" .. intent.id .. " resolves with Block " .. startingBlock, function()
                local s = Combat.new(data, { enemies = { definition.id }, seed = 42 })
                local enemy = s.enemies[1]
                equal(enemy.hp, definition.hp, "source HP")
                enemy.intentIndex = index
                s.player.block = startingBlock
                local preview = Combat.intent(s, 1)
                equal(preview.id, intent.id, "displayed intent")
                preview.effects[1].value = 999 -- detached UI cannot rewrite queued values
                local hp, block, enemyBlock, hits = s.player.hp, startingBlock, 0, 0
                local playerStatuses, enemyStatuses, expectedDamage = {}, {}, {}
                for _, effect in ipairs(intent.effects) do
                    if effect.op == "damage" then
                        for _ = 1, effect.times or 1 do
                            hits = hits + 1
                            local amount = effect.value + (enemyStatuses.strength or 0)
                            if (playerStatuses.vulnerable or 0) > 0 then
                                amount = math.floor(amount * data.rules.combat.vulnerablePercent / 100)
                            end
                            local absorbed = math.min(block, amount)
                            local lost = math.min(hp, amount - absorbed)
                            block, hp = block - absorbed, hp - lost
                            expectedDamage[#expectedDamage + 1] = { amount = lost, blocked = absorbed }
                        end
                    elseif effect.op == "block" then enemyBlock = enemyBlock + effect.value
                    elseif effect.op == "gainStatus" then
                        enemyStatuses[effect.status] = (enemyStatuses[effect.status] or 0) + effect.value
                    elseif effect.op == "applyStatus" then
                        playerStatuses[effect.status] = (playerStatuses[effect.status] or 0) + effect.value
                    else error("unmodelled configured enemy effect: " .. effect.op) end
                end
                assert(Combat.endTurn(s))
                equal(s.player.hp, hp, "player HP")
                equal(enemy.block, enemyBlock, "enemy Block")
                equal(s.player.block, 0, "next player turn clears Block")
                equal(enemy.hp, definition.hp, "enemy HP unchanged")
                for id in pairs(s.catalog.statuses) do
                    equal(s.player.statuses[id] or 0, playerStatuses[id] or 0, "player " .. id)
                    equal(enemy.statuses[id] or 0, enemyStatuses[id] or 0, "enemy " .. id)
                end
                local actualDamage = events(s, "damage")
                equal(#actualDamage, hits, "hit count")
                for i, expected in ipairs(expectedDamage) do
                    equal(actualDamage[i].amount, expected.amount, "hit HP loss")
                    equal(actualDamage[i].blocked, expected.blocked, "hit absorbed")
                    equal(actualDamage[i].source, enemy.id, "damage source")
                    equal(actualDamage[i].target, "player", "damage target")
                end
                equal(events(s, "intent")[1].id, intent.id, "executed intent")
                equal(Combat.intent(s, 1).id, definition.intents[index % #definition.intents + 1].id, "next intent")
                equal(s.phase, "player", "next phase")
            end)
        end
    end
    test(definition.id .. " cycles naturally until defeat or two full cycles", function()
        local s = Combat.new(data, { enemies = { definition.id }, seed = 42 })
        for turn = 1, #definition.intents * 2 do
            if s.phase == "defeat" then break end
            local expected = definition.intents[(turn - 1) % #definition.intents + 1].id
            equal(Combat.intent(s, 1).id, expected, "queued sequence")
            assert(Combat.endTurn(s))
            local executed = events(s, "intent")
            equal(executed[#executed].id, expected, "executed sequence")
        end
        assert(s.phase == "player" or s.phase == "defeat")
    end)
end

test("configured cultist strength persists into its next natural attack", function()
    local s = Combat.new(data, { enemies = { "cultist" }, seed = 42 })
    local enemy = s.enemies[1]
    local attack, buff = enemy.intents[1], enemy.intents[2]
    equal(attack.effects[1].op, "damage", "configured first intent")
    equal(buff.effects[1].op, "gainStatus", "configured second intent")
    equal(buff.effects[1].status, "strength", "configured buff")
    local base, strength = attack.effects[1].value, buff.effects[1].value
    assert(Combat.endTurn(s)) -- ordinary attack, no state edits
    equal(s.player.hp, s.player.maxHp - base, "first attack HP")
    assert(Combat.endTurn(s)) -- actual configured buff
    equal(enemy.statuses.strength, strength, "buff retained after enemy turn")
    local hp = s.player.hp
    assert(Combat.endTurn(s)) -- next attack in the natural cycle
    equal(hp - s.player.hp, base + strength, "buffed attack HP loss")
    equal(enemy.statuses.strength, strength, "strength remains after attack")
    local damage = events(s, "damage")
    equal(#damage, 2, "natural attack count")
    equal(damage[2].amount, base + strength, "buffed damage event")
end)

local generated, encounterById = {}, {}
for _, encounter in ipairs(data.enemies.encounters) do encounterById[encounter.id] = encounter end
for seed = 1, 256 do
    local map = Map.generate(data, seed)
    for _, node in ipairs(map.nodes) do
        if node.encounterId then
            local encounter = assert(encounterById[node.encounterId], "unknown generated encounter")
            assert(node.floor >= encounter.minFloor and node.floor <= encounter.maxFloor, "illegal encounter floor")
            generated[encounter.id] = (generated[encounter.id] or 0) + 1
        end
    end
end
for _, encounter in ipairs(data.enemies.encounters) do
    test(encounter.id .. " rejects both adjacent out-of-range floors without mutation", function()
        for _, floor in ipairs({ encounter.minFloor - 1, encounter.maxFloor + 1 }) do
            local run = Run.new(data, 42)
            -- Includes host-entry fixtures at 0/16: no completed map route claimed.
            run.floor = floor
            local before = Combat.copy(run)
            local ok, reason = Run.startCombat(run, encounter.id)
            equal(ok, false, "out-of-range encounter rejected")
            equal(reason, "wrong_floor", "floor rejection reason")
            same(run, before, "rejected run")
        end
    end)
    test(encounter.id .. " appears in deterministic map sample", function()
        assert(generated[encounter.id], "encounter absent across seeds 1..256: " .. encounter.id)
        print("coverage " .. encounter.id .. " nodes=" .. generated[encounter.id])
    end)
    test(encounter.id .. " starts at both legal floor endpoints and resolves original-data turns", function()
        for _, floor in ipairs({ encounter.minFloor, encounter.maxFloor }) do
            local run = Run.new(data, 42)
            run.floor = floor -- isolated host-entry fixture, not a completed map route
            assert(Run.startCombat(run, encounter.id))
            equal(#run.combat.enemies, #encounter.enemies, "encounter size")
            for i, id in ipairs(encounter.enemies) do
                equal(run.combat.enemies[i].definitionId, id, "encounter member")
            end
            for _ = 1, 10 do
                if run.phase ~= "combat" then break end
                assert(Run.endTurn(run)) -- no healing, HP edits, or forced victories
            end
            assert(run.phase == "combat" or run.phase == "defeat", "unexpected no-action outcome")
            if run.phase == "defeat" then
                equal(run.hp, 0, "defeat HP")
                equal(run.lastResult.encounterId, encounter.id, "defeat ownership")
                local eventCount = #run.combat.events
                local ok, reason = Run.endTurn(run)
                equal(ok, false, "terminal command rejected")
                equal(reason, "not_in_combat", "terminal reason")
                equal(#run.combat.events, eventCount, "terminal event stability")
            end
        end
    end)
end
print("encounter coverage: " .. #data.enemies.enemies .. " enemies, " .. intentCount .. " intents, " .. #data.enemies.encounters .. " encounters; " .. count .. " groups passed")
