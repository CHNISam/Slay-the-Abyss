local fixture = dofile('tests/helpers/boss_rewards.lua')
local Run, data, bossWin = fixture.Run, fixture.data, fixture.bossWin
local equal, same = fixture.equal, fixture.same
local Combat = require('abyss_combat')
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
    dofile('tests/lua/support/finish_combat_rewards.lua')(run)
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

-- Frozen reward-entry seeds/outputs protect other tiers independently of enemy
-- AI consumption. The fourth field is the old HP+9-shuffle LCG state, not an
-- original-RNG parity claim; Cultist now also consumes its required opening roll.
local legacy = {
    {1, 44130, 'rampage,carnage,flex', 20919},
    {42, 58063, 'iron_wave,thunderclap,carnage', 35128},
    {65535, 13080, 'battle_trance,hemokinesis,flex', 17029},
}
for _, tier in ipairs({'normal', 'elite'}) do
    for _, fixture in ipairs(legacy) do
        local run = Run.new(data, fixture[1])
        assert(Run.startCombat(run, 'cultist_solo'))
        run.encounterTier = tier -- isolate reward dispatch from encounter AI.
        run.combat.seed = fixture[4]
        for _, enemy in ipairs(run.combat.enemies) do enemy.hp = 0 end
        assert(Run.finishCombat(run))
        equal(run.seed, fixture[2]); equal(table.concat(Run.rewardOptions(run), ','), fixture[3])
        equal(run.gold, data.rules.player.startingGold + data.rules.rewards[tier .. 'Gold'])
    end
end
print('ok normal and elite frozen reward outputs and RNG remain unchanged')
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
print('LUA_BOSS_REWARD_TRANSACTIONS_PASS')
