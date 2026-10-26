local F=dofile('tests/lua/support/act3_winding_fixture.lua')
local Run,Map,Nodes,C,P,Q,R,D,eq=F.Run,F.Map,F.Nodes,F.C,F.P,F.Q,F.R,F.D,F.eq
local r=Run.new(D,'11',{experimental=true,campaign=true});local m=Map.generate(D,'11',3)
r.act,r.floor=3,34;r.encounters=Q.new(r.runSeed,3);r.unknown.pools=P.new('full',false,3)
local original=C.copy(r.unknown.pools);local first=Map.available(m)[1]
for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId=nil end end
assert(Nodes.enter(r,m,first.id));eq(r.nodeFlow.event.id,'winding_halls');eq(r.nodeFlow.event.originalId,'Winding Halls')
eq(#r.unknown.pools.act,6);for i,id in ipairs(r.unknown.pools.act)do eq(id,original.act[i])end
for _,kind in ipairs({'shrine','once'})do eq(#r.unknown.pools[kind],#original[kind]);for i,id in ipairs(original[kind])do eq(r.unknown.pools[kind][i],id)end end
local snap=R.snapshot(r.eventRng);eq(snap.counter,1);eq(snap.words[1],'5681a0b732533a20');eq(snap.words[2],'f997a3117bf204c2')
local snap=r.nodeFlow.selectionRng;eq(snap.counter,3);eq(snap.words[1],'f48f2c8978dceb95');eq(snap.words[2],'85a54e326cec4070')
local snap=R.snapshot(r.miscRng);eq(snap.counter,0);eq(snap.words[1],'9c3fe26fde390827');eq(snap.words[2],'501473c0ac338ea0')
assert(Nodes.chooseEvent(r,'continue'));assert(Nodes.chooseEvent(r,'madness'));assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
print('ACT3_WINDING_NATURAL_PASS seed11 unfiltered full pool, exact single removal/once history and independent full RNG words')
