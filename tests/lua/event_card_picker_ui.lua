-- Generated approved controls and actual Nodes transactions. Explicit staged
-- source events/controlled bottle flags are NOT natural/device evidence.
local H=dofile('tests/helpers/act2_choice_events.lua')
local UI=dofile('tests/helpers/event_cards_native_ui.lua')
local function click(tap,path,n)assert(tap(path,n),path)end
local function slot(i)return 'pickerView/card'..i end
H.test('Augmenter pair stays UI-local until one ordered mandatory command',function()
 local r,m=H.fixture('drug_dealer');local ui,get,shown,tap=UI.setup(r,m)
 click(tap,'eventView/option2',1);assert(r.nodeFlow.event.stage=='choose_card')
 assert(shown('pickerView')and not shown('eventView')and not shown('back')and shown('confirm'))
 assert(not ui:press('confirm'));local deck=H.C.copy(r.deck);local rng=H.C.copy(r.miscRng)
 local uid1,uid2=r.deck[1].uid,r.deck[2].uid;local stale=ui.actions[slot(1)].handler
 click(tap,slot(2),2);assert(not ui:press('confirm'));assert(not stale())
 H.same(r.deck,deck);H.same(r.miscRng,rng)
 click(tap,slot(1),3);assert(get(slot(2)..'/stamp').text=='第 1 张'and get(slot(1)..'/stamp').text=='第 2 张')
 local paid=ui.actions.confirm.handler;click(tap,'confirm',4)
 assert(r.nodeFlow.event.stage=='result');H.same(r.nodeFlow.event.removedUids,{uid2,uid1})
 assert(not paid());click(tap,'eventView/option1',5);assert(r.phase=='map')
end)
H.test('Duplicator presents bottles, preserves misc and upgrade, and emits a fresh unbottled UID',function()
 local r,m=H.fixture('duplicator',function(s)
  s.deck[1].inBottleFlame=true;s.deck[1].misc=123;s.deck[1].upgraded=true;s.deck[1].upgrades=1
 end)
 local before=r.nextDeckUid;local ui,get,shown,tap=UI.setup(r,m)
 click(tap,'eventView/option1',1);assert(shown(slot(1))and not shown('back'))
 click(tap,slot(1),2);assert(ui.selected==r.deck[1].uid)
 click(tap,'confirm',3);local card=r.deck[#r.deck]
 assert(card.uid==before and card.misc==123 and card.upgraded and card.upgrades==1)
 assert(not card.inBottleFlame and not card.inBottleLightning and not card.inBottleTornado)
 assert(ui.view.node.event.stage=='result')
end)
H.test('ordered selection toggles without RNG and old callbacks retire on hide resize and deck mutation',function()
 local r,m=H.fixture('drug_dealer');local ui,_,_,tap=UI.setup(r,m);click(tap,'eventView/option2',1)
 local before=H.snapshot(r);click(tap,slot(1),2);click(tap,slot(1),3);H.same(r,before)
 local old=ui.actions[slot(1)].handler;ui:setVisible(false);assert(not old());ui:setVisible(true)
 old=ui.actions[slot(1)].handler;ui:resize(1280,720);assert(not old())
 old=ui.actions[slot(1)].handler;r.deck[1].misc=99;assert(not old())
 ui:render();click(tap,slot(1),4);local stale=ui.actions[slot(2)].handler
 local saved=ui.run;ui.run=H.snapshot(r);assert(not stale());ui.run=saved;ui:render()
 assert(not ui:press('back'));assert(r.nodeFlow.event.stage=='choose_card')
end)
H.test('late second obtain refuses exact ordered UI selection then retries the same original outcomes',function()
 local r,m=H.fixture('drug_dealer');local ui,get,_,tap=UI.setup(r,m)
 click(tap,'eventView/option2',1);click(tap,slot(2),2);click(tap,slot(1),3)
 local before={run=H.snapshot(r),map=H.C.copy(m)}
 local owners={flow=r.nodeFlow,event=r.nodeFlow.event,deck=r.deck,misc=r.miscRng,cards=r.cardRng}
 local expected,calls={},0
 H.withHook('onObtainCard',function(old)return function(staged,card,d,api)
  calls=calls+1;expected[calls]=card.cardId
  local ok,why=old(staged,card,d,api)
  if calls==2 then H.R.randomInt(staged.eventRng,99);return false,'late_picker_refusal'end
  return ok,why
 end end,function()
  local ok,why=tap('confirm',4);assert(not ok and why=='late_picker_refusal')
 end)
 assert(calls==2);H.same({run=r,map=m},before)
 assert(r.nodeFlow==owners.flow and r.nodeFlow.event==owners.event and r.deck==owners.deck)
 assert(r.miscRng==owners.misc and r.cardRng==owners.cards)
 assert(get(slot(2)..'/stamp').text=='第 1 张'and get(slot(1)..'/stamp').text=='第 2 张')
 assert(ui.actions.confirm.enabled);local old=ui.actions.confirm.handler
 click(tap,'confirm',5);assert(not old());assert(r.nodeFlow.event.stage=='result')
 assert(r.deck[#r.deck-1].cardId==expected[1]and r.deck[#r.deck].cardId==expected[2])
end)
H.test('source undersized mandatory group displays pending with no cancel refund or synthetic completion',function()
 local r,m=H.fixture('designer');assert(H.Nodes.chooseEvent(r,'continue'))
 -- Source constructor branch is controlled only to isolate the native empty
 -- selector. This is not proof that this particular menu is naturally reached.
 r.nodeFlow.event.cleanUpRemovesCards=false;r.deck={r.deck[1],r.deck[2]}
 assert(H.Nodes.chooseEvent(r,'cleanup'));local paid=r.gold
 -- Simulate a host-side deck change before rendering the already-paid grid.
 r.deck={r.deck[1]};local ui,get,shown=UI.setup(r,m)
 assert(shown('pickerView')and not shown('back')and shown('confirm'))
 assert(get('pickerView/empty').text:find('不能跳过或退款',1,true))
 assert(not ui:press('confirm')and not ui:press('back'))
 assert(r.gold==paid and r.nodeFlow.event.stage=='choose_card'and not r.nodeFlow.complete)
end)
H.finish('EVENT_CARD_PICKER_UI')
