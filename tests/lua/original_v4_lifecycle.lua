package.path='tests/lua/?.lua;'..package.path
local F=require('support.original_v4_fixture')
local R,N,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local Capability=require('abyss_card_capability')
local C,eq=F.combat,F.eq
local roles={hutao='HT',arlecchino='AR',furina='FR',raiden='RD'}
-- Isolated channel fixtures position the map cursor without simulating intervening
-- rooms. Natural starter/reward/cross-room evidence is in acquisition.lua.
local function enterKind(run,map,kind)
    if kind=='shop' then
        assert(Map.choose(map,'f1_l4'));assert(Map.choose(map,'f2_l5'))
        assert(N.enter(run,map,'f3_l5'));return
    end
    while true do
        local choices=Map.available(map)
        for _,node in ipairs(choices)do if node.type==kind then assert(N.enter(run,map,node.id));return end end
        assert(Map.choose(map,assert(choices[1]).id))
    end
end
local count=0
for character,role in pairs(roles)do
    local run=R.new(F.data,'1',{character=character})
    local ids,counts={}, {common=0,uncommon=0,rare=0}
    for rarity,pool in pairs(run.data.cards.sourcePools.reward)do for _,id in ipairs(pool)do
        assert(not ids[id] and id:sub(1,2)==role);ids[id]=true;counts[rarity]=counts[rarity]+1
    end end
    eq(counts.common,26);eq(counts.uncommon,25);eq(counts.rare,18)
    local definitions=0
    for _,card in ipairs(run.data.cards.cards)do if card.originalV4 then
        assert(card.id:sub(1,2)==role and Capability.isImplemented(card))
        for _,up in ipairs({false,true})do
            local def=C.cardDefinition({catalog={cards={[card.id]=card}}},{cardId=card.id,upgraded=up})
            local raw=card.originalV4[up and 'upgrade' or 'base']
            eq(def.cost,raw.cost);eq(def.exhaust,raw.exhaust)
        end
        definitions=definitions+1
    end end
    eq(definitions,75);eq(#run.deck,10)
    local map=Map.generate(run.data,'1')
    local checkpoint=R.snapshotEncounters(run);assert(R.restoreEncounters(run,checkpoint))
    local saved=Map.snapshot(map);local restored=Map.restore(run.data,saved)
    assert(restored and restored~=map and restored.nodes~=map.nodes)
    enterKind(run,map,'shop')
    local view=N.view(run,map);local purchased
    for slot,offer in ipairs(view.node.cards)do
        if slot<=5 then assert(offer.id and ids[offer.id] and not offer.unavailable,'original colored shelf gap')end
        if not purchased and ids[offer.id] and not offer.unavailable and offer.price<=run.gold then
            local gold,n,uid=run.gold,#run.deck,run.nextDeckUid
            assert(N.buyCardSlot(run,slot));eq(run.gold,gold-offer.price);eq(#run.deck,n+1)
            eq(run.deck[#run.deck].uid,uid);eq(run.deck[#run.deck].cardId,offer.id)
            assert(not N.buyCardSlot(run,slot));eq(run.gold,gold-offer.price)
            purchased=uid
        end
    end
    assert(purchased,'fixture must afford a normal colored purchase')
    assert(N.leaveShop(run))
    assert(R.startRoomCombat(run,'normal'))
    local kept=false
    for _,pile in ipairs({run.combat.hand,run.combat.draw})do for _,card in ipairs(pile)do
        if card.uid==purchased then kept=true end
    end end
    assert(kept,'purchased permanent UID did not reach the next combat')
    run=R.new(F.data,'1',{character=character});map=Map.generate(run.data,'1')
    enterKind(run,map,'camp')
    local uid=run.deck[1].uid
    assert(N.upgrade(run,uid));assert(run.deck[1].upgraded)
    local removed=run.deck[2].uid;assert(R.removeCard(run,removed))
    local hp,gold,relics,potions=run.hp,run.gold,C.copy(run.relics),C.copy(run.potions)
    assert(R.startRoomCombat(run,'normal'))
    eq(run.hp,hp);eq(run.gold,gold);eq(#run.relics,#relics);eq(#run.potions,#potions)
    local found={}
    for _,pile in ipairs({run.combat.hand,run.combat.draw})do for _,card in ipairs(pile)do
        assert(card.uid~=removed and not found[card.uid]);found[card.uid]=card
    end end
    assert(found[uid].upgraded);eq(run.combat.originalV4.healUsed,0)
    assert(not R.restoreEncounters(run,checkpoint))
    count=count+1
end
-- Shared modifiers use native arithmetic; already taxed Raiden block is 5, not 4.
local s=F.state('RD',40);C.addStatus(s.player,'dexterity',2);C.addStatus(s.player,'frail',1)
F.play(s,'RD2-002');eq(s.player.block,5)
s=F.state('HT',40);C.addStatus(s.player,'strength',3);C.addStatus(s.player,'weak',1)
F.play(s,'HT2-001',false,1);eq(s.enemies[1].hp,494)
-- Zero healing from a public potion respects AR's burst gate and cannot revive.
s=F.state('AR',20);local H=require('abyss_original_v4_health')
eq(H.heal(s,s.player,10,'potion'),0);eq(s.originalV4.healUsed,0)
s.player.hp=0;eq(H.heal(s,s.player,10,'burst'),0)
-- Cleanse affects Weak/Frail only, preserving Vulnerable and Poison.
s=F.state('HT',40)
for _,id in ipairs({'weak','frail','vulnerable','poison'})do C.addStatus(s.player,id,2)end
local cleanse
for _,card in pairs(s.catalog.cards)do if card.originalV4 then
    for _,e in ipairs(card.originalV4.base.effects)do if e.op=='cleanse'then cleanse=card.id end end
end end
assert(cleanse);F.play(s,cleanse,false,1)
eq(s.player.statuses.weak,nil);eq(s.player.statuses.frail,nil)
eq(s.player.statuses.vulnerable,2);eq(s.player.statuses.poison,2)
-- Actor-pipeline fixtures, deliberately isolated from natural route/balance evidence.
local function actionFixture(first,second,hp)
    local battle=F.state('FR',hp or 40,2)
    for i,enemy in ipairs(battle.enemies)do
        enemy.ai=nil;enemy.intentIndex=1
        enemy.intents={{id='fixture_'..i,effects=(i==1 and first or second) or {{op='block',value=0}}}}
    end
    battle.originalV4.counter=8;battle.originalV4.soften=6
    return battle
end
s=actionFixture({{op='block',value=5}},{{op='damage',value=10}})
assert(C.endTurn(s));eq(s.player.hp,36);eq(s.enemies[1].hp,500);eq(s.enemies[2].hp,492)
eq(s.originalV4.counter,0);eq(s.originalV4.soften,0)
s=actionFixture({{op='damage',value=10,times=3}})
assert(C.endTurn(s));eq(s.player.hp,16);eq(s.enemies[1].hp,492)
s=actionFixture({{op='damage',value=10,times=3}});s.player.block=100
assert(C.endTurn(s));eq(s.player.hp,40);eq(s.enemies[1].hp,492)
s=actionFixture({{op='damage',value=10,times=3}},nil,5)
assert(C.endTurn(s));eq(s.player.hp,0);eq(s.enemies[1].hp,500);eq(C.outcome(s),'defeat')
s=actionFixture({{op='block',value=5}})
assert(C.endTurn(s));eq(s.player.hp,40);eq(s.enemies[1].hp,500)
s=actionFixture({{op='damage',value=10}});C.addStatus(s.player,'thorns',600)
assert(C.endTurn(s));eq(s.player.hp,36);eq(s.enemies[1].hp,0)
-- Maximum health is dynamic and may exceed the VM integer multiplication range.
s=F.state('HT',40);s.player.maxHp=2147483647;s.player.hp=1500000000
assert(not require('abyss_original_v4').snapshot(s,s.enemies[1]).low)
print('ORIGINAL_V4_LIFECYCLE_PASS '..count..' channels modifiers cleanup')
