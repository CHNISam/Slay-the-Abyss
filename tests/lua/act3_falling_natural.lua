package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Map,Nodes,Pool,C=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_event_pool'),require('abyss_combat')
local D=require('abyss_data')
local r=Run.new(D,'8',{experimental=true,campaign=true});local m=Map.generate(D,'8',3)
r.act,r.floor=3,34;r.encounters=require('abyss_encounter_queue').new(r.runSeed,3);r.unknown.pools=Pool.new('full',false,3)
local original=C.copy(r.unknown.pools);local first=Map.available(m)[1]
for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId=nil end end
assert(Nodes.enter(r,m,first.id));assert(r.nodeFlow.event.id=='falling');assert(r.nodeFlow.event.originalId=='Falling')
local R=require('abyss_sts_random');local eventRng=R.snapshot(r.eventRng)
assert(eventRng.counter==1 and eventRng.words[1]=='68ecf1cacb69f37b' and eventRng.words[2]=='7c8ee6a72ed52f5f')
local selection=r.nodeFlow.selectionRng
assert(selection.counter==3 and selection.words[1]=='f107e54fd91cce9b' and selection.words[2]=='de1e7ecfdfa8f298')
assert(#r.unknown.pools.act==6);for i,id in ipairs(r.unknown.pools.act)do assert(id==original.act[i+1])end
assert(#r.unknown.pools.shrine==#original.shrine and #r.unknown.pools.once==#original.once)
assert(Nodes.chooseEvent(r,'continue'));assert(Nodes.chooseEvent(r,'skill'));assert(Nodes.chooseEvent(r,'leave'));assert(r.phase=='map')
print('ACT3_FALLING_NATURAL_PASS seed8 unfiltered full source pool, exact one removal and public settlement')
