local fixture = dofile('tests/helpers/boss_rewards.lua')
local Run, data, bossWin = fixture.Run, fixture.data, fixture.bossWin
local rarities = {}
for _, card in ipairs(data.cards.cards) do rarities[card.id] = card.rarity end
local allSeen = {}
for seed = 1, 128 do
    local run = bossWin(seed)
    local seen, choices = {}, Run.rewardOptions(run)
    assert(#choices == 3, "boss must offer three choices")
    for _, id in ipairs(choices) do
        assert(rarities[id] == "rare", "seed " .. seed .. " boss offered " .. id .. " rarity " .. tostring(rarities[id]))
        assert(not seen[id], "duplicate boss card")
        seen[id] = true
        allSeen[id] = true
    end
end
print("ok boss reward rarity - 128 seeds, three unique rare cards each")

local seenCount = 0
for _ in pairs(allSeen) do seenCount = seenCount + 1 end
fixture.equal(seenCount, fixture.rareCount)
print('ok all supported rare cards reachable across 128 seeds')
print('LUA_BOSS_REWARD_RARITY_PASS')
