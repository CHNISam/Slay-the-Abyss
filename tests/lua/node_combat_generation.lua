-- Experimental Defect, one card obtained through the permanent Run command.
-- Seek is naturally drawn in the real first map battle: no hand, energy, enemy
-- HP, RNG or battle-generation injection. Not a full route/platform acceptance.
local Run=require('abyss_run')
local Nodes=require('abyss_nodes')
local Map=require('abyss_map')
local Data=require('abyss_data')
local Combat=require('abyss_combat')
local Pile=require('abyss_pile_choice')
local count=0
local function same(a,b,path)
    path=path or 'state';assert(type(a)==type(b),path)
    if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
    for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
    for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function test(name,fn)fn();count=count+1;print('ok node combat generation '..count..' - '..name)end
local function entered()
    local run=Run.new(Data,'42',{experimental=true,character='defect'})
    assert(Run.obtainCard(run,'seek'))
    local map=Map.generate(run.data,run.runSeed)
    local node=assert(Map.available(map)[1]);assert(node.type=='combat')
    assert(Nodes.enter(run,map,node.id))
    local seek
    for _,card in ipairs(run.combat.hand)do if card.cardId=='seek' then seek=card end end
    assert(seek,'seed must naturally draw Seek')
    assert(Run.play(run,seek.uid,1))
    return run,map,assert(Pile.view(run.combat))
end

test('a valid naturally played Seek completes after public map entry',function()
    local run,_,view=entered()
    assert(#view.candidateUids>0)
    local uid=view.candidateUids[1]
    local ok,reason=Run.choosePile(run,{uid},view.token,view.generation)
    assert(ok,'naturally played Seek rejected: '..tostring(reason))
    assert(run.combatGeneration==1 and run.combat.combatGeneration==run.combatGeneration)
    assert(not run.combat.pendingPileChoice)
    local found=false;for _,card in ipairs(run.combat.hand)do if card.uid==uid then found=true end end
    assert(found,'valid Seek did not move the chosen card to hand')
end)

test('stale generation/token and invalid cards preserve the live selection before valid continuation',function()
    local run,_,view=entered()
    for _,request in ipairs({
        {{view.candidateUids[1]},view.token,view.generation-1,'stale_combat_generation'},
        {{view.candidateUids[1]},view.token+1,view.generation},
        {{999999},view.token,view.generation},
    })do
        local before=Combat.copy(run);local battle=run.combat
        local ok,reason=Run.choosePile(run,request[1],request[2],request[3])
        assert(not ok);if request[4]then assert(reason==request[4])end
        same(run,before);assert(run.combat==battle)
    end
    assert(Run.choosePile(run,{view.candidateUids[1]},view.token,view.generation))
    local before=Combat.copy(run)
    assert(not Run.choosePile(run,{view.candidateUids[1]},view.token,view.generation));same(run,before)
end)

test('next real map battle advances once, rollback leaks no generation, and old commands stay stale',function()
    local run,map,view=entered()
    assert(Run.choosePile(run,{view.candidateUids[1]},view.token,view.generation))
    -- Finish the actual unchanged first encounter; only skip offered rewards.
    local actions=0
    while run.phase=='combat' do
        actions=actions+1;assert(actions<100,'bounded first encounter did not finish')
        local s=run.combat
        if s.pendingPileChoice then
            local choice=assert(Pile.view(s))
            assert(Run.choosePile(run,{choice.candidateUids[1]},choice.token,choice.generation))
        else
            local target
            for i,enemy in ipairs(s.enemies)do if enemy.hp>0 and not enemy.escaped then target=i;break end end
            local chosen,best
            for _,card in ipairs(s.hand)do
                if Combat.canPlay(s,card.uid,target)then
                    local score=card.cardId=='dualcast' and 100 or card.cardId=='zap' and 90
                        or Combat.cardDefinition(s,card).type=='attack' and 80 or 10
                    if not best or score>best then chosen,best=card,score end
                end
            end
            if chosen then assert(Run.play(run,chosen.uid,target))else assert(Run.endTurn(run))end
        end
    end
    assert(run.phase=='reward','unchanged first encounter must be won')
    assert(Run.claimCardReward(run,0));dofile('tests/lua/support/finish_combat_rewards.lua')(run)
    assert(Nodes.completeCombat(run,map))
    local node
    for _,choice in ipairs(Nodes.available(run,map))do if choice.type=='combat' then node=choice;break end end
    assert(node,'seed must offer a second ordinary map battle')
    local before=Combat.copy({run=run,map=map});local battle=run.combat
    local start=Run.startRoomCombat
    Run.startRoomCombat=function(staged,tier)
        assert(start(staged,tier));error('forced post-setup entry failure')
    end
    local called,ok,reason=pcall(Nodes.enter,run,map,node.id)
    Run.startRoomCombat=start
    assert(called and not ok and reason=='combat_unavailable')
    same({run=run,map=map},before);assert(run.combat==battle and run.combatGeneration==1)
    assert(Nodes.enter(run,map,node.id))
    assert(run.combatGeneration==2 and run.combat.combatGeneration==2 and run.combat~=battle)
    before=Combat.copy(run)
    for _,command in ipairs({Run.choosePile,Run.chooseDiscard,Run.chooseScry,Run.chooseHand})do
        local accepted,why=command(run,{view.candidateUids[1]},view.token,view.generation)
        assert(not accepted and why=='stale_combat_generation');same(run,before)
    end
end)
print('NODE_COMBAT_GENERATION_PASS '..count)
