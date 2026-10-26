local F=dofile('tests/lua/support/sensory_stone_fixture.lua');local Run,Nodes=F.Run,F.Nodes
for _,row in ipairs({{'one',1,1,1},{'two',2,80,75},{'three',3,80,70},{'two',2,1,0},{'three',3,1,0}})do
 local r,m,n=F.fixture(row[3]);assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'))
 local original=Run.eventDamage;local reached=false;local deck,uid=#r.deck,r.nextDeckUid
 Run.eventDamage=function(owner,amount)
  reached=true;F.eq(owner.nodeFlow.event.stage,'rewards');F.eq(#owner.nodeFlow.event.rewards,row[2]);assert(owner.cardRng.counter>=row[2]*6)
  for _,group in ipairs(owner.nodeFlow.event.rewards)do F.eq(#group.cards,3)end
  return original(owner,amount)
 end
 local called,ok,why=pcall(Nodes.chooseEvent,r,row[1]);Run.eventDamage=original;assert(called and ok,why)
 F.eq(reached,row[2]>1);F.eq(r.hp,row[4]);F.eq(#r.nodeFlow.event.rewards,row[2]);F.eq(#r.deck,deck);F.eq(r.nextDeckUid,uid)
 if r.hp==0 then F.eq(r.phase,'defeat');F.eq(r.nodeFlow.complete,true);F.eq(Nodes.chooseEvent(r,'open_1'),false)
 else F.eq(r.phase,'node');assert(Nodes.chooseEvent(r,'proceed'));assert(Nodes.chooseEvent(r,'leave'))end
end
do
 local r,m,n=F.fixture(1);assert(Run.obtainPotion(r,'fairy_in_a_bottle'));assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));assert(Nodes.chooseEvent(r,'three'))
 F.eq(r.hp,24);F.eq(r.potions[1],nil);F.eq(r.phase,'node');F.eq(#r.nodeFlow.event.rewards,3);assert(Nodes.chooseEvent(r,'open_3'));assert(Nodes.chooseEvent(r,'take_3_1'))
end
do
 local r,m,n=F.fixture(1);assert(Run.obtainPotion(r,'fairy_in_a_bottle'));r.relics[#r.relics+1]='mark_of_bloom'
 assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));assert(Nodes.chooseEvent(r,'two'));F.eq(r.hp,0);F.eq(r.phase,'defeat');F.eq(r.potions[1],'fairy_in_a_bottle')
end
do
 local r,m,n=F.fixture();assert(Run.obtainRelic(r,'ceramic_fish'));assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));assert(Nodes.chooseEvent(r,'one'))
 local gold=r.gold;assert(Nodes.chooseEvent(r,'open_1'));assert(Nodes.chooseEvent(r,'skip_1'));F.eq(r.gold,gold)
 assert(Nodes.chooseEvent(r,'open_1'));assert(Nodes.chooseEvent(r,'take_1_1'));F.eq(r.gold,gold+9)
end
for _,id in ipairs({'question_card','busted_crown','toxic_egg','molten_egg','frozen_egg','singing_bowl','lizard_tail'})do
 local r,m,n=F.fixture();r.relics[#r.relics+1]=id;assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));local before=F.C.copy(r)
 if id=='toxic_egg'then
  assert(Nodes.chooseEvent(r,'two'));F.eq(r.hp,75)
  for _,g in ipairs(r.nodeFlow.event.rewards)do for _,c in ipairs(g.cards)do
   local d;for _,v in ipairs(r.data.cards.cards)do if v.id==c.cardId then d=v end end
   F.eq(c.upgraded,d.type=='skill'and next(d.upgrade or{})~=nil)
  end end
 else F.eq(Nodes.chooseEvent(r,'two'),false);F.same(r,before)end
 if id=='lizard_tail'then assert(Nodes.chooseEvent(r,'one'))end
end
print('SENSORY_STONE_OUTCOMES_PASS all1/2/3 frozen before HP_LOSS, fatal consumes source streams/no claims, real Fairy/CeramicFish and explicit unsupported-owner boundaries')
