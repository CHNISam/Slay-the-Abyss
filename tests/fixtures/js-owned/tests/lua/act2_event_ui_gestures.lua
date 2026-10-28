local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq=H.test,H.eq
local function ready()
 local r,m=H.selecting({{uid=7,cardId='strike'},{uid=8,cardId='defend'}})
 local ui,get,shown,click,changes,root,host=H.setup(r,m);assert(click('pickerView/card1'))
 return r,m,ui,get,shown,click,changes,root,host
end

test('held/repeated donation cannot become second confirmation after rerender',function()
 local r,m=H.fixture('beggar');local ui,get,shown,click=H.setup(r,m);local hit=get('eventView/option1/hit')
 hit:emit('down',31);local old=ui.actions['eventView/option1'].handler
 H.unchanged(r,m,function()return click('eventView/option1',32)end)
 assert(ui:press('eventView/option1'));eq(r.gold,25);eq(r.nodeFlow.event.stage,'gave_money')
 H.unchanged(r,m,function()hit:emit('up',31);return hit:emit('click',31)end)
 H.unchanged(r,m,old);eq(r.nodeFlow.event.stage,'gave_money');assert(click('eventView/option1',33));eq(r.nodeFlow.event.stage,'choose_card')
end)
test('foreign touch, held picker-to-confirm, end-drag/exit cancel and repeated clicks never remove',function()
 local r,m,ui,get,shown,click=ready();local hit=get('confirm/hit')
 for _,cancel in ipairs({'endDrag','exit'})do
  hit:emit('down',4);hit:emit(cancel,4);hit:emit('up',4)
  H.unchanged(r,m,function()return hit:emit('click',4)end)
 end
 hit:emit('down',5);hit:emit('up',6)
 H.unchanged(r,m,function()return hit:emit('click',6)end)
 hit:emit('up',5);assert(hit:emit('click',5));eq(#r.deck,1);eq(r.gold,25)
 H.unchanged(r,m,function()return hit:emit('click',5)end)
end)
test('resize/hide clears held gestures, invalidates captured action, fresh visible input recovers',function()
 local r,m,ui,get,shown,click=ready();local hit=get('confirm/hit')
 for _,interrupt in ipairs({'resize','hide'})do
  ui:render();local old=ui.actions.confirm.handler;hit:emit('down',7)
  if interrupt=='resize' then ui:resize(1920,1080)else ui:setVisible(false);ui:setVisible(true)end
  H.unchanged(r,m,function()hit:emit('up',7);return hit:emit('click',7)end);H.unchanged(r,m,old)
 end
 assert(ui.actions.confirm.observe(),'fresh unhidden action must recover without an extra render')
 ui:render();H.parity(r,m,'purge',7,function()return click('confirm')end)
end)
test('render-time run/map/flow/event/stage/generation/UID identity invalidation cannot revive on repair',function()
 local r,m,ui,get,shown,click=ready()
 local cases={
  function()local v=ui.run;ui.run=H.snapshot(r);return function()ui.run=v end end,
  function()local v=ui.map;ui.map=H.Copy(m);return function()ui.map=v end end,
  function()local v=r.nodeFlow;r.nodeFlow=H.Copy(v);return function()r.nodeFlow=v end end,
  function()local v=r.nodeFlow.event;r.nodeFlow.event=H.Copy(v);return function()r.nodeFlow.event=v end end,
  function()local v=r.roomGeneration;r.roomGeneration=v+1;return function()r.roomGeneration=v end end,
  function()local v=r.nodeFlow.event.stage;r.nodeFlow.event.stage='gave_money';return function()r.nodeFlow.event.stage=v end end,
  function()local v=ui.selected;ui.selected=8;return function()ui.selected=v end end,
  function()local v=r.nodeFlow.id;r.nodeFlow.id='foreign';return function()r.nodeFlow.id=v end end,
 }
 for _,mutate in ipairs(cases)do
  ui:render();local old=ui.actions.confirm.handler;local hit=get('confirm/hit');hit:emit('down',8)
  local repair=mutate();ui:update(0);repair()
  H.unchanged(r,m,function()hit:emit('up',8);return hit:emit('click',8)end);H.unchanged(r,m,old)
 end
 ui:render();H.parity(r,m,'purge',7,function()return click('confirm')end)
end)
test('hidden/detached/foreign controls or ancestors refuse and observed invalidity stays retired after repair',function()
 local r,m,ui,get,shown,click,changes,root,host=ready()
 local cases={
  function()root.visible=false;return function()root.visible=true end end,
  function()host.visible=false;return function()host.visible=true end end,
  function()local v=root.parent;root.parent=nil;return function()root.parent=v end end,
  function()local v=host.children.nodePanel;host.children.nodePanel={};return function()host.children.nodePanel=v end end,
  function()local v=get('confirm').parent;get('confirm').parent={visible=true};return function()get('confirm').parent=v end end,
  function()local v=root.children.confirm;root.children.confirm=H.control({name='confirm'},root);return function()root.children.confirm=v end end,
  function()local hit=get('confirm/hit');hit.visible=false;return function()hit.visible=true end end,
  function()local hit=get('confirm/hit');local v=hit.parent;hit.parent=nil;return function()hit.parent=v end end,
  function()local box=get('confirm');local v=box.children.hit;box.children.hit=H.control({name='hit'},box);return function()box.children.hit=v end end,
 }
 for _,mutate in ipairs(cases)do
  ui:render();local old=ui.actions.confirm.handler;local hit=get('confirm/hit');hit:emit('down',9)
  local repair=mutate();hit:emit('up',9);repair()
  H.unchanged(r,m,function()return hit:emit('click',9)end);H.unchanged(r,m,old)
 end
 ui:render();H.parity(r,m,'purge',7,function()return click('confirm')end)
end)
test('nested picker parent hide/reparent/replacement cannot select another UID or revive a stale row',function()
 local r,m,ui,get,shown,click,changes,root=ready()
 for _,variant in ipairs({'hide','reparent','replace'})do
  ui:render();local parent=get('pickerView');local row=get('pickerView/card2');local old=ui.actions['pickerView/card2'].handler
  local hit=row:GetChild('hit');hit:emit('down',10);local saved
  if variant=='hide' then parent.visible=false
  elseif variant=='reparent' then saved=parent.parent;parent.parent={visible=true}
  else saved=root.children.pickerView;root.children.pickerView=H.control({name='pickerView'},root)end
  ui:update(0)
  if variant=='hide' then parent.visible=true elseif variant=='reparent' then parent.parent=saved else root.children.pickerView=saved end
  eq(ui.selected,7);H.unchanged(r,m,function()hit:emit('up',10);return hit:emit('click',10)end);H.unchanged(r,m,old);eq(ui.selected,7)
 end
end)
test('final native GetChild reentrant render invalidates option/footer/row after its last ownership read',function()
 for _,kind in ipairs({'option','confirm','row'})do
  local r,m
  if kind=='option' then r,m=H.fixture('addict')else r,m=H.selecting({{uid=7,cardId='strike'},{uid=8,cardId='defend'}})end
  local ui,get,shown,click,changes,root,host=H.setup(r,m)
  if kind=='confirm' then assert(click('pickerView/card1'))end
  local key=kind=='option' and 'eventView/option3' or kind=='confirm' and 'confirm' or 'pickerView/card2'
  local old=ui.actions[key].handler;local original=host.GetChild;local fired=false
  host.GetChild=function(owner,name)
   local result=original(owner,name)
   if not fired then fired=true;host.GetChild=original;ui:render()end
   return result
  end
  H.unchanged(r,m,old);host.GetChild=original;assert(fired);eq(ui.selected,kind=='confirm' and 7 or nil)
 end
end)
test('click-only accessibility is guarded against foreign parent and fresh UI still uses canonical mandatory purge',function()
 local r,m,ui,get,shown,click,changes,root=ready();local original=root.parent;local old=ui.actions.confirm.handler
 root.parent=nil;H.unchanged(r,m,function()return get('confirm/hit'):emit('click',11)end);root.parent=original
 H.unchanged(r,m,old);ui:render();H.parity(r,m,'purge',7,function()return get('confirm/hit'):emit('click',11)end)
end)
H.finish()
