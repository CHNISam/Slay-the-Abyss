local H=dofile('tests/helpers/match_event.lua')
local eq,same,test=H.eq,H.same,H.test
test('intro/rules/play/result reject early leave, cancellation and foreign tokens',function()
 local r=H.fixture();H.reject(r,'leave');H.reject(r,'cancel');H.reject(r,'continue',1)
 assert(H.choose(r,'continue'));eq(r.nodeFlow.event.stage,'rules');H.reject(r,'leave')
 assert(H.choose(r,'start'));eq(r.nodeFlow.event.stage,'play');H.reject(r,'leave');H.reject(r,'cancel')
 for _,bad in ipairs({1,true,{},'match:wrong'})do H.reject(r,'flip',bad,'stale_match_action')end
 eq(r.nodeFlow.event.attemptsLeft,5)
end)
test('pair attempts, matched permanent cards and final fifth award occur exactly once',function()
 local r=H.play(H.fixture());r.relics={'ceramic_fish'};local deck,gold,uid=#r.deck,r.gold,r.nextDeckUid
 local pairs=H.pairs(r)
 for n=1,5 do local p=pairs[n];local old=H.view(r).match.slots[p[1]].token
  assert(H.flip(r,p[1]));eq(r.nodeFlow.event.attemptsLeft,6-n)
  H.reject(r,'flip',old,'stale_match_action');assert(H.flip(r,p[2]))
  eq(r.nodeFlow.event.stage,'resolving');eq(H.view(r).match.waitSeconds,1)
  local token=H.view(r).match.resolveToken;H.reject(r,'flip',H.view(r).match.slots[1].token,'invalid_event_choice')
  assert(H.choose(r,'resolve',token));eq(r.nodeFlow.event.attemptsLeft,5-n);eq(#r.deck,deck+n)
  eq(r.deck[#r.deck].uid,uid+n-1);eq(r.gold,gold+n*9);H.reject(r,'resolve',token)
 end
 eq(r.nodeFlow.event.stage,'cleanup');eq(#r.nodeFlow.event.awards,5);H.reject(r,'flip','anything');H.reject(r,'leave')
 assert(H.finish(r));eq(r.nodeFlow.event.stage,'result')
 eq(H.Match.options(r,r.nodeFlow.event)[1].choice,'leave');assert(H.choose(r,'leave'))
end)
test('mismatches consume attempts and reset only the revealed pair without any obtain',function()
 local r=H.play(H.fixture());local a,b=1,2
 while r.nodeFlow.event.board[a].cardId==r.nodeFlow.event.board[b].cardId do b=b+1 end
 local before=H.C.copy(r.deck)
 for n=1,5 do assert(H.flip(r,a));assert(H.flip(r,b));eq(H.view(r).match.waitSeconds,1.25)
  assert(H.resolve(r));eq(r.nodeFlow.event.attemptsLeft,5-n);same(r.deck,before)
 end
 eq(r.nodeFlow.event.stage,'cleanup');eq(#r.nodeFlow.event.awards,0);assert(H.finish(r));eq(r.nodeFlow.event.stage,'result')
end)
test('Omamori blocks a matched curse once but still removes the pair and spends the attempt',function()
 local r=H.play(H.fixture());r.relics={'omamori'};r.relicCounters={omamori=2};local p
 for _,pair in ipairs(H.pairs(r))do local c=r.nodeFlow.event.board[pair[1]]
  for _,d in ipairs(r.data.cards.cards)do if d.id==c.cardId and d.type=='curse'then p=pair end end
 end
 assert(p);local count,uid=#r.deck,r.nextDeckUid
 assert(H.flip(r,p[1]));assert(H.flip(r,p[2]));assert(H.resolve(r))
 eq(#r.deck,count);eq(r.nextDeckUid,uid);eq(r.relicCounters.omamori,1);eq(r.nodeFlow.event.attemptsLeft,4)
 eq(r.nodeFlow.event.awards[1].blocked,true);local token=H.view(r).match.slots[p[1]].token
 H.reject(r,'flip',token,'match_slot_unavailable')
end)
test('Egg board preview is not a permanent obtain; fresh awards run actual upgrade and Fish hooks once',function()
 local r=H.play(H.fixture({relics={'molten_egg','ceramic_fish'}}));local p
 for _,pair in ipairs(H.pairs(r))do if r.nodeFlow.event.board[pair[1]].cardId=='twin_strike'then p=pair end end
 assert(p);eq(r.nodeFlow.event.board[p[1]].upgraded,true);eq(r.nodeFlow.event.board[p[2]].upgrades,1)
 local count,gold=#r.deck,r.gold;assert(H.flip(r,p[1]));assert(H.flip(r,p[2]));assert(H.resolve(r))
 eq(#r.deck,count+1);eq(r.gold,gold+9);eq(r.deck[#r.deck].upgraded,true);eq(r.deck[#r.deck].upgrades,1)
 local seed
 for n=0,128 do local rng=H.R.fromSeed(tostring(n));H.R.randomInt(rng,15)
  if r.data.cards.sourcePools.reward.uncommon[H.R.randomInt(rng,35)+1]=='searing_blow'then seed=tostring(n);break end
 end
 assert(seed,'bounded actual Searing Blow sample missing')
 local s=H.play(H.fixture({seed=seed,relics={'molten_egg'}}));local pair
 for _,candidate in ipairs(H.pairs(s))do if s.nodeFlow.event.board[candidate[1]].cardId=='searing_blow'then pair=candidate end end
 assert(pair);eq(s.nodeFlow.event.board[pair[1]].upgrades,1)
 assert(H.flip(s,pair[1]));assert(H.flip(s,pair[2]));assert(H.resolve(s))
 local obtained=s.deck[#s.deck];eq(obtained.searingBlowCopyUpgrades,1);eq(obtained.upgrades,2);eq(obtained.upgraded,true)
end)
test('late obtain refusal/exception/UID collision roll back pair, deck, relic effects and every stream',function()
 for _,kind in ipairs({'refuse','throw','uid'})do
  local r=H.play(H.fixture());r.relics={'ceramic_fish'};local p=H.pairs(r)[1]
  assert(H.flip(r,p[1]));assert(H.flip(r,p[2]));local original=H.Hooks.onObtainCard
  if kind=='uid'then r.nextDeckUid=r.deck[1].uid else
   H.Hooks.onObtainCard=function(owner,c,d,api)
    original(owner,c,d,api);owner.hp=1;H.R.randomInt(owner.cardRng,99);H.R.randomInt(owner.miscRng,99)
    if kind=='throw'then error('late Match obtain')end;return false,'match_late_refusal'
   end
  end
  H.reject(r,'resolve',H.view(r).match.resolveToken,kind=='uid'and'invalid_deck_uid'or kind=='throw'and'transaction_failed'or'match_late_refusal')
  H.Hooks.onObtainCard=original;if kind=='uid'then r.nextDeckUid=100 end
  assert(H.resolve(r));eq(r.nodeFlow.event.attemptsLeft,4);eq(#r.nodeFlow.event.awards,1)
 end
end)
test('stale room generation, replaced flow, complete node and invalid source identity never award',function()
 local r=H.play(H.fixture());local token=H.view(r).match.slots[1].token;r.roomGeneration=r.roomGeneration+1
 H.reject(r,'flip',token,'stale_match_action')
 local current=H.play(H.fixture());local p=H.pairs(current)[1];assert(H.flip(current,p[1]));assert(H.flip(current,p[2]))
 current.nodeFlow.event.board[p[1]].sourceCardId='wrong source'
 H.reject(current,'resolve',H.view(current).match.resolveToken,'card_content_unavailable')
 current.nodeFlow.complete=true;H.reject(current,'resolve',H.view(current).match.resolveToken,'no_pending_node')
end)
print('MATCH_EVENT_COMMANDS_PASS '..H.count)
