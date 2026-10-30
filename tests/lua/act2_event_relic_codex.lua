local H=dofile('tests/helpers/act2_event_relics.lua')
local eq,same,test=H.eq,H.same,H.test
local function expected(s)
 local pool={};for _,rarity in ipairs({'common','uncommon','rare'})do for _,id in ipairs(s.sourcePools.src[rarity])do if not s.catalog.cards[id].healing then pool[#pool+1]=id end end end
 local rng=H.R.cloneState(s.cardRandomRng);local cards,seen={},{}
 while #cards<3 do local id=pool[H.R.randomInt(rng,#pool-1)+1];if not seen[id]then cards[#cards+1]=id;seen[id]=true end end
 return cards,rng
end
test('Codex opens optional exact3 distinct HEALING-excluded source choices before Regret/discard; skip does NOT redraw',function()
 local r,s=H.battle({"Nilry's Codex"},{'regret','defend'});local cards,rng=expected(s);local hp=s.player.hp;local before=#s.hand
 assert(H.Run.endTurn(r));eq(s.turn,1);eq(s.player.hp,hp);eq(#s.hand,before);eq(s.pendingChoice.op,'codex');eq(s.pendingChoice.optional,true)
 for i,c in ipairs(s.pendingChoice.cards)do eq(c.cardId,cards[i]);eq(c.upgraded,false)end;same(s.cardRandomRng,rng)
 H.reject(r,function()return H.Run.endTurn(r)end,'card_choice_pending')
 local token=s.pendingChoice.token;assert(H.Run.chooseCard(r,token,0));eq(s.turn,2);eq(s.pendingChoice,nil);eq(s.player.hp,hp-before)
 same(s.cardRandomRng,rng)
end)
test('Codex pick inserts fresh normally-costed card using one exact random draw only when pile nonempty',function()
 local r,s=H.battle({"Nilry's Codex"},{'defend','defend','defend','defend','defend','defend'})
 assert(H.Run.endTurn(r));local p=s.pendingChoice;local id=p.cards[2].cardId;local nextUid=s.nextUid;local rng=H.R.cloneState(s.cardRandomRng)
 eq(#s.draw,1);H.R.randomInt(rng,0);assert(H.Run.chooseCard(r,p.token,2));eq(s.turn,2);same(s.cardRandomRng,rng)
 local generated;for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,c in ipairs(pile)do if c.uid==nextUid then generated=c end end end
 assert(generated);eq(generated.cardId,id);eq(generated.costForTurn,nil);eq(generated.deckUid,nil);eq(generated.upgraded,false)
 eq(#r.deck,6);eq(s.nextUid,nextUid+1)
end)
test('Codex empty draw insertion has no additional RNG and only begins once before real end-turn death',function()
 local r,s=H.battle({"Nilry's Codex"},{'regret'},function(staged)staged.hp=1 end)
 assert(H.Run.endTurn(r));local p=s.pendingChoice;local rng=H.R.cloneState(s.cardRandomRng);eq(#s.draw,0)
 assert(H.Run.chooseCard(r,p.token,1));eq(r.phase,'defeat');eq(s.player.hp,0);eq(s.turn,1);same(s.cardRandomRng,rng)
end)
test('Codex stale token/out-of-range refusal is pure and late insertion failure retains original choice/RNG for retry',function()
 local r,s=H.battle({"Nilry's Codex"},{'defend','defend','defend','defend','defend','defend'});assert(H.Run.endTurn(r));local p=s.pendingChoice
 H.reject(r,function()return H.Run.chooseCard(r,p.token+1,1)end,'stale_card_choice')
 H.reject(r,function()return H.Run.chooseCard(r,p.token,4)end,'invalid_card_choice')
 local before=H.C.copy(r,{[r.data]=r.data});local original=H.E.emit
 H.E.emit=function(state,kind,detail)local result=original(state,kind,detail);if kind=='cards_created'and detail.relic=='nilrys_codex'then error('late Codex')end;return result end
 local called=pcall(H.Run.chooseCard,r,p.token,1);H.E.emit=original;eq(called,false);same(r,before);eq(r.combat.pendingChoice,p)
 assert(H.Run.chooseCard(r,p.token,0));eq(s.turn,2)
end)
test('Codex first/second source draw failure leaves no partial choice or spent RNG/turn reset',function()
 local r,s=H.battle({"Nilry's Codex"},{'defend'});local before=H.C.copy(r,{[r.data]=r.data});local original=H.C.cardRandom;local calls=0
 H.C.cardRandom=function(state,max)calls=calls+1;local result=original(state,max);if calls==2 then error('Codex generation')end;return result end
 local called=pcall(H.Run.endTurn,r);H.C.cardRandom=original;eq(called,false);same(r,before);eq(calls,2)
 assert(H.Run.endTurn(r));eq(s.pendingChoice.op,'codex')
end)
test('Codex unsupported selected source outcome refuses without filtering, rerolling or spending the saved offer RNG',function()
 local r,s=H.battle({"Nilry's Codex"},{'defend'});assert(H.Run.endTurn(r));local p=s.pendingChoice
 local definition=s.catalog.cards[p.cards[1].cardId];local old=definition.effects;definition.effects={{op='unimplemented_codex_fixture'}}
 H.reject(r,function()return H.Run.chooseCard(r,p.token,1)end,'card_content_unavailable')
 eq(s.pendingChoice,p);definition.effects=old;assert(H.Run.chooseCard(r,p.token,0))
end)
test('pending actual AttackPotion Discovery blocks Codex end-turn without changing its source refusal reason or RNG',function()
 local r,s=H.battle({"Nilry's Codex"},{'defend'});assert(H.Run.obtainPotion(r,'attack_potion'));assert(H.Run.usePotion(r,1))
 eq(s.pendingChoice.op,'discover');H.reject(r,function()return H.Run.endTurn(r)end,'card_choice_pending')
 eq(s.relicEndTurnResolved,nil)
end)
test('legacy Orichalcum-only runs retain their existing path with no new relic dispatch markers',function()
 local r,s=H.battle({'Orichalcum'},{'defend'});assert(not require('abyss_relic_end_turn').needed(s));assert(H.Run.endTurn(r))
 eq(s.relicEndTurnResolved,nil);eq(s.relicPreCardsResolved,nil)
 local blocks=0;for _,event in ipairs(s.events)do if event.kind=='block'and event.detail.amount==6 then blocks=blocks+1 end end;eq(blocks,1)
end)
test('Orichalcum keeps exact held order around Codex pause and never duplicates legacy pre-card block',function()
 for _,ids in ipairs({{'Orichalcum',"Nilry's Codex"},{"Nilry's Codex",'Orichalcum'}})do
  local r,s=H.battle(ids,{'defend'});assert(H.Run.endTurn(r));eq(s.player.block,ids[1]=='Orichalcum'and 6 or 0)
  local p=s.pendingChoice;assert(H.Run.chooseCard(r,p.token,0));local blocks=0
  for _,event in ipairs(s.events)do if event.kind=='block'and event.detail.amount==6 then blocks=blocks+1 end end;eq(blocks,1)
 end
end)
H.finish('ACT2_EVENT_RELIC_CODEX')
