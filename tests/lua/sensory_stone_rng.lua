local F=dofile('tests/lua/support/sensory_stone_fixture.lua')
local V=dofile('tests/fixtures/sensory-stone-vectors.lua')
do
 local r=F.Run.new(F.D,'42')
 for rarity,expected in pairs(V.pools)do
  local actual={};for _,id in ipairs(r.data.cards.sourcePools.colorlessShop[rarity])do actual[#actual+1]=r.data.cards.sourcePools.cardSourceMetadata[id].sourceId end
  table.sort(actual);F.same(actual,expected)
 end
end
for _,v in ipairs(V.cases)do
 local r,m,n=F.fixture(nil,v.seed);r.cardRarityOffset=v.initialOffset
 assert(F.Nodes.enter(r,m,n));local old=F.R.snapshot(r.cardRng);assert(F.Nodes.chooseEvent(r,'continue'));F.same(F.R.snapshot(r.cardRng),old)
 assert(F.Nodes.chooseEvent(r,({'one','two','three'})[v.count]));local event=r.nodeFlow.event
 F.eq(event.memory,v.memory);F.same(F.R.snapshot(r.miscRng),v.miscRng);F.same(F.R.snapshot(r.cardRng),v.cardRng);F.eq(r.cardRarityOffset,v.finalOffset)
 for i,group in ipairs(event.rewards)do
  local seen={};for j,c in ipairs(group.cards)do
   local d;for _,card in ipairs(r.data.cards.cards)do if card.id==c.cardId then d=card;break end end
   F.eq(d.sourceId,v.groups[i][j]);F.eq(c.upgraded,false);assert(not seen[c.cardId]);seen[c.cardId]=true
  end
 end
end
-- Source HEALING cards remain eligible, and the same identity in different
-- groups is legal. Each actual claim receives its own permanent owner UID.
local r,m,n=F.fixture(nil,'139');assert(F.Nodes.enter(r,m,n));assert(F.Nodes.chooseEvent(r,'continue'));assert(F.Nodes.chooseEvent(r,'three'))
local uid=r.nextDeckUid
assert(F.Nodes.chooseEvent(r,'open_1'));assert(F.Nodes.chooseEvent(r,'take_1_2'));assert(F.Nodes.chooseEvent(r,'open_2'));assert(F.Nodes.chooseEvent(r,'take_2_1'))
F.eq(r.deck[#r.deck-1].cardId,'bandage_up');F.eq(r.deck[#r.deck].cardId,'bandage_up');F.eq(r.deck[#r.deck-1].uid,uid);F.eq(r.deck[#r.deck].uid,uid+1)
local rng=F.R.snapshot(r.cardRng);assert(F.Nodes.chooseEvent(r,'proceed'));assert(F.Nodes.chooseEvent(r,'leave'))
-- Keep the independent constructor ownership control, without consuming the
-- real Run's source encounter queue or its persistent card reward stream.
local replay=F.C.new(r.data,{deck=r.deck,enemies={'cultist'},seed=139,cardRng=r.cardRng})
local seen={};for _,pile in ipairs({replay.hand,replay.draw})do for _,c in ipairs(pile)do if c.cardId=='bandage_up'then seen[c.deckUid]=true end end end
assert(seen[uid]and seen[uid+1]);F.same(F.R.snapshot(r.cardRng),rng)
-- The original source encounter is now implemented. Preserve the late-setup
-- refusal contract with an actual injected fault, then retry the SAME queue.
local expected=F.Q.peek(r.encounters,'normal');local before=F.C.copy(r)
local refs,visited={},{}
local function capture(owner)
 if visited[owner]then return end;visited[owner]=true
 for key,value in pairs(owner)do if type(value)=='table'then
  refs[#refs+1]={owner,key,value};capture(value)
 end end
end
capture(r)
local original,reached=F.C.new,false
F.C.new=function(...)original(...);reached=true;error('INJECTED_SENSORY_NEXT_ROOM_SETUP')end
local called,started,why=pcall(F.Run.startRoomCombat,r,'normal');F.C.new=original
assert(called and reached);F.eq(started,false);F.eq(why,'combat_unavailable');F.same(r,before)
for _,ref in ipairs(refs)do assert(ref[1][ref[2]]==ref[3],'failed setup replaced an original owner')end
assert(F.Run.startRoomCombat(r,'normal'));F.eq(r.encounterSource,expected)
seen={};for _,pile in ipairs({r.combat.hand,r.combat.draw,r.combat.discard,r.combat.exhaust})do
 for _,c in ipairs(pile)do if c.cardId=='bandage_up'then seen[c.deckUid]=true end end
end
assert(seen[uid]and seen[uid+1]);F.same(F.R.snapshot(r.cardRng),rng)
print('SENSORY_STONE_RNG_PASS 15 independent normal seed vectors/all35 source order/rare-reset/no-upgrade-roll/within-group retries/memory Java shuffle; cross-group duplicates real UIDs')
