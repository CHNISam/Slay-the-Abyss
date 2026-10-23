package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Run = require("abyss_run")
local data = require("abyss_data")
local rarities = {}
for _, card in ipairs(data.cards.cards) do rarities[card.id] = card.rarity end
local function bossWin(seed)
    local run = Run.new(data, seed)
    run.floor = 16
    assert(Run.startCombat(run, "boss_guardian"))
    -- Isolate the reward boundary, not a full playable boss kill.
    for _, enemy in ipairs(run.combat.enemies) do enemy.hp = 0 end
    assert(Run.finishCombat(run))
    return run
end
for seed = 1, 128 do
    local run = bossWin(seed)
    local seen, choices = {}, Run.rewardOptions(run)
    assert(#choices == 3, "boss must offer three choices")
    for _, id in ipairs(choices) do
        assert(rarities[id] == "rare", "seed " .. seed .. " boss offered " .. id .. " rarity " .. tostring(rarities[id]))
        assert(not seen[id], "duplicate boss card")
        seen[id] = true
    end
end
print("ok boss reward rarity - 128 seeds, three unique rare cards each")

local function equal(a, b) assert(a == b, tostring(a) .. ' ~= ' .. tostring(b)) end
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
local allSeen = {}
for seed = 1, 128 do
    local a, b = bossWin(seed), bossWin(seed)
    same(Run.rewardOptions(a), Run.rewardOptions(b)); equal(a.seed, b.seed)
    local probe = { seed = a.combat.seed }
    for size = rareCount, rareCount - data.rules.rewards.cardChoices + 1, -1 do Combat.random(probe, size) end
    equal(a.seed, probe.seed)
    for _, id in ipairs(Run.rewardOptions(a)) do allSeen[id] = true end
end
local seenCount = 0
for _ in pairs(allSeen) do seenCount = seenCount + 1 end
equal(seenCount, rareCount)
print('ok boss reward deterministic draws and all supported rare cards reachable')

for choice = 0, 3 do
    local run = bossWin(42)
    local options, before = Run.rewardOptions(run), Combat.copy(run)
    options[1] = 'strike'
    same(run, before)
    for _, invalid in ipairs({ -1, 4, 0.5, '1', false, {}, math.huge, 0/0 }) do
        equal(Run.claimCardReward(run, invalid), false); same(run, before)
    end
    equal(Run.claimCardReward(run, nil), false); same(run, before)
    local selected = before.rewards.cards[choice]
    assert(Run.claimCardReward(run, choice))
    equal(run.gold, before.gold); equal(run.seed, before.seed)
    equal(run.hp, before.hp); equal(run.victories, before.victories)
    equal(#run.deck, #before.deck + (choice > 0 and 1 or 0))
    if choice > 0 then
        local card = run.deck[#run.deck]
        equal(card.cardId, selected); equal(card.uid, before.nextDeckUid); equal(card.upgraded, false)
        equal(run.nextDeckUid, before.nextDeckUid + 1)
    else equal(run.nextDeckUid, before.nextDeckUid) end
    equal(run.phase, 'map')
    local after = Combat.copy(run)
    equal(Run.claimCardReward(run, choice), false); equal(Run.finishCombat(run), false)
    same(run, after)
end
print('ok boss reward all three claims, skip, invalid and duplicate requests preserve resources')

-- Frozen pre-change outputs protect other tiers, not an original-RNG parity claim.
local legacy = {
    {1, 44130, 'rampage,carnage,flex'},
    {42, 58063, 'iron_wave,thunderclap,carnage'},
    {65535, 13080, 'battle_trance,hemokinesis,flex'},
}
for _, tier in ipairs({'normal', 'elite'}) do
    for _, fixture in ipairs(legacy) do
        local run = Run.new(data, fixture[1])
        assert(Run.startCombat(run, 'cultist_solo'))
        run.encounterTier = tier -- isolate reward dispatch from encounter AI.
        for _, enemy in ipairs(run.combat.enemies) do enemy.hp = 0 end
        assert(Run.finishCombat(run))
        equal(run.seed, fixture[2]); equal(table.concat(Run.rewardOptions(run), ','), fixture[3])
        equal(run.gold, data.rules.player.startingGold + data.rules.rewards[tier .. 'Gold'])
    end
end
print('ok normal and elite frozen reward outputs and RNG remain unchanged')
print('LUA_BOSS_REWARD_RARITY_PASS')
local run = Run.new(data, 42)
run.floor = 16
assert(Run.startCombat(run, 'boss_guardian'))
local before = Combat.copy(run)
equal(Run.finishCombat(run), false); same(run, before)
run.combat.player.hp = 0
assert(Run.finishCombat(run)); equal(run.phase, 'defeat')
equal(run.gold, data.rules.player.startingGold); equal(#run.deck, #before.deck)
equal(#Run.rewardOptions(run), 0); equal(Run.claimCardReward(run, 1), false)
run = bossWin(42)
equal(run.gold, data.rules.player.startingGold + data.rules.rewards.bossGold)
before = Combat.copy(run)
equal(Run.finishCombat(run), false); same(run, before)
print('ok unfinished, defeated and repeated boss completion never award extra resources')
