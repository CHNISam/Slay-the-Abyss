package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/helpers/library_event.lua')
for _,character in ipairs({'ironclad','silent','defect','watcher'})do
 local a=H.fixture(character);local b=H.fixture(character)
 assert(H.Run.obtainRelic(a,'Molten Egg 2'));local baseDeck=H.C.copy(a.deck)
 local offers,plain=H.read(a),H.read(b);H.eq(#offers,20);H.eq(#plain,20)
 local selected;local attacks,others=0,0
 for i,c in ipairs(offers)do
  H.eq(c.cardId,plain[i].cardId)
  local d;for _,v in ipairs(a.data.cards.cards)do if v.id==c.cardId then d=v end end
  local eligible=d.type=='attack'and next(d.upgrade or{})~=nil
  H.eq(c.upgraded,eligible);if eligible then selected=c;attacks=attacks+1 else others=others+1 end
 end
 assert(selected and attacks>0 and others>0);H.same(a.cardRng,b.cardRng);H.same(a.deck,baseDeck)
 local uid=a.nextDeckUid;assert(H.Nodes.chooseEvent(a,'select',selected.offerToken))
 H.eq(a.deck[#a.deck].upgraded,true);H.eq(a.deck[#a.deck].upgrades,1);H.eq(a.deck[#a.deck].uid,uid)
end
-- Both egg owners compose by actual card type without upgrading twice.
local a=H.fixture();assert(H.Run.obtainRelic(a,'Toxic Egg 2'));assert(H.Run.obtainRelic(a,'Molten Egg 2'))
for _,spec in ipairs({{'strike',true},{'defend',true},{'demon_form',false},{'wound',false}})do
 assert(H.Run.obtainCard(a,spec[1]));local c=a.deck[#a.deck];H.eq(c.upgraded,spec[2]);if spec[2]then H.eq(c.upgrades,1)end
end
print('MOLTEN_EGG_LIBRARY_PASS four full20 class offers retain RNG/identity and acquire upgraded attacks once; two eggs compose by type')
