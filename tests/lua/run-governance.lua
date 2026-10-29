package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Current=require('abyss_run')
local C=require('abyss_combat')
local data=require('abyss_data')
local function same(a,b,seen,back)
    assert(type(a)==type(b),'different types')
    if type(a)~='table' then
        if type(a)~='function' then assert(a==b,'different values: '..tostring(a)..' / '..tostring(b)) end
        return
    end
    seen,back=seen or {},back or {}
    if seen[a]then assert(seen[a]==b,'alias changed');return end
    assert(not back[b],'alias merged');seen[a],back[b]=b,a
    for k,v in pairs(a)do same(v,b[k],seen,back)end
    for k in pairs(b)do assert(a[k]~=nil,'extra key '..tostring(k))end
end
local function exercise(Run)
    local trace={}
    local called,reason=pcall(Run.new,data,321,{experimental=true,campaign=1})
    assert(not called and tostring(reason):match('invalid campaign option$'))
    local function record(tag,run,...) trace[#trace+1]={tag=tag,run=C.copy(run),result=table.pack(...)} end
    local run=Run.new(data,321)
    local deck,content=run.deck,run.data
    local ok,why=Run.transaction(run,function(staged)
        staged.gold=1
        Run.transaction(staged,function(inner)inner.hp=1;return false,'nested_refusal'end)
        return true
    end)
    assert(not ok and why=='nested_refusal' and run.deck==deck and run.data==content)
    record('nested rejected',run,ok,why)
    ok,why=Run.transaction(run,function(staged)staged.gold=3;error('forced')end)
    assert(not ok and why=='transaction_failed' and run.deck==deck)
    record('exception rejected',run,ok,why)
    assert(Run.transaction(run,function(staged)staged.shared=staged.deck;return true,'committed'end))
    assert(run.shared==run.deck and run.data==content)
    record('committed alias',run)
    run.shared=nil
    assert(Run.startRoomCombat(run,'normal'))
    local battle=run.combat
    record('room',run)
    local restore=require('abyss_snapshot').capture(run)
    assert(not Run.play(run,-1,1))
    assert(run.combat==battle)
    record('invalid play',run)
    restore()
    -- Controlled terminal state exercises actual settlement and item owners;
    -- this fixture does not claim a natural player victory.
    for _,enemy in ipairs(battle.enemies)do enemy.hp=0 end
    battle.phase='victory'
    assert(Run.finishCombat(run))
    local rewards,flow,inventory=run.rewards,run.nodeFlow,run.deck
    local uid=run.nextDeckUid
    assert(Run.claimCardReward(run,1))
    assert(run.rewards==rewards and run.deck==inventory and run.nodeFlow==flow and run.combat==battle)
    assert(run.deck[#run.deck].uid==uid)
    assert(not Run.claimCardReward(run,1))
    assert(Run.claimGoldReward(run));assert(not Run.claimGoldReward(run))
    record('claimed',run)
    assert(Run.leaveCombatRewards(run));assert(run.pendingCombatRewards.rewards==rewards)
    assert(Run.reopenCombatRewards(run));assert(run.rewards==rewards and run.combat==battle)
    record('reopened',run)
    local campaign=Run.new(data,321,{experimental=true,character='ironclad',campaign=true,campaignProfile='competition-two-act'})
    campaign.phase,campaign.pendingAct,campaign.floor='act_transition',2,17
    campaign.nodeFlow={complete=true,floor=17,roomKind='boss_treasure',result='boss_treasure_complete'}
    campaign.hp=20
    campaign.unknown.chances.tinyChestCount=2
    require('abyss_sts_random').randomBoolean(campaign.cardRng)
    local nextUid=campaign.nextDeckUid
    assert(Run.advanceAct(campaign))
    assert(campaign.act==2 and campaign.hp==campaign.maxHp and campaign.nextDeckUid==nextUid)
    assert(campaign.unknown.chances.tinyChestCount==2)
    assert(require('abyss_sts_random').snapshot(campaign.cardRng).counter==250)
    record('act2 continuous',campaign)
    local currentDeck=campaign.deck
    ok,why=Run.advanceAct(campaign)
    assert(not ok and why=='competition_act_limit' and campaign.deck==currentDeck)
    record('act3 refused',campaign,ok,why)
    local ending=Run.new(data,321,{experimental=true,campaign=true})
    ending.act,ending.floor,ending.endingUnlocked,ending.keys=4,55,true,{ruby=true,emerald=true,sapphire=true}
    local Queue=require('abyss_encounter_queue')
    ending.bossInitialization,ending.encounters=Queue.initializeBoss(Queue.new(ending.runSeed,4))
    local _,nextQueue=Queue.consume(ending.encounters,'elite');ending.encounters=nextQueue
    local factory=require('abyss_act4_enemies')
    local resolve=factory.resolve
    factory.resolve=function()return nil end
    local called,accepted,reason=pcall(Run.startRoomCombat,ending,'boss')
    factory.resolve=resolve
    assert(called and accepted==false and reason=='unknown_encounter')
    assert(ending.phase=='map' and not ending.combat)
    record('missing ending boss',ending,accepted,reason)
    return trace
end
local trace=exercise(Current)
if RUN_GOVERNANCE_REFERENCE then
    local Reference=assert(loadfile(RUN_GOVERNANCE_REFERENCE))()
    for name,fn in pairs(Current)do assert(type(fn)=='function' and type(Reference[name])=='function','new API '..name)end
    for name in pairs(Reference)do assert(Current[name],'missing API '..name)end
    same(trace,exercise(Reference))
    print('RUN_GOVERNANCE_DIFFERENTIAL_PASS '..#trace)
end
print('RUN_GOVERNANCE_PASS '..#trace)
