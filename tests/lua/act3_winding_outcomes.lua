local F=dofile('tests/lua/support/act3_winding_fixture.lua')
local fixture,eq,same,Run,Nodes,C,P,R=F.fixture,F.eq,F.same,F.Run,F.Nodes,F.C,F.P,F.R
for _,spec in ipairs({{1,{'mark_of_bloom'},1},{79,{},80},{1,{'magic_flower'},21}})do
 local r,m,n=fixture(spec[1]);for _,id in ipairs(spec[2])do r.relics[#r.relics+1]=id end
 assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));local uid=r.nextDeckUid;assert(Nodes.chooseEvent(r,'writhe'))
 eq(r.hp,spec[3]);eq(r.deck[#r.deck].cardId,'writhe');eq(r.deck[#r.deck].uid,uid);eq(r.nextDeckUid,uid+1);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end
do local r,m,n=fixture(1);assert(Run.obtainRelic(r,'omamori'));assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'))
 local uid,deck=r.nextDeckUid,#r.deck;assert(Nodes.chooseEvent(r,'writhe'));eq(r.hp,21);eq(#r.deck,deck);eq(r.nextDeckUid,uid);eq(r.relicCounters.omamori,1);eq(r.nodeFlow.event.curseBlocked,true)
end
for _,hp in ipairs({1,80})do
 local r,m,n=fixture(hp);assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));local deck=C.copy(r.deck);assert(Nodes.chooseEvent(r,'max_hp'))
 eq(r.maxHp,76);eq(r.hp,math.min(hp,76));same(r.deck,deck);eq(r.nodeFlow.event.stage,'result')
end
for _,spec in ipairs({{false,false,0},{true,false,24},{true,true,0}})do
 local r,m,n=fixture(1);if spec[1]then assert(Run.obtainPotion(r,'fairy_in_a_bottle'))end;if spec[2]then r.relics[#r.relics+1]='mark_of_bloom'end
 assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));local uid,deck=r.nextDeckUid,#r.deck
 assert(Nodes.chooseEvent(r,'madness'));eq(r.hp,spec[3]);eq(#r.deck,deck+2);eq(r.deck[deck+1].uid,uid);eq(r.deck[deck+2].uid,uid+1)
 if r.hp==0 then eq(r.phase,'defeat');eq(r.nodeFlow.complete,true)else eq(r.phase,'node');eq(r.potions[1],nil)end
 if spec[2]then eq(r.potions[1],'fairy_in_a_bottle')end
end
do
 local r,m,n=fixture(20,32);r.relics[#r.relics+1]='torii';assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'))
 r.combat={player={hp=0,maxHp=999,block=999,statuses={intangible=5,buffer=5}},relics={'magic_flower'},events={{kind='old'}}};local history=C.copy(r.combat)
 assert(Nodes.chooseEvent(r,'madness'));eq(r.hp,16);same(r.combat,history)
end
for _,id in ipairs({'tungsten_rod','lizard_tail'})do
 local r,m,n=fixture();r.relics[#r.relics+1]=id;assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));local b,bm=C.copy(r),C.copy(m)
 local ok,why=Nodes.chooseEvent(r,'madness');eq(ok,false);eq(why,'event_damage_content_unavailable');same(r,b);same(m,bm)
 assert(Nodes.chooseEvent(r,'max_hp'));eq(r.maxHp,76)
end
for _,spec in ipairs({{'toxic_egg','madness'},{'darkstone_periapt','writhe'}})do
 local r,m,n=fixture(1);r.relics[#r.relics+1]=spec[1];assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));local b,bm=C.copy(r),C.copy(m)
 local ok,why=Nodes.chooseEvent(r,spec[2]);eq(ok,false);eq(why,'event_obtain_content_unavailable');same(r,b);same(m,bm);assert(Nodes.chooseEvent(r,'max_hp'))
end
print('ACT3_WINDING_OUTCOMES_PASS heal/Bloom/Flower/Writhe/Omamori, max-health clamp without heal, fatal obtains/Fairy, null-owner Torii and refused missing relic hooks')
