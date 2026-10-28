-- Real Nodes/Run and generated controls; no native device or natural-run claim.
local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq=H.test,H.eq
test('registered Nest enters intro and existing controls retain separate gold result and leave',function()
 eq(H.Pool.contentId.Nest,'nest')
 local r,m=H.fixture('nest');local before=H.snapshot(r)
 local ui,get,shown,click=H.setup(r,m);H.same(r,before)
 eq(r.nodeFlow.event.stage,'intro');assert(shown('eventView'));eq(get('eventView/name').text,'未知事件')
 local old=ui.actions['eventView/option1'].handler
 H.parity(r,m,'continue',nil,function()return click('eventView/option1')end)
 eq(r.nodeFlow.event.stage,'choice');H.unchanged(r,m,old)
 local gold=r.gold;local stale=ui.actions['eventView/option1'].handler
 H.parity(r,m,'gold',nil,function()return click('eventView/option1')end)
 eq(r.gold,gold+99);eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result')
 H.unchanged(r,m,stale)
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
 eq(r.phase,'map');assert(not shown('eventView'))
end)
test('dagger public option applies damage and actual permanent card then keeps result visible',function()
 local r,m=H.fixture('nest');local ui,get,shown,click=H.setup(r,m)
 assert(click('eventView/option1'));local hp,n=r.hp,#r.deck
 H.parity(r,m,'dagger',nil,function()return click('eventView/option2')end)
 eq(r.hp,hp-6);eq(#r.deck,n+1);eq(r.deck[#r.deck].cardId,'ritual_dagger')
 eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node');assert(shown('eventView'))
 assert(click('eventView/option1'));eq(r.phase,'map')
end)
test('lethal normal damage finalizes defeat through actual Nodes rather than leaving a clickable event',function()
 local r,m=H.fixture('nest');r.hp=6
 assert(H.Nodes.chooseEvent(r,'continue'))
 local n=#r.deck;local ok,why=H.Nodes.chooseEvent(r,'dagger')
 eq(ok,true);eq(why,'defeat');eq(r.hp,0);eq(r.phase,'defeat');eq(#r.deck,n+1)
 H.unchanged(r,m,function()return H.Nodes.chooseEvent(r,'leave')end)
end)
test('old event option cannot act on a replaced owner or resurrect after restoration',function()
 local r,m=H.fixture('nest');local ui=H.setup(r,m)
 local old=ui.actions['eventView/option1'].handler
 local other,map=H.fixture('nest');ui.run,ui.map=other,map;ui:render()
 H.unchanged(other,map,old);ui.run,ui.map=r,m;ui:render();H.unchanged(r,m,old)
 eq(r.nodeFlow.event.stage,'intro');eq(other.nodeFlow.event.stage,'intro')
end)
test('unmodified full Act2 source draw resolves Nest without explicit event override',function()
 local r=H.Run.new(H.Data,'42',{experimental=true,campaign=true});r.act,r.floor=2,17
 r.unknown.pools=H.Pool.new('full',false,2)
 local counter;local Unknown=require('abyss_unknown')
 for n=0,255 do
  local state=H.Random.atCounter(r.eventSeed,n);local nextState=H.Random.cloneState(state)
  if Unknown.advancePc(Unknown.newPc(),H.Random.randomFloat(nextState),{})=='event'then
   local id=H.Pool.draw(H.Pool.new('full',false,2),{floor=18,gold=100,act=2,hp=80,relicCount=0,elapsedSeconds=0,cursed=false},H.Random.atCounter(r.eventSeed,nextState.counter))
   if id=='Nest'then counter=n;break end
  end
 end
 assert(counter,'bounded source draw for Nest');r.eventRng=H.Random.atCounter(r.eventSeed,counter)
 local m=H.Map.generate(r.data,'42',2);local first=H.Map.available(m)[1]
 for _,node in ipairs(m.nodes)do if node.id==first.id then node.type='event';node.eventId=nil end end
 assert(H.Nodes.enter(r,m,first.id));eq(r.nodeFlow.event.originalId,'Nest');eq(#r.unknown.pools.act,12)
 local ui,get,shown,click=H.setup(r,m);assert(shown('eventView'))
 H.parity(r,m,'continue',nil,function()return click('eventView/option1')end)
 H.parity(r,m,'gold',nil,function()return click('eventView/option1')end)
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end);eq(r.phase,'map')
end)
print('NEST_EVENT_UI 5 passed')
