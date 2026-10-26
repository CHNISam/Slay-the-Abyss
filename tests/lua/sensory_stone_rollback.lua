local F=dofile('tests/lua/support/sensory_stone_fixture.lua');local Nodes,Run=F.Nodes,F.Run
for _,which in ipairs({'eventDamage','obtainCard'})do for _,failure in ipairs({'throw','reject'})do
 local r,m,n=F.fixture(1);assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'))
 if which=='obtainCard'then assert(Nodes.chooseEvent(r,'one'));assert(Nodes.chooseEvent(r,'open_1'))end
 local before,bmap=F.C.copy(r),F.C.copy(m);local flow,rng,potions=r.nodeFlow,r.cardRng,r.potions;local original=Run[which];local reached=false
 Run[which]=function(...)
  local ok=original(...);assert(ok);reached=true
  if failure=='throw'then error('SENSORY_LATE_FAILURE')end;return false,'SENSORY_LATE_REJECT'
 end
 local called,ok=pcall(Nodes.chooseEvent,r,which=='eventDamage'and'three'or'take_1_1');Run[which]=original
 assert(called and not ok and reached);F.same(r,before);F.same(m,bmap);F.eq(r.nodeFlow,flow);F.eq(r.cardRng,rng);F.eq(r.potions,potions)
 assert(Nodes.chooseEvent(r,which=='eventDamage'and'three'or'take_1_1'))
end end
for _,after in ipairs({false,true})do
 local r,m,n=F.fixture();assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'))
 if after then assert(Nodes.chooseEvent(r,'one'));assert(Nodes.chooseEvent(r,'open_1'))end
 local id=after and r.nodeFlow.event.rewards[1].cards[1].cardId or 'sadistic_nature'
 -- A late group's source-selected definition stays in the full source bucket;
 -- its absence must fail instead of filtering the candidate or rerolling.
 if not after then
  local v=dofile('tests/fixtures/sensory-stone-vectors.lua');local source
  for _,c in ipairs(v.cases)do if c.seed=='42'and c.count==3 then source=c.groups[3][3]end end
  for _,d in ipairs(r.data.cards.cards)do if d.sourceId==source then id=d.id;break end end
 end
 local removed;for i,d in ipairs(r.data.cards.cards)do if d.id==id then removed=table.remove(r.data.cards.cards,i);break end end;assert(removed)
 local before=F.C.copy(r);F.eq(Nodes.chooseEvent(r,after and'take_1_1'or'three'),false);F.same(r,before)
 r.data.cards.cards[#r.data.cards.cards+1]=removed;assert(Nodes.chooseEvent(r,after and'take_1_1'or'three'))
end
local r,m,n=F.fixture();assert(Nodes.enter(r,m,n));local before=F.C.copy(r)
for _,choice in ipairs({'leave','three','take_1_1','skip_1','proceed'})do F.eq(Nodes.chooseEvent(r,choice),false);F.same(r,before)end
F.eq(Nodes.chooseEvent(r,'continue',1),false);F.same(r,before)
print('SENSORY_STONE_ROLLBACK_PASS late damage/obtain reject and throw, original owner graphs/RNG, late-group or claimed missing definition with exact retry, stages and UID guards')
