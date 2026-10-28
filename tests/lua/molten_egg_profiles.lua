local F=dofile('tests/lua/support/toxic_egg_fixture.lua')
for _,kind in ipairs({'ironclad','silent','defect','watcher','hutao'})do
 local r=F.Run.new(F.D,42,{character=kind,experimental=true});assert(F.Run.obtainRelic(r,'Molten Egg 2'))
 local eligible
 for _,card in ipairs(r.deck)do local d=F.definition(r,card.cardId);if d.type=='attack'and next(d.upgrade or{})then eligible=card.cardId;break end end
 assert(eligible,kind..' must have a real upgradeable starter Attack')
 local rng=F.C.copy(r.cardRng);local ok,uid=F.Run.obtainCard(r,eligible);assert(ok,uid)
 F.eq(r.deck[#r.deck].upgraded,true);F.eq(r.deck[#r.deck].upgrades,1);F.same(r.cardRng,rng)
 assert(F.Run.startCombat(r,'cultist_solo'));local found
 for _,pile in ipairs({r.combat.hand,r.combat.draw,r.combat.discard})do for _,c in ipairs(pile)do if c.deckUid==uid then found=c end end end
 assert(found and found.upgraded);F.eq(found.upgrades,1)
 if kind=='watcher'then
  local miracle;for _,c in ipairs(r.combat.hand)do if c.cardId=='miracle'then miracle=c end end
  assert(miracle and not miracle.upgraded and F.C.canUpgrade(r.combat,miracle),'Egg must not upgrade eligible combat-created Miracle')
 end
 if kind=='hutao'then assert(r.data.originalV4Role);assert(r.combat.originalV4)
 else local n=0;for _,d in ipairs(r.data.cards.cards)do if ({red=true,green=true,blue=true,purple=true})[d.color]and d.rarity~='special'and d.type~='curse'and d.type~='status'then n=n+1 end end;F.eq(n,300)end
end
-- Real Blade Dance creates upgradeable ATTACK Shivs in combat. Egg only owns
-- permanent acquisition, so even these eligible temporary attacks remain base.
do
 local r=F.Run.new(F.D,42,{character='silent',experimental=true})
 r.deck={{uid=1,cardId='blade_dance',upgraded=false}}
 assert(F.Run.obtainRelic(r,'Molten Egg 2'));assert(F.Run.startCombat(r,'cultist_solo'))
 assert(F.Run.play(r,r.combat.hand[1].uid));F.eq(#r.combat.hand,3)
 for _,c in ipairs(r.combat.hand)do F.eq(c.cardId,'shiv');assert(not c.upgraded and not c.deckUid);assert(F.C.canUpgrade(r.combat,c))end
end
print('MOLTEN_EGG_PROFILES_PASS four STS selected classes preserve full300, V4 keeps its native data/path; same permanent UID upgrades in next battle, no card RNG')
