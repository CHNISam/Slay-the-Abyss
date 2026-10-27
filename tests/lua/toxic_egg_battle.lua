local F=dofile('tests/lua/support/toxic_egg_fixture.lua');local Run,Nodes,C,R=F.Run,F.Nodes,F.C,F.R
local Pool=require('abyss_card_pool');local r=Run.new(F.D,8)
-- An explicit room boundary; the relic roll is the actual untouched full pool.
local queue=C.copy(r.relicPool);local offer,nextPool=Run.prepareRelic(r,{channel='event',screenless=true,room='event'})
assert(offer,nextPool);F.eq(offer.sourceId,'Toxic Egg 2');F.eq(#offer.trace,1);F.same(r.relicPool,queue)
F.enter(r,'event','big_fish');assert(Nodes.chooseEvent(r,'box'));F.eq(r.nodeFlow.event.relicOffer.sourceId,'Toxic Egg 2')
F.same(r.relicPool,nextPool);F.eq(r.relics[#r.relics],'toxic_egg');assert(Nodes.chooseEvent(r,'leave'));F.eq(r.phase,'map')
assert(Run.obtainRelic(r,'CeramicFish'));local gold=r.gold
local cards,rng,offset,upgrades=Pool.prepareRewards(r)
assert(Run.startCombat(r,'cultist_solo'));F.win(r)
F.same(r.rewards.cards,cards);F.same(R.snapshot(r.cardRng),R.snapshot(rng));F.eq(r.cardRarityOffset,offset);F.eq(r.gold,gold)
local selected
for i,id in ipairs(cards)do
 local d=F.definition(r,id);local eligible=d.type=='skill'and next(d.upgrade or {})~=nil
 F.eq(r.rewards.cardUpgrades[i],upgrades[i]or eligible)
 if eligible then selected=i end
end
assert(selected,'seed8 ordinary reward must offer a Skill')
local uid=r.nextDeckUid;assert(Run.claimCardReward(r,selected));local c=r.deck[#r.deck]
F.eq(c.uid,uid);F.eq(c.cardId,cards[selected]);F.eq(c.upgraded,true);assert(not c.upgrades or c.upgrades==1);F.eq(r.gold,gold+9)
F.eq(Run.claimCardReward(r,selected),false);F.eq(r.gold,gold+9)
assert(Run.leaveCombatRewards(r));assert(Run.startCombat(r,'cultist_solo'))
local found;for _,pile in ipairs({r.combat.hand,r.combat.draw,r.combat.discard})do for _,x in ipairs(pile)do if x.deckUid==uid then found=x end end end
assert(found and found.upgraded);local def=C.cardDefinition(r.combat,found);F.eq(def.id,c.cardId)
print('TOXIC_EGG_BATTLE_PASS seed8 complete event relic queue -> true acquire -> starter/source enemy victory -> exact reward RNG/preview -> once claim -> upgraded UID next battle; room boundary, not campaign clear')
