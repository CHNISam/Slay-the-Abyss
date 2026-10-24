package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Unknown = require('abyss_unknown')
local n = 0
local function test(name, fn) fn(); n=n+1; print('ok unknown events '..n..' - '..name) end
local function same(a,b)
    if type(a)~='table' then assert(a==b,tostring(a)..' ~= '..tostring(b)); return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil,'extra '..tostring(k)) end
end
test('production reducer suppresses a previous actual shop without reroll',function()
    assert(type(Unknown.newPc)=='function','production unknown-room adapter missing')
    local s=Unknown.newPc()
    assert(Unknown.advancePc(s,0.10,{previousRoom='shop'})=='treasure')
    assert(s.shop>0.059 and s.monster>0.199)
end)
test('production exact buckets, overflow overwrite, Juzu and Tiny Chest',function()
    for _,v in ipairs({{0,'monster'},{.099,'monster'},{.10,'shop'},{.129,'shop'},{.13,'treasure'},{.149,'treasure'},{.15,'event'},{.999,'event'}}) do
        assert(Unknown.advancePc(Unknown.newPc(),v[1],{})==v[2])
    end
    local s=Unknown.newPc();s.monster=1.0
    assert(Unknown.advancePc(s,.999,{})=='treasure','mirror min(99,start) overwrites final bucket')
    s=Unknown.newPc(); assert(Unknown.advancePc(s,0,{juzu=true})=='event'); assert(s.monster<.101)
    s=Unknown.newPc();s.tinyChestCount=3
    assert(Unknown.advancePc(s,0,{tinyChest=true})=='treasure');assert(s.tinyChestCount==0)
    local restored=assert(Unknown.restorePc(Unknown.snapshotPc(s)));same(s,restored)
    assert(not pcall(Unknown.advancePc,s,1,{}));same(s,restored)
end)
local Pool, R, Run, Map, Nodes, C, data
test('full catalog retains 11 act events and six shrines; production is explicit six',function()
    Pool=require('abyss_event_pool');R=require('abyss_sts_random')
    local p=Pool.new('full');assert(#p.act==11 and #p.shrine==6 and #p.once==13)
    local limited=Pool.new('restricted-six');assert(#limited.act==4 and #limited.shrine==2 and #limited.once==0)
    local context={floor=6,gold=34,act=1,hp=80,relicCount=1}
    local e=Pool.eligible(p,context)
    for _,id in ipairs(e.act) do assert(id~='The Cleric' and id~='Mushrooms' and id~='Dead Adventurer') end
    context.floor=7;context.gold=35;e=Pool.eligible(p,context)
    local seen={};for _,id in ipairs(e.act) do seen[id]=true end
    assert(seen['The Cleric'] and seen.Mushrooms and seen['Dead Adventurer'])
end)
test('source pool boundary, fallback and lifecycle without supported-pool rerolls',function()
    local p={mode='full',act={'The Cleric'},shrine={'Purifier'},once={'Lab'}}
    local s=R.fromSeed('42');local ctx={floor=7,gold=35,act=1}
    local id,kind=Pool.draw(p,ctx,s,.25);assert(id=='The Cleric' and kind=='act' and #p.act==0)
    id,kind=Pool.draw(p,ctx,s,.9);assert(kind~='act' and id~='The Cleric')
    Pool.draw(p,ctx,s,0);local before=R.snapshot(s)
    assert(Pool.draw(p,ctx,s,0)==nil);same(R.snapshot(s),before)
    local once=#p.once;Pool.nextAct(p);assert(#p.act==11 and #p.shrine==6 and #p.once==once)
end)
local function setup(id,seed)
    C=C or require('abyss_combat');data=data or require('abyss_data')
    Run=Run or require('abyss_run');Map=Map or require('abyss_map');Nodes=Nodes or require('abyss_nodes')
    local run=Run.new(data,seed or 42);local map=Map.generate(data,seed or 42)
    map.nodes[1].type='event';map.nodes[1].eventId=id
    return run,map,map.nodes[1].id
end
test('natural unknown rooms route all four handlers and never change the map symbol',function()
    local types,events={},{}
    for seed=1,220 do
        local run,map,id=setup(nil,seed)
        assert(Nodes.enter(run,map,id));local kind=run.nodeFlow.type;types[kind]=true
        if kind=='event' then events[run.nodeFlow.event.id]=true end
        assert(map.nodes[1].type=='event' and run.nodeFlow.sourceType=='event')
        local state=C.copy(run.unknown);Nodes.view(run,map);Nodes.view(run,map);same(run.unknown,state)
        assert(not Nodes.enter(run,map,id));same(run.unknown,state)
    end
    assert(types.combat and types.shop and types.treasure and types.event)
    local count=0;for _ in pairs(events) do count=count+1 end;assert(count==7,'all seven events must be reachable across seeds')
end)
test('Goop entry loss is fixed, capped and death stops navigation',function()
    local run,map,id=setup('goop');run.gold=12
    assert(Nodes.enter(run,map,id));assert(run.nodeFlow.event.goldLoss==12)
    local rng=C.copy(run.miscRng);assert(Nodes.chooseEvent(run,'leave'));assert(run.gold==0);same(run.miscRng,rng)
    assert(not Nodes.chooseEvent(run,'leave'))
    run,map,id=setup('goop');run.hp=10;local gold=run.gold
    assert(Nodes.enter(run,map,id));assert(Nodes.chooseEvent(run,'gather'));assert(run.hp==0 and run.gold==gold+75 and run.phase=='defeat')
end)
test('shining light rounds 83 to 17 and upgrades at most two unique permanent UIDs',function()
    local run,map,id=setup('shining_light');run.maxHp=83;run.hp=83
    assert(Nodes.enter(run,map,id));assert(run.nodeFlow.event.damage==17)
    assert(Nodes.chooseEvent(run,'accept'));assert(run.hp==66)
    local count=0;for _,c in ipairs(run.deck) do if c.upgraded then count=count+1 end end;assert(count==2)
    local rng=C.copy(run.miscRng);assert(not Nodes.chooseEvent(run,'accept'));same(rng,run.miscRng)
end)
test('upgrade shrine revalidates UIDs, leaves cancel untouched and cannot upgrade twice',function()
    local run,map,id=setup('upgrade_shrine');assert(Nodes.enter(run,map,id))
    local before=C.copy(run);assert(not Nodes.chooseEvent(run,'upgrade',-1));same(before,run)
    local uid=run.deck[1].uid;assert(Nodes.chooseEvent(run,'upgrade',uid));assert(run.deck[1].upgraded)
    assert(not Nodes.chooseEvent(run,'upgrade',uid))
    run,map,id=setup('upgrade_shrine');for _,c in ipairs(run.deck) do c.upgraded=true end
    assert(Nodes.enter(run,map,id));assert(not Nodes.view(run,map).node.event.options[1].enabled)
    assert(Nodes.chooseEvent(run,'leave'))
end)
test('Golden Wing requires single hit base damage ten; sacrifice is a committed damage stage',function()
    local run,map,id=setup('golden_wing')
    for _,c in ipairs(run.deck) do c.cardId=data.cards.starter_deck.cards[1];c.upgraded=false end
    assert(Nodes.enter(run,map,id));local before=C.copy(run)
    assert(not Nodes.chooseEvent(run,'take_gold'));same(before,run)
    local hp=run.hp;assert(Nodes.chooseEvent(run,'sacrifice'));assert(run.hp==hp-7 and not run.nodeFlow.complete)
    assert(not Nodes.chooseEvent(run,'sacrifice'));local uid=run.deck[1].uid
    assert(Nodes.chooseEvent(run,'purge',uid));assert(#run.deck==#before.deck-1)
end)
test('floor14 unknown combat has eligible ordinary encounters and can finish with normal rewards',function()
    local run,map=setup(nil,42)
    for floor=1,13 do assert(Map.choose(map,Map.available(map)[1].id)) end
    local node=Map.available(map)[1]
    for _,candidate in ipairs(map.nodes) do if candidate.id==node.id then candidate.type='event' end end
    run.unknown.chances.monster=1.0
    assert(Nodes.enter(run,map,node.id),'floor14 cannot reject a legitimate unknown-room monster')
    assert(run.phase=='combat' and run.nodeFlow.type=='combat')
    for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
    assert(Run.finishCombat(run));assert(Run.claimCardReward(run,0));assert(Nodes.completeCombat(run,map))
    assert(run.phase=='map' and #Nodes.available(run,map)>0)
end)
test('pool exhaustion and battle setup failure preserve every map, probability, stream and pool field',function()
    local run,map,id=setup(nil,42)
    run.unknown.pools.act={};run.unknown.pools.shrine={};run.unknown.pools.once={}
    local before=C.copy({run=run,map=map})
    local ok,reason=Nodes.enter(run,map,id);assert(not ok and reason=='event_pool_exhausted')
    same({run=run,map=map},before)
    run,map,id=setup(nil,42);run.unknown.chances.monster=1.0;run.relics={'missing'}
    before=C.copy({run=run,map=map});assert(not Nodes.enter(run,map,id));same({run=run,map=map},before)
end)
test('saved active event resumes without rerolling or changing the next selection stream',function()
    local run,map,id=setup('goop',7);assert(Nodes.enter(run,map,id))
    local saved=C.copy(run);local eventRng=C.copy(run.eventRng)
    Nodes.view(saved,map);assert(saved.nodeFlow.event.goldLoss==run.nodeFlow.event.goldLoss)
    assert(Nodes.chooseEvent(saved,'gather'));assert(Nodes.chooseEvent(run,'gather'));same(saved,run)
    same(eventRng,run.eventRng)
end)
test('Golden Wing gold branch uses captured base attack qualification and pays only once',function()
    local run,map,id=setup('golden_wing',9)
    run.deck[1].cardId='bash';run.deck[1].upgraded=true
    assert(Nodes.enter(run,map,id));assert(run.nodeFlow.event.canAttack)
    local gold,hp,counter=run.gold,run.hp,run.miscRng.counter
    assert(Nodes.chooseEvent(run,'take_gold'));assert(run.gold>=gold+50 and run.gold<=gold+80 and run.hp==hp)
    assert(run.miscRng.counter==counter+1);local before=C.copy(run)
    assert(not Nodes.chooseEvent(run,'take_gold'));same(before,run)
end)
test('eligibility covers conditional one-time events and Note availability without contaminating Act1',function()
    local c={act=1,floor=6,gold=49,hp=12,relicCount=1,cursed=false,elapsedSeconds=0}
    assert(not Pool.isEligible('The Woman in Blue',c));c.gold=50;assert(Pool.isEligible('The Woman in Blue',c))
    assert(not Pool.isEligible('Duplicator',c) and not Pool.isEligible('Designer',c))
    assert(Pool.isEligible('FaceTrader',c) and not Pool.isEligible('Fountain of Cleansing',c))
    c.cursed=true;assert(Pool.isEligible('Fountain of Cleansing',c))
    c.act=2;assert(not Pool.isEligible('Knowing Skull',c));c.hp=13;assert(Pool.isEligible('Knowing Skull',c))
    c.gold=74;assert(not Pool.isEligible('Designer',c));c.gold=75;assert(Pool.isEligible('Designer',c))
    assert(not Pool.isEligible("N'loth",c));c.relicCount=2;assert(Pool.isEligible("N'loth",c))
    c.act=3;c.elapsedSeconds=799;assert(not Pool.isEligible('SecretPortal',c));c.elapsedSeconds=800;assert(Pool.isEligible('SecretPortal',c))
    assert(#Pool.new('full',true).once==14 and Pool.new('full',true).once[10]=='NoteForYourself')
end)
print('LUA_UNKNOWN_EVENTS_PASS '..n)
