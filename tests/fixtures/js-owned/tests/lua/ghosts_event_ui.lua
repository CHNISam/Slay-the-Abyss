-- Generated controls, real public Nodes/Run, native methods mocked only.
local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq,same=H.test,H.eq,H.same
local function fixture()return H.fixture('ghosts')end

test('title, five-card cached cost, pure detached views and no picker/back/confirm',function()
 local r,m=fixture();local before=H.snapshot(r);local ui,get,shown=H.setup(r,m);same(r,before)
 eq(get('eventView/name').text,'幽灵');eq(get('eventView/body').text,r.nodeFlow.event.body)
 eq(get('eventView/option1/title').text,'［接受］');eq(get('eventView/option2/title').text,'［拒绝］')
 assert(get('eventView/option1/description').text:find('40',1,true));assert(get('eventView/option1/description').text:find('5',1,true))
 assert(not shown('pickerView') and not shown('back') and not shown('confirm'));eq(ui:holding(),false)
end)
test('accept gives five once; real result body states actual before/after, distinct Leave no hold',function()
 local r,m=fixture();local old=#r.deck;local ui,get,shown,click=H.setup(r,m);local stale=ui.actions['eventView/option1'].handler
 H.parity(r,m,'accept',nil,function()return click('eventView/option1')end)
 eq(#r.deck,old+5);eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result');eq(r.maxHp,40)
 local body=get('eventView/body').text;assert(body:find('5',1,true) and body:find('80',1,true) and body:find('40',1,true))
 assert(shown('eventView') and not shown('pickerView'));eq(get('eventView/option1/title').text,'［离开］');eq(ui:holding(),false)
 H.unchanged(r,m,stale);local leave=ui.actions['eventView/option1'].handler
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end);eq(r.phase,'map');eq(ui:holding(),false)
 assert(not shown('eventView'));H.unchanged(r,m,leave);eq(#r.deck,old+5)
end)
test('decline is a resource-free result page, then source Leave',function()
 local r,m=fixture();local before=H.snapshot(r);local ui,get,shown,click=H.setup(r,m)
 H.parity(r,m,'leave',nil,function()return click('eventView/option2')end);eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node')
 same(r.deck,before.deck);same(r.potions,before.potions);eq(r.hp,before.hp);eq(r.maxHp,before.maxHp);eq(r.gold,before.gold)
 eq(get('eventView/option1/title').text,'［离开］');assert(not shown('pickerView'));eq(ui:holding(),false)
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end);eq(r.phase,'map')
end)
test('real intro Fruit Juice does not reprice; rerender/resize retires old action and actual result uses85to45',function()
 local r,m=fixture();local ui,get,shown,click=H.setup(r,m);local old=ui.actions['eventView/option1'].handler
 r.potions={'fruit_juice'};assert(H.Run.usePotion(r,1));ui:render();H.unchanged(r,m,old)
 assert(get('eventView/option1/description').text:find('40',1,true));eq(r.nodeFlow.event.hpLoss,40)
 local resized=ui.actions['eventView/option1'].handler;ui:resize(1600,900);H.unchanged(r,m,resized)
 H.parity(r,m,'accept',nil,function()return click('eventView/option1')end);eq(r.maxHp,45)
 assert(get('eventView/body').text:find('85',1,true));assert(get('eventView/body').text:find('45',1,true));assert(not shown('pickerView'))
end)
test('stage/run/map/flow/generation/act/floor/phase/node changes retire saved callbacks without revival',function()
 for _,key in ipairs({'stage','run','map','flow','generation','act','floor','phase','node'})do
  local r,m=fixture();local ui=H.setup(r,m);local old=ui.actions['eventView/option1'].handler;local restore
  if key=='stage'then r.nodeFlow.event.stage='result';restore=function()r.nodeFlow.event.stage='intro'end
  elseif key=='run'then local other=fixture();ui.run=other;restore=function()ui.run=r end
  elseif key=='map'then ui.map=H.Copy(m);restore=function()ui.map=m end
  elseif key=='flow'then local f=r.nodeFlow;r.nodeFlow=H.Copy(f);restore=function()r.nodeFlow=f end
  elseif key=='generation'then local n=r.roomGeneration;r.roomGeneration=n+1;restore=function()r.roomGeneration=n end
  elseif key=='act'then r.act=3;restore=function()r.act=2 end
  elseif key=='floor'then r.floor=19;restore=function()r.floor=18 end
  elseif key=='phase'then r.phase='map';restore=function()r.phase='node'end
  else local n=r.nodeFlow.id;r.nodeFlow.id='other';restore=function()r.nodeFlow.id=n end end
  H.unchanged(r,m,old);restore();H.unchanged(r,m,old);ui:render()
 end
end)
test('hide, resize, detached/rebound control and held native release cannot revive accept',function()
 for _,mode in ipairs({'hide','resize','detach','rebind'})do
  local r,m=fixture();local ui,get,shown,click=H.setup(r,m);local old=ui.actions['eventView/option1'].handler
  local option=get('eventView/option1');local hit=get('eventView/option1/hit');hit:emit('down',90)
  if mode=='hide'then ui:setVisible(false);H.unchanged(r,m,old);ui:setVisible(true)
  elseif mode=='resize'then ui:resize(1000,600)
  elseif mode=='detach'then local p=option.parent;option.parent=nil;H.unchanged(r,m,old);option.parent=p;ui:render()
  else option.children.hit=H.control({name='hit'},option);H.unchanged(r,m,old);option.children.hit=hit;ui:render()end
  H.unchanged(r,m,old);H.unchanged(r,m,function()hit:emit('up',90);return hit:emit('click',90)end)
  ui:render();H.parity(r,m,'accept',nil,function()return click('eventView/option1',91)end);eq(r.nodeFlow.event.stage,'result')
 end
end)
test('late fourth obtain refusal keeps intro/resources and next fresh command recovers',function()
 local r,m=fixture();local ui,get,shown,click=H.setup(r,m);local original=H.Hooks.onObtainCard;local n=0
 H.Hooks.onObtainCard=function(staged,card,definition,api)n=n+1;original(staged,card,definition,api);if n%4==0 then return false,'ui_ghosts_late_refusal'end;return true end
 H.parity(r,m,'accept',nil,function()return click('eventView/option1')end);H.Hooks.onObtainCard=original
 eq(r.maxHp,80);eq(r.nodeFlow.event.stage,'intro');assert(shown('eventView') and not shown('pickerView'))
 H.parity(r,m,'accept',nil,function()return click('eventView/option1')end);eq(r.maxHp,40);eq(r.nodeFlow.event.stage,'result')
end)
test('real full source draw reaches generated Ghosts controls, result then Leave',function()
 local r=H.Run.new(H.Data,'42',{experimental=true,campaign=true});r.act,r.floor=2,17;r.unknown.pools=H.Pool.new('full',false,2)
 local counter;local Unknown=require('abyss_unknown')
 for n=0,127 do local state=H.Random.atCounter(r.eventSeed,n);local nextState=H.Random.cloneState(state)
  if Unknown.advancePc(Unknown.newPc(),H.Random.randomFloat(nextState),{})=='event'then
   local id=H.Pool.draw(H.Pool.new('full',false,2),{floor=18,gold=100,act=2,hp=80,relicCount=0,elapsedSeconds=0,cursed=false},H.Random.atCounter(r.eventSeed,nextState.counter))
   if id=='Ghosts'then counter=n;break end
  end
 end
 assert(counter);r.eventRng=H.Random.atCounter(r.eventSeed,counter)
 local m=H.Map.generate(r.data,'42',2);local first=H.Map.available(m)[1]
 for _,node in ipairs(m.nodes)do if node.id==first.id then node.type='event';node.eventId=nil end end
 assert(H.Nodes.enter(r,m,first.id));eq(r.nodeFlow.event.originalId,'Ghosts');eq(#r.unknown.pools.act,12)
 local ui,get,shown,click=H.setup(r,m);eq(get('eventView/name').text,'幽灵');assert(shown('eventView'))
 H.parity(r,m,'accept',nil,function()return click('eventView/option1')end)
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end);eq(r.phase,'map');eq(ui:holding(),false)
end)
print('GHOSTS_EVENT_UI '..H.count..' passed')
