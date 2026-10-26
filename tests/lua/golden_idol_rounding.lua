local F=dofile('tests/lua/support/golden_idol_fixture.lua')
do local r,m,n=F.fixture(1,1);assert(F.Nodes.enter(r,m,n));F.eq(r.nodeFlow.event.damage,0);F.eq(r.nodeFlow.event.maxHpLoss,1)end
do local r,m,n=F.fixture(1,3);assert(F.Nodes.enter(r,m,n));F.eq(r.nodeFlow.event.damage,0);F.eq(r.nodeFlow.event.maxHpLoss,1)end
do local r,m,n=F.fixture(1,6);assert(F.Nodes.enter(r,m,n));F.eq(r.nodeFlow.event.damage,1);F.eq(r.nodeFlow.event.maxHpLoss,1)end
do local r,m,n=F.fixture(1,7);assert(F.Nodes.enter(r,m,n));F.eq(r.nodeFlow.event.damage,1);F.eq(r.nodeFlow.event.maxHpLoss,1)end
do local r,m,n=F.fixture(1,12);assert(F.Nodes.enter(r,m,n));F.eq(r.nodeFlow.event.damage,3);F.eq(r.nodeFlow.event.maxHpLoss,1)end
do local r,m,n=F.fixture(1,13);assert(F.Nodes.enter(r,m,n));F.eq(r.nodeFlow.event.damage,3);F.eq(r.nodeFlow.event.maxHpLoss,1)end
do local r,m,n=F.fixture(1,39);assert(F.Nodes.enter(r,m,n));F.eq(r.nodeFlow.event.damage,9);F.eq(r.nodeFlow.event.maxHpLoss,3)end
do local r,m,n=F.fixture(1,80);assert(F.Nodes.enter(r,m,n));F.eq(r.nodeFlow.event.damage,20);F.eq(r.nodeFlow.event.maxHpLoss,6)end
do local r,m,n=F.fixture(1,89);assert(F.Nodes.enter(r,m,n));F.eq(r.nodeFlow.event.damage,22);F.eq(r.nodeFlow.event.maxHpLoss,7)end
do local r,m,n=F.fixture(1,16777219);assert(F.Nodes.enter(r,m,n));F.eq(r.nodeFlow.event.damage,4194305);F.eq(r.nodeFlow.event.maxHpLoss,1342177)end
do local r,m,n=F.fixture(1,2147483647);assert(F.Nodes.enter(r,m,n));F.eq(r.nodeFlow.event.damage,536870912);F.eq(r.nodeFlow.event.maxHpLoss,171798688)end
print('GOLDEN_IDOL_ROUNDING_PASS independent IEEE32 truncation for cached .25/.08 costs including minimum-one and large int boundaries')
