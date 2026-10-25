-- Real explicit-encounter replay; not natural map or platform acceptance.
local C,Run,Data=require('abyss_combat'),require('abyss_run'),require('abyss_data')
local finish=dofile('tests/lua/support/finish_combat_rewards.lua')
local targets=dofile('tests/fixtures/warrior75-reward-targets.lua')
local seeds=dofile('tests/fixtures/warrior75-reward-seeds.lua')
local function equal(a,b,why) assert(a==b,(why or 'value')..': '..tostring(a)..' ~= '..tostring(b)) end
local function victory(run)
    assert(Run.startCombat(run,'cultist_solo'))
    for _=1,100 do
        if run.phase~='combat' then break end
        local chosen
        for _,instance in ipairs(run.combat.hand) do
            if C.canPlay(run.combat,instance.uid,1) and (not chosen or C.cardDefinition(run.combat,instance).type=='attack') then chosen=instance end
        end
        if chosen then assert(Run.play(run,chosen.uid,1)) else assert(Run.endTurn(run)) end
    end
    equal(run.phase,'reward','real starter victory')
    for _,enemy in ipairs(run.combat.enemies) do assert(enemy.hp<=0,'enemy was not defeated') end
end
local function metadata(id)
    for _,def in ipairs(Data.cards.cards) do if def.id==id then return def end end
    error('missing definition '..id)
end
return function(rarity,first,last)
    assert(rarity~='basic' and targets[rarity],'reward rarity required')
    assert(type(first)=='number' and first%1==0 and first>=1)
    assert(type(last)=='number' and last%1==0 and last>=first and last<=#targets[rarity])
    local total,seen=0,{}
    for group,ids in pairs(targets) do
        equal(#ids,assert(({basic=3,common=20,uncommon=36,rare=16})[group]),'full source group')
        local pool=Data.cards.sourcePools.reward[group]
        if group~='basic' then equal(#pool,#ids,'full original reward pool') end
        local poolSet={};for _,id in ipairs(pool or {}) do assert(not poolSet[id]);poolSet[id]=true end
        for _,id in ipairs(ids) do
            assert(not seen[id]);seen[id]=true;total=total+1;equal(metadata(id).rarity,group,id)
            if group~='basic' then assert(poolSet[id],'source pool missing '..id);assert(seeds[id]) end
        end
    end
    equal(total,75)
    local seedCount=0;for id in pairs(seeds) do assert(seen[id] and metadata(id).rarity~='basic');seedCount=seedCount+1 end
    equal(seedCount,72)
    local count=0
    for i=first,last do
        local id=assert(targets[rarity][i]);local trace=assert(seeds[id])
        local run=Run.new(Data,trace.seed)
        for round=1,trace.victories do
            victory(run)
            local options=Run.rewardOptions(run)
            if round==1 then for _,offered in ipairs(options) do assert(metadata(offered).rarity~='rare','first A0 reward cannot be rare') end end
            if round<trace.victories then
                assert(Run.claimCardReward(run,0));finish(run);equal(#run.deck,10,'starter deck unchanged')
            else
                local slot
                for index,offered in ipairs(options) do if offered==id then slot=index end end
                assert(slot,'fixed real-victory trajectory lost '..id)
                local uid=run.nextDeckUid
                assert(Run.claimCardReward(run,slot));equal(#run.deck,11)
                equal(run.deck[11].cardId,id);equal(run.deck[11].uid,uid);assert(not run.deck[11].upgraded)
                assert(not Run.claimCardReward(run,slot),'card reward claimed twice')
                equal(#run.deck,11);equal(run.nextDeckUid,uid+1)
                finish(run);assert(Run.startCombat(run,'cultist_solo'))
                local found=0
                for _,pile in ipairs({run.combat.hand,run.combat.draw}) do for _,card in ipairs(pile) do
                    if card.cardId==id then found=found+1;equal(card.uid,uid,'permanent identity');assert(not card.upgraded) end
                end end
                equal(found,1,'reward persists exactly once into next battle')
                count=count+1;print('PASS full reward '..id..' seed='..trace.seed..' realVictory='..round)
            end
        end
    end
    equal(count,last-first+1)
    print('FULL_REWARD_PASS '..rarity..' '..first..'..'..last..' count='..count)
end
