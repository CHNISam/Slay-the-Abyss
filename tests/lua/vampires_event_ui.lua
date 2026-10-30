-- Generated native controls and real Nodes commands; not actual device evidence.
local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq,same=H.test,H.eq,H.same
local function fixture(vial)
 local r=H.Run.new(H.Data,'42',{experimental=true,campaign=true,campaignProfile='competition-two-act'})
 r.act,r.floor=2,17;r.unknown.pools=H.Pool.new('full',false,2)
 if vial then assert(H.Run.obtainRelic(r,'blood_vial'))end
 local m=H.Map.generate(r.data,'42',2);local n=H.Map.available(m)[1]
 for _,node in ipairs(m.nodes)do if node.id==n.id then node.type='event';node.eventId='vampires'end end
 assert(H.Nodes.enter(r,m,n.id));return r,m
end
test('generated title and two or three choices show actual cost without a card picker',function()
 for _,vial in ipairs({false,true})do
  local r,m=fixture(vial);local before=H.snapshot(r);local ui,get,shown=H.setup(r,m);same(r,before)
  eq(get('eventView/name').text,'夜行者');assert(get('eventView/body').text:find('噬咬',1,true))
  assert(get('eventView/option1/description').text:find('24',1,true))
  eq(get('eventView/option1/title').text,'［接受］')
  eq(get('eventView/option2/title').text,vial and '［献出血瓶］' or '［拒绝］')
  eq(shown('eventView/option3'),vial);assert(not shown('pickerView'));eq(ui:holding(),false)
 end
end)
test('accept and blood vial clicks reach separate result and Leave; stale actions never pay twice',function()
 for _,vial in ipairs({false,true})do
  local r,m=fixture(vial);local ui,get,shown,click=H.setup(r,m)
  local key=vial and 'eventView/option2' or 'eventView/option1';local old=ui.actions[key].handler
  H.parity(r,m,vial and 'give_vial' or 'accept',nil,function()return click(key)end)
  eq(r.nodeFlow.event.stage,'result');eq(r.maxHp,vial and 80 or 56);eq(r.phase,'node');H.unchanged(r,m,old)
  eq(get('eventView/option1/title').text,'［离开］');eq(shown('eventView/option2'),false)
  local n=0;for _,card in ipairs(r.deck)do if card.cardId=='bite'then n=n+1 end end;eq(n,5)
  local leave=ui.actions['eventView/option1'].handler
  H.parity(r,m,'leave',nil,function()return click('eventView/option1')end);eq(r.phase,'map')
  H.unchanged(r,m,leave);assert(not shown('eventView'))
 end
end)
test('decline retains resources and still needs a separate Leave',function()
 local r,m=fixture(true);local before=H.snapshot(r);local ui,get,shown,click=H.setup(r,m)
 H.parity(r,m,'leave',nil,function()return click('eventView/option3')end);eq(r.phase,'node')
 for _,key in ipairs({'deck','relics','hp','maxHp','nextDeckUid','cardRng','eventRng'})do same(r[key],before[key])end
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end);eq(r.phase,'map')
end)
test('hide and resize retire held native callbacks while new input remains usable',function()
 for _,mode in ipairs({'hide','resize'})do
  local r,m=fixture();local ui,get,shown,click=H.setup(r,m);local old=ui.actions['eventView/option1'].handler
  local hit=get('eventView/option1/hit');hit:emit('down',90)
  if mode=='hide'then ui:setVisible(false);ui:setVisible(true)else ui:resize(1000,600)end
  H.unchanged(r,m,old);H.unchanged(r,m,function()hit:emit('up',90);return hit:emit('click',90)end)
  ui:render();H.parity(r,m,'accept',nil,function()return click('eventView/option1',91)end);eq(r.maxHp,56)
 end
end)
test('actual native failed command rolls back and permits a fresh successful exchange',function()
 local r,m=fixture(true);local ui,get,shown,click=H.setup(r,m);local original=H.Hooks.onObtainCard;local n=0
 H.Hooks.onObtainCard=function(staged,card,definition,api)
  n=n+1;local ok,why=original(staged,card,definition,api);if n%4==0 then return false,'vampires_ui_failure'end;return ok,why
 end
 local ok,why=pcall(H.parity,r,m,'give_vial',nil,function()return click('eventView/option2')end)
 H.Hooks.onObtainCard=original;assert(ok,why);eq(r.nodeFlow.event.stage,'intro');eq(r.maxHp,80)
 assert(shown('eventView'));H.parity(r,m,'give_vial',nil,function()return click('eventView/option2')end)
 eq(r.nodeFlow.event.stage,'result');eq(r.nodeFlow.event.lostRelicId,'blood_vial')
end)
H.finish('VAMPIRES_EVENT_UI')
