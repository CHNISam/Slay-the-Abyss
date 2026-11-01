local F=dofile('tests/lua/support/golden_idol_fixture.lua')
local fixture,eq,same,Run,Map,Nodes,C,R,P,D=F.fixture,F.eq,F.same,F.Run,F.Map,F.Nodes,F.C,F.R,F.P,F.D
for _,spec in ipairs({{'damage',80,80,60,80},{'max_hp',80,80,74,74},{'max_hp',1,1,1,1},{'damage',1,80,0,80}})do
 local r,m,n=fixture(spec[2],spec[3]);assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'take'));assert(Nodes.chooseEvent(r,spec[1]))
 eq(r.hp,spec[4]);eq(r.maxHp,spec[5]);eq(r.relics[#r.relics],'golden_idol')
 if r.hp==0 then eq(r.phase,'defeat');eq(r.nodeFlow.complete,true)else eq(r.nodeFlow.event.stage,'result');assert(Nodes.chooseEvent(r,'leave'))end
end
do local r,m,n=fixture(1);assert(Run.obtainPotion(r,'fairy_in_a_bottle'));assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'take'));assert(Nodes.chooseEvent(r,'damage'));eq(r.hp,24);eq(r.potions[1],nil);eq(r.nodeFlow.event.stage,'result')end
do local r,m,n=fixture();assert(Run.obtainRelic(r,'omamori'));assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'take'));local uid,deck=r.nextDeckUid,#r.deck;assert(Nodes.chooseEvent(r,'injury'));eq(r.relicCounters.omamori,1);eq(r.nextDeckUid,uid);eq(#r.deck,deck)end
do local r,m,n=fixture();assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'leave'));eq(r.nodeFlow.event.stage,'result');eq(#r.relics,1);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')end
for _,cost in ipairs({'damage','max_hp'})do local r,m,n=fixture();assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'take'));assert(Run.obtainPotion(r,'fruit_juice'));assert(Run.usePotion(r,1));eq(r.maxHp,85);assert(Nodes.chooseEvent(r,cost));eq(r.maxHp,cost=='max_hp'and 79 or 85);eq(r.hp,cost=='max_hp'and 79 or 65)end
-- Actual repeat event commands keep one Golden owner and use real Circlet count.
do
 local r,m,n=fixture();assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'take'));assert(Nodes.chooseEvent(r,'max_hp'));assert(Nodes.chooseEvent(r,'leave'))
 for pass=1,2 do
  local next=Map.available(m)[1];assert(next)
  for _,node in ipairs(m.nodes)do if node.id==next.id then node.type='event';node.eventId='golden_idol'end end
  assert(Nodes.enter(r,m,next.id));assert(Nodes.chooseEvent(r,'take'));eq(r.nodeFlow.event.obtainedRelicId,'circlet');eq(r.relicCounters.circlet,pass)
  assert(Nodes.chooseEvent(r,'max_hp'));assert(Nodes.chooseEvent(r,'leave'))
 end
 local count=0;for _,id in ipairs(r.relics)do if id=='golden_idol'then count=count+1 end end;eq(count,1)
end
for _,spec in ipairs({{'tungsten_rod','damage'},{'lizard_tail','damage'},{'darkstone_periapt','injury'}})do
 local r,m,n=fixture();assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'take'))
 if spec[1]~='darkstone_periapt'then assert(Run.obtainRelic(r,spec[1]))else r.relics[#r.relics+1]=spec[1]end
 local b=C.copy(r)
 if spec[1]~='darkstone_periapt'then
  assert(Nodes.chooseEvent(r,spec[2]));eq(r.hp,spec[1]=='tungsten_rod'and 61 or 60);eq(r.nodeFlow.event.stage,'result')
  if spec[1]=='lizard_tail'then eq(b.relicCounters.lizard_tail,-1);eq(r.relicCounters.lizard_tail,-1)end
 else eq(Nodes.chooseEvent(r,spec[2]),false);same(r,b);assert(Nodes.chooseEvent(r,'max_hp'))end
end
do
 local r,m,n=fixture();assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'take'));assert(Run.obtainRelic(r,'lizard_tail'))
 local deck=C.copy(r.deck);assert(Nodes.chooseEvent(r,'max_hp'));eq(r.maxHp,74);eq(r.hp,74);same(r.deck,deck);eq(r.relicCounters.lizard_tail,-1)
end
-- Controlled next-room event/HP setup; the second obtain is Circlet, never Tail.
do
 local r,m,n=fixture(1);assert(Run.obtainRelic(r,'lizard_tail'));eq(r.relicCounters.lizard_tail,-1)
 for pass=1,2 do
  assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'take'))
  eq(r.nodeFlow.event.obtainedRelicId,pass==1 and'golden_idol'or'circlet')
  local deck,uid,gold=#r.deck,r.nextDeckUid,r.gold
  local card,misc,event=C.copy(r.cardRng),C.copy(r.miscRng),C.copy(r.eventRng)
  assert(Nodes.chooseEvent(r,'damage'));eq(r.hp,pass==1 and 40 or 0);eq(r.relicCounters.lizard_tail,-2)
  eq(r.maxHp,80);eq(#r.deck,deck);eq(r.nextDeckUid,uid);eq(r.gold,gold)
  same(r.cardRng,card);same(r.miscRng,misc);same(r.eventRng,event)
  if pass==1 then
   eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
   n=assert(Map.available(m)[1]).id
   for _,node in ipairs(m.nodes)do if node.id==n then node.type='event';node.eventId='golden_idol'end end
   r.hp=1
  else eq(r.relicCounters.circlet,1);eq(r.phase,'defeat');eq(r.nodeFlow.complete,true);eq(Nodes.chooseEvent(r,'leave'),false)end
 end
end
print('GOLDEN_IDOL_COSTS_PASS exact truncation/min1, three trap costs/fatal/Fairy/Omamori, real Tail once across events, real duplicate Circlet, live Fruit and missing-hook refusals')
