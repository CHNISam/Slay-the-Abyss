-- Existing generated control tree, native surface mocks, real Nodes/Run.
local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq,same=H.test,H.eq,H.same
local function fixture(deck)return H.fixture('back_to_basics',deck,0)end
local function selecting(deck)
 local r,m=fixture(deck);assert(H.Nodes.chooseEvent(r,'elegance'));return r,m
end
test('actual event rows show title, body, both source choices at zero gold and pure views',function()
 local r,m=fixture();local before=H.snapshot(r);local ui,get,shown=H.setup(r,m);same(r,before)
 eq(get('eventView/name').text,'古老文字');eq(get('eventView/body').text,r.nodeFlow.event.body)
 eq(get('eventView/option1/title').text,'［优雅］');eq(get('eventView/option2/title').text,'［简洁］')
 eq(ui.actions['eventView/option1'].enabled,true);eq(ui.actions['eventView/option2'].enabled,true)
 assert(not shown('back') and not shown('confirm'))
end)
test('Elegance source stage/UID command, no normal Cancel, result then separate Leave, no extra hold',function()
 local r,m=fixture({{uid=7,cardId='parasite'},{uid=8,cardId='strike',inBottleFlame=true}});r.hp,r.maxHp=80,80
 local ui,get,shown,click=H.setup(r,m);local old=ui.actions['eventView/option1'].handler
 H.parity(r,m,'elegance',nil,function()return click('eventView/option1')end)
 assert(shown('pickerView'));eq(#ui.removeRows,1);eq(r.gold,0);assert(not shown('back'))
 eq(ui.view.node.event.selection.canCancel,true);eq(ui.view.node.event.selection.forPurge,false)
 H.unchanged(r,m,old);H.unchanged(r,m,function()return ui:press('back')end)
 assert(click('pickerView/card1'));local stale=ui.actions.confirm.handler
 H.parity(r,m,'purge',7,function()return click('confirm')end)
 eq(r.maxHp,77);eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result');assert(shown('eventView'))
 assert(not shown('pickerView'));eq(ui:holding(),false);H.unchanged(r,m,stale)
 local leave=ui.actions['eventView/option1'].handler
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
 eq(r.phase,'map');assert(not shown('eventView'));eq(ui:holding(),false);H.unchanged(r,m,leave)
end)
test('Simplicity upgrades actual bottled starters without picker and keeps result Leave',function()
 local r,m=fixture({{uid=7,cardId='strike',inBottleTornado=true},{uid=8,cardId='bash'}})
 local ui,get,shown,click=H.setup(r,m);local stale=ui.actions['eventView/option2'].handler
 H.parity(r,m,'simplicity',nil,function()return click('eventView/option2')end)
 eq(r.deck[1].upgraded,true);eq(r.deck[1].inBottleTornado,true);eq(r.deck[2].upgraded,nil)
 assert(shown('eventView') and not shown('pickerView'));eq(get('eventView/option1/title').text,'［离开］')
 H.unchanged(r,m,stale);H.parity(r,m,'leave',nil,function()return click('eventView/option1')end);eq(r.phase,'map')
end)
test('zero eligible outcomes use result page without impossible picker',function()
 for _,option in ipairs({1,2})do
  local r,m=fixture({});local ui,get,shown,click=H.setup(r,m)
  H.parity(r,m,option==1 and 'elegance' or 'simplicity',nil,function()return click('eventView/option'..option)end)
  eq(r.nodeFlow.event.stage,'result');assert(shown('eventView') and not shown('pickerView'))
  eq(get('eventView/option1/title').text,'［离开］');assert(not shown('back'));eq(ui:holding(),false)
  H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
 end
end)
test('duplicate, removed, newly bottled UIDs invalidate confirm and fresh legal selection recovers',function()
 for _,kind in ipairs({'duplicate','deleted','bottled'})do
  local r,m=selecting({{uid=7,cardId='strike'},{uid=8,cardId='defend'}});local ui,get,shown,click=H.setup(r,m)
  assert(click('pickerView/card1'));local old=ui.actions.confirm.handler
  if kind=='duplicate'then r.deck[#r.deck+1]={uid=7,cardId='bash'}elseif kind=='deleted'then table.remove(r.deck,1)else r.deck[1].inBottleFlame=true end
  H.parity(r,m,'purge',7,function()return click('confirm')end)
  eq(ui.selected,nil);eq(ui.actions.confirm.enabled,false);H.unchanged(r,m,old)
  if kind=='duplicate'then H.unchanged(r,m,function()return click('pickerView/card1')end);table.remove(r.deck,#r.deck)end
  r.deck={{uid=8,cardId='defend'}};ui:render();assert(click('pickerView/card1'))
  H.parity(r,m,'purge',8,function()return click('confirm')end);eq(r.nodeFlow.event.stage,'result')
 end
end)
test('failed hook preserves selection stage and resources before a new successful command',function()
 local r,m=selecting({{uid=7,cardId='parasite'}});local ui,get,shown,click=H.setup(r,m);assert(click('pickerView/card1'))
 local original=H.Curses.onRemove
 H.Curses.onRemove=function(staged,card)original(staged,card);staged.gold=999;error('basics UI fault')end
 H.parity(r,m,'purge',7,function()return click('confirm')end);H.Curses.onRemove=original
 eq(r.gold,0);eq(r.nodeFlow.event.stage,'choose_card');assert(shown('pickerView'))
 H.parity(r,m,'purge',7,function()return click('confirm')end);eq(r.nodeFlow.event.stage,'result')
end)
test('V4 real owner keeps Elegance enabled and explanatory Simplicity refusal in generated UI',function()
 local r=H.Run.new(H.Data,'42',{experimental=true,campaign=true,character='HT'});r.act,r.floor=2,17;r.unknown.pools=H.Pool.new('full',false,2)
 local _,m=fixture();local node=H.Map.available(H.Map.generate(r.data,'42',2))[1]
 m=H.Map.generate(r.data,'42',2);for _,v in ipairs(m.nodes)do if v.id==node.id then v.type='event';v.eventId='back_to_basics'end end
 assert(H.Nodes.enter(r,m,node.id));local ui,get,shown,click=H.setup(r,m)
 eq(ui.actions['eventView/option2'].enabled,false);assert(get('eventView/option2/description').text:find('映射尚未确认'))
 H.unchanged(r,m,function()return click('eventView/option2')end)
 H.parity(r,m,'elegance',nil,function()return click('eventView/option1')end);assert(shown('pickerView'))
 assert(click('pickerView/card1'));local uid=ui.selected;H.parity(r,m,'purge',uid,function()return click('confirm')end)
 eq(r.nodeFlow.event.stage,'result')
end)
test('old held option/purge actions cannot redirect to another event owner or revive',function()
 local r,m=selecting({{uid=7,cardId='strike'}});local ui,get,shown,click=H.setup(r,m);assert(click('pickerView/card1'))
 local old=ui.actions.confirm.handler;local hit=get('confirm/hit');hit:emit('down',90)
 local nextRun,nextMap=H.fixture('beggar');ui.run,ui.map=nextRun,nextMap;ui:render()
 H.unchanged(nextRun,nextMap,old);H.unchanged(nextRun,nextMap,function()hit:emit('up',90);return hit:emit('click',90)end)
 ui.run,ui.map=r,m;ui:render();H.unchanged(r,m,old);eq(#r.deck,1);eq(r.gold,0)
end)
test('actual full source-pool draw enters generated NodeUI and resolves source result then Leave',function()
 local r=H.Run.new(H.Data,'42',{experimental=true,campaign=true});r.act,r.floor=2,17;r.unknown.pools=H.Pool.new('full',false,2)
 local counter;local Unknown=require('abyss_unknown')
 for n=0,127 do
  local state=H.Random.atCounter(r.eventSeed,n);local nextState=H.Random.cloneState(state)
  if Unknown.advancePc(Unknown.newPc(),H.Random.randomFloat(nextState),{})=='event'then
   local id=H.Pool.draw(H.Pool.new('full',false,2),{floor=18,gold=100,act=2,hp=80,relicCount=0,elapsedSeconds=0,cursed=false},H.Random.atCounter(r.eventSeed,nextState.counter))
   if id=='Back to Basics'then counter=n;break end
  end
 end
 assert(counter);r.eventRng=H.Random.atCounter(r.eventSeed,counter)
 local m=H.Map.generate(r.data,'42',2);local first=H.Map.available(m)[1]
 for _,node in ipairs(m.nodes)do if node.id==first.id then node.type='event';node.eventId=nil end end
 assert(H.Nodes.enter(r,m,first.id));eq(r.nodeFlow.event.originalId,'Back to Basics');eq(#r.unknown.pools.act,12)
 local ui,get,shown,click=H.setup(r,m);eq(get('eventView/name').text,'古老文字');assert(shown('eventView'))
 H.parity(r,m,'simplicity',nil,function()return click('eventView/option2')end)
 eq(r.nodeFlow.event.stage,'result');H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
 eq(r.phase,'map');eq(ui:holding(),false)
end)
print('BACK_TO_BASICS_UI '..H.count..' passed')
