-- Controlled consecutive event constructors on one real Run, not natural map play.
local F=dofile('tests/lua/support/shared_special_event_fixture.lua')
local Run,C,R=F.Run,F.C,F.R
local Match=require('abyss_match_event')
local Skull=require('abyss_knowing_skull_event')
local Hooks=require('abyss_relic_hooks')
local eq,same=F.eq,F.same
local r=F.fixture(Match,'match_game')
local owner=assert(r.colorlessCardPool)
local cards=owner.cards
local expected=C.copy(cards)
local rng=Run.roomStreams(r,19).shuffleRng
R.shuffle(rng,expected)
local wanted
for _,id in ipairs(expected)do
 for _,d in ipairs(r.data.cards.cards)do if d.id==id and d.rarity=='uncommon'then wanted=id;break end end
 if wanted then break end
end
r.floor=19;r.nodeFlow={type='event',event={id='knowing_skull'}}
Skull.prepare(r,r.nodeFlow.event,r.miscRng,19);F.ready(Skull,r)
assert(F.choose(Skull,r,'card'))
owner=r.colorlessCardPool;cards=owner.cards
same(cards,expected);eq(r.nodeFlow.event.cards[1].cardId,wanted)
same(R.snapshot(r.nodeFlow.event.shuffleRng),R.snapshot(rng))
eq(r.eventCardPools,nil)
-- A late hook refusal must restore the pre-existing Match-owned permutation,
-- its object identities, Skull cost, HP, deck UID and room shuffle stream.
local old=Hooks.onObtainCard
Hooks.onObtainCard=function(...)old(...);error('shared pool late refusal')end
local ok,why=pcall(F.reject,Skull,r,'card',nil,'transaction_failed')
Hooks.onObtainCard=old;assert(ok,why)
eq(r.colorlessCardPool,owner);eq(owner.cards,cards);same(cards,expected)
-- Match's next constructor must start from the order Skull actually left.
r.floor=20;r.nodeFlow={type='event',event={id='match_game'}}
local nextRng=Run.roomStreams(r,20).shuffleRng
R.shuffle(nextRng,expected)
assert(Run.transaction(r,function(s)return Match.prepare(s,s.nodeFlow.event,s.miscRng,20)end))
same(r.colorlessCardPool.cards,expected)
same(R.snapshot(r.nodeFlow.event.shuffleRng),R.snapshot(nextRng))
-- Act changes reset the one canonical owner to the original complete pool.
r.act=3
local sample=require('abyss_event_card_sampling')
local reset=sample.reset(r)
eq(reset,r.colorlessCardPool);eq(reset.act,3)
same(reset.cards,r.data.cards.sourcePools.colorlessRaw)
print('M3_SHARED_COLORLESS_POOL_PASS match_skull_match rollback act_reset')
