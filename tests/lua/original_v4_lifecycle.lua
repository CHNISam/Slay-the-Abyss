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
-- Lethal damage still completes legal trailing healing; death never revives.
s=F.state('HT',30);s.enemies[1].hp=1
F.play(s,'HT2-004');eq(C.outcome(s),'victory');eq(s.player.hp,36);eq(s.originalV4.healUsed,6)
s=F.state('HT',50);F.play(s,'HT2-003')
assert(C.endTurn(s));eq(s.originalV4.infuse,1)
assert(C.endTurn(s));eq(s.originalV4.infuse,0)
s=F.state('AR',40);s.originalV4.bond=8
assert(C.endTurn(s));eq(s.originalV4.bond,8)
-- Public potion transactions use the same battle ledger; room healing is separate.
local fr=R.new(F.data,73,{character='furina'});fr.hp=20
assert(R.obtainPotion(fr,'blood_potion'));assert(R.startRoomCombat(fr,'normal'))
assert(R.usePotion(fr,1));eq(fr.hp,32);eq(fr.combat.originalV4.healUsed,12);eq(fr.combat.originalV4.fan,3)
assert(R.obtainPotion(fr,'blood_potion'));assert(R.usePotion(fr,1));eq(fr.hp,32);eq(fr.combat.originalV4.fan,3)
local ar=R.new(F.data,73,{character='arlecchino'});ar.hp=20
assert(R.obtainPotion(ar,'blood_potion'));assert(R.obtainPotion(ar,'fruit_juice'));assert(R.startRoomCombat(ar,'normal'))
assert(R.usePotion(ar,1));eq(ar.hp,20);eq(ar.combat.originalV4.healUsed,0)
assert(R.usePotion(ar,2));eq(ar.hp,20);eq(ar.maxHp,79)
local room=R.new(F.data,73,{character='arlecchino'});room.hp=20
assert(R.obtainPotion(room,'blood_potion'));assert(R.usePotion(room,1));eq(room.hp,34)
-- Marks are settled once by absorb or actual death, including public poison.
s=F.state('AR',40);F.play(s,'AR2-003',false,1);F.play(s,'AR2-005',false,1)
eq(s.originalV4.bond,2);eq(s.enemies[1].v4Directive,nil)
s=F.state('AR',40);F.play(s,'AR2-003',false,1);assert(C.endTurn(s))
assert(s.enemies[1].v4Directive.mature);F.play(s,'AR2-003',false,1)
assert(s.enemies[1].v4Directive.mature);F.play(s,'AR2-005',false,1)
eq(s.originalV4.bond,6);eq(s.originalV4.relicUsed,true);eq(s.player.block,3)
s=F.state('AR',40,2);s.enemies[1].hp=1;s.enemies[1].v4Directive={mature=false}
F.play(s,'AR2-001',false,1);eq(s.originalV4.bond,4);eq(s.enemies[1].v4Directive,nil)
C.damage(s,s.player,s.enemies[1],1,true);eq(s.originalV4.bond,4)
s=F.state('AR',40,2);s.enemies[1].hp=1;s.enemies[1].v4Directive={mature=true}
C.addStatus(s.enemies[1],'poison',1);assert(C.endTurn(s));eq(s.originalV4.bond,4);eq(s.enemies[1].v4Directive,nil)
-- Bloom damage is derived, expires after two actual own end phases, and gets no root bonus.
s=F.state('HT',50);F.play(s,'HT2-003');F.play(s,'HT2-005',false,1)
eq(s.enemies[1].hp,488);assert(C.endTurn(s));eq(s.enemies[1].hp,486)
assert(C.endTurn(s));eq(s.enemies[1].hp,484);eq(s.enemies[1].v4Bloom,nil)
-- Re-summoning takes max rather than stacking; the inactive form preserves uses.
s=F.state('FR',40);F.play(s,'FR2-003');F.play(s,'FR2-003')
for _,uses in pairs(s.originalV4.guests)do eq(uses,2)end
F.play(s,'FR2-005',false,1);eq(s.originalV4.mode,'pneuma');assert(C.endTurn(s))
for _,uses in pairs(s.originalV4.guests)do eq(uses,2)end
F.play(s,'FR2-005',false,1);eq(s.originalV4.mode,'ousia');assert(C.endTurn(s))
for _,uses in pairs(s.originalV4.guests)do eq(uses,1)end
-- Musou refunds are delayed, capped once per turn, and materialize at real turn start.
s=F.state('RD',40);s.originalV4.resolve=6;F.play(s,'RD2-004',false,1)
F.play(s,'RD2-001',false,1);F.play(s,'RD2-001',false,1)
eq(s.originalV4.nextEnergy,1);assert(C.endTurn(s));eq(s.energy,4);eq(s.originalV4.nextEnergy,0)
-- Cross-act boundary fixtures exercise the shared transition, not unavailable
-- later-act enemies. Ordinary original runs keep their Act1 victory contract.
local function same(a,b)
    assert(type(a)==type(b),'cross-act owner type changed')
    if type(a)~='table'then eq(a,b);return end
    for key,value in pairs(a)do same(value,b[key])end
    for key in pairs(b)do assert(a[key]~=nil,'cross-act owner gained '..tostring(key))end
