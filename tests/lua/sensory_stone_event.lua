local F=dofile('tests/lua/support/sensory_stone_fixture.lua')
local r,m,n=F.fixture();local ok,why=F.Nodes.enter(r,m,n);assert(ok,why)
F.eq(r.nodeFlow.event.stage,'intro');F.eq(#F.Nodes.view(r,m).node.event.options,1)
assert(F.Nodes.chooseEvent(r,'continue'));F.eq(r.nodeFlow.event.stage,'choice');F.eq(#F.Nodes.view(r,m).node.event.options,3)
local hp=r.hp;local deck=#r.deck;local uid=r.nextDeckUid
assert(F.Nodes.chooseEvent(r,'three'));local e=r.nodeFlow.event;F.eq(e.stage,'rewards');F.eq(#e.rewards,3);F.eq(r.hp,hp-10);F.eq(#r.deck,deck)
for _,group in ipairs(e.rewards)do F.eq(#group.cards,3);for _,c in ipairs(group.cards)do F.eq(c.upgraded,false)end end
local rng=F.R.snapshot(r.cardRng);local offers=F.C.copy(e.rewards)
assert(F.Nodes.chooseEvent(r,'open_2'));assert(F.Nodes.chooseEvent(r,'skip_2'));e=r.nodeFlow.event;F.eq(e.stage,'rewards');F.same(e.rewards,offers);F.same(F.R.snapshot(r.cardRng),rng)
assert(F.Nodes.chooseEvent(r,'open_2'));local selected=e.rewards[2].cards[1].cardId;assert(F.Nodes.chooseEvent(r,'take_2_1'));e=r.nodeFlow.event
F.eq(#r.deck,deck+1);F.eq(r.deck[#r.deck].uid,uid);F.eq(r.deck[#r.deck].cardId,selected);F.eq(e.rewards[2].claimed,true);F.eq(e.stage,'rewards')
F.eq(F.Nodes.chooseEvent(r,'take_2_1'),false);F.eq(F.Nodes.chooseEvent(r,'open_2'),false)
assert(F.Nodes.chooseEvent(r,'open_1'));F.eq(F.Nodes.chooseEvent(r,'take_2_1'),false);assert(F.Nodes.chooseEvent(r,'skip_1'))
assert(F.Nodes.chooseEvent(r,'proceed'));e=r.nodeFlow.event;F.eq(e.stage,'result');F.eq(r.phase,'node');F.eq(F.Nodes.chooseEvent(r,'open_1'),false)
F.same(F.R.snapshot(r.cardRng),rng);assert(F.Nodes.chooseEvent(r,'leave'));F.eq(r.phase,'map')
print('SENSORY_STONE_EVENT_PASS all groups before HP_LOSS; arbitrary group order, skip/reopen frozen offers, permanent UID and explicit reward/event exits')
