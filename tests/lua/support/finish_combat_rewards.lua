-- Explicitly finish the potion decision when another suite needs the next room.
-- Potion ownership/atomic rejection is asserted in its dedicated fixtures.
return function(run)
    local Run=require('abyss_run')
    if run.phase~='reward' or not run.rewards.manualContinue then return end
    local potion=run.rewards.potion
    if potion and not potion.resolved then
        local ok,why=Run.claimPotionReward(run)
        if not ok then
            assert(why=='potion_slots_full' or why=='potion_content_unavailable' or why=='potion_blocked_by_sozu',why)
            assert(Run.skipPotionReward(run))
        end
    end
    assert(Run.leaveCombatRewards(run))
end
