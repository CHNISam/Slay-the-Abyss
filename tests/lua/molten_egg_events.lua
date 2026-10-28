local F=dofile('tests/lua/support/sensory_stone_fixture.lua');local Run,Nodes=F.Run,F.Nodes
local r,m,n=F.fixture();assert(Run.obtainRelic(r,'Molten Egg 2'));assert(Run.obtainRelic(r,'CeramicFish'))
assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));local gold,uid=r.gold,r.nextDeckUid
assert(Nodes.chooseEvent(r,'three'));F.eq(r.gold,gold);F.eq(r.nextDeckUid,uid)
local baseline,bm,bn=F.fixture();assert(Nodes.enter(baseline,bm,bn));assert(Nodes.chooseEvent(baseline,'continue'));assert(Nodes.chooseEvent(baseline,'three'))
F.same(r.cardRng,baseline.cardRng);F.same(r.miscRng,baseline.miscRng);F.eq(r.cardRarityOffset,baseline.cardRarityOffset)
local selected
for g,group in ipairs(r.nodeFlow.event.rewards)do for i,c in ipairs(group.cards)do
 local d;for _,v in ipairs(r.data.cards.cards)do if v.id==c.cardId then d=v end end
 F.eq(c.cardId,baseline.nodeFlow.event.rewards[g].cards[i].cardId)
 local eligible=d.type=='attack'and next(d.upgrade or{})~=nil;F.eq(c.upgraded,eligible)
 if eligible then selected={g,i};F.eq(c.upgrades,1)end
end end
assert(selected);assert(Nodes.chooseEvent(r,'open_'..selected[1]))
local group=r.nodeFlow.event.rewards[selected[1]];local c=group.cards[selected[2]];c.upgrades=2
local before=F.C.copy(r);F.eq(Nodes.chooseEvent(r,'take_'..selected[1]..'_'..selected[2]),false);F.same(r,before);c.upgrades=1
assert(Nodes.chooseEvent(r,'take_'..selected[1]..'_'..selected[2]));F.eq(r.deck[#r.deck].upgrades,1);F.eq(r.gold,gold+9)
F.eq(Nodes.chooseEvent(r,'take_'..selected[1]..'_'..selected[2]),false)
-- Exact CombatRewardScreen ownership: taking Egg after generation previews all
-- existing unclaimed groups, including a currently opened card group.
assert(Nodes.chooseEvent(baseline,'open_1'));assert(Run.obtainRelic(baseline,'Molten Egg 2'))
for _,group2 in ipairs(baseline.nodeFlow.event.rewards)do for _,card in ipairs(group2.cards)do
 local d;for _,v in ipairs(baseline.data.cards.cards)do if v.id==card.cardId then d=v end end
 F.eq(card.upgraded,d.type=='attack'and next(d.upgrade or{})~=nil)
end end
print('MOLTEN_EGG_EVENTS_PASS three source colorless groups/unchanged dual RNG, upgrades frozen before HP loss, once true acquire, stale flag rejection and onEquip existing open rewards')
