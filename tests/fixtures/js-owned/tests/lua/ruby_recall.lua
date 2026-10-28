local sliceFirst,sliceLast=...
sliceFirst,sliceLast=sliceFirst or 1,sliceLast or 8
local sliceRegistered,sliceExecuted=0,0
-- Navigation/qualification boundary fixtures, not a natural campaign or proof
-- of earned/persisted three-character history. The key itself is never injected:
-- every successful Ruby acquisition below uses the public camp command.
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
local function copy(run)return C.copy(run)end
local function test(name,fn)
    sliceRegistered=sliceRegistered+1
    if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end
    fn();sliceExecuted=sliceExecuted+1;count=count+1
    print('ok ruby recall '..count..' - '..name)
    print('RUBY_RECALL_CASE '..sliceRegistered)
end
local readyMaps={}
local function beforeCamp(act)
    if not readyMaps[act] then
        local map=Map.generate(Data,'42',act)
        while true do
            local available=Map.available(map);assert(#available>0,'no camp route')
            local camp
            for _,node in ipairs(available)do if node.type=='camp' then camp=node;break end end
            if camp then readyMaps[act]={map=map,id=camp.id};break end
            -- Existing navigation-only fixture convention: preceding rooms are
            -- not claimed as played. The selected camp enters via real Nodes.
            assert(Map.choose(map,available[1].id))
        end
    end
    return C.copy(readyMaps[act].map),readyMaps[act].id
end
local function camp(options)
    options=options or {};local act=options.act or 1
    local runOptions
    if not options.standalone then runOptions={experimental=true,campaign=true,character=options.character} end
    local run=Run.new(Data,'42',runOptions)
    if not options.standalone then run.act=act end
    run.endingUnlocked=options.qualified~=false
    for _,id in ipairs(options.relics or {})do assert(Run.obtainRelic(run,id))end
    local map,id=beforeCamp(act);assert(Nodes.enter(run,map,id))
    return run,map
end
local function source(run,map)
    return assert(Nodes.recallSource(run,map))
end
local function rejected(run,map,fn)
    local before,mapBefore=copy(run),C.copy(map)
    local roots={};for k,v in pairs(run)do if type(v)=='table' then roots[k]=v end end
    local path,nodes=map.path,map.nodes
    local called,ok,why=pcall(fn);assert(called,'refusal threw');assert(ok==false and type(why)=='string',tostring(why))
    same(run,before);same(map,mapBefore)
    for k,v in pairs(roots)do assert(run[k]==v,'refusal replaced '..k)end
    assert(map.path==path and map.nodes==nodes,'refusal replaced map owner')
    return why
end

test('constructor leaves history absent, standalone camp never offers Recall',function()
    local fresh=Run.new(Data,'42',{experimental=true,campaign=true})
    assert(fresh.endingUnlocked==nil);same(fresh.keys,{ruby=false,emerald=false,sapphire=false})
    local run,map=camp({standalone=true})
    assert(not Nodes.recallSource(run,map) and run.campaign==nil and run.keys==nil)
    rejected(run,map,function()return Nodes.recall(run,map,{})end)
end)

test('Recall source is detached; history is an existing input, never created',function()
    local run,map=camp();local before,mapBefore=copy(run),C.copy(map)
    local token=source(run,map)
    assert(token.roomGeneration==run.roomGeneration and token.id==map.currentNodeId)
    token.roomGeneration=999;token.id='forged'
    same(run,before);same(map,mapBefore)
    assert(Nodes.recallSource(run,map).roomGeneration==run.roomGeneration)
end)

test('real camp choice grants only Ruby and consumes the room without heal upgrade hooks or RNG',function()
    local run,map=camp({relics={'Dream Catcher','Regal Pillow','Ancient Tea Set','MawBank'}})
    run.hp=17;run.gold=231;run.potions={'block_potion'}
    run.combat={phase='finished',player={hp=17,statuses={strength=4}},events={{kind='unchanged'}},powerState={once=true}}
    run.rewards={cards={'anger'},gold=19,goldClaimed=true,cardResolved=true}
    run.nodeFlow.reward={gold=27,relicId='vajra'}
    local token=source(run,map);local expected,mapBefore=copy(run),C.copy(map)
    expected.keys.ruby=true;expected.phase='map';expected.nodeFlow.campChoice='recall'
    expected.nodeFlow.complete=true;expected.nodeFlow.result='recall';expected.nodeFlow.reward=nil
    local heal,onRest=Run.heal,H.onRest
    Run.heal=function()error('Recall invoked healing')end
    H.onRest=function()error('Recall invoked rest hooks')end
    local called,ok,result=pcall(Nodes.recall,run,map,token)
    Run.heal,H.onRest=heal,onRest
    assert(called and ok and result=='recall',tostring(result))
    same(run,expected);same(map,mapBefore)
    assert(run.endingUnlocked==true and not run.keys.emerald and not run.keys.sapphire)
    assert(not Nodes.recallSource(run,map) and #Nodes.available(run,map)>0)
    rejected(run,map,function()return Nodes.recall(run,map,token)end)
    rejected(run,map,function()return Nodes.rest(run)end)
    rejected(run,map,function()return Nodes.upgrade(run,run.deck[1].uid)end)
    rejected(run,map,function()return Nodes.claimRestReward(run,1)end)
end)

test('no card to forge, full HP and healing prohibition do not prevent eligible Recall',function()
    local run,map=camp();run.relics[#run.relics+1]='mark_of_bloom';run.deck={}
    local token=source(run,map)
    assert(#Nodes.view(run,map).node.upgradeCards==0 and run.hp==run.maxHp)
    local expected=copy(run);expected.keys.ruby=true;expected.phase='map'
    expected.nodeFlow.campChoice='recall';expected.nodeFlow.complete=true;expected.nodeFlow.result='recall'
    assert(Nodes.recall(run,map,token));same(run,expected)
end)

test('all four character profiles use the same real camp command',function()
    for _,character in ipairs({'ironclad','silent','defect','watcher'})do
        local run,map=camp({character=character});local token=source(run,map)
        local expected=copy(run);expected.keys.ruby=true;expected.phase='map'
        expected.nodeFlow.campChoice='recall';expected.nodeFlow.complete=true;expected.nodeFlow.result='recall'
        assert(Nodes.recall(run,map,token));same(run,expected)
    end
end)

test('existing history gate rejects nil false strings numbers and tables purely',function()
    for _,value in ipairs({false,'true',1,{true}})do
        local run,map=camp();run.endingUnlocked=value;local token={}
        assert(not Nodes.recallSource(run,map));rejected(run,map,function()return Nodes.recall(run,map,token)end)
    end
    local run,map=camp();run.endingUnlocked=nil;local token={}
    assert(not Nodes.recallSource(run,map));rejected(run,map,function()return Nodes.recall(run,map,token)end)
end)

test('malformed key owners and any nonboolean key flag refuse without normalization',function()
    local invalid={false,'keys',1,{}, {ruby=false,emerald=false}, {ruby=0,emerald=false,sapphire=false},
        {ruby=false,emerald='false',sapphire=false},{ruby=false,emerald=false,sapphire={}}}
    for _,keys in ipairs(invalid)do
        local run,map=camp();run.keys=keys;local token={}
        assert(not Nodes.recallSource(run,map));rejected(run,map,function()return Nodes.recall(run,map,token)end)
    end
    local run,map=camp();run.keys=nil;local token={}
    assert(not Nodes.recallSource(run,map));rejected(run,map,function()return Nodes.recall(run,map,token)end)
    run,map=camp();local keys=setmetatable({ruby=false,emerald=false,sapphire=false},{})
    run.keys=keys;token={};assert(not Nodes.recallSource(run,map))
    rejected(run,map,function()return Nodes.recall(run,map,token)end);assert(getmetatable(run.keys)~=nil)
end)

test('an owned Ruby hides Recall and cannot be acquired at a later camp',function()
    local run,map=camp();local token=source(run,map)
    assert(Nodes.recall(run,map,token));assert(run.keys.ruby)
    -- Stage navigation only to the next source camp; no played-room claim.
    run.nodeFlow=nil
    while true do
        local available=Map.available(map);assert(#available>0,'second camp missing')
        local target
        for _,node in ipairs(available)do if node.type=='camp' then target=node;break end end
        if target then assert(Nodes.enter(run,map,target.id));break end
        assert(Map.choose(map,available[1].id))
    end
    local nextToken={id=run.nodeFlow.id,roomGeneration=run.roomGeneration};assert(not Nodes.recallSource(run,map))
    assert(nextToken.roomGeneration==token.roomGeneration+1 and nextToken.id~=token.id)
    rejected(run,map,function()return Nodes.recall(run,map,token)end)
    rejected(run,map,function()return Nodes.recall(run,map,nextToken)end)
end)

test('a stale callback from a completed camp cannot Recall in a different pending camp',function()
    local run,map=camp();local stale=source(run,map);assert(Nodes.rest(run))
    -- Navigation-only staging again; both camps themselves use real entry.
    run.nodeFlow=nil
    while true do
        local available=Map.available(map);assert(#available>0,'second camp missing')
        local target
        for _,node in ipairs(available)do if node.type=='camp' then target=node;break end end
        if target then assert(Nodes.enter(run,map,target.id));break end
        assert(Map.choose(map,available[1].id))
    end
    local current=source(run,map)
    assert(current.roomGeneration==stale.roomGeneration+1 and current.id~=stale.id)
    assert(rejected(run,map,function()return Nodes.recall(run,map,stale)end)=='camp_source_mismatch')
    assert(Nodes.recall(run,map,current) and run.keys.ruby)
end)

test('phase pending choice and source-map mismatches never spend resources',function()
    local mutations={
        function(r)r.phase='map'end,function(r)r.phase='combat'end,function(r)r.nodeFlow.complete=true end,
        function(r)r.nodeFlow.type='event'end,function(r)r.nodeFlow.campChoice='rest'end,
        function(r)r.nodeFlow.campChoice='upgrade'end,function(r)r.roomGeneration=0 end,
        function(r)r.floor=r.floor+1 end,function(r)r.runSeed='43'end,
        function(_,m)m.currentNodeId='missing'end,function(_,m)m.sourceSignature='other'end,
        function(_,m)m.nodes[1]=false end,function(_,m)m.path[#m.path]='missing'end,
        function(r)r.nodeFlow.mapSeed=nil end,function(r)r.nodeFlow.mapSignature=nil end,
        function(r)r.nodeFlow.floor='15'end,function(r)r.act='1'end,
        function(r)r.nodeFlow=nil end,function(r)r.nodeFlow.complete=nil end,
    }
    for _,mutate in ipairs(mutations)do
        local run,map=camp();local token=source(run,map);mutate(run,map)
        assert(not Nodes.recallSource(run,map))
        rejected(run,map,function()return Nodes.recall(run,map,token)end)
    end
end)

test('missing malformed and altered source tokens refuse purely',function()
    local run,map=camp();local token=source(run,map)
    for _,bad in ipairs({false,1,'recall',{},setmetatable(C.copy(token),{})})do
        rejected(run,map,function()return Nodes.recall(run,map,bad)end)
    end
    rejected(run,map,function()return Nodes.recall(run,map)end)
    for key,value in pairs(token)do
        local bad=C.copy(token);bad[key]=type(value)=='number' and value+1 or 'other'
        rejected(run,map,function()return Nodes.recall(run,map,bad)end)
    end
end)

test('rest upgrade and pending Dream Catcher each consume the Recall opportunity',function()
    for _,choice in ipairs({'rest','upgrade'})do
        local run,map=camp({relics={'Regal Pillow'}});run.hp=10
        local token=source(run,map);local uid=run.deck[1].uid
        if choice=='rest' then assert(Nodes.rest(run)) else assert(Nodes.upgrade(run,uid))end
        assert(not run.keys.ruby and not Nodes.recallSource(run,map))
        rejected(run,map,function()return Nodes.recall(run,map,token)end)
    end
    for _,choice in ipairs({0,1})do
        local run,map=camp({relics={'Dream Catcher','CeramicFish'}});run.hp=10
        local token=source(run,map);assert(Nodes.rest(run))
        assert(run.phase=='node' and run.nodeFlow.restReward and not run.nodeFlow.restReward.resolved)
        rejected(run,map,function()return Nodes.recall(run,map,token)end)
        assert(Nodes.claimRestReward(run,choice));assert(not run.keys.ruby)
        rejected(run,map,function()return Nodes.recall(run,map,token)end)
    end
    local run,map=camp();local token=source(run,map)
    run.nodeFlow.restReward={cards={'anger'},resolved=false}
    rejected(run,map,function()return Nodes.recall(run,map,token)end)
end)

test('failure after staged room completion rolls back every Run and map owner',function()
    local run,map=camp();local token=source(run,map)
    local transaction=Run.transaction
    Run.transaction=function(owner,command)
        return transaction(owner,function(staged)
            local ok,detail=command(staged)
            if ok then
                assert(staged.keys.ruby and staged.nodeFlow.complete and staged.phase=='map')
                error('injected failure after room completion before commit')
            end
            return ok,detail
        end)
    end
    local called,why=pcall(rejected,run,map,function()return Nodes.recall(run,map,token)end)
    Run.transaction=transaction
    assert(called,tostring(why));assert(not run.keys.ruby)
    assert(Nodes.recall(run,map,token),'legitimate retry after rolled-back failure refused')
end)

test('source maps for later chapters retain the same existing eligibility contract',function()
    for _,act in ipairs({2,3,4})do
        local run,map=camp({act=act});local token=source(run,map)
        assert(token.act==act and map.act==act)
        local expected=copy(run);expected.keys.ruby=true;expected.phase='map'
        expected.nodeFlow.campChoice='recall';expected.nodeFlow.complete=true;expected.nodeFlow.result='recall'
        assert(Nodes.recall(run,map,token));same(run,expected)
    end
end)

test('other existing keys stay byte-identical for every boolean combination',function()
    for _,emerald in ipairs({false,true})do for _,sapphire in ipairs({false,true})do
        local run,map=camp();run.keys.emerald,run.keys.sapphire=emerald,sapphire
        local token=source(run,map);assert(Nodes.recall(run,map,token))
        same(run.keys,{ruby=true,emerald=emerald,sapphire=sapphire})
    end end
end)

print('RUBY_RECALL_PASS '..count)

assert(sliceRegistered==15,'all fifteen original Recall groups must register')
assert(sliceExecuted==sliceLast-sliceFirst+1,'every selected Recall group must execute')
print('RUBY_RECALL_SLICE '..sliceFirst..' '..sliceLast..' '..sliceExecuted)