end
local function bossChestBoundary(run)
    local map=Map.generate(run.data,run.runSeed,1)
    while #Map.available(map)>0 do assert(Map.choose(map,Map.available(map)[1].id))end
    run.floor,run.phase=17,'node'
    run.nodeFlow={id=map.currentNodeId,floor=map.floor,type='treasure',roomKind='boss_treasure',
        mapSeed=map.seed,mapSignature=map.sourceSignature,complete=false,reward={relics={}}}
    return map
end
for character,role in pairs(roles)do
    assert(not pcall(R.new,F.data,'42',{character=character,campaign=true}),
        'original identity bypassed the explicit development campaign gate')
    assert(not pcall(R.new,F.data,'42',{character=character,campaign='yes'}))
    local run=R.new(F.data,'42',{character=character,experimental=true,campaign=true})
    assert(R.startRoomCombat(run,'normal'))
    local command='cross-act-prior-'..role
    local played,oldUid,oldTarget
    for _,held in ipairs(run.combat.hand)do
        local target
        if not C.canPlay(run.combat,held.uid,nil)then target=1 end
        if C.canPlay(run.combat,held.uid,target)then
            assert(R.play(run,held.uid,target,command))
            played,oldUid,oldTarget=true,held.uid,target;break
        end
    end
    assert(played and run.originalCommands[command],'fixture did not commit a real original command')
    local map=bossChestBoundary(run)
    run.deck[1].upgraded=true
    run.hp=3;run.gold=345;run.potions={'block_potion'};run.relicCounters={persisted=3}
    local expected={data=run.data,profile=C.copy(run.characterProfile),deck=C.copy(run.deck),
        relics=C.copy(run.relics),potions=C.copy(run.potions),counters=C.copy(run.relicCounters),
        commands=C.copy(run.originalCommands),uid=run.nextDeckUid,generation=run.combatGeneration}
    assert(N.claimBossTreasure(run,0));eq(run.phase,'act_transition');eq(run.pendingAct,2)
    assert(N.advanceAct(run,map));eq(run.act,2);eq(run.phase,'map');eq(map.floor,17)
    eq(run.character,character);eq(run.data,expected.data);eq(run.data.originalV4Role,role)
    same(run.characterProfile,expected.profile);same(run.deck,expected.deck)
    same(run.relics,expected.relics);same(run.potions,expected.potions);same(run.relicCounters,expected.counters)
    same(run.originalCommands,expected.commands);eq(run.nextDeckUid,expected.uid)
    eq(run.combatGeneration,expected.generation);eq(run.combat,nil);eq(run.hp,run.maxHp);eq(run.gold,345)
    local checkpoint=R.snapshotEncounters(run);assert(R.restoreEncounters(run,checkpoint))
    local replay,why=R.play(run,oldUid,oldTarget,command);assert(replay);eq(why,'already_committed')
    same(run.deck,expected.deck);eq(run.gold,345)
    assert(not N.advanceAct(run,map),'duplicate original chapter transition accepted')
    local entered,reason=N.enter(run,map,Map.available(map)[1].id)
    assert(not entered);eq(reason,'act_content_unavailable')
    -- Fresh battle construction is isolated because the upstream chapter content
    -- gate deliberately blocks the normal Act2 room; do not relabel it a route.
    local fresh=C.new(run.data,{seed=42,hp=run.hp,maxHp=run.maxHp,deck=run.deck,enemies={'cultist'}})
    eq(fresh.originalV4.role,role);eq(fresh.originalV4.healUsed,0);eq(fresh.originalV4.infuse,0)
    eq(fresh.originalV4.bond,0);eq(fresh.originalV4.fan,0);eq(fresh.originalV4.resolve,0)
    eq(fresh.originalV4.eye.uses,0);eq(fresh.originalV4.musou.uses,0)
    local found={}
    for _,pile in ipairs({fresh.hand,fresh.draw})do for _,held in ipairs(pile)do found[held.uid]=held end end
    for _,held in ipairs(run.deck)do assert(found[held.uid]);eq(found[held.uid].upgraded,held.upgraded)end
end
-- Both chapter boundaries have floor17/roomGeneration0 and full queue lengths:
-- the queue's own act must fence a stale first-act checkpoint.
local campaign=R.new(F.data,'42',{character='furina',experimental=true,campaign=true})
local campaignMap=bossChestBoundary(campaign)
local priorChapter=R.snapshotEncounters(campaign)
assert(N.claimBossTreasure(campaign,0) and N.advanceAct(campaign,campaignMap))
local restored,restoreWhy=R.restoreEncounters(campaign,priorChapter)
assert(not restored);eq(restoreWhy,'encounter_act_mismatch');eq(campaign.encounters.act,2)
print('ORIGINAL_V4_CROSS_ACT_PASS 4 identities inventory commands new-battle reset and queue fence')
print('ORIGINAL_V4_LIFECYCLE_PASS '..count..' channels modifiers cleanup')
