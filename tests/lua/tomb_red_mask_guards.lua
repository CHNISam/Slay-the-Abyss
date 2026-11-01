local F=dofile('tests/lua/support/tomb_red_mask_fixture.lua');local eq,same,Run,Nodes=F.eq,F.same,F.Run,F.Nodes
do
 local r,m,n=F.fixture(41);assert(Run.obtainRelic(r,'MawBank'));assert(Nodes.enter(r,m,n));eq(r.gold,53)
 Run.gainGold(r,7);eq(r.gold,60);assert(Nodes.eventOptions(r,r.nodeFlow)[2].description:find('60',1,true))
 local uid=r.nextDeckUid;assert(Nodes.chooseEvent(r,'pay'));eq(r.gold,0);eq(r.nodeFlow.event.goldPaid,60);eq(r.relicCounters.maw_bank,0);eq(r.nextDeckUid,uid)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
end
do
 local r,m,n=F.fixture(41);assert(Nodes.enter(r,m,n));local before=F.C.copy(r)
 for _,command in ipairs({'invalid','continue'})do eq(Nodes.chooseEvent(r,command),false);same(r,before)end
 eq(Nodes.chooseEvent(r,'pay',1),false);same(r,before)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');eq(r.gold,41);same(r.relics,before.relics)
end
do
 local r,m,n=F.fixture(41);r.act=1;local before,bm=F.C.copy(r),F.C.copy(m)
 eq(Nodes.enter(r,m,n),false);same(r,before);same(m,bm)
end
print('TOMB_RED_MASK_GUARDS_PASS current all-gold quote/payment including room Maw income, no shop disable, no card UID, direct leave, invalid UID/choice/act unchanged')
