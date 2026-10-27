local F=dofile('tests/lua/support/tomb_red_mask_fixture.lua');local eq,same,Run,Nodes=F.eq,F.same,F.Run,F.Nodes
for _,gold in ipairs({0,99})do
 local r,m,n=F.fixture(gold);assert(Nodes.enter(r,m,n));local rows=Nodes.eventOptions(r,r.nodeFlow)
 eq(#rows,3);eq(rows[1].enabled,false);eq(rows[2].choice,'pay');eq(rows[2].enabled,true)
 local before=F.C.copy(r);eq(Nodes.chooseEvent(r,'wear'),false);same(r,before)
 assert(Nodes.chooseEvent(r,'pay'));eq(r.gold,0);eq(r.nodeFlow.event.goldPaid,gold);eq(r.nodeFlow.event.stage,'result');eq(r.relics[#r.relics],'red_mask')
 before=F.C.copy(r);eq(Nodes.chooseEvent(r,'pay'),false);same(r,before);eq(#Nodes.eventOptions(r,r.nodeFlow),1)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');before=F.C.copy(r);eq(Nodes.chooseEvent(r,'leave'),false);same(r,before)
end
-- Held-mask branches are permanent-inventory component fixtures; the actual
-- natural named obtain is separately proven by the seed14 source route.
for _,ecto in ipairs({false,true})do
 local r,m,n=F.fixture(17);assert(Run.obtainRelic(r,'Red Mask'));assert(Run.obtainRelic(r,'golden_idol'))
 if ecto then r.relics[#r.relics+1]='ectoplasm'end -- existing gold-hook boundary, not Ectoplasm acquisition evidence
 assert(Nodes.enter(r,m,n));local rows=Nodes.eventOptions(r,r.nodeFlow);eq(#rows,2);eq(rows[1].choice,'wear')
 local before=F.C.copy(r);eq(Nodes.chooseEvent(r,'pay'),false);same(r,before)
 assert(Nodes.chooseEvent(r,'wear'));eq(r.gold,ecto and 17 or 239);eq(r.nodeFlow.event.goldGained,ecto and 0 or 222)
 eq(#r.relics,#before.relics);local masks=0;for _,id in ipairs(r.relics)do if id=='red_mask'then masks=masks+1 end end;eq(masks,1)
 before=F.C.copy(r);eq(Nodes.chooseEvent(r,'wear'),false);same(r,before);assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end
print('TOMB_RED_MASK_EVENT_PASS 4 outcomes: zero/all gold, disabled branch/replay, held mask222/direct-not-GOLD bonus, Ectoplasm0, single physical relic')
