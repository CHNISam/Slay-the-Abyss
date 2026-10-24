package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Run = require("abyss_run")
local data = require("abyss_data")
local function bossWin(seed)
    local run = Run.new(data, seed)
    run.floor = 16
    assert(Run.startCombat(run, "boss_guardian"))
    -- Isolate the reward boundary, not a full playable boss kill.
    for _, enemy in ipairs(run.combat.enemies) do enemy.hp = 0 end
    assert(Run.finishCombat(run))
    return run
end
local function equal(a, b)
    -- Build diagnostics only on failure: full-state rejection checks compare
    -- thousands of scalar values, including the untouched production catalog.
    if a ~= b then error(tostring(a) .. ' ~= ' .. tostring(b), 2) end
end
local function same(a, b)
    equal(type(a), type(b))
    if type(a) ~= 'table' then equal(a, b); return end
    for key, value in pairs(a) do same(value, b[key]) end
    for key in pairs(b) do assert(a[key] ~= nil, 'unexpected key ' .. tostring(key)) end
end
local Combat, Effects = require('abyss_combat'), require('abyss_effects')
local rareCount = 0
for _, card in ipairs(data.cards.cards) do
    if card.rarity == 'rare' and not card.condition and not card.costMode and Effects.supported(card.effects) then
        rareCount = rareCount + 1
    end
end
assert(rareCount >= data.rules.rewards.cardChoices, 'production supported rare pool must fill every choice')
-- Keep deterministic replay batches bounded under the unchanged per-file budget.
-- Across eight entry points every seed from 1 through 128 is replayed twice.
-- Each constructs real independent runs; no state, draws or assertions are skipped.
local function deterministicSeeds(first, last)
    for seed = first, last do
        local a, b = bossWin(seed), bossWin(seed)
        same(Run.rewardOptions(a), Run.rewardOptions(b)); equal(a.seed, b.seed)
        equal(a.seed,a.combat.seed) -- card rewards own an independent continuous stream.
        local Random=require('abyss_sts_random')
        same(Random.snapshot(a.cardRng),Random.snapshot(b.cardRng))
        assert(a.cardRng.counter>=6 and a.cardRarityOffset==5)
    end
end
return { Run = Run, data = data, bossWin = bossWin, equal = equal, same = same,
    rareCount = rareCount, deterministicSeeds = deterministicSeeds }
