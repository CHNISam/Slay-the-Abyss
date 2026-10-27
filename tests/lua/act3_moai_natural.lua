package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Map,Nodes,P,C,R=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_event_pool'),require('abyss_combat'),require('abyss_sts_random')
local D=require('abyss_data')
local r=Run.new(D,'32',{experimental=true,campaign=true});local m=Map.generate(D,'32',3)
r.act,r.floor=3,34;r.encounters=require('abyss_encounter_queue').new(r.runSeed,3);r.unknown.pools=P.new('full',false,3)
local original=C.copy(r.unknown.pools);local first=Map.available(m)[1]
for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId=nil end end
assert(r.hp==r.maxHp);assert(Nodes.enter(r,m,first.id));assert(r.nodeFlow.event.id=='moai_head');assert(r.nodeFlow.event.originalId=='The Moai Head')
local expected={'Falling','MindBloom','Mysterious Sphere','SensoryStone','Tomb of Lord Red Mask','Winding Halls'}
assert(#r.unknown.pools.act==6);for i,id in ipairs(expected)do assert(r.unknown.pools.act[i]==id)end
for _,kind in ipairs({'shrine','once'})do for i,id in ipairs(original[kind])do assert(r.unknown.pools[kind][i]==id)end;assert(#r.unknown.pools[kind]==#original[kind])end
local room=R.snapshot(r.miscRng);assert(room.counter==0 and room.words[1]=='297b44a673fb0841' and room.words[2]=='a7435b3cded0370f')
local er=R.snapshot(r.eventRng);assert(er.counter==1 and er.words[1]=='1cca48eb804a9c6a' and er.words[2]=='575093616d9669c0')
local selection=r.nodeFlow.selectionRng;assert(selection.counter==3 and selection.words[1]=='3e5aca543a2af754' and selection.words[2]=='d9bce1fd0d24cd51')
assert(Nodes.chooseEvent(r,'heal'));assert(r.maxHp==70 and r.hp==70);assert(R.snapshot(r.miscRng).counter==0)
assert(Nodes.chooseEvent(r,'leave'));assert(r.phase=='map')
print('ACT3_MOAI_NATURAL_PASS seed32 full-HP unfiltered source pool, exact one removal, once history, no event-body RNG and public settlement')
