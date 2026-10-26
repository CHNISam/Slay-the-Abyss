package.path='tests/lua/?.lua;'..package.path
local F=require('support.original_v4_fixture')
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local Data=F.data
for _,character in ipairs({'hutao','arlecchino','furina','raiden'})do
    local seed='1'
    local run=Run.new(Data,seed,{character=character})
    local map=Map.generate(run.data,seed)
    local first=assert(Nodes.available(run,map)[1])
    assert(Nodes.enter(run,map,first.id))
    local actions=F.naturalBattle(run)
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
