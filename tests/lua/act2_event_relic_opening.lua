local H=dofile('tests/helpers/act2_event_relics.lua')
local eq,same,test=H.eq,H.same,H.test
local Inventory=require('abyss_inventory')
test('Mutagenic real Augmenter relic opening applies timed loss BEFORE strength and first draw',function()
 local r,s=H.battle({'MutagenicStrength'},{'defend','defend'})
 eq(s.player.statuses.strength,3);eq(s.player.temporaryStrength,3);local found={}
 for _,e in ipairs(s.events)do if e.kind=='status'and(e.detail.status=='lose_strength'or e.detail.status=='strength')then found[#found+1]=e end end
 eq(found[1].detail.status,'lose_strength');eq(found[2].detail.status,'strength');eq(#found[1].frame.hand,0);eq(#found[2].frame.hand,0)
 assert(H.Run.endTurn(r));eq(r.combat.turn,2);eq(r.combat.player.statuses.strength,0);eq(r.combat.player.temporaryStrength,0)
 assert(H.Run.endTurn(r));eq(r.combat.turn,3);eq(r.combat.player.statuses.strength,0)
end)
test('Mutagenic opening Artifact blocks debt BEFORE gain, using a controlled pre-battle ApplyPower fixture',function()
 local r=H.run({'MutagenicStrength'},{'defend'})
 local opening=assert(Inventory.opening(r.data.relics.relics,r.relics,r.relicCounters))
 local s=assert(H.C.new(r.data,{deck=r.deck,enemies={'cultist'},cardRandomSeed='42',shuffleSeed='42',
  beforeFirstTurn=function(staged)H.A.applyPower(staged,staged.player,'artifact',1,staged.player);return true end,
  beforeOpeningDraw=function(staged)return Inventory.applyOpening(staged,opening.beforeDraw)end}))
 eq(s.player.statuses.artifact,0);eq(s.player.temporaryStrength,nil);eq(s.player.statuses.strength,3)
 local blocked,gained
 for i,e in ipairs(s.events)do if e.kind=='status'and e.detail.blockedStatus=='lose_strength'then blocked=i elseif e.kind=='status'and e.detail.status=='strength'then gained=i end end
 assert(blocked and gained and blocked<gained);assert(H.C.endTurn(s));eq(s.player.statuses.strength,3)
end)
test('Enchiridion samples full src POWER order via cardRandom, creates zero-turn card BEFORE normal opening draw',function()
 local r=H.run({'Enchiridion'},{'defend','defend','defend','defend','defend'})
 local candidates={};for _,rarity in ipairs({'common','uncommon','rare'})do for _,id in ipairs(r.data.cards.sourcePools.src[rarity])do
  for _,d in ipairs(r.data.cards.cards)do if d.id==id and d.type=='power'and not d.healing then candidates[#candidates+1]=id end end
 end end
 local expected=H.Run.roomStreams(r,1).cardRandomRng;local wanted=candidates[H.R.randomInt(expected,#candidates-1)+1]
 assert(H.Run.startCombat(r,'cultist_solo'));local s=r.combat;same(s.cardRandomRng,expected);eq(#s.hand,6)
 local created
 for _,e in ipairs(s.events)do if e.kind=='cards_created'and e.detail.relic=='enchiridion'then created=e;break end end
 assert(created);eq(created.detail.cardId,wanted);eq(#created.frame.hand,1)
 local card=H.card(r,wanted);eq(card.costForTurn,0);eq(H.C.cardDefinition(s,card).cost,0)
 assert(H.Run.endTurn(r));eq(card.costForTurn,nil);eq(H.C.cardDefinition(s,card).cost,H.C.combatBaseCost(s,card))
end)
test('Enchiridion leaves its source selection unchanged when missing selected card callback fails transactionally',function()
 local r=H.run({'Enchiridion'});local before=H.C.copy(r,{[r.data]=r.data});local old=H.E.emit
 H.E.emit=function(state,kind,detail)local value=old(state,kind,detail);if kind=='cards_created'and detail.relic=='enchiridion'then error('late Enchiridion')end;return value end
 local called=pcall(H.Run.startCombat,r,'cultist_solo');H.E.emit=old;eq(called,false);same(r,before)
 assert(H.Run.startCombat(r,'cultist_solo'));eq(r.phase,'combat')
end)
test('Enchiridion selected unsupported definition refuses the battle constructor without filtering or reroll',function()
 local r=H.run({'Enchiridion'});local pool={}
 for _,rarity in ipairs({'common','uncommon','rare'})do for _,id in ipairs(r.data.cards.sourcePools.src[rarity])do
  for _,d in ipairs(r.data.cards.cards)do if d.id==id and d.type=='power'and not d.healing then pool[#pool+1]=d end end
 end end
 local rng=H.Run.roomStreams(r,1).cardRandomRng;local selected=pool[H.R.randomInt(rng,#pool-1)+1];local original=selected.effects
 selected.effects={{op='unimplemented_enchiridion_fixture'}}
 local before=H.C.copy(r,{[r.data]=r.data});local called,why=pcall(H.Run.startCombat,r,'cultist_solo');eq(called,false)
 assert(tostring(why):find('card_content_unavailable',1,true));same(r,before)
 selected.effects=original;assert(H.Run.startCombat(r,'cultist_solo'))
end)
H.finish('ACT2_EVENT_RELIC_OPENING')
