package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local R = require('abyss_sts_random')
local Run, Map, Nodes, C, data
local function same(a,b)
    if type(a)~='table' then assert(a==b,tostring(a)..' ~= '..tostring(b)); return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil,'extra '..tostring(k)) end
end
local function runtime()
    C=C or require('abyss_combat');data=data or require('abyss_data')
    Run=Run or require('abyss_run');Map=Map or require('abyss_map');Nodes=Nodes or require('abyss_nodes')
end

local function verify(types,events)
    assert(types.combat and types.shop and types.treasure and types.event)
    local count=0;for _ in pairs(events) do count=count+1 end;assert(count==7,'all seven events must be reachable across seeds')
end

local function run(firstSeed,lastSeed)
    runtime()
    -- Two disjoint110-seed fixtures retain all220 real Run seeds and every
    -- per-seed assertion. Each half also proves all four routes/seven events.
    -- Topology is fixed; per-seed source topology belongs to the map fixtures.
    local routingMap=dofile('tests/lua/support/unknown_event_routing_map.lua')
    local types,events={},{}
    for seed=firstSeed,lastSeed do
        local run=Run.new(data,seed)
        local map,id=routingMap.new(data,run)
        assert(Nodes.enter(run,map,id));local kind=run.nodeFlow.type;types[kind]=true
        if kind=='event' then events[run.nodeFlow.event.id]=true end
        assert(map.nodes[1].type=='event' and run.nodeFlow.sourceType=='event')
        local state=C.copy(run.unknown)
        local eventRng,miscRng=R.snapshot(run.eventRng),R.snapshot(run.miscRng)
        Nodes.view(run,map);Nodes.view(run,map);same(run.unknown,state)
        same(R.snapshot(run.eventRng),eventRng);same(R.snapshot(run.miscRng),miscRng)
        assert(not Nodes.enter(run,map,id));same(run.unknown,state)
        same(R.snapshot(run.eventRng),eventRng);same(R.snapshot(run.miscRng),miscRng)
        print('ROUTING_SEED '..seed..' '..kind..' '..(kind=='event' and run.nodeFlow.event.id or '-'))
    end
    return types,events
end

return {run=run,verify=verify}
