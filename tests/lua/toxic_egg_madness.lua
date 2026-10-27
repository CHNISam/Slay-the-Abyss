local F=dofile('tests/lua/support/act3_winding_fixture.lua');local Run,Nodes=F.Run,F.Nodes
local r,m,n=F.fixture();assert(Run.obtainRelic(r,'Toxic Egg 2'));assert(Run.obtainRelic(r,'CeramicFish'))
assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));local gold,uid=r.gold,r.nextDeckUid;local rng=F.C.copy(r.cardRng)
assert(Nodes.chooseEvent(r,'madness'));F.eq(r.nextDeckUid,uid+2);F.eq(r.gold,gold+18);F.same(r.cardRng,rng)
for i=#r.deck-1,#r.deck do F.eq(r.deck[i].cardId,'madness');F.eq(r.deck[i].uid,uid+i-(#r.deck-1));F.eq(r.deck[i].upgraded,true);F.eq(r.deck[i].upgrades,1)end
assert(Nodes.chooseEvent(r,'leave'));F.eq(r.phase,'map')
print('TOXIC_EGG_MADNESS_PASS Winding shared permanent obtain produces two distinct upgraded Madness UIDs without extra RNG or preview gold')
