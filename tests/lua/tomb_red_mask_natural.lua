local F=dofile('tests/lua/support/tomb_red_mask_fixture.lua')
local vector=dofile('tests/fixtures/tomb-red-mask-vectors.lua').natural
local r,m,n=F.fixture(99,'14',true);local before=F.C.copy(r.unknown.pools)
local ok,why=F.Nodes.enter(r,m,n);assert(ok,why)
F.eq(r.nodeFlow.event.id,'tomb_red_mask');F.eq(r.nodeFlow.event.originalId,'Tomb of Lord Red Mask')
F.eq(r.eventRng.counter,1);F.eq(r.nodeFlow.selectionRng.counter,3);F.eq(r.miscRng.counter,0)
F.same(F.R.snapshot(r.eventRng),vector.eventRng);F.same(r.nodeFlow.selectionRng,vector.selectionRng);F.same(F.R.snapshot(r.miscRng),vector.miscRng)
F.eq(#r.unknown.pools.act,6);local remaining={};for _,id in ipairs(before.act)do if id~='Tomb of Lord Red Mask'then remaining[#remaining+1]=id end end
F.same(r.unknown.pools.act,remaining);F.same(r.unknown.pools.once,before.once);F.same(r.unknown.pools.shrine,before.shrine)
local relic=F.C.copy(r.relicPool);local misc=F.R.snapshot(r.miscRng)
assert(F.Nodes.chooseEvent(r,'pay'));F.eq(r.gold,0);F.eq(r.relics[#r.relics],'red_mask');F.eq(r.nodeFlow.event.stage,'result')
F.same(r.relicPool,relic);F.same(F.R.snapshot(r.miscRng),misc);assert(F.Nodes.chooseEvent(r,'leave'));F.eq(r.phase,'map')
print('TOMB_RED_MASK_NATURAL_PASS seed14 full seven-source entry/one removal, exact source counters, named SPECIAL obtain consumes no relic or misc RNG; room boundary not campaign clear')
