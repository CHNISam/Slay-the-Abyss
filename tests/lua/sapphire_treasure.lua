-- Real Nodes entry/choice commands over navigation-only fixtures. Prior rooms
-- and endingUnlocked are staged, not earned campaign/history evidence.
local Nodes,Run,Map=require('abyss_nodes'),require('abyss_run'),require('abyss_map')
local C,Data,H=require('abyss_combat'),require('abyss_data'),require('abyss_relic_hooks')
local count=0
local function same(a,b,path,forward,backward)
    if a==b then return end
    path=path or 'state';assert(type(a)==type(b),path..' type')
    if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
    forward,backward=forward or {},backward or {}
    if forward[a] then assert(forward[a]==b,path..' alias');return end
    assert(not backward[b],path..' unexpected alias');forward[a],backward[b]=b,a
    for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k),forward,backward)end
    for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function test(name,fn)fn();count=count+1;print('ok sapphire treasure '..count..' - '..name)end
local readyMaps={}
local function beforeTreasure(act)
    if not readyMaps[act] then
        local map=Map.generate(Data,'42',act)
        while true do
            local available=Map.available(map);assert(#available>0,'treasure route missing')
            local target
            for _,node in ipairs(available)do if node.type=='treasure' and node.roomKind~='boss_treasure' then target=node;break end end
            if target then readyMaps[act]={map=map,id=target.id};break end
            assert(Map.choose(map,available[1].id))
        end
    end
    return C.copy(readyMaps[act].map),readyMaps[act].id
end
local function onlyRelic(id)
    local data=C.copy(Data);local relics={}
    for _,relic in ipairs(data.relics.relics)do
        if relic.id==id or relic.rarity=='starter' then relics[#relics+1]=relic end
    end
    data.relics.relics=relics;return data
end
local function treasure(options)
    options=options or {};local act=options.act or 1
    local constructor=not options.standalone and {experimental=true,campaign=true,character=options.character} or nil
    local run=Run.new(options.data or Data,'42',constructor)
    if not options.standalone then run.act=act end
    if options.qualified~=false then run.endingUnlocked=true end
    if options.owned then run.keys.sapphire=true end
    if options.exhausted then
        for _,relic in ipairs(run.data.relics.relics)do
            if relic.rarity=='common' or relic.rarity=='uncommon' or relic.rarity=='rare' then
                run.relics[#run.relics+1]=relic.id
            end
        end
    end
    local map,id=beforeTreasure(act);assert(Nodes.enter(run,map,id));return run,map
end
local function source(run,map)return assert(Nodes.treasureSource(run,map))end
local function rejected(run,map,fn)
    local before,mapBefore=C.copy(run),C.copy(map)
    local roots={};for key,value in pairs(run)do if type(value)=='table' then roots[key]=value end end
    local nodes,path=map.nodes,map.path
    local called,ok,why=pcall(fn);assert(called,'refusal threw: '..tostring(ok))
    assert(ok==false and type(why)=='string','refusal result: '..tostring(why))
    same(run,before);same(map,mapBefore)
    for key,value in pairs(roots)do assert(run[key]==value,'refusal replaced '..key)end
    assert(map.nodes==nodes and map.path==path,'refusal replaced map owner');return why
end

test('constructor/history remain unearned and ineligible entry never creates a late offer',function()
    local fresh=Run.new(Data,'42',{experimental=true,campaign=true})
    assert(fresh.endingUnlocked==nil);same(fresh.keys,{ruby=false,emerald=false,sapphire=false})
    for _,options in ipairs({{standalone=true},{qualified=false},{owned=true}})do
        local run,map=treasure(options)
        assert(not run.nodeFlow.reward.sapphireKey and not Nodes.treasureSource(run,map))
        rejected(run,map,function()return Nodes.chooseTreasure(run,map,{},'sapphire')end)
        if not options.standalone then run.endingUnlocked=true;run.keys.sapphire=false end
        assert(not Nodes.treasureSource(run,map),'eligibility after opening created a new offer')
        assert(Nodes.claimTreasure(run),'legacy displayed relic claim must remain available')
    end
end)

test('prepared pair and source/view are detached and bind exactly the generated base relic',function()
    local run,map=treasure();local before,mapBefore=C.copy(run),C.copy(map)
    local token=source(run,map);assert(token.relicId==run.nodeFlow.reward.relicId)
    assert(run.nodeFlow.reward.sapphireKey.relicId==token.relicId and token.roomGeneration==run.roomGeneration)
    local view=Nodes.view(run,map);view.node.reward.relicId='forged';view.node.reward.sapphireKey.relicId='forged'
    token.relicId='forged';token.roomGeneration=999;same(run,before);same(map,mapBefore)
    assert(source(run,map).relicId==before.nodeFlow.reward.relicId)
end)

test('key choice grants only Sapphire, expires relic/link, and spends no gameplay RNG/hooks',function()
    local run,map=treasure({data=onlyRelic('strawberry')});local token=source(run,map)
    run.hp=17;run.gold=231;run.potions={'block_potion'}
    run.combat={phase='finished',events={{kind='retained'}},powerState={once=true}}
    run.rewards={cards={'anger'},gold=19,goldClaimed=true,cardResolved=true}
    local expected,mapBefore=C.copy(run),C.copy(map)
    expected.keys.sapphire=true;expected.phase='map';expected.nodeFlow.complete=true
    expected.nodeFlow.result='sapphire';expected.nodeFlow.treasureChoice='sapphire'
    expected.nodeFlow.reward.relicId=nil;expected.nodeFlow.reward.sapphireKey=nil
    local obtain,equip,gold=Run.obtainRelic,H.onEquip,Run.gainGold
    Run.obtainRelic=function()error('key choice obtained a relic')end
    H.onEquip=function()error('key choice equipped relic')end
    Run.gainGold=function()error('key choice granted gold')end
    local called,ok,why=pcall(Nodes.chooseTreasure,run,map,token,'sapphire')
    Run.obtainRelic,H.onEquip,Run.gainGold=obtain,equip,gold
    assert(called and ok and why=='sapphire',tostring(why));same(run,expected);same(map,mapBefore)
    assert(run.endingUnlocked and not run.keys.ruby and not run.keys.emerald)
end)

test('legacy displayed-relic claim remains explicit and consumes linked key with equip effects',function()
    local run,map=treasure({data=onlyRelic('strawberry')});run.hp=17
    local token=source(run,map);local maxHp,gold=run.maxHp,run.gold
    assert(Nodes.claimTreasure(run));assert(run.maxHp==maxHp+7 and run.hp==24 and run.gold==gold)
    assert(run.relics[#run.relics]=='strawberry' and not run.keys.sapphire)
    assert(run.nodeFlow.treasureChoice=='relic' and run.nodeFlow.result=='complete')
    assert(run.nodeFlow.reward.relicId=='strawberry' and not run.nodeFlow.reward.sapphireKey)
    rejected(run,map,function()return Nodes.chooseTreasure(run,map,token,'sapphire')end)
end)

test('token relic choice uses exactly the existing obtain/equip transaction',function()
    local run,map=treasure({data=onlyRelic('whetstone')});local token=source(run,map)
    local legacy=C.copy(run);assert(Nodes.claimTreasure(legacy))
    assert(Nodes.chooseTreasure(run,map,token,'relic'));same(run,legacy)
    assert(not run.keys.sapphire and run.nodeFlow.treasureChoice=='relic')
end)

test('each choice refuses repeated or opposite public claims without partial resources',function()
    for _,choice in ipairs({'relic','sapphire'})do
        local run,map=treasure();local token=source(run,map)
        assert(Nodes.chooseTreasure(run,map,token,choice));assert(not Nodes.treasureSource(run,map))
        for _,nextChoice in ipairs({'relic','sapphire'})do
            rejected(run,map,function()return Nodes.chooseTreasure(run,map,token,nextChoice)end)
        end
        rejected(run,map,function()return Nodes.claimTreasure(run)end)
        rejected(run,map,function()return Nodes.claimBossTreasure(run,0)end)
    end
end)

test('all four profiles share the same core key path and keep other keys unchanged',function()
    for _,character in ipairs({'ironclad','silent','defect','watcher'})do
        for _,ruby in ipairs({false,true})do for _,emerald in ipairs({false,true})do
            local run,map=treasure({character=character});run.keys.ruby,run.keys.emerald=ruby,emerald
            assert(Nodes.chooseTreasure(run,map,source(run,map),'sapphire'))
            same(run.keys,{ruby=ruby,emerald=emerald,sapphire=true})
        end end
    end
end)

test('acts one to three use real chapter maps without fabricating an act-four treasure',function()
    for _,act in ipairs({1,2,3})do
        local run,map=treasure({act=act});local token=source(run,map)
        assert(token.act==act and (map.act or 1)==act)
        assert(Nodes.chooseTreasure(run,map,token,'sapphire') and run.keys.sapphire)
    end
    local map=Map.generate(Data,'42',4)
    for _,node in ipairs(map.nodes)do assert(node.type~='treasure','act four treasure was invented')end
end)

test('gold fallback remains gold only and cannot exchange for a free key',function()
    local run,map=treasure({exhausted=true});local gold=run.gold
    assert(run.nodeFlow.reward.gold==run.data.rules.rewards.normalGold)
    assert(not run.nodeFlow.reward.relicId and not run.nodeFlow.reward.sapphireKey and not Nodes.treasureSource(run,map))
    rejected(run,map,function()return Nodes.chooseTreasure(run,map,{},'sapphire')end)
    assert(Nodes.claimTreasure(run));assert(run.gold==gold+run.data.rules.rewards.normalGold and not run.keys.sapphire)
end)

test('a real Tiny Chest unknown-room resolution links its base relic, not the map question mark',function()
    local run=Run.new(Data,'42',{experimental=true,campaign=true});run.endingUnlocked=true
    assert(Run.obtainRelic(run,'Tiny Chest'));run.unknown.chances.tinyChestCount=3
    local map=Map.generate(Data,'42');local target
    while not target do
        local available=Map.available(map);assert(#available>0,'unknown-room route missing')
        for _,node in ipairs(available)do if node.type=='event' and not node.eventId then target=node;break end end
        if not target then assert(Map.choose(map,available[1].id))end
    end
    assert(Nodes.enter(run,map,target.id))
    assert(run.nodeFlow.type=='treasure' and run.nodeFlow.sourceType=='event' and run.unknown.chances.tinyChestCount==0)
    local token=source(run,map);assert(token.id==target.id and token.relicId==run.nodeFlow.reward.relicId)
    assert(Nodes.chooseTreasure(run,map,token,'sapphire') and run.keys.sapphire)
end)

test('earned Boss chest never offers Sapphire and its existing choice remains available',function()
    local run=Run.new(Data,'42',{experimental=true,campaign=true});run.endingUnlocked=true
    local map=Map.generate(Data,'42');local target
    while not target do
        local available=Map.available(map);assert(#available>0,'boss treasure route missing')
        for _,node in ipairs(available)do if node.roomKind=='boss_treasure' then target=node;break end end
        if not target then assert(Map.choose(map,available[1].id))end
    end
    -- Staged victory boundary, not a played Boss or natural campaign.
    run.nodeFlow={id=map.currentNodeId,floor=map.floor,type='boss',complete=true,result='boss_victory',
        mapSeed=map.seed,mapSignature=map.sourceSignature}
    assert(Nodes.enter(run,map,target.id));assert(run.nodeFlow.reward.relics and not run.nodeFlow.reward.sapphireKey)
    assert(not Nodes.treasureSource(run,map))
    rejected(run,map,function()return Nodes.chooseTreasure(run,map,{},'sapphire')end)
    assert(Nodes.claimBossTreasure(run,0));assert(not run.keys.sapphire and run.phase=='act_transition')
end)

test('malformed history/key owners refuse before graph-copy normalization',function()
    local mutations={
        function(r)r.campaign=false end,function(r)r.act=0 end,function(r)r.act='1'end,
        function(r)r.endingUnlocked=nil end,function(r)r.endingUnlocked='true'end,
        function(r)r.keys=nil end,function(r)r.keys={}end,function(r)r.keys.ruby=0 end,
        function(r)r.keys.emerald='false'end,function(r)r.keys.sapphire=1 end,
        function(r)r.keys.sapphire=true end,function(r)r.keys=setmetatable(r.keys,{})end,
    }
    for _,mutate in ipairs(mutations)do
        local run,map=treasure();local token=source(run,map);mutate(run)
        assert(not Nodes.treasureSource(run,map))
        rejected(run,map,function()return Nodes.chooseTreasure(run,map,token,'sapphire')end)
    end
end)

test('source tokens bind every field and malformed/invalid choices are pure refusals',function()
    local run,map=treasure();local token=source(run,map)
    for _,bad in ipairs({false,1,'sapphire',{},setmetatable(C.copy(token),{})})do
        rejected(run,map,function()return Nodes.chooseTreasure(run,map,bad,'sapphire')end)
    end
    rejected(run,map,function()return Nodes.chooseTreasure(run,map,nil,'sapphire')end)
    for key,value in pairs(token)do
        local bad=C.copy(token);bad[key]=type(value)=='number' and value+1 or 'other'
        rejected(run,map,function()return Nodes.chooseTreasure(run,map,bad,'sapphire')end)
    end
    for _,bad in ipairs({false,0,1,'key','ruby','gold',{},'skip'})do
        rejected(run,map,function()return Nodes.chooseTreasure(run,map,token,bad)end)
    end
    rejected(run,map,function()return Nodes.chooseTreasure(run,map,token)end)
end)

test('phase map and room-generation mismatches never grant or replace owners',function()
    local mutations={
        function(r)r.phase='map'end,function(r)r.phase='combat'end,function(r)r.nodeFlow.complete=true end,
        function(r)r.nodeFlow.type='camp'end,function(r)r.nodeFlow.complete=nil end,
        function(r)r.nodeFlow.treasureChoice='relic'end,function(r)r.roomGeneration=0 end,
        function(r)r.roomGeneration=1.5 end,function(r)r.roomGeneration=2147483648 end,
        function(r)r.floor=r.floor+1 end,function(r)r.runSeed='43'end,
        function(_,m)m.currentNodeId='missing'end,function(_,m)m.sourceSignature='other'end,
        function(_,m)m.nodes[1]=false end,function(_,m)m.path[#m.path]='missing'end,
        function(r)r.nodeFlow.mapSeed=nil end,function(r)r.nodeFlow.mapSignature=nil end,
        function(r)r.nodeFlow.floor='9'end,function(r)r.nodeFlow.roomKind='boss_treasure'end,
        function(r)r.nodeFlow=nil end,
    }
    for _,mutate in ipairs(mutations)do
        local run,map=treasure();local token=source(run,map);mutate(run,map)
        assert(not Nodes.treasureSource(run,map))
        rejected(run,map,function()return Nodes.chooseTreasure(run,map,token,'sapphire')end)
    end
end)

test('unsupported reward lists, broken links, changed or missing relic content refuse',function()
    local mutations={
        function(r)r.nodeFlow.reward=nil end,function(r)r.nodeFlow.reward={}end,
        function(r)r.nodeFlow.reward=setmetatable(r.nodeFlow.reward,{})end,
        function(r)r.nodeFlow.reward.relicId='missing'end,
        function(r)r.nodeFlow.reward.sapphireKey=nil end,
        function(r)r.nodeFlow.reward.sapphireKey.relicId='other'end,
        function(r)r.nodeFlow.reward.sapphireKey=setmetatable(r.nodeFlow.reward.sapphireKey,{})end,
        function(r)r.nodeFlow.reward.sapphireKey.extra=true end,
        function(r)r.nodeFlow.reward.gold=23 end,
        function(r)r.nodeFlow.reward.relics={'anchor'}end,
        function(r)r.nodeFlow.reward.extraRelics={'anchor'}end,
        function(r)r.relics[#r.relics+1]=r.nodeFlow.reward.relicId end,
        function(r)r.data=C.copy(r.data);r.data.relics.relics={}end,
    }
    for _,mutate in ipairs(mutations)do
        local run,map=treasure();local token=source(run,map);mutate(run)
        assert(not Nodes.treasureSource(run,map))
        rejected(run,map,function()return Nodes.chooseTreasure(run,map,token,'sapphire')end)
    end
end)

test('old callback cannot choose a different later eligible chest',function()
    local run,map=treasure({data=onlyRelic('strawberry')});local stale=source(run,map)
    assert(Nodes.claimTreasure(run))
    -- Chapter navigation boundary only; no prior rooms/act transition claimed.
    run.nodeFlow=nil;run.act=2;run.phase='map'
    local nextMap,id=beforeTreasure(2);assert(Nodes.enter(run,nextMap,id))
    -- Strawberry is owned, so this chapter has only gold and no key offer.
    assert(not Nodes.treasureSource(run,nextMap))
    rejected(run,nextMap,function()return Nodes.chooseTreasure(run,nextMap,stale,'sapphire')end)
    -- A separate supported full pool still provides an unowned next relic.
    run,map=treasure();stale=source(run,map);assert(Nodes.claimTreasure(run))
    run.nodeFlow=nil;run.act=2;run.phase='map';nextMap,id=beforeTreasure(2)
    assert(Nodes.enter(run,nextMap,id));local current=source(run,nextMap)
    assert(current.id~=stale.id and current.roomGeneration==stale.roomGeneration+1)
    assert(rejected(run,nextMap,function()return Nodes.chooseTreasure(run,nextMap,stale,'sapphire')end)=='treasure_source_mismatch')
    assert(Nodes.chooseTreasure(run,nextMap,current,'sapphire'))
end)

test('obtaining a key prevents a later prepared chest from offering it again',function()
    local run,map=treasure();assert(Nodes.chooseTreasure(run,map,source(run,map),'sapphire'))
    run.nodeFlow=nil;run.act=2;run.phase='map';local nextMap,id=beforeTreasure(2)
    assert(Nodes.enter(run,nextMap,id));assert(not run.nodeFlow.reward.sapphireKey and not Nodes.treasureSource(run,nextMap))
    assert(Nodes.claimTreasure(run) and run.keys.sapphire)
end)

test('key failure after staged completion rolls back every owner and allows legitimate retry',function()
    local run,map=treasure();local token=source(run,map);local transaction=Run.transaction
    local injected=false
    Run.transaction=function(owner,command)
        return transaction(owner,function(staged)
            local ok,why=command(staged)
            if ok then
                assert(staged.keys.sapphire and staged.nodeFlow.complete and staged.phase=='map')
                injected=true;error('sapphire completion fault before commit')
            end
            return ok,why
        end)
    end
    local called,why=pcall(rejected,run,map,function()return Nodes.chooseTreasure(run,map,token,'sapphire')end)
    Run.transaction=transaction;assert(called and injected,tostring(why))
    assert(not run.keys.sapphire and Nodes.chooseTreasure(run,map,token,'sapphire'))
end)

test('real equip mutation then throw/refuse rolls back relic/link/resources and nested poison',function()
    for _,mode in ipairs({'throw','refuse'})do for _,legacy in ipairs({false,true})do
        local run,map=treasure({data=onlyRelic('strawberry')});local token=source(run,map)
        local equip=H.onEquip;local injected=false
        H.onEquip=function(owner,id,api)
            equip(owner,id,api);assert(owner.maxHp==run.maxHp+7 and owner.relics[#owner.relics]=='strawberry')
            injected=true
            if mode=='throw' then error('sapphire relic equip fault')end
            -- Real nested permanent command refusal poisons its parent even
            -- when a hook forgets to propagate its returned failure.
            Run.obtainRelic(owner,'missing')
        end
        local called,why=pcall(rejected,run,map,function()
            if legacy then return Nodes.claimTreasure(run)end
            return Nodes.chooseTreasure(run,map,token,'relic')
        end)
        H.onEquip=equip;assert(called and injected,tostring(why))
        assert(run.nodeFlow.reward.sapphireKey and not run.keys.sapphire)
        assert(Nodes.chooseTreasure(run,map,token,'sapphire'),'rollback lost legitimate offer')
    end end
end)

test('unsupported Matryoshka and Cursed Key are not silently declared implemented',function()
    local run,map=treasure()
    for _,id in ipairs({'Matryoshka','matryoshka','Cursed Key','cursed_key'})do
        rejected(run,map,function()return Run.obtainRelic(run,id)end)
    end
end)

test('ignored nested choice preflight failures poison their enclosing permanent transaction',function()
    local cases={
        function(r)r.endingUnlocked=false end,
        function(r)r.keys=setmetatable(r.keys,{})end,
        function(_,token)token.roomGeneration=token.roomGeneration+1 end,
        function()end,
    }
    for index,mutate in ipairs(cases)do
        local run,map=treasure();local token=source(run,map)
        local injected=false
        rejected(run,map,function()
            return Run.transaction(run,function(staged)
                staged.gold=staged.gold+91;mutate(staged,token)
                local ok=Nodes.chooseTreasure(staged,map,token,index==4 and 'gold' or 'sapphire')
                assert(not ok,'injected nested refusal did not occur');injected=true
                return true -- Deliberately ignore the rejected child command.
            end)
        end)
        assert(injected and not run.keys.sapphire)
    end
end)

print('SAPPHIRE_TREASURE_PASS '..count)
