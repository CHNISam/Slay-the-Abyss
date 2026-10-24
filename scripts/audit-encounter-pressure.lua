-- TASK-15 diagnostic, not a balance or platform acceptance test.
-- Run with: npm run build:data; node scripts/test-lua.mjs scripts/audit-encounter-pressure.lua
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Run = require("abyss_run")
local data = require("abyss_data")
local limit = 20

print("Original-data idle diagnostic; seed=42; no cards/potions played; max enemy turns=" .. limit)
print("Floor is an isolated legal-entry fixture, not a completed map route.")
print("| Encounter | Tier | Enemies | Total enemy HP | HP lost on enemy turns 1 / 2 / 3 | Defeat on enemy turn |")
print("|---|---|---:|---:|---|---:|")
for _, encounter in ipairs(data.enemies.encounters) do
    local run = Run.new(data, 42)
    run.floor = encounter.minFloor
    assert(Run.startCombat(run, encounter.id))
    local enemyCount = #run.combat.enemies
    local hp, totalHp, losses, turn = run.hp, 0, {}, 0
    for _, enemy in ipairs(run.combat.enemies) do totalHp = totalHp + enemy.hp end
    while run.phase == "combat" and turn < limit do
        turn = turn + 1
        assert(Run.endTurn(run))
        losses[turn] = hp - run.combat.player.hp
        hp = run.combat.player.hp
    end
    local first = {}
    for i = 1, 3 do first[i] = losses[i] and tostring(losses[i]) or "—" end
    local defeat = run.phase == "defeat" and tostring(turn) or ">" .. limit
    print("| " .. encounter.id .. " | " .. encounter.tier .. " | " .. enemyCount
        .. " | " .. totalHp .. " | " .. table.concat(first, " / ") .. " | " .. defeat .. " |")
end
print("Loss is actual HP lost (capped by remaining HP); no-action survival is not player difficulty.")
