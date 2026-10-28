-- Differential oracle is the exact pre-refactor Nodes module at 1f260a7.
-- Real Run/Map/content/transactions execute on both sides; no copied mock logic.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Current=require('abyss_nodes')
local Before=dofile('tests/nodes-governance-baseline.lua')
local Run,Map,Combat=require('abyss_run'),require('abyss_map'),require('abyss_combat')
local Data=require('abyss_data')
local External=require('abyss_external_random')
local Random=require('abyss_randomxs128')
local replay=Random.snapshot(Random.fromSeed('12345'))
local first,last=...
first,last=first or 1,last or 72
local count,registered=0,0
local function equalGraph(a,b,forward,reverse)
    assert(type(a)==type(b),'type mismatch')
    if type(a)~='table' then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
    forward,reverse=forward or {},reverse or {}
    if forward[a] then assert(forward[a]==b,'alias changed');return end
    assert(not reverse[b],'distinct owners collapsed')
    forward[a],reverse[b]=b,a
    assert(getmetatable(a)==getmetatable(b),'metatable changed')
    for key,value in pairs(a)do equalGraph(value,b[key],forward,reverse)end
    for key in pairs(b)do assert(a[key]~=nil,'unexpected key '..tostring(key))end
end
local function owners(run,map)
    return {run,run.deck,run.relics,run.keys,run.nodeFlow,map,map.path,run.data}
end
local function compare(label,fixture,command)
    registered=registered+1
    if registered<first or registered>last then return end
    local initial,map=fixture()
    local left,right=Combat.copy(initial),Combat.copy(initial)
    local lm,rm=Combat.copy(map),Combat.copy(map)
    local lo,ro=owners(left,lm),owners(right,rm)
    External.setReplayState(replay)
    local a=table.pack(pcall(command,Before,left,lm))
    local entropy=External.snapshot().words
    External.setReplayState(replay)
    local b=table.pack(pcall(command,Current,right,rm))
    equalGraph(a,b);equalGraph(left,right);equalGraph(lm,rm)
    equalGraph(entropy,External.snapshot().words)
    local la,ra=owners(left,lm),owners(right,rm)
    for i=1,8 do assert((lo[i]==la[i])==(ro[i]==ra[i]),'owner replacement changed: '..label)end
    count=count+1
    print('NODES_GOVERNANCE_CASE '..registered..' '..label)
end
local function fixture(kind,eventId,legacy)
    local run=Run.new(Data,'42',{experimental=true,campaign=true})
    local map=Map.generate(run.data,run.runSeed)
    local id=Map.available(map)[1].id
    for _,node in ipairs(map.nodes)do if node.id==id then node.type,node.eventId=kind,eventId end end
    if legacy then run.relicPool=nil end
    return run,map,id
end
local function entered(kind,eventId,legacy)
    local run,map,id=fixture(kind,eventId,legacy)
    External.setReplayState(replay)
    assert(Before.enter(run,map,id))
    return run,map
end
-- API keys and function arities form the existing adapter contract.
for key,value in pairs(Before)do
    assert(type(value)=='function' and type(Current[key])=='function','API removed: '..key)
    assert(debug.getinfo(value,'u').nparams==debug.getinfo(Current[key],'u').nparams,'arity changed: '..key)
end
for key in pairs(Current)do assert(Before[key],'API added: '..key)end
for _,kind in ipairs({'combat','camp','shop','treasure'})do
    for _,legacy in ipairs({false,true})do
        compare('enter '..kind,function()return fixture(kind,nil,legacy)end,function(N,r,m)
            return N.enter(r,m,Map.available(m)[1].id)
        end)
    end
end
for _,case in ipairs({{'cleric','heal'},{'cleric','purify'},{'purifier','pray'},
    {'goop','gather'},{'goop','leave'},{'upgrade_shrine','upgrade'},
    {'golden_shrine','pray'},{'golden_shrine','desecrate'},
    {'shining_light','accept'},{'golden_wing','sacrifice'},
    {'golden_wing','take_gold'},{'living_wall','forget'},{'fountain','cleanse'}})do
    for _,choice in ipairs({case[2],'leave','invalid'})do
        compare(case[1]..choice,function()return entered('event',case[1])end,function(N,r,m)
            local preview=N.view(r,m)
            local result=table.pack(N.chooseEvent(r,choice,r.deck[1].uid))
            return preview,result
        end)
    end
end
for _,command in ipairs({'rest','upgrade','claimRestReward','recallSource'})do
    compare('camp '..command,function()return entered('camp')end,function(N,r,m)
        if command=='recallSource'then return N[command](r,m)end
        return N[command](r,r.deck[1].uid)
    end)
end
for _,mutation in ipairs({'phase','generation','mapSeed','pending','content'})do
    compare('entry refusal '..mutation,function()
        local r,m=fixture('camp')
        if mutation=='phase'then r.phase='defeat'
        elseif mutation=='generation'then r.roomGeneration=-1
        elseif mutation=='mapSeed'then m.runSeed='999'
        elseif mutation=='pending'then r.nodeFlow={complete=false}
        else r.data=Combat.copy(r.data);r.data.rules.camp=nil end
        return r,m
    end,function(N,r,m)return N.enter(r,m,Map.available(m)[1].id)end)
end
for _,legacy in ipairs({false,true})do
    for _,command in ipairs({'openTreasure','claimTreasure','leaveTreasure','treasureSource','treasureRewardSource'})do
        compare('treasure '..command,function()return entered('treasure',nil,legacy)end,function(N,r,m)
            if command=='treasureSource'then return N[command](r,m)end
            return N[command](r,1)
        end)
    end
end
for _,outcome in ipairs({'victory','escaped','defeat','reward'})do
    compare('combat settlement '..outcome,function()
        local r,m=entered('combat')
        r.phase=(outcome=='victory' or outcome=='escaped')and'map'or outcome
        r.lastResult={outcome=outcome,encounterId=r.nodeFlow.encounterId}
        return r,m
    end,function(N,r,m)return N.completeCombat(r,m)end)
end
for _,act in ipairs({1,2})do
    compare('boss act '..act,function()
        local r,m=fixture('treasure',nil,true)
        r.campaignProfile='competition-two-act'
        r.act=act;r.floor=act==1 and 17 or 34
        r.phase='node';r.nodeFlow={type='treasure',roomKind='boss_treasure',floor=r.floor,
            mapSeed=m.seed,mapSignature=m.sourceSignature,id=m.currentNodeId,reward={relics={}},complete=false}
        m.act=act;m.floor=r.floor
        return r,m
    end,function(N,r,m)
        local result=table.pack(N.claimBossTreasure(r,0))
        assert(result[1] and result[2]=='boss_treasure_complete','Boss settlement did not execute')
        if act==1 then
            local advanced=table.pack(N.advanceAct(r,m))
            assert(advanced[1] and r.act==2 and m.act==2 and r.phase=='map','Act 1 did not continue into Act 2')
            return result,advanced
        end
        assert(r.phase=='victory' and r.pendingAct==nil and r.ending=='two_act_complete','Act 2 did not settle')
        return result
    end)
end
assert(registered==72 and count==last-first+1,'missing differential scenario')
print('NODES_GOVERNANCE_PASS '..first..' '..last..' '..count..'; API keys/arity, returns, graph aliases, owner identity and entropy match')
