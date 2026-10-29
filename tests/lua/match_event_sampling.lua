local H=dofile('tests/helpers/match_event.lua')
local vectors=dofile('tests/fixtures/match-event-vectors.lua')
local eq,same,test=H.eq,H.same,H.test
test('four actual class catalogues reproduce independent sampling, order and complete RNG continuations',function()
 for _,v in ipairs(vectors)do
  local r=H.Run.new(H.Data,v.seed,{experimental=true,campaign=true,character=v.character})
  r.floor=v.floor-1;r.act=v.floor<17 and 1 or 2;r.roomGeneration=9
  local oldMisc=r.miscRng;local beforeMisc=H.R.snapshot(oldMisc);local event={id='match_game'}
  local misc=H.Run.roomStreams(r,v.floor).miscRng
  assert(H.Match.prepare(r,event,misc,v.floor));eq(r.floor,v.floor-1);same(H.R.snapshot(oldMisc),beforeMisc)
  eq(#event.board,12);local actual={};for i,c in ipairs(event.board)do actual[i]=c.sourceCardId;eq(c.uid,nil)end
  same(actual,v.board);same(H.R.snapshot(r.cardRng),v.card);same(H.R.snapshot(misc),v.misc)
  same(H.R.snapshot(event.shuffleRng),v.shuffle);eq(r.cardRarityOffset,5)
  local order={};for i,id in ipairs(r.colorlessCardPool.cards)do for _,d in ipairs(r.data.cards.cards)do if d.id==id then order[i]=d.sourceId end end end
  same(order,v.colorless)
 end
end)
test('constructor previews six originals only, board stat copies stay detached and hidden',function()
 local original,count=H.Hooks.onPreviewObtainCard,0
 H.Hooks.onPreviewObtainCard=function(r,c,d)count=count+1;eq(c.uid,nil);original(r,c,d)end
 local r=H.fixture();H.Hooks.onPreviewObtainCard=original;eq(count,6)
 local before=H.C.copy(r.nodeFlow.event);local view=H.view(r);eq(view.board,nil);eq(#view.match.slots,12)
 for _,slot in ipairs(view.match.slots)do eq(slot.cardId,nil);eq(slot.sourceCardId,nil);eq(slot.upgrades,nil)end
 view.match.slots[1].cardId='strike';same(r.nodeFlow.event,before)
 for _,p in ipairs(H.pairs(r))do assert(r.nodeFlow.event.board[p[1]]~=r.nodeFlow.event.board[p[2]])end
end)
test('actual full pool is never capability-filtered or rerolled on missing drawn content',function()
 local r=H.fixture();r.data=H.C.copy(r.data);r.cardRng=H.R.fromSeed('42');local selected=r.nodeFlow.event.board[1].cardId
 -- Reject every possible source rare capability; no supported subset may be sampled instead.
 for _,d in ipairs(r.data.cards.cards)do if d.rarity=='rare'and d.color=='red'then d.effects={{op='match_missing'}}end end
 local before=H.C.copy(r,{[r.data]=r.data});local ok,why=H.Run.transaction(r,function(s)
  local event={id='match_game'};local misc=H.Run.roomStreams(s,8).miscRng;return H.Match.prepare(s,event,misc,8)
 end)
 eq(ok,false);eq(why,'card_content_unavailable');same(r,before);assert(selected)
end)
test('failure after colorless shuffle restores full pool, streams, UID and graph aliases',function()
 local r=H.fixture();r.data=H.C.copy(r.data);r.cardRng=H.R.fromSeed('42')
 for i=#r.data.cards.cards,1,-1 do if r.data.cards.cards[i].type=='curse'then table.remove(r.data.cards.cards,i)end end
 r.extension={pool=r.colorlessCardPool,cards=r.colorlessCardPool.cards};r.extension.owner=r.extension
 local owner,list=r.colorlessCardPool,r.colorlessCardPool.cards
 local before=H.C.copy(r,{[r.data]=r.data});local ok,why=H.Run.transaction(r,function(s)
  return H.Match.prepare(s,{id='match_game'},H.Run.roomStreams(s,8).miscRng,8)
 end)
 eq(ok,false);eq(why,'card_content_unavailable');same(r,before);eq(r.colorlessCardPool,owner)
 eq(r.colorlessCardPool.cards,list);eq(r.extension.pool,owner);eq(r.extension.cards,list);eq(r.extension.owner,r.extension)
end)
test('same-act entries preserve mutable order while a new act resets the full source pool',function()
 local r=H.fixture();local initial=H.C.copy(r.data.cards.sourcePools.colorlessRaw)
 local expected=H.C.copy(r.colorlessCardPool.cards);H.R.shuffle(H.Run.roomStreams(r,8).shuffleRng,expected)
 assert(H.Match.prepare(r,{id='match_game'},H.Run.roomStreams(r,8).miscRng,8));same(r.colorlessCardPool.cards,expected)
 r.act=2;H.R.shuffle(H.Run.roomStreams(r,18).shuffleRng,initial)
 assert(H.Match.prepare(r,{id='match_game'},H.Run.roomStreams(r,18).miscRng,18));same(r.colorlessCardPool.cards,initial);eq(r.colorlessCardPool.act,2)
end)
print('MATCH_EVENT_SAMPLING_PASS '..H.count)
