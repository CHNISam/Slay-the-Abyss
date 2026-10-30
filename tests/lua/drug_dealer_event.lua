local H=dofile('tests/helpers/act2_choice_events.lua')
local eq,same,test=H.eq,H.same,H.test
local Context,Transform=require('abyss_event_transform_context'),require('abyss_transform_card')
local function selecting(setup)
    local r,m=H.fixture('drug_dealer',setup);assert(H.Nodes.chooseEvent(r,'test_subject'));return r,m
end
test('Augmenter three exact options, no Leave, cached eligibility, bottles selectable and protected curses excluded',function()
    local r,m=H.fixture('drug_dealer',function(s)s.deck={{uid=7,cardId='strike',inBottleFlame=true},{uid=8,cardId='defend',inBottleLightning=true},
        {uid=9,cardId='Necronomicurse'},{uid=10,cardId='AscendersBane'},{uid=11,cardId='CurseOfTheBell'}}end)
    local before=H.snapshot(r);local event=H.Nodes.view(r,m).node.event;eq(#event.options,3);eq(event.options[2].enabled,true);same(r,before)
    H.reject(r,'leave',nil,'invalid_event_choice');assert(H.Nodes.chooseEvent(r,'test_subject'))
    event=H.Nodes.view(r,m).node.event;eq(event.selection.count,2);eq(event.selection.canCancel,false);eq(#event.selectionCards,2)
    eq(event.selectionCards[1].uid,7);eq(event.selectionCards[2].uid,8);eq(event.selectionCards[1].inBottleFlame,true)
    H.reject(r,'leave',nil,'invalid_event_choice');H.reject(r,'transform',{7},'invalid_card_selection')
    H.reject(r,'transform',{7,7},'invalid_card_selection');H.reject(r,'transform',{7,9},'card_not_purgeable')
    H.reject(r,'transform',{7,8,11},'invalid_card_selection');H.reject(r,'transform',7,'invalid_card_selection')
    r,m=H.fixture('drug_dealer',function(s)s.deck={{uid=7,cardId='strike'}}end)
    eq(H.Nodes.view(r,m).node.event.options[2].enabled,false);H.reject(r,'test_subject',nil,'event_condition_unmet')
end)
test('Augmenter JAX fresh obtain, separate Leave, Toxic Egg and Fish exact hooks',function()
    local r=H.fixture('drug_dealer',function(s)s.relics={'toxic_egg','ceramic_fish'}end);local before=H.snapshot(r)
    assert(H.Nodes.chooseEvent(r,'jax'));eq(#r.deck,#before.deck+1);eq(r.deck[#r.deck].cardId,'jax');eq(r.deck[#r.deck].upgraded,true)
    eq(r.gold,before.gold+9);eq(r.nodeFlow.event.stage,'result');same(r.miscRng,before.miscRng)
    H.reject(r,'jax',nil,'invalid_event_choice');assert(H.Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('Augmenter transforms exactly two ordered source targets; both draws/removals before obtains',function()
    local r=selecting(function(s)s.deck={{uid=7,cardId='strike'},{uid=8,cardId='defend'},{uid=9,cardId='bash'}};s.nextDeckUid=100;s.relics={'ceramic_fish'}end)
    local before=H.snapshot(r);local context=Context.new(r);assert(context)
    local rng=H.R.cloneState(r.miscRng);local expected={}
    for i,id in ipairs({'defend','strike'})do local original=context.cards[id];local out,nextRng=Transform.select(original.category,original.sourceId,context.pools,rng);assert(out);expected[i]=out.cardId;rng=nextRng end
    local calls=0
    H.withHook('onObtainCard',function(old)return function(staged,card,definition,api)
        eq(#staged.deck,1+calls);eq(staged.deck[1].cardId,'bash');eq(card.uid,100+calls)
        same(staged.miscRng,rng);calls=calls+1;return old(staged,card,definition,api)
    end end,function()assert(H.Nodes.chooseEvent(r,'transform',{8,7}))end)
    eq(calls,2);same(r.miscRng,rng);same(r.nodeFlow.event.removedUids,{8,7});same(r.nodeFlow.event.obtainedSourceIds,expected)
    eq(#r.deck,3);eq(r.deck[2].uid,100);eq(r.deck[3].uid,101);eq(r.gold,before.gold+18)
    same(r.eventRng,before.eventRng);same(r.cardRng,before.cardRng);same(r.relicPool,before.relicPool)
end)
test('Augmenter stale/duplicate UID and missing natural draw refuse atomically, no redraw/filter',function()
    local r=selecting(function(s)s.deck={{uid=7,cardId='strike'},{uid=7,cardId='defend'},{uid=8,cardId='bash'}}end)
    H.reject(r,'transform',{7,8},'invalid_card')
    r=selecting(function(s)s.deck={{uid=7,cardId='strike'},{uid=8,cardId='defend'}}end)
    H.reject(r,'transform',{7,999},'invalid_card')
    -- Controlled unavailable-definition fixture, preserving the entire source
    -- transform context/pool and naturally selected RNG outcome unchanged.
    r.transformContext=Context.new(r);local first=r.transformContext.cards.strike
    local out=Transform.select(first.category,first.sourceId,r.transformContext.pools,r.miscRng);assert(out)
    local id=r.transformContext.sourceToLocal[out.cardId];assert(id)
    H.removeDefinition(r,'cards',id);H.reject(r,'transform',{7,8},'event_content_unavailable')
end)
test('Augmenter second delayed obtain refusal rolls back both removals, Parasite maxHP, first reward and all RNG',function()
    local r=selecting(function(s)s.deck={{uid=7,cardId='parasite'},{uid=8,cardId='strike'}};s.relics={'ceramic_fish'}end)
    local calls=0
    H.withHook('onObtainCard',function(old)return function(staged,card,definition,api)
        calls=calls+1;local ok,why=old(staged,card,definition,api)
        if calls==2 then H.R.randomInt(staged.eventRng,99);return false,'late_transform_refusal'end
        return ok,why
    end end,function()H.reject(r,'transform',{7,8},'late_transform_refusal')end)
    eq(calls,2);assert(H.Nodes.chooseEvent(r,'transform',{7,8}));eq(r.maxHp,77);eq(r.nodeFlow.event.stage,'result')
end)
test('Augmenter missing MutagenicStrength refuses, duplicate original relic gives exact Circlet fallback',function()
    local r=H.fixture('drug_dealer');H.removeDefinition(r,'relics','mutagenic_strength');H.reject(r,'mutagens',nil,'relic_content_unavailable')
    r=H.fixture('drug_dealer',function(s)s.relics={'mutagenic_strength'}end);local before=H.snapshot(r)
    assert(H.Nodes.chooseEvent(r,'mutagens'));eq(r.nodeFlow.event.obtainedRelicId,'circlet');eq(r.relicCounters.circlet,1);same(r.miscRng,before.miscRng)
end)
H.finish('DRUG_DEALER_EVENT')
