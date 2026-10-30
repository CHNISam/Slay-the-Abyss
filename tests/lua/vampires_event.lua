local H=dofile('tests/helpers/act2_choice_events.lua')
local eq,same,test=H.eq,H.same,H.test
test('Vampires cached float32 ceil30percent cost, Vial option and pure detached views',function()
    for _,row in ipairs({{1,0},{2,1},{3,1},{10,3},{71,22},{80,24}})do
        local r,m=H.fixture('vampires',function(s)s.maxHp=row[1];s.hp=row[1]end)
        local before=H.snapshot(r);local event=H.Nodes.view(r,m).node.event
        eq(event.maxHpLoss,row[2]);eq(#event.options,2);eq(event.options[1].choice,'accept');eq(event.options[2].choice,'leave');same(r,before)
        H.reject(r,'give_vial',nil,'event_condition_unmet')
    end
    local r,m=H.fixture('vampires',function(s)s.relics={'blood_vial'}end)
    local options=H.Nodes.view(r,m).node.event.options;eq(#options,3);eq(options[2].choice,'give_vial');eq(options[3].choice,'leave')
end)
test('Vampires removes ALL starter strikes in reverse order, including upgraded/bottled, then five fresh Bites',function()
    local r=H.fixture('vampires',function(s)
        s.deck={{uid=7,cardId='strike',upgraded=true,inBottleFlame=true},{uid=8,cardId='perfected_strike'},
            {uid=9,cardId='strike'},{uid=10,cardId='swift_strike'},{uid=11,cardId='strike'}}
        s.nextDeckUid=100;s.relics={'ceramic_fish'}
    end)
    local before=H.snapshot(r);local oldRemove=H.Run.removeCard;local removed={}
    H.Run.removeCard=function(staged,uid)removed[#removed+1]=uid;return oldRemove(staged,uid)end
    local obtains=0
    H.withHook('onObtainCard',function(old)return function(staged,card,definition,api)
        eq(staged.maxHp,56);eq(staged.hp,56);eq(definition.id,'bite');eq(#staged.deck,2+obtains)
        eq(staged.deck[1].cardId,'perfected_strike');eq(staged.deck[2].cardId,'swift_strike');eq(card.uid,100+obtains)
        obtains=obtains+1;return old(staged,card,definition,api)
    end end,function()assert(H.Nodes.chooseEvent(r,'accept'))end)
    H.Run.removeCard=oldRemove;same(removed,{11,9,7});eq(obtains,5);eq(#r.deck,7);eq(r.nextDeckUid,105);eq(r.gold,before.gold+45)
    same(r.nodeFlow.event.removedUids,{11,9,7});eq(#r.nodeFlow.event.obtainedCardUids,5)
    for i=3,7 do eq(r.deck[i].cardId,'bite');eq(r.deck[i].upgraded,false);eq(r.deck[i].inBottleFlame,nil)end
    same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng);same(r.cardRng,before.cardRng);same(r.relicPool,before.relicPool)
    H.reject(r,'accept',nil,'invalid_event_choice');assert(H.Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
test('Vampires zero strikes still gives five; Vial loses only its slot and never maxHP',function()
    local r=H.fixture('vampires',function(s)s.deck={};s.relics={'anchor','blood_vial','lantern'}end)
    assert(H.Nodes.chooseEvent(r,'give_vial'));eq(r.maxHp,80);eq(r.hp,80);eq(#r.deck,5)
    same(r.relics,{'anchor','lantern'});eq(#r.nodeFlow.event.removedUids,0)
    r=H.fixture('vampires',function(s)s.deck={{uid=4,cardId='bash'}};s.hp=20 end)
    assert(H.Nodes.chooseEvent(r,'accept'));eq(r.maxHp,56);eq(r.hp,20);eq(#r.deck,6);eq(r.deck[1].cardId,'bash')
end)
test('Vampires cache survives real Fruit Juice, maxHP clamp does not dispatch HP-loss callbacks',function()
    local r=H.fixture('vampires',function(s)s.potions={'fruit_juice'}end)
    assert(H.Run.usePotion(r,1));eq(r.maxHp,85);eq(r.nodeFlow.event.maxHpLoss,24)
    local old=H.Run.eventDamage;H.Run.eventDamage=function()error('not damage')end
    local ok,why=H.Nodes.chooseEvent(r,'accept');H.Run.eventDamage=old;assert(ok,why);eq(r.maxHp,61);eq(r.hp,61)
end)
test('Vampires late fourth Bite refusal rolls back paid maxHP, Vial removal, all strikes/UIDs/hooks/RNG',function()
    for _,choice in ipairs({'accept','give_vial'})do
        local r=H.fixture('vampires',function(s)s.relics={'blood_vial','ceramic_fish'}end)
        local calls=0
        H.withHook('onObtainCard',function(old)return function(staged,card,definition,api)
            calls=calls+1;local ok,why=old(staged,card,definition,api)
            if calls==4 then H.R.randomInt(staged.miscRng,99);return false,'late_bite_refusal'end
            return ok,why
        end end,function()H.reject(r,choice,nil,'late_bite_refusal')end)
        eq(calls,4);assert(H.Nodes.chooseEvent(r,choice));eq(#r.nodeFlow.event.obtainedCardUids,5)
    end
end)
test('Vampires missing Bite and UID overflow refuse before committing any cost/deck changes',function()
    local r=H.fixture('vampires',function(s)s.relics={'blood_vial'}end)
    local original=H.removeDefinition(r,'cards','bite');H.reject(r,'give_vial',nil,'card_content_unavailable')
    r.data=original;assert(H.Nodes.chooseEvent(r,'give_vial'))
    r=H.fixture('vampires',function(s)s.nextDeckUid=9007199254740988.0 end);H.reject(r,'accept',nil,'invalid_deck_uid')
end)
test('Vampires decline is separate result and has no economic or RNG effects',function()
    local r=H.fixture('vampires');local before=H.snapshot(r);assert(H.Nodes.chooseEvent(r,'leave'));eq(r.phase,'node')
    eq(r.nodeFlow.event.stage,'result');same(r.deck,before.deck);same(r.miscRng,before.miscRng);same(r.relics,before.relics)
    eq(r.hp,before.hp);eq(r.maxHp,before.maxHp);assert(H.Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end)
H.finish('VAMPIRES_EVENT')
