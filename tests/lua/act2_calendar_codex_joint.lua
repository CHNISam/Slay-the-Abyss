-- Controlled component checkpoint: actual Run obtains all relics and starts
-- combat with its real opening effects. Only turn7/Calendar counter7 and the
-- final enemy's52HP are set below to bound the source end-turn order test.
-- This is NOT evidence of naturally reaching turn7, a natural win, or native UI.
-- No card pools, deck after opening, RNG owners, queue or choice are replaced.
local H=dofile('tests/helpers/act2_event_relics.lua')
local eq,same,test=H.eq,H.same,H.test
local function checkpoint(ids)
 local r,s=H.battle(ids,{'defend','defend','defend','defend','defend','defend'})
 eq(s.relicCounters.stone_calendar,1);eq(s.player.statuses.plated_armor,4);eq(s.player.block,0)
 s.turn=7;s.relicCounters.stone_calendar=7;s.enemies[1].hp=52
 return r,s
end
local function expectedOffer(s)
 local pool={}
 for _,rarity in ipairs({'common','uncommon','rare'})do
  for _,id in ipairs(s.sourcePools.src[rarity])do if not s.catalog.cards[id].healing then pool[#pool+1]=id end end
 end
 local rng=H.R.cloneState(s.cardRandomRng);local cards,seen={},{}
 while #cards<3 do local id=pool[H.R.randomInt(rng,#pool-1)+1];if not seen[id]then cards[#cards+1]=id;seen[id]=true end end
 return cards,rng
end
local function observations(s)
 local result={hits=0,blocks=0,offers=0,resolved=0,created=0}
 for i,e in ipairs(s.events)do if e.frame.turn==7 then
  if e.kind=='damage'and e.detail.target==s.enemies[1].id and e.detail.amount==52 then
   result.hits=result.hits+1;result.hitAt=i;eq(e.detail.source,nil);assert(#e.frame.hand>0)
  elseif e.kind=='block'and e.detail.target==s.player.id and e.detail.amount==4 then
   result.blocks=result.blocks+1;result.blockAt=i
  elseif e.kind=='card_choice'and e.detail.op=='codex'then result.offers=result.offers+1;result.offerAt=i
  elseif e.kind=='card_choice_resolved'and e.detail.op=='codex'then result.resolved=result.resolved+1;result.resolveAt=i
  elseif e.kind=='cards_created'and e.detail.relic=='nilrys_codex'then result.created=result.created+1;result.createdAt=i end
 end end
 return result
end
local function terminal(r,s,hp)
 eq(r.phase,'reward');eq(s.turn,7);eq(s.enemies[1].hp,0);eq(s.player.hp,hp);eq(s.player.block,4)
 eq(s.pendingChoice,nil);eq(s.actionQueue,nil);eq(s.relicEndTurnResolved,7);eq(s.relicPreCardsResolved,7)
 local result=observations(s);eq(result.hits,1);eq(result.blocks,1);assert(result.hitAt<result.blockAt)
 H.reject(r,function()return H.Run.endTurn(r)end,'not_in_combat')
 return result
end
test('Calendar before Codex lethal suppresses the later offer/RNG but retains source queued Plated block',function()
 local r,s=checkpoint({'StoneCalendar',"Nilry's Codex",'Thread and Needle'})
 local rng=H.R.cloneState(s.cardRandomRng);local serial=s.choiceSerial;local uid=s.nextUid;local hp=s.player.hp
 assert(H.Run.endTurn(r));local result=terminal(r,s,hp)
 eq(result.offers,0);eq(result.resolved,0);eq(result.created,0);eq(s.choiceSerial,serial);eq(s.nextUid,uid)
 same(s.cardRandomRng,rng)
end)
test('Codex before Calendar pauses then real pick or skip resumes the remaining lethal Calendar once without a reoffer',function()
 for _,selection in ipairs({0,2})do
  local r,s=checkpoint({"Nilry's Codex",'StoneCalendar','Thread and Needle'})
  local cards,rng=expectedOffer(s);local uid=s.nextUid;local hp=s.player.hp
  assert(H.Run.endTurn(r));eq(r.phase,'combat');eq(s.turn,7);eq(s.enemies[1].hp,52);eq(s.player.block,0);eq(s.player.hp,hp)
  local p=s.pendingChoice;eq(p.op,'codex');eq(p.optional,true);eq(#p.cards,3);eq(s.actionQueue.paused,true)
  for i,c in ipairs(p.cards)do eq(c.cardId,cards[i])end;same(s.cardRandomRng,rng)
  local paused=observations(s);eq(paused.hits,0);eq(paused.blocks,0);eq(paused.offers,1);eq(paused.resolved,0)
  H.reject(r,function()return H.Run.endTurn(r)end,'card_choice_pending')
  -- The real single insertion is one bounded(size-1) draw; source Codex never
  -- rerolls its three offers when retrieving a choice. Skip draws nothing.
  eq(#s.draw,1);if selection~=0 then H.R.randomInt(rng,0)end
  assert(H.Run.chooseCard(r,p.token,selection));local result=terminal(r,s,hp)
  eq(result.offers,1);eq(result.resolved,1);assert(result.offerAt<result.resolveAt and result.resolveAt<result.hitAt)
  eq(result.created,selection==0 and 0 or 1);eq(s.choiceSerial,p.token);eq(s.nextUid,uid+(selection==0 and 0 or 1));same(s.cardRandomRng,rng)
  if selection~=0 then
   assert(result.createdAt<result.resolveAt);local generated
   for _,c in ipairs(s.draw)do if c.uid==uid then generated=c end end
   assert(generated);eq(generated.cardId,cards[selection]);eq(generated.costForTurn,nil);eq(generated.deckUid,nil)
  end
  H.reject(r,function()return H.Run.chooseCard(r,p.token,selection)end,'not_in_combat')
 end
end)
H.finish('ACT2_CALENDAR_CODEX_JOINT')
