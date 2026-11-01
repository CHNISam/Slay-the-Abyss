-- Generated UI/public Nodes integration; room is staged, not native/campaign evidence.
local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq,same=H.test,H.eq,H.same

test('Joust five pages use the generated event controls and return to map only after result Leave',function()
 local r,m=H.fixture('joust',nil,100)
 local ui,get,shown,click=H.setup(r,m)
 eq(get('eventView/name').text,'决斗');eq(r.nodeFlow.event.stage,'halt')
 local before=H.snapshot(r);ui:render();same(r,before)
 local start=H.Random.snapshot(r.miscRng).counter
 H.parity(r,m,'continue',nil,function()return click('eventView/option1')end)
 eq(r.nodeFlow.event.stage,'explanation');eq(r.gold,100)
 H.parity(r,m,'bet_for',nil,function()return click('eventView/option2')end)
 eq(r.gold,50);eq(r.nodeFlow.event.stage,'pre_joust');eq(r.miscRng.counter,start)
 H.parity(r,m,'continue',nil,function()return click('eventView/option1')end)
 eq(r.nodeFlow.event.stage,'joust');eq(r.miscRng.counter,start+1)
 H.parity(r,m,'continue',nil,function()return click('eventView/option1')end)
 eq(r.nodeFlow.event.stage,'complete');eq(r.phase,'node');eq(r.miscRng.counter,start+1)
 local gold=r.gold
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
 eq(r.phase,'map');eq(r.gold,gold);eq(ui:holding(),false)
end)
test('stale event handlers cannot pay again or resolve another owner',function()
 local r,m=H.fixture('joust',nil,100);local ui,get,shown,click=H.setup(r,m)
 assert(click('eventView/option1'));local stale=ui.actions['eventView/option2'].handler
 assert(click('eventView/option2'));eq(r.gold,50)
 H.unchanged(r,m,stale)
 local other,otherMap=H.fixture('beggar');ui.run,ui.map=other,otherMap;ui:render()
 H.unchanged(other,otherMap,stale)
end)
print('JOUST_UI '..H.count..' passed')
