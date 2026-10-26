-- Boundary fixtures exercise real production commands; these are not natural
-- playthrough evidence or proof that later chapter content is implemented.
local Acts=require('abyss_acts')
local Seed=require('abyss_run_seed')
local Map=require('abyss_map')
local Run=require('abyss_run')
local Nodes=require('abyss_nodes')
local R=require('abyss_sts_random')
local Q=require('abyss_encounter_queue')
local Pool=require('abyss_event_pool')
local Unknown=require('abyss_unknown')
local C=require('abyss_combat')
local Data=require('abyss_data')
local count=0
local function same(a,b,path)
    path=path or 'state';assert(type(a)==type(b),path)
    if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
    for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
    for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function test(name,fn)fn();count=count+1;print('ok cross act '..count..' - '..name)end
local function terminal(act,character)
    local options={experimental=true,campaign=true,character=character}
    local run=Run.new(Data,'42',options)
    local map=Map.generate(run.data,'42',act)
    while #Map.available(map)>0 do assert(Map.choose(map,Map.available(map)[1].id))end
    run.act,run.floor,run.phase=act,Acts.get(act).last,'node'
    if act~=1 then run.encounters=Q.new(run.runSeed,act);run.unknown.pools=Pool.new('full',false,act) end
    run.nodeFlow={id=map.currentNodeId,floor=map.floor,type='treasure',roomKind='boss_treasure',
        mapSeed=map.seed,mapSignature=map.sourceSignature,complete=false,reward={relics={}}}
    return run,map
end

test('all global floors round-trip and chapter boundaries are exact',function()
    for floor=1,55 do
        local act,row=Acts.forFloor(floor)
        assert(Acts.globalFloor(act,row)==floor)
    end
    for _,v in ipairs({{1,1,17,16},{2,18,34,33},{3,35,51,50},{4,52,55,55}})do
        local a=Acts.get(v[1]);assert(a.first==v[2] and a.last==v[3] and a.boss==v[4])
        a.first=0;assert(Acts.get(v[1]).first==v[2],'mutable chapter config escaped')
    end
    for _,bad in ipairs({0,5,-1,1.5,'2',false,{}})do assert(not pcall(Acts.get,bad))end
    for _,bad in ipairs({0,56,-1,1.5,'2',false,{}})do assert(not pcall(Acts.forFloor,bad))end
    assert(not pcall(Acts.globalFloor,4,5))
end)

test('raw signed64 map and room seeds use chapter expressions including wrap',function()
    same({Acts.mapSeed('42',1),Acts.mapSeed('42',2),Acts.mapSeed('42',3),Acts.mapSeed('42',4)},
        {'43','242','642','1242'})
    assert(Acts.mapSeed('9223372036854775807',2)=='-9223372036854775609')
    assert(Acts.mapSeed('-200',2)=='0')
    assert(Acts.mapSeed('-9223372036854775808',4)=='-9223372036854774608')
    assert(Seed.forFloor('9223372036854775807',55)=='-9223372036854775754')
    assert(not pcall(Seed.forFloor,'42',56))
    assert(not pcall(Seed.add,'42',1201))
end)

