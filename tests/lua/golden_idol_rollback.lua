local F=dofile('tests/lua/support/golden_idol_fixture.lua')
local fixture,eq,same,Run,Map,Nodes,C,R,P,D=F.fixture,F.eq,F.same,F.Run,F.Map,F.Nodes,F.C,F.R,F.P,F.D
for _,stage in ipairs({'take','injury','damage'})do for _,failure in ipairs({'return','throw'})do
 local r,m,n=fixture(1);assert(Nodes.enter(r,m,n));if stage~='take'then assert(Nodes.chooseEvent(r,'take'))end
 local b,bm=C.copy(r),C.copy(m);local key=stage=='take'and'obtainRelic'or stage=='injury'and'obtainCard'or'eventNormalDamage';local fn=Run[key]
 Run[key]=function(...)local ok,why=fn(...);assert(ok);if failure=='throw'then error('Golden late failure')end;return false,'late_golden_failure'end
 local called,ok=pcall(Nodes.chooseEvent,r,stage);Run[key]=fn;assert(called);eq(ok,false);same(r,b);same(m,bm)
end end
for _,choice in ipairs({'injury','damage','max_hp'})do local r,m,n=fixture();assert(Nodes.enter(r,m,n));local b=C.copy(r);eq(Nodes.chooseEvent(r,choice),false);same(r,b);assert(Nodes.chooseEvent(r,'take'));b=C.copy(r);eq(Nodes.chooseEvent(r,choice,999),false);same(r,b)end
for _,kind in ipairs({'relic','card'})do
 local r,m,n=fixture(1);assert(Nodes.enter(r,m,n));if kind=='card'then assert(Nodes.chooseEvent(r,'take'))end
 local list=kind=='relic'and r.data.relics.relics or r.data.cards.cards;local id=kind=='relic'and'golden_idol'or'injury'
 for i=#list,1,-1 do if list[i].id==id then table.remove(list,i)end end
 local b,bm=C.copy(r),C.copy(m);eq(Nodes.chooseEvent(r,kind=='relic'and'take'or'injury'),false);same(r,b);same(m,bm)
end
for _,values in ipairs({{0,80},{81,80},{1,0},{1,2147483648}})do
 local r,m,n=fixture();assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'take'));r.hp,r.maxHp=values[1],values[2]
 local before=C.copy(r);eq(Nodes.chooseEvent(r,'max_hp'),false);same(r,before)
end
do
 local r,m,n=fixture();assert(Run.obtainRelic(r,'golden_idol'));assert(Nodes.enter(r,m,n))
 for i=#r.data.relics.relics,1,-1 do if r.data.relics.relics[i].id=='circlet'then table.remove(r.data.relics.relics,i)end end
 local before=C.copy(r);eq(Nodes.chooseEvent(r,'take'),false);same(r,before)
end
print('GOLDEN_IDOL_ROLLBACK_PASS actual obtain/curse/fatal-damage late failures preserve stage owner and RNG; wrong stage/UID/missing definition atomic')
