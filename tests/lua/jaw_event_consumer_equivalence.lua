package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,data=require('abyss_combat'),require('abyss_data')
local consumer=dofile('tests/lua/support/jaw_event_consumer.lua')
local function same(a,b,seen)
    assert(type(a)==type(b),'type mismatch')
    if type(a)~='table'then assert(a==b,'value mismatch');return end
    seen=seen or {};if seen[a]then assert(seen[a]==b,'alias mismatch');return end;seen[a]=b
    for k,v in pairs(a)do same(v,b[k],seen)end
    for k in pairs(b)do assert(a[k]~=nil,'extra field')end
end
for _,seed in ipairs({0,15})do
    local options={enemies={'jaw_worm','jaw_worm'},deck={'defend'},seed=seed}
    local retained,drained=C.new(data,options),C.new(data,options)
    for _=1,4 do
        local before=#retained.events
        for _,state in ipairs({retained,drained})do
            state.player.hp=80;state.player.block=999;C.addStatus(state.player,'barricade',1)
            assert(C.endTurn(state))
        end
        -- No gameplay field or per-turn event is omitted from the comparison.
        local a,b=retained.events,drained.events
        local offset=before
        if _==1 then offset=0 end
        assert(#a-offset==#b,'same complete turn event count')
        for i,event in ipairs(b)do same(a[offset+i],event)end
        for k,v in pairs(retained)do if k~='events'then same(v,drained[k])end end
        for k in pairs(drained)do assert(retained[k]~=nil,'extra state field')end
        local identity=drained.events;assert(consumer.consume(drained)==#a-offset)
        assert(drained.events==identity and #identity==0,'in-place complete acknowledgement')
    end
end
local malformed={phase='player',events={{kind='broken',detail={}}}}
assert(not pcall(consumer.consume,malformed));assert(#malformed.events==1,'failed validation retains the batch')
print('LUA_JAW_EVENT_CONSUMER_EQUIVALENCE_PASS 2 seeds 4 rounds all fields and events')
