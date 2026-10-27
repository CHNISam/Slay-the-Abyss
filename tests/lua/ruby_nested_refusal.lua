-- Regression for the newly discovered ignored-nested-Recall refusal. The
-- preceding route/history is staged; Recall itself uses the public command.
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local C,Data=require('abyss_combat'),require('abyss_data')
local count=0
local function same(a,b,seen)
    if a==b then return end
    assert(type(a)==type(b),'type mismatch')
    if type(a)~='table' then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
    seen=seen or {};if seen[a] then assert(seen[a]==b,'alias mismatch');return end;seen[a]=b
    for key,value in pairs(a)do same(value,b[key],seen)end
    for key in pairs(b)do assert(a[key]~=nil,'unexpected '..tostring(key))end
end
local function identities(root)
    local refs,seen={},{}
    local function visit(owner)
        if seen[owner] then return end;seen[owner]=true
        for key,value in pairs(owner)do if type(value)=='table' then
            refs[#refs+1]={owner=owner,key=key,value=value};visit(value)
        end end
    end
    visit(root);return refs
end
local readyMap,campId
local function camp()
    if not readyMap then
        readyMap=Map.generate(Data,'42')
        while not campId do
            local available=Map.available(readyMap);assert(#available>0,'camp route missing')
            for _,node in ipairs(available)do if node.type=='camp' then campId=node.id;break end end
            if not campId then assert(Map.choose(readyMap,available[1].id))end
        end
    end
    local run=Run.new(Data,'42',{experimental=true,campaign=true});run.endingUnlocked=true
    local map=C.copy(readyMap);assert(Nodes.enter(run,map,campId))
    return run,map,assert(Nodes.recallSource(run,map))
end
local function rejected(run,map,command,reason)
    local before,mapBefore=C.copy(run),C.copy(map);local runRefs,mapRefs=identities(run),identities(map)
    local called,ok,why=pcall(command);assert(called,'refusal threw: '..tostring(ok))
    assert(ok==false and why==reason,'wrong refusal: '..tostring(why))
    same(run,before);same(map,mapBefore)
    for _,refs in ipairs({runRefs,mapRefs})do for _,ref in ipairs(refs)do
        assert(ref.owner[ref.key]==ref.value,'refusal replaced original table '..tostring(ref.key))
    end end
end
local function test(name,fn)fn();count=count+1;print('ok Ruby nested refusal '..count..' - '..name)end

test('ignored stale/history/metatable/invalid-token child refusals roll back real gold/card changes',function()
    local cases={
        {reason='camp_source_mismatch',mutate=function(_,token)token.roomGeneration=token.roomGeneration+1;return token end},
        {reason='ending_history_required',mutate=function(r,token)r.endingUnlocked=false;return token end},
        {reason='invalid_keys',mutate=function(r,token)r.keys=setmetatable(r.keys,{});return token end},
        {reason='camp_source_mismatch',mutate=function()return false end},
        {reason='camp_source_mismatch',mutate=function(_,token)return setmetatable(token,{})end},
    }
    for _,case in ipairs(cases)do
        local run,map,token=camp();local childCalled=false
        rejected(run,map,function()
            return Run.transaction(run,function(staged)
                assert(Run.gainGold(staged,91)==91)
                assert(Run.obtainCard(staged,'anger'))
                assert(staged.gold==run.gold+91 and #staged.deck==#run.deck+1)
                local bad=case.mutate(staged,token)
                local ok,why=Nodes.recall(staged,map,bad)
                assert(ok==false and why==case.reason,'intended child refusal missing');childCalled=true
                return true -- Parent deliberately forgets to return child failure.
            end)
        end,case.reason)
        assert(childCalled and not run.keys.ruby and run.nodeFlow.complete==false)
        assert(Nodes.recall(run,map,assert(Nodes.recallSource(run,map))),'rolled-back refusal lost valid camp')
    end
end)

test('top-level plain-owner preflight reasons stay pure before graph-copy normalization',function()
    local run,map,token=camp();run.keys=setmetatable(run.keys,{})
    rejected(run,map,function()return Nodes.recall(run,map,token)end,'invalid_keys')
    assert(getmetatable(run.keys)~=nil,'original invalid key owner normalized')
    run,map,token=camp();token.roomGeneration=token.roomGeneration+1
    rejected(run,map,function()return Nodes.recall(run,map,token)end,'camp_source_mismatch')
    run,map,token=camp();run.endingUnlocked=false
    rejected(run,map,function()return Nodes.recall(run,map,token)end,'ending_history_required')
end)

test('legitimate nested Recall still commits prior real changes and grants only Ruby',function()
    local run,map,token=camp();local gold,deckSize=run.gold,#run.deck
    assert(Run.transaction(run,function(staged)
        assert(Run.gainGold(staged,91)==91);assert(Run.obtainCard(staged,'anger'))
        return Nodes.recall(staged,map,token)
    end))
    assert(run.gold==gold+91 and #run.deck==deckSize+1)
    assert(run.keys.ruby and not run.keys.emerald and not run.keys.sapphire)
    assert(run.nodeFlow.complete and run.nodeFlow.campChoice=='recall' and run.phase=='map')
end)

print('RUBY_NESTED_REFUSAL_PASS '..count)
