local F=dofile('tests/lua/support/act3_winding_fixture.lua')
local fixture,eq,same,Run,Nodes,C,P,R=F.fixture,F.eq,F.same,F.Run,F.Nodes,F.C,F.P,F.R
local r,m,n=fixture();local ok,why=Nodes.enter(r,m,n);assert(ok,why)
eq(P.contentId['Winding Halls'],'winding_halls');eq(r.nodeFlow.event.stage,'intro');eq(#Nodes.view(r,m).node.event.options,1)
assert(Nodes.chooseEvent(r,'continue'));local rows=Nodes.view(r,m).node.event.options;eq(#rows,3);eq(rows[1].choice,'madness');eq(rows[2].choice,'writhe');eq(rows[3].choice,'max_hp')
local before=C.copy(r);eq(Nodes.chooseEvent(r,'leave'),false);same(r,before)
local deck,uid,rng=C.copy(r.deck),r.nextDeckUid,R.snapshot(r.miscRng)
assert(Nodes.chooseEvent(r,'madness'));eq(r.hp,70);eq(r.maxHp,80);eq(#r.deck,#deck+2);eq(r.nextDeckUid,uid+2)
for i=1,#deck do same(r.deck[i],deck[i])end;for i=1,2 do eq(r.deck[#deck+i].cardId,'madness');eq(r.deck[#deck+i].uid,uid+i-1)end
same(R.snapshot(r.miscRng),rng);eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node');assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
print('ACT3_WINDING_EVENT_PASS real public entry, mandatory three choices and exact two permanent UIDs')
