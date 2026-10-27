local F=dofile('tests/lua/support/sensory_stone_fixture.lua');local V=dofile('tests/fixtures/sensory-stone-vectors.lua')
local template=F.Map.generate(F.D,'42',3)
for _,character in ipairs({'default','silent','defect','watcher'})do
 local r=F.Run.new(F.D,'42',{character=character~='default'and character or nil,experimental=true,campaign=true})
 r.act,r.floor=3,34;r.encounters=F.Q.new('42',3);r.unknown.pools=F.P.new('full',false,3)
 local m=F.C.copy(template);local first=F.Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId='sensory_stone'end end
 local pool=F.C.copy(r.data.cards.sourcePools.reward);local hp,uid=r.hp,r.nextDeckUid
 assert(F.Nodes.enter(r,m,first.id));assert(F.Nodes.chooseEvent(r,'continue'));assert(F.Nodes.chooseEvent(r,'one'));F.eq(r.hp,hp)
 F.same(F.R.snapshot(r.cardRng),V.cases[7].cardRng) -- seed42/count1, same persistent source stream for all classes.
 assert(F.Nodes.chooseEvent(r,'open_1'));local id=r.nodeFlow.event.rewards[1].cards[1].cardId;assert(F.Nodes.chooseEvent(r,'take_1_1'))
 F.eq(r.deck[#r.deck].cardId,id);F.eq(r.deck[#r.deck].uid,uid);F.same(r.data.cards.sourcePools.reward,pool)
 assert(F.Nodes.chooseEvent(r,'proceed'));assert(F.Nodes.chooseEvent(r,'leave'));F.eq(r.phase,'map')
end
print('SENSORY_STONE_PROFILES_PASS actual four Run factories share full colorless rewards/RNG and permanent UID; selected-class reward pools unchanged')
