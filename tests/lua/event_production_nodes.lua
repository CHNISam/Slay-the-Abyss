-- Controlled room boundaries with the real map/Nodes/Run transaction owners.
local H=dofile('tests/helpers/library_event.lua')
local eq,same,test=H.eq,H.same,H.test
local function enter(id)
 local r,m,key=H.fixture(nil,nil,nil,true)
 local chosen
 for _,node in ipairs(m.nodes)do if node.id==key then node.eventId=id;chosen=node end end
 local ok,why=H.Nodes.enter(r,m,key);assert(ok,why)
 return r,m,chosen
end
test('Duplicator is admitted by real Nodes and completes with one permanent copy and unchanged command RNG',function()
 eq(H.Pool.contentId.Duplicator,'duplicator')
 local r,m=enter('duplicator');local n=#r.deck;local uid=r.deck[1].uid;local before=H.snap(r)
 assert(H.Nodes.chooseEvent(r,'copy'));eq(r.nodeFlow.event.stage,'choose_card')
 local view=H.Nodes.view(r,m).node.event
 eq(#view.copyCards,n);eq(view.selection.canCancel,false)
 view.copyCards[1].cardId='bad-detached-value';eq(r.deck[1].cardId,before.deck[1].cardId)
 assert(H.Nodes.chooseEvent(r,'select',uid));eq(#r.deck,n+1)
 eq(r.nodeFlow.event.stage,'result');eq(r.deck[n+1].cardId,before.deck[1].cardId)
 H.reject(r,'select',uid,'invalid_event_choice')
 assert(H.Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');eq(r.nodeFlow.complete,true)
 same(r.cardRng,before.cardRng);same(r.eventRng,before.eventRng);same(r.miscRng,before.miscRng)
end)
test('Match receives the staged room floor and runs all five attempts through Nodes without exposing concealed card IDs',function()
 eq(H.Pool.contentId['Match and Keep!'],'match_game')
 local r,m,node=enter('match_game');local event=r.nodeFlow.event
 eq(event.roomFloor,node.floor);eq(r.floor,node.floor);eq(event.attemptsLeft,5)
 assert(H.Nodes.chooseEvent(r,'continue'));assert(H.Nodes.chooseEvent(r,'start'))
 local count=#r.deck
 for attempt=1,5 do
  local a,b
  for i,card in ipairs(event.board)do
   if not event.removed[i]then
    for j=i+1,#event.board do
     if not event.removed[j]and event.board[j].cardId==card.cardId then a,b=i,j;break end
    end
   end
   if a then break end
  end
  assert(a and b)
  local view=H.Nodes.view(r,m).node.event
  eq(view.board,nil);eq(view.match.slots[a].cardId,nil)
  assert(H.Nodes.chooseEvent(r,'flip',view.match.slots[a].token))
  view=H.Nodes.view(r,m).node.event
  assert(H.Nodes.chooseEvent(r,'flip',view.match.slots[b].token))
  view=H.Nodes.view(r,m).node.event;eq(view.stage,'resolving')
  assert(H.Nodes.chooseEvent(r,'resolve',view.match.resolveToken))
  event=r.nodeFlow.event;eq(event.attemptsLeft,5-attempt);eq(#r.deck,count+attempt)
 end
 eq(event.stage,'cleanup');H.reject(r,'leave',nil,'invalid_event_choice')
 local view=H.Nodes.view(r,m).node.event
 assert(H.Nodes.chooseEvent(r,'finish',view.match.completionToken));eq(r.nodeFlow.event.stage,'result')
 assert(H.Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');eq(r.nodeFlow.complete,true)
end)
H.finish('EVENT_PRODUCTION_NODES')
