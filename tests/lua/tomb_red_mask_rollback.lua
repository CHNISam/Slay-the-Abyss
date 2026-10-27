local F=dofile('tests/lua/support/tomb_red_mask_fixture.lua');local eq,same,Run,Nodes,C=F.eq,F.same,F.Run,F.Nodes,F.C
do
 local r,m,n=F.fixture(99);assert(Nodes.enter(r,m,n))
 r.data=C.copy(r.data);for i=#r.data.relics.relics,1,-1 do if r.data.relics.relics[i].id=='red_mask'then table.remove(r.data.relics.relics,i)end end
 local before,bm=C.copy(r),C.copy(m);local flow,event,held,deck,pool,misc=r.nodeFlow,r.nodeFlow.event,r.relics,r.deck,r.relicPool,r.miscRng
 local ok,why=Nodes.chooseEvent(r,'pay');eq(ok,false);eq(why,'relic_content_unavailable');same(r,before);same(m,bm)
 eq(r.nodeFlow,flow);eq(r.nodeFlow.event,event);eq(r.relics,held);eq(r.deck,deck);eq(r.relicPool,pool);eq(r.miscRng,misc)
end
do
 local r,m,n=F.fixture(99);assert(Run.obtainRelic(r,'red_mask'));assert(Nodes.enter(r,m,n))
 local before,bm=C.copy(r),C.copy(m);local flow,event,held,deck=r.nodeFlow,r.nodeFlow.event,r.relics,r.deck
 local gain=Run.gainGold;local reached=false
 Run.gainGold=function(staged,amount)local value=gain(staged,amount);eq(staged.gold,321);reached=true;error('AFTER_TOMB_GOLD')end
 local ok,why=Nodes.chooseEvent(r,'wear');Run.gainGold=gain
 eq(ok,false);eq(why,'transaction_failed');assert(reached);same(r,before);same(m,bm)
 eq(r.nodeFlow,flow);eq(r.nodeFlow.event,event);eq(r.relics,held);eq(r.deck,deck)
 assert(Nodes.chooseEvent(r,'wear'));eq(r.gold,321)
end
do
 local r,m,n=F.fixture(99,'14',true);local before,bm=C.copy(r),C.copy(m);local unknown,event,misc=r.unknown,r.eventRng,r.miscRng
 local Tomb=require('abyss_tomb_red_mask_event');local prepare=Tomb.prepare;local reached=false
 Tomb.prepare=function(...)prepare(...);reached=true;error('AFTER_TOMB_CONSTRUCTION')end
 local ok,why=Nodes.enter(r,m,n);Tomb.prepare=prepare
 eq(ok,false);eq(why,'node_content_unavailable');assert(reached);same(r,before);same(m,bm);eq(r.unknown,unknown);eq(r.eventRng,event);eq(r.miscRng,misc)
 assert(Nodes.enter(r,m,n));eq(r.nodeFlow.event.id,'tomb_red_mask')
end
print('TOMB_RED_MASK_ROLLBACK_PASS missing fixed relic after payment, late direct222 gain, full-pool late constructor; complete values/original aliases and retry')
