-- Queue checkpoint boundaries only. Campaign terminal positions are fixtures,
-- not evidence that the later chapters have been played or implemented.
local Run=require('abyss_run')
local Nodes=require('abyss_nodes')
local Map=require('abyss_map')
local Data=require('abyss_data')
local Combat=require('abyss_combat')
local Queue=require('abyss_encounter_queue')
local count=0
local function same(a,b,path)
    path=path or 'state';assert(type(a)==type(b),path)
    if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
    for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
    for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function test(name,fn)fn();count=count+1;print('ok checkpoint chapter boundary '..count..' - '..name)end
local function laterAct(target)
    local run=Run.new(Data,'42',{experimental=true,campaign=true})
    local map=Map.generate(Data,run.runSeed)
    for _=1,target-1 do
        while #Map.available(map)>0 do assert(Map.choose(map,Map.available(map)[1].id))end
        run.phase,run.floor='node',map.floor
        run.nodeFlow={id=map.currentNodeId,floor=map.floor,type='treasure',roomKind='boss_treasure',
            mapSeed=map.seed,mapSignature=map.sourceSignature,complete=false,reward={relics={}}}
        assert(Nodes.claimBossTreasure(run,0) and Nodes.advanceAct(run,map))
    end
    return run
end
local function rejected(run,snapshot,reason)
    local before=Combat.copy({run=run,snapshot=snapshot})
    local owner=run.encounters
    local ok,why=Run.restoreEncounters(run,snapshot)
    assert(not ok,'current act accepted a foreign-act checkpoint queue')
    if reason then assert(why==reason,tostring(why))end
    same({run=run,snapshot=snapshot},before);assert(run.encounters==owner)
end

test('equal-length valid foreign chapter queues cannot cross the current boundary',function()
    for _,act in ipairs({2,3})do
        local run=laterAct(act)
        local snapshot=Run.snapshotEncounters(run)
        snapshot.queue=Queue.snapshot(Queue.new(run.runSeed,act==2 and 3 or 2))
        assert(snapshot.queue.rawSeed==run.runSeed and #snapshot.queue.normal==#run.encounters.normal
            and #snapshot.queue.elite==#run.encounters.elite)
        assert(Queue.restore(snapshot.queue),'foreign queue must itself be valid')
        rejected(run,snapshot,'encounter_act_mismatch')
        assert(Run.restoreEncounters(run,Run.snapshotEncounters(run)))
    end
end)

test('default and explicit first-act legacy queues still restore without adding an act field',function()
    for _,options in ipairs({false,{experimental=true,campaign=true}})do
        local run=Run.new(Data,'42',options or nil)
        local snapshot=Run.snapshotEncounters(run)
        assert(snapshot.version==2 and snapshot.queue.version==1 and snapshot.queue.act==nil)
        assert(Run.restoreEncounters(run,snapshot))
        same(Run.snapshotEncounters(run),snapshot)
        assert(run.encounters.act==nil)
        -- Match the later queue's 15-entry length to isolate act identity from
        -- the existing progress-length rejection.
        table.remove(run.encounters.normal,1)
        snapshot=Run.snapshotEncounters(run)
        snapshot.queue=Queue.snapshot(Queue.new(run.runSeed,2))
        rejected(run,snapshot,'encounter_act_mismatch')
    end
end)

test('current later-act restore is detached and retains seed/floor/generation/progress guards',function()
    local run=laterAct(2)
    local original=Run.snapshotEncounters(run)
    local snapshot=Combat.copy(original)
    assert(Run.restoreEncounters(run,snapshot));assert(run.encounters~=snapshot.queue)
    snapshot.queue.normal[1]='foreign';same(Run.snapshotEncounters(run),original)
    for _,change in ipairs({
        function(s)s.runSeed='43'end,
        function(s)s.floor=s.floor+1 end,
        function(s)s.roomGeneration=s.roomGeneration+1 end,
        function(s)table.remove(s.queue.normal,1)end,
        function(s)s.queue.rawSeed='43'end,
    })do
        local bad=Combat.copy(original);change(bad);rejected(run,bad)
    end
end)
print('CROSS_ACT_CHECKPOINT_PASS '..count)