test('later random maps use global floors and keep the ordinary source topology',function()
    for act=2,3 do
        local map=Map.generate(Data,'42',act)
        local floors={}
        for _,node in ipairs(map.nodes)do
            floors[node.floor]=true
            assert(node.floor==Acts.globalFloor(act,node.localFloor))
            if node.floor==Acts.get(act).treasure then assert(node.type=='treasure')end
            if node.floor==Acts.get(act).camp then assert(node.type=='camp')end
        end
        for floor=Acts.get(act).first,Acts.get(act).last do assert(floors[floor])end
        assert(map.floor==Acts.get(act).first-1 and #Map.available(map)>0)
        assert(map.mapSeed==Acts.mapSeed('42',act))
        while #Map.available(map)>0 do assert(Map.choose(map,Map.available(map)[1].id))end
        assert(Map.view(map).complete and #map.path==17)
        local last=map.nodes[#map.nodes]
        assert(last.floor==Acts.get(act).last)
        assert(last.roomKind==(act==2 and 'boss_treasure' or 'ending'))
        assert(last.type==(act==2 and 'treasure' or 'event'))
        same(Map.restore(Data,Map.snapshot(map)),map)
        local wrong=Map.snapshot(map);wrong.act=act==2 and 3 or 2
        assert(not Map.restore(Data,wrong),'cross-chapter snapshot accepted')
    end
end)

test('fourth chapter contains exactly four fixed playable rooms and no reward chest',function()
    local map=Map.generate(Data,'42',4)
    assert(#map.nodes==4 and #Map.available(map)==1)
    for row,kind in ipairs({'camp','shop','elite','boss'})do
        local node=map.nodes[row];assert(node.floor==51+row and node.type==kind and not node.roomKind)
        assert(Map.choose(map,node.id))
    end
    assert(map.floor==55 and Map.view(map).complete and #Map.available(map)==0)
    same(Map.restore(Data,Map.snapshot(map)),map)
    local wrong=Map.snapshot(map);wrong.nodes[4].nextIds={'f56_l4'}
    assert(not Map.restore(Data,wrong),'fake playable floor 56 accepted')
end)

test('normal legacy run keeps the earned first-act victory boundary',function()
    local run=Run.new(Data,42)
    run.phase='node';run.nodeFlow={type='treasure',roomKind='boss_treasure',reward={relics={}}}
    assert(Nodes.claimBossTreasure(run,0));assert(run.phase=='victory' and not run.pendingAct)
    assert(not Run.advanceAct(run))
end)

test('four characters keep card UIDs inventory counters and raw seed on a real chest choice',function()
    for _,character in ipairs({'native','ironclad','silent','defect','watcher'})do
        local run,map=terminal(1,character~='native' and character or nil)
        run.maxHp,run.hp,run.gold=run.maxHp+7,3,345
        run.deck[1].upgraded=true
        run.potions={'block_potion'};run.relicCounters={persisted=3}
        local expected={deck=C.copy(run.deck),relics=C.copy(run.relics),potions=C.copy(run.potions),
            counters=C.copy(run.relicCounters),uid=run.nextDeckUid,character=run.character,maxHp=run.maxHp}
        local stream=R.snapshot(run.eventRng)
        assert(Nodes.claimBossTreasure(run,0));assert(run.phase=='act_transition' and run.pendingAct==2)
        assert(Nodes.advanceAct(run,map));assert(run.act==2 and run.phase=='map' and map.floor==17)
        assert(run.hp==expected.maxHp and run.maxHp==expected.maxHp and run.gold==345)
        same(run.deck,expected.deck);same(run.relics,expected.relics);same(run.potions,expected.potions)
        same(run.relicCounters,expected.counters);same(R.snapshot(run.eventRng),stream)
        assert(run.nextDeckUid==expected.uid and run.character==expected.character and run.runSeed=='42')
        assert(not Nodes.advanceAct(run,map),'second transition accepted')
        local before=C.copy(run)
        local entered,why=Nodes.enter(run,map,Map.available(map)[1].id)
        assert(not entered and why=='act_content_unavailable','missing second-act content silently reused Act1')
        same(run,before)
    end
end)

test('card RNG counter advancement consumes original booleans and preserves exact boundary states',function()
    for _,n in ipairs({0,1,249,250,251,499,500,501,749,750,751})do
        local run,map=terminal(1)
        for _=1,n do R.randomBoolean(run.cardRng)end
        run.cardRarityOffset=-17
        local expected=R.cloneState(run.cardRng)
        local target=n==0 and 0 or n<=250 and 250 or n<=500 and 500 or n<=750 and 750 or n
        while expected.counter<target do R.randomBoolean(expected)end
        assert(Nodes.claimBossTreasure(run,0) and Nodes.advanceAct(run,map))
        same(R.snapshot(run.cardRng),R.snapshot(expected))
        assert(run.cardRarityOffset==-17,'rarity offset reset on new chapter')
    end
end)

test('ordinary and shrine pools reset in source order while global events and tiny chest persist',function()
    local run,map=terminal(1)
    table.remove(run.unknown.pools.once,1)
    local once=C.copy(run.unknown.pools.once)
    run.unknown.chances.monster=.5;run.unknown.chances.tinyChestCount=3
    assert(Nodes.claimBossTreasure(run,0) and Nodes.advanceAct(run,map))
    assert(#run.unknown.pools.act==13 and run.unknown.pools.act[1]=='Addict' and run.unknown.pools.act[13]=='Vampires')
    same(run.unknown.pools.shrine,{'Match and Keep!','Wheel of Change','Golden Shrine','Transmorgrifier','Purifier','Upgrade Shrine'})
    same(run.unknown.pools.once,once)
    local fresh=Unknown.newPc();fresh.tinyChestCount=3;same(run.unknown.chances,fresh)
    Pool.nextAct(run.unknown.pools,3)
    assert(#run.unknown.pools.act==7 and run.unknown.pools.act[1]=='Falling' and run.unknown.pools.act[7]=='Winding Halls')
    same(run.unknown.pools.once,once)
end)

test('second-act chest advances to the third map and respects healing prohibition',function()
    local run,map=terminal(2)
    run.hp=5;run.relics[#run.relics+1]='mark_of_bloom'
    assert(Nodes.claimBossTreasure(run,0) and Nodes.advanceAct(run,map))
    assert(run.act==3 and map.floor==34 and map.nodes[#map.nodes].roomKind=='ending' and run.hp==5)
end)

test('wrong maps invalid requests and thrown new-map preparation leave all owners intact',function()
    local run,map=terminal(1)
    assert(Nodes.claimBossTreasure(run,0))
    local before,mapBefore=C.copy(run),Map.snapshot(map)
    local wrong=Map.generate(Data,'43')
    assert(not Nodes.advanceAct(run,wrong));same(run,before);same(map,mapBefore)
    local generate=Map.generate
    Map.generate=function()error('forced map preparation fault')end
    local called,ok=pcall(Nodes.advanceAct,run,map)
    Map.generate=generate
    assert(called and not ok);same(run,before);same(map,mapBefore)
    run.pendingAct=3;before=C.copy(run)
    assert(not Nodes.advanceAct(run,map));same(run,before);same(map,mapBefore)
end)

test('third-act terminal makes a normal victory or requires history and all three keys',function()
    for _,v in ipairs({{false,false,false,false,false},{true,true,true,false,false},{false,true,true,true,false},{true,true,true,true,true}})do
        local run=Run.new(Data,'42',{experimental=true,campaign=true})
        local map=Map.generate(Data,'42',3)
        while map.floor<50 do assert(Map.choose(map,Map.available(map)[1].id))end
        run.act,run.floor,run.phase=3,50,'map'
        run.encounters=Q.new(run.runSeed,3)
        run.keys={ruby=v[2],emerald=v[3],sapphire=v[4]};run.endingUnlocked=v[1]
        run.nodeFlow={id=map.currentNodeId,floor=50,type='boss',result='boss_victory',complete=true,
            mapSeed=map.seed,mapSignature=map.sourceSignature}
        assert(Nodes.enter(run,map,'f51_l4'))
        assert(run.phase==(v[5] and 'act_transition' or 'victory') and run.floor==51)
        assert(run.nodeFlow.roomKind=='ending' and not run.nodeFlow.reward)
        if v[5] then
            assert(Nodes.advanceAct(run,map))
            assert(run.act==4 and map.floor==51 and Map.available(map)[1].floor==52)
        else assert(not Nodes.advanceAct(run,map))end
    end
end)

test('new monster queues retain distinct chapters and first two weak fights',function()
    for act=2,3 do
        local q=Q.new('42',act)
        assert(#q.normal==15 and #q.elite==10 and q.act==act)
        local weak={};for _,entry in ipairs(Q.rules(act).weak)do weak[entry[1]]=true end
        assert(weak[q.normal[1]] and weak[q.normal[2]])
        same(Q.restore(Q.snapshot(q)),q)
    end
end)
print('CROSS_ACT_PASS '..count)
