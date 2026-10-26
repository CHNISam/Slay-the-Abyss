local F=dofile('tests/lua/support/sensory_stone_fixture.lua');local v=dofile('tests/fixtures/sensory-stone-vectors.lua').natural
local r=F.Run.new(F.D,v.seed,{experimental=true,campaign=true});r.act,r.floor=3,34;r.encounters=F.Q.new(v.seed,3);r.unknown.pools=F.P.new('full',false,3)
local m=F.Map.generate(F.D,v.seed,3);local first=F.Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId=nil end end
local pool=F.C.copy(r.unknown.pools);assert(F.Nodes.enter(r,m,first.id));F.eq(r.nodeFlow.event.id,'sensory_stone');F.eq(r.nodeFlow.event.originalId,'SensoryStone')
local remaining={};for _,id in ipairs(pool.act)do if id~='SensoryStone'then remaining[#remaining+1]=id end end
F.same(r.unknown.pools.act,remaining);F.same(r.unknown.pools.shrine,pool.shrine);F.same(r.unknown.pools.once,pool.once)
F.same(F.R.snapshot(r.eventRng),v.eventRng);F.same(r.nodeFlow.selectionRng,v.selectionRng);F.eq(r.miscRng.counter,0);F.eq(r.cardRng.counter,0)
assert(F.Nodes.chooseEvent(r,'continue'));assert(F.Nodes.chooseEvent(r,'one'));F.eq(r.hp,r.maxHp)
assert(F.Nodes.chooseEvent(r,'proceed'));assert(F.Nodes.chooseEvent(r,'leave'));F.eq(r.phase,'map')
print('SENSORY_STONE_NATURAL_PASS full seven source pool/unfiltered eligibility/exact event streams/only selected removal and once preservation; room boundary, not campaign clear')
