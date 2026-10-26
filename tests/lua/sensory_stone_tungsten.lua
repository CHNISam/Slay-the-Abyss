local F=dofile('tests/lua/support/sensory_stone_fixture.lua')
for _,row in ipairs({{'two',5,4},{'three',10,9}})do
 local r,m,n=F.fixture();assert(F.Run.obtainRelic(r,'tungsten_rod'));assert(F.Nodes.enter(r,m,n));assert(F.Nodes.chooseEvent(r,'continue'))
 local hp=r.hp;assert(F.Nodes.chooseEvent(r,row[1]));F.eq(r.nodeFlow.event.hpLoss,row[2]);F.eq(r.hp,hp-row[3])
end
for _,fairy in ipairs({false,true})do
 local r,m,n=F.fixture(5);assert(F.Run.obtainRelic(r,'tungsten_rod'))
 if fairy then assert(F.Run.obtainPotion(r,'fairy_in_a_bottle'))end
 assert(F.Nodes.enter(r,m,n));assert(F.Nodes.chooseEvent(r,'continue'));assert(F.Nodes.chooseEvent(r,'two'));F.eq(r.hp,1);F.eq(r.phase,'node')
 if fairy then F.eq(r.potions[1],'fairy_in_a_bottle')end
end
local r,m,n=F.fixture(1);assert(F.Run.obtainRelic(r,'tungsten_rod'));assert(F.Run.obtainPotion(r,'fairy_in_a_bottle'));assert(F.Nodes.enter(r,m,n));assert(F.Nodes.chooseEvent(r,'continue'));assert(F.Nodes.chooseEvent(r,'three'));F.eq(r.hp,24);F.eq(r.potions[1],nil);F.eq(#r.nodeFlow.event.rewards,3)
print('SENSORY_STONE_TUNGSTEN_PASS actual ff01 Rod definition/obtain and shared HP_LOSS4/9, survival keeps Fairy, fatal still revives after all offers')
