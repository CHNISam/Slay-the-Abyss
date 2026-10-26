package.path='tests/lua/?.lua;'..package.path
local F=require('support.original_v4_fixture')
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local Data=F.data
-- Fixed legal seed-1 commands recorded from the production preview policy.
-- Replaying commands avoids re-solving the same hand during every CI fixture.
local inputs={
    hutao='7,9@1,2@1,end,8,3@1,end,1@1,2@1',
    arlecchino='7,2@1,9@1,end,8,3@1,end,1@1,9@1,3@1,end,7',
    furina='7,2@1,end,3@1,1@1,6,end,7,2@1',
    raiden='7@1,9@1,2@1,end,3@1,1@1,6,end,7@1,9@1,2@1',
}
local expected={hutao={66,3,7},arlecchino={59,4,9},furina={63,3,7},raiden={71,3,9}}
local function replay(run)
    local plays=0
    for command in inputs[run.character]:gmatch('[^,]+')do
        assert(run.phase=='combat','trajectory ended early')
        if command=='end' then assert(Run.endTurn(run))
        else
            local uid,target=command:match('^(%d+)@?(%d*)$');plays=plays+1
            assert(Run.play(run,tonumber(uid),target~='' and tonumber(target) or nil,'seed1-'..plays))
        end
    end
    local want=expected[run.character]
    assert(run.hp==want[1] and run.combat.turn==want[2] and plays==want[3])
    return plays
end
for _,character in ipairs({'hutao','arlecchino','furina','raiden'})do
    local seed='1'
    local run=Run.new(Data,seed,{character=character})
    local map=Map.generate(run.data,seed)
    local first=assert(Nodes.available(run,map)[1])
    assert(Nodes.enter(run,map,first.id))
    local actions=replay(run)
    print(character..' seed='..seed..' first='..first.id..' encounter='..run.encounterSource
        ..' result='..run.phase..' hp='..run.hp..' turns='..run.combat.turn..' plays='..actions)
    assert(run.phase=='reward','natural starter battle did not win')
    local oldDeck=#run.deck
    assert(#Run.rewardOptions(run)==3)
    assert(Run.claimGoldReward(run))
    assert(Run.claimCardReward(run,1))
    assert(#run.deck==oldDeck+1)
    if run.rewards.potion then assert(Run.claimPotionReward(run))end
    assert(Run.leaveCombatRewards(run))
    assert(Nodes.completeCombat(run,map))
    local nexts=Nodes.available(run,map)
    local selected=nexts[1]
    for _,node in ipairs(nexts)do if node.type=='combat'then selected=node;break end end
    local hp=run.hp
    assert(Nodes.enter(run,map,assert(selected).id))
    assert(run.hp==hp)
    assert(run.combatGeneration==2 and run.combat.combatGeneration==2)
    local v=run.combat.originalV4
    assert(v.healUsed==0 and v.infuse==0 and v.bond==0 and v.fan==0 and v.resolve==0)
    for _,pile in ipairs({run.combat.hand,run.combat.draw})do for _,card in ipairs(pile)do assert(card.uid<run.nextDeckUid)end end
    assert(run.phase=='combat','next natural room did not start')
    print('CROSS_NODE '..character..' node='..selected.id..' type='..selected.type
        ..' phase='..run.phase..' deck='..#run.deck..' hp='..run.hp)
end

print('ORIGINAL_V4_ACQUISITION_PASS 4')
