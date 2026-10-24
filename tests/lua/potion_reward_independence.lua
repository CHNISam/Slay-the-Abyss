package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function won()
    local run=Run.new(Data,42)
    assert(Run.startCombat(run,'cultist_solo'))
    for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
    assert(Run.finishCombat(run));assert(run.rewards.potion)
    return run
end
for _,choice in ipairs({0,1}) do
    local run=won();local offer=run.rewards.potion
    assert(Run.claimCardReward(run,choice))
    assert(Run.potionCount(run)==0,'card choice must never acquire a potion')
    assert(run.phase=='reward' and run.rewards.potion==offer and not offer.resolved)
    assert(#run.deck==10+choice)
    local rewards=run.rewards
    assert(Run.leaveCombatRewards(run));assert(run.pendingCombatRewards.rewards==rewards and not offer.resolved)
    assert(Run.reopenCombatRewards(run))
    assert(Run.claimPotionReward(run));assert(run.phase=='reward')
    assert(Run.leaveCombatRewards(run));assert(run.phase=='map')
end
local full=won()
for _,id in ipairs({'fire_potion','energy_potion','block_potion'}) do assert(Run.obtainPotion(full,id)) end
assert(Run.claimCardReward(full,1),'full belt cannot block independent card selection')
assert(not full.rewards.potion.resolved and #full.deck==11)
local inventory=full.potions
local ok,reason=Run.claimPotionReward(full)
assert(not ok and reason=='potion_slots_full' and full.potions==inventory)
assert(Run.discardPotion(full,2));assert(Run.claimPotionReward(full))
assert(full.potions[2]==full.rewards.potion.id)
assert(Run.leaveCombatRewards(full))
print('LUA_POTION_REWARD_INDEPENDENCE_PASS 3')
