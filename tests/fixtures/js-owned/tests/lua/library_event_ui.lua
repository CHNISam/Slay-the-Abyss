-- Existing generated controls/native surface mocks, real public Nodes/Run.
local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq,same=H.test,H.eq,H.same
local function fixture()return H.fixture('the_library')end
local function reading()
 local r,m=fixture();assert(H.Nodes.chooseEvent(r,'read'));return r,m
end
local function freeze(r)return H.snapshot(r)end

test('generated intro has Read/Sleep without Leave and uses cached heal text',function()
 local r,m=fixture();local before=freeze(r);local ui,get,shown=H.setup(r,m);same(r,before)
 eq(get('eventView/name').text,'图书馆');eq(get('eventView/option1/title').text,'［阅读］')
 eq(get('eventView/option2/title').text,'［睡觉］');assert(get('eventView/option2/description').text:find('26'))
 assert(not shown('eventView/option3') and not shown('back') and not shown('confirm'))
 eq(ui.actions['eventView/option1'].enabled,true)
end)
test('actual Read opens20-card paginated acquisition picker, no reward skip, first selection then result Leave',function()
 local r,m=fixture();local ui,get,shown,click=H.setup(r,m);local old=ui.actions['eventView/option1'].handler
 H.parity(r,m,'read',nil,function()return click('eventView/option1')end)
 assert(shown('pickerView'));eq(ui.picker,'library_offer');eq(#ui.offerRows,20);eq(ui.pageCount,4)
 assert(not shown('back'));eq(ui.actions.confirm.enabled,false);assert(get('pickerView/empty').text:find('不能跳过'))
 H.unchanged(r,m,old);H.unchanged(r,m,function()return ui:press('back')end)
 local chosen=ui.offerRows[1];eq(chosen.uid,nil);assert(click('pickerView/card1'))
 eq(ui.selected,chosen.offerToken);assert(shown('confirm'));eq(get('pickerView/label').text,'将加入牌组')
 local stale=ui.actions.confirm.handler
 H.parity(r,m,'select',chosen.offerToken,function()return click('confirm')end)
 eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node');assert(shown('eventView') and not shown('pickerView'))
 eq(ui:holding(),false);eq(get('eventView/option1/title').text,'［离开］');H.unchanged(r,m,stale)
 local leave=ui.actions['eventView/option1'].handler
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
 eq(r.phase,'map');eq(ui:holding(),false);H.unchanged(r,m,leave)
end)
test('page arrows/controller select last real offer once without reroll or deck-UID lookup',function()
 local r,m=reading();local ui,get,shown,click=H.setup(r,m);local before=freeze(r)
 assert(click('pickerView/next'));assert(click('pickerView/next'));assert(click('pickerView/next'))
 eq(ui.pickPage,4);assert(get('pickerView/page').text:find('4/4'));same(r,before)
 assert(not shown('pickerView/card3'));assert(click('pickerView/card2'))
 local chosen=r.nodeFlow.event.offers[20];eq(ui.selected,chosen.offerToken)
 H.parity(r,m,'select',chosen.offerToken,function()return ui:press('confirm')end)
 eq(r.deck[#r.deck].cardId,chosen.cardId);eq(#r.deck,#before.deck+1);eq(ui:holding(),false)
end)
test('hide/show, resize and rerender retain same cached20 offers and RNG but retire held gestures',function()
 local r,m=reading();local ui,get,shown,click=H.setup(r,m);assert(click('pickerView/card1'))
 local old=ui.actions.confirm.handler;local before=freeze(r)
 get('confirm/hit'):emit('down',70);ui:setVisible(false);ui:setVisible(true)
 H.unchanged(r,m,old);H.unchanged(r,m,function()local hit=get('confirm/hit');hit:emit('up',70);return hit:emit('click',70)end)
 ui:render();assert(click('pickerView/card1'));local resized=ui.actions.confirm.handler
 get('confirm/hit'):emit('down',71);ui:resize(1600,900)
 H.unchanged(r,m,resized);H.unchanged(r,m,function()local hit=get('confirm/hit');hit:emit('up',71);return hit:emit('click',71)end)
 same(r,before);eq(#ui.offerRows,20);assert(shown('pickerView'));assert(not shown('back'))
end)
test('offered identity, upgrade, epoch, token, row reorder and replaced table retire old callbacks permanently',function()
 for _,kind in ipairs({'identity','upgrade','epoch','token','reorder','replace'})do
  local r,m=reading();local ui,get,shown,click=H.setup(r,m);assert(click('pickerView/card1'))
  local old=ui.actions.confirm.handler;local event=r.nodeFlow.event;local card=event.offers[1]
  local value=kind=='identity' and card.cardId or kind=='upgrade' and card.upgraded or kind=='epoch' and event.offerEpoch or card.offerToken
  if kind=='identity'then card.cardId='strike'elseif kind=='upgrade'then card.upgraded=not card.upgraded
  elseif kind=='epoch'then event.offerEpoch=event.offerEpoch+1 elseif kind=='token'then card.offerToken='changed'
  elseif kind=='reorder'then event.offers[1],event.offers[2]=event.offers[2],event.offers[1]
  else event.offers=H.Copy(event.offers)end
  H.unchanged(r,m,old)
  if kind=='identity'then card.cardId=value elseif kind=='upgrade'then card.upgraded=value
  elseif kind=='epoch'then event.offerEpoch=value elseif kind=='token'then card.offerToken=value
  elseif kind=='reorder'then event.offers[1],event.offers[2]=event.offers[2],event.offers[1]end
  H.unchanged(r,m,old);ui:render();assert(shown('pickerView'))
 end
end)
test('stale physical selection/confirm cannot redirect to another event run/map, detached owner or stage',function()
 local r,m=reading();local ui,get,shown,click=H.setup(r,m);assert(click('pickerView/card1'))
 local old=ui.actions.confirm.handler;local hit=get('confirm/hit');hit:emit('down',80)
 local nextRun,nextMap=fixture();ui.run,ui.map=nextRun,nextMap;ui:render()
 H.unchanged(nextRun,nextMap,old);H.unchanged(nextRun,nextMap,function()hit:emit('up',80);return hit:emit('click',80)end)
 ui.run,ui.map=r,m;ui:render();H.unchanged(r,m,old)
 assert(click('pickerView/card1'));local detached=ui.actions.confirm.handler
 local owner=r.nodeFlow.event;r.nodeFlow.event=H.Copy(owner);H.unchanged(r,m,detached)
 r.nodeFlow.event=owner;H.unchanged(r,m,detached)
end)
test('late obtain failure preserves acquisition picker and fresh confirm recovers without another offer roll',function()
 local r,m=reading();local ui,get,shown,click=H.setup(r,m);assert(click('pickerView/card1'))
 local token=ui.selected;local before=freeze(r);local original=H.Hooks.onObtainCard
 H.Hooks.onObtainCard=function(owner)owner.gold=999;H.Random.randomInt(owner.miscRng,99);return false,'library_ui_late'end
 H.parity(r,m,'select',token,function()return click('confirm')end);H.Hooks.onObtainCard=original
 same(r,before);assert(shown('pickerView'));eq(ui.selected,token)
 H.parity(r,m,'select',token,function()return click('confirm')end);eq(r.nodeFlow.event.stage,'result')
 same(r.cardRng,before.cardRng)
end)
test('Sleep result uses public health and exactly one result Leave, never an extra held result screen',function()
 local r,m=fixture();r.hp=10;local ui,get,shown,click=H.setup(r,m)
 H.parity(r,m,'sleep',nil,function()return click('eventView/option2')end)
 eq(r.hp,36);eq(r.nodeFlow.event.stage,'result');eq(ui:holding(),false)
 assert(shown('eventView') and not shown('pickerView'));assert(get('eventView/body').text:find('26'))
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end);eq(r.phase,'map')
end)
print('LIBRARY_UI '..H.count..' passed')
