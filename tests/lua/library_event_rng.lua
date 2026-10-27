local H=dofile('tests/helpers/library_event.lua')
local V=dofile('tests/fixtures/library-event-vectors.lua')
local eq,same,R=H.eq,H.same,H.R
local Capability=require('abyss_card_capability')
local function definition(r,id)for _,d in ipairs(r.data.cards.cards)do if d.id==id then return d end end end
H.test('all four complete source-ordered reward rarity buckets and actual canonical capabilities',function()
 for character,wanted in pairs(V.pools)do
  local r=H.fixture(character)
  eq(r.data.runCardCatalog,true);eq(r.data.runCardCharacter,character)
  local total=0
  for _,rarity in ipairs({'common','uncommon','rare'})do
   local actual=r.data.cards.sourcePools.reward[rarity];eq(#actual,#wanted[rarity]);total=total+#actual
   for i,id in ipairs(actual)do
    local d=assert(definition(r,id));eq(d.sourceId,wanted[rarity][i]);eq(d.rarity,rarity)
    eq(r.data.cards.sourcePools.cardSourceMetadata[id].sourceId,d.sourceId)
    assert(Capability.isImplemented(d),'actual source capability '..character..' '..d.sourceId)
    assert(d.type~='status' and d.type~='curse' and d.rarity~='basic' and d.rarity~='special')
   end
  end
  eq(total,character=='ironclad' and 72 or 71)
 end
end)
H.test('17 independent offer vectors fix every retry, source identity, reversed order, unchanged pity and full RNG continuation',function()
 eq(#V.cases,17)
 for _,case in ipairs(V.cases)do
  local r=H.fixture(case.character);r.cardRng=R.restore(case.initial);r.cardRarityOffset=case.offset
  r.relics=case.gift and {"Nloth's Gift"} or {}
  local before=H.snap(r);local calls,preview={},{}
  local random,hook=R.randomInt,H.Hooks.onPreviewObtainCard
  R.randomInt=function(owner,maximum,...)
   local value=random(owner,maximum,...);calls[#calls+1]={maximum,value};return value
  end
  H.Hooks.onPreviewObtainCard=function(owner,card,d)
   preview[#preview+1]=d.sourceId;return hook(owner,card,d)
  end
  local offers=H.read(r);R.randomInt,H.Hooks.onPreviewObtainCard=random,hook
  eq(#offers,20);eq(#calls,2*#case.attempts);eq(#preview,20)
  local previewIndex,seen=0,{}
  for i,attempt in ipairs(case.attempts)do
   eq(calls[2*i-1][1],99);eq(calls[2*i-1][2],attempt.roll)
   eq(calls[2*i][1],#V.pools[case.character][attempt.rarity]-1);eq(calls[2*i][2],attempt.index)
   if attempt.accepted then previewIndex=previewIndex+1;eq(preview[previewIndex],attempt.sourceId)end
  end
  for i,card in ipairs(offers)do
   eq(card.sourceCardId,case.offers[i]);eq(card.uid,nil);eq(card.upgraded,false)
   assert(not seen[card.sourceCardId]);seen[card.sourceCardId]=true
  end
  same(R.snapshot(r.cardRng),case.final);eq(r.cardRarityOffset,case.offset)
  same(r.deck,before.deck);eq(r.nextDeckUid,before.nextDeckUid);eq(r.gold,before.gold)
  same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng);same(r.treasureRng,before.treasureRng)
  same(r.unknown,before.unknown);same(r.relicPool,before.relicPool)
 end
end)
H.test('primitive rejection remains one wrapper counter and two raw words, never guessed counter-only replay',function()
 local p=V.rejection;local owner=R.restore(p.initial)
 eq(R.randomInt(owner,99),p.value);same(R.snapshot(owner),p.final);eq(#p.rawWords,2)
 eq(owner.counter,1);eq(p.rawWords[1],'ffffffffffffffff')
end)
H.test('full deck ownership and ordinary reward relics do not filter, alter20, cross-color or add upgrade draws',function()
 local r=H.fixture();r.deck={};r.relics={'question_card','busted_crown','prayer_wheel','prismatic_shard'}
 for _,bucket in pairs(r.data.cards.sourcePools.reward)do for _,id in ipairs(bucket)do r.deck[#r.deck+1]={uid=#r.deck+1,cardId=id}end end
 r.nextDeckUid=#r.deck+1
 local CardPool,CardRandom=require('abyss_card_pool'),require('abyss_card_random')
 local prepare,upgrade,preview=CardPool.prepareRewards,CardRandom.upgrade,H.Hooks.previewCardReward
 CardPool.prepareRewards=function()error('Library must not use ordinary rewards')end
 CardRandom.upgrade=function()error('Library must not roll random upgrades')end
 H.Hooks.previewCardReward=function()error('Library dispatches individual accepted preview hooks')end
 local offers=H.read(r)
 CardPool.prepareRewards,CardRandom.upgrade,H.Hooks.previewCardReward=prepare,upgrade,preview
 eq(#offers,20);eq(r.cardRng.counter,V.cases[1].final.counter)
 for i,card in ipairs(offers)do eq(card.sourceCardId,V.cases[1].offers[i])end
end)
H.finish('LIBRARY_RNG')
