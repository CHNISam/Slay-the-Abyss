local F=dofile('tests/lua/support/mushrooms_fixture.lua')
local r,m,id=F.fixture('35');for _,node in ipairs(m.nodes)do if node.id==id then node.eventId=nil end end
local before=F.C.copy(r.unknown.pools);assert(F.N.enter(r,m,id));F.eq(r.nodeFlow.event.id,'mushrooms');F.eq(r.nodeFlow.event.originalId,'Mushrooms')
local remaining={};for _,event in ipairs(before.act)do if event~='Mushrooms'then remaining[#remaining+1]=event end end
F.same(r.unknown.pools.act,remaining);F.same(r.unknown.pools.shrine,before.shrine);F.same(r.unknown.pools.once,before.once)
F.eq(r.eventRng.counter,1);F.eq(r.nodeFlow.selectionRng.counter,3)
assert(F.N.chooseEvent(r,'heal'));assert(F.N.chooseEvent(r,'leave'));F.eq(r.phase,'map')
local Pool=require('abyss_event_pool');assert(not Pool.isEligible('Mushrooms',{floor=6}));assert(Pool.isEligible('Mushrooms',{floor=7}))
print('MUSHROOMS_NATURAL_ROOM_PASS seed35 unfiltered source pool/removal/qualification; controlled room boundary not campaign clear')
