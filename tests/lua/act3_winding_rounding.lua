local F=dofile('tests/lua/support/act3_winding_fixture.lua')
local fixture,eq,Nodes=F.fixture,F.eq,F.Nodes
do local r,m,n=fixture(1,1);assert(Nodes.enter(r,m,n));local e=r.nodeFlow.event;eq(e.hpDamage,0);eq(e.healAmount,0);eq(e.maxHpLoss,0)end
do local r,m,n=fixture(1,4);assert(Nodes.enter(r,m,n));local e=r.nodeFlow.event;eq(e.hpDamage,1);eq(e.healAmount,1);eq(e.maxHpLoss,0)end
do local r,m,n=fixture(1,9);assert(Nodes.enter(r,m,n));local e=r.nodeFlow.event;eq(e.hpDamage,1);eq(e.healAmount,2);eq(e.maxHpLoss,0)end
do local r,m,n=fixture(1,10);assert(Nodes.enter(r,m,n));local e=r.nodeFlow.event;eq(e.hpDamage,1);eq(e.healAmount,3);eq(e.maxHpLoss,1)end
do local r,m,n=fixture(1,11);assert(Nodes.enter(r,m,n));local e=r.nodeFlow.event;eq(e.hpDamage,1);eq(e.healAmount,3);eq(e.maxHpLoss,1)end
do local r,m,n=fixture(1,12);assert(Nodes.enter(r,m,n));local e=r.nodeFlow.event;eq(e.hpDamage,2);eq(e.healAmount,3);eq(e.maxHpLoss,1)end
do local r,m,n=fixture(1,20);assert(Nodes.enter(r,m,n));local e=r.nodeFlow.event;eq(e.hpDamage,3);eq(e.healAmount,5);eq(e.maxHpLoss,1)end
do local r,m,n=fixture(1,80);assert(Nodes.enter(r,m,n));local e=r.nodeFlow.event;eq(e.hpDamage,10);eq(e.healAmount,20);eq(e.maxHpLoss,4)end
do local r,m,n=fixture(1,16777219);assert(Nodes.enter(r,m,n));local e=r.nodeFlow.event;eq(e.hpDamage,2097153);eq(e.healAmount,4194305);eq(e.maxHpLoss,838861)end
do local r,m,n=fixture(1,2147483647);assert(Nodes.enter(r,m,n));local e=r.nodeFlow.event;eq(e.hpDamage,268435456);eq(e.healAmount,536870912);eq(e.maxHpLoss,107374184)end
local r,m,n=fixture(1,1);assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));assert(Nodes.chooseEvent(r,'max_hp'));eq(r.hp,1);eq(r.maxHp,1)
print('ACT3_WINDING_ROUNDING_PASS independent Java float/round three ratios and min-one no-heal boundary')
