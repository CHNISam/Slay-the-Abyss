-- Controlled real Nodes/native-mock integration; not a naturally played route.
local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq,same=H.test,H.eq,H.same
test('full source mapping retains Duplicator and its source eligibility',function()
 eq(H.Pool.contentId.Duplicator,'duplicator')
 local p=H.Pool.new('full',false,2);local found=false
 for _,id in ipairs(p.once)do if id=='Duplicator'then found=true end end
 assert(found);assert(not H.Pool.isEligible('Duplicator',{act=1}))
 assert(H.Pool.isEligible('Duplicator',{act=2}))
end)
test('real node copy picker includes bottled source and awards a detached new permanent card exactly once',function()
 local deck={{uid=7,cardId='ritual_dagger',misc=29,costOverride=0,inBottleFlame=true},{uid=8,cardId='defend'}}
 local r,m=H.fixture('duplicator',deck);local before=H.snapshot(r)
 local ui,get,shown,click=H.setup(r,m)
 eq(get('eventView/name').text,'映光石龛');same(r,before)
 H.parity(r,m,'copy',nil,function()return click('eventView/option1')end)
 eq(ui.picker,'duplicator_card');assert(shown('pickerView'));assert(not shown('back'))
 eq(#ui.removeRows,2);eq(ui.removeRows[1].misc,29);eq(ui.removeRows[1].costOverride,0)
 assert(click('pickerView/card1'));eq(ui.selected,7)
 assert(get('pickerView/label').text:find('复制'))
 local stale=ui.actions.confirm.handler
 H.parity(r,m,'select',7,function()return click('confirm')end)
 eq(#r.deck,3);eq(r.deck[1].uid,7);eq(r.deck[1].inBottleFlame,true)
 local copy=r.deck[3];eq(copy.uid,100);eq(copy.cardId,'ritual_dagger');eq(copy.misc,29)
 eq(copy.costOverride,0);eq(copy.inBottleFlame,nil)
 eq(r.nodeFlow.event.stage,'result');assert(shown('eventView'));assert(not shown('pickerView'))
 H.unchanged(r,m,stale)
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
 eq(r.phase,'map');eq(r.nodeFlow.complete,true)
 same(r.cardRng,before.cardRng);same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng)
end)
test('empty deck copy rejects before opening an impossible mandatory picker and original Leave remains usable',function()
 local r,m=H.fixture('duplicator',{});local ui,_,shown,click=H.setup(r,m)
 eq(ui.actions['eventView/option1'].enabled,false)
 H.unchanged(r,m,function()return click('eventView/option1')end)
 eq(r.nodeFlow.event.stage,'intro');assert(not shown('pickerView'))
 H.parity(r,m,'leave',nil,function()return click('eventView/option2')end)
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
 eq(r.phase,'map')
end)
test('changed selected source permanently retires old callback and fresh rendered selection recovers',function()
 for _,key in ipairs({'cardId','upgrades','misc','costOverride'})do
  local r,m=H.fixture('duplicator',{{uid=7,cardId='strike',upgrades=0,misc=0,costOverride=1}})
  local ui,_,_,click=H.setup(r,m);assert(click('eventView/option1'));assert(click('pickerView/card1'))
  local old=ui.actions.confirm.handler;local prior=r.deck[1][key]
  r.deck[1][key]=key=='cardId' and 'defend' or prior+1
  H.unchanged(r,m,old);r.deck[1][key]=prior;H.unchanged(r,m,old)
  ui:render();assert(click('pickerView/card1'));assert(click('confirm'));eq(#r.deck,2)
 end
end)
test('late obtain failure preserves chooser and resources; retry does not duplicate award',function()
 local r,m=H.fixture('duplicator');local ui,_,shown,click=H.setup(r,m)
 assert(click('eventView/option1'));assert(click('pickerView/card1'));local uid=ui.selected
 local original=H.Hooks.onObtainCard
 H.Hooks.onObtainCard=function(owner,card,definition,api)
  original(owner,card,definition,api);owner.gold=999;error('controlled late failure')
 end
 H.parity(r,m,'select',uid,function()return click('confirm')end)
 H.Hooks.onObtainCard=original
 eq(r.nodeFlow.event.stage,'choose_card');assert(shown('pickerView'))
 local n=#r.deck;ui:render();assert(click('pickerView/card1'));assert(click('confirm'));eq(#r.deck,n+1)
end)
test('deck replacement, UID and nested permanent metadata changes retire copy selection callbacks',function()
 for _,kind in ipairs({'deck','owner','uid','metadata'})do
  local r,m=H.fixture('duplicator',{{uid=7,cardId='strike',metadata={origin='kept'}}})
  local ui,_,_,click=H.setup(r,m);assert(click('eventView/option1'))
  local old=ui.actions['pickerView/card1'].handler
  if kind=='deck'then r.deck=H.Copy(r.deck)
  elseif kind=='owner'then r.deck[1]=H.Copy(r.deck[1])
  elseif kind=='uid'then r.deck[1].uid=8
  else r.deck[1].metadata.origin='changed'end
  H.unchanged(r,m,old)
  ui:render();assert(click('pickerView/card1'));assert(click('confirm'));eq(#r.deck,2)
 end
end)
test('hide and resize retire selected copy confirmation; refreshed callbacks recover without removing original',function()
 local r,m=H.fixture('duplicator');local ui,_,_,click=H.setup(r,m)
 assert(click('eventView/option1'));assert(click('pickerView/card1'))
 local old=ui.actions.confirm.handler;ui:resize(1600,900);H.unchanged(r,m,old)
 old=ui.actions.confirm.handler;ui:setVisible(false);H.unchanged(r,m,old);ui:setVisible(true);H.unchanged(r,m,old)
 local count=#r.deck;assert(click('confirm'));eq(#r.deck,count+1)
end)
H.finish()
