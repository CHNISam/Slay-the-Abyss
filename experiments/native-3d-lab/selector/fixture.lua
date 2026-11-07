-- Explicit reward fixture, generated only by the existing Run commands.
local Run=require('abyss_run')
local Combat=require('abyss_combat')
local M={}
function M.make(data,seed,options)
    local run=Run.new(data,seed or 42)
    if options and options.relic then assert(Run.obtainRelic(run,options.relic))end
    assert(Run.startCombat(run,'cultist_solo'))
    local commands=0
    while run.phase=='combat' and commands<100 do
        local battle=run.combat
        assert(not battle.pendingChoice,'fixture requires manual card choice; unsupported')
        local played=false
        for _,card in ipairs(battle.hand)do
            if Combat.canPlay(battle,card.uid,1)then
                assert(Run.play(run,card.uid,1));played=true;break
            end
        end
        if not played then assert(Run.endTurn(run))end
        commands=commands+1
    end
    assert(run.phase=='reward' and run.rewards and not run.rewards.cardResolved,'fixture did not win with the existing rules')
    assert(#Run.rewardOptions(run)==3,'fixture requires the normal three-card reward')
    return run,{seed=seed or 42,encounter='cultist_solo',commands=commands,kind='real_run_commands_reward_fixture',relic=options and options.relic}
end
return M
