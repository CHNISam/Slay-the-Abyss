local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq,same=H.test,H.eq,H.same

test('all three event titles/body and core option order use actual generated rows, pure rendering',function()
 for _,id in ipairs({'beggar','mausoleum','addict'})do
  local r,m=H.fixture(id);local before=H.snapshot(r);local ui,get,shown=H.setup(r,m);same(r,before)
  assert(shown('eventView'));assert(get('eventView/name').text~='未知事件')
  eq(get('eventView/body').text,r.nodeFlow.event.body);eq(get('eventView/caption').text,'未知事件')
  local options=H.Nodes.view(r,m).node.event.options
  for i,row in ipairs(options)do
   assert(shown('eventView/option'..i));eq(get('eventView/option'..i..'/title').text,'［'..row.title..'］')
   eq(ui.actions['eventView/option'..i].enabled,row.enabled)
  end
  for i=#options+1,#require('abyss_theme').layout.nativeNode.event.options.rows do assert(not shown('eventView/option'..i))end
  assert(not shown('back') and not shown('confirm'))
 end
end)
test('donation insufficient funds and exact75 pay once before separate confirm, no premature picker',function()
 for _,gold in ipairs({0,74,75,76})do
  local r,m=H.fixture('beggar',nil,gold);local ui,get,shown,click=H.setup(r,m)
  if gold<75 then H.unchanged(r,m,function()return click('eventView/option1')end)
  else
   local stale=ui.actions['eventView/option1'].handler
   H.parity(r,m,'donate',nil,function()return click('eventView/option1')end)
   eq(r.gold,gold-75);eq(r.nodeFlow.event.stage,'gave_money');assert(shown('eventView') and not shown('pickerView'))
   assert(get('eventView/body').text:find('75'));H.unchanged(r,m,stale)
   H.parity(r,m,'confirm',nil,function()return click('eventView/option1')end)
   assert(shown('pickerView'));eq(r.gold,gold-75);assert(not shown('back'));eq(ui.actions.confirm.enabled,false)
  end
 end
end)
test('Beggar Ignore has distinct LEAVE then map, Mausoleum has RESULT then map, Addict directly maps',function()
 for _,item in ipairs({{'beggar',2,'leave'},{'mausoleum',2,'result'},{'addict',3,false}})do
  local r,m=H.fixture(item[1]);local ui,get,shown,click=H.setup(r,m)
  H.parity(r,m,'leave',nil,function()return click('eventView/option'..item[2])end)
  if item[3] then
   eq(r.phase,'node');eq(r.nodeFlow.event.stage,item[3]);assert(shown('eventView'));assert(not shown('confirm'))
   H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
  end
  eq(r.phase,'map');assert(r.nodeFlow.complete);assert(not shown('eventView'));assert(shown('confirm'))
  eq(get('confirm/label').text,'返回路线');assert(ui:press('confirm'))
 end
end)
test('mandatory picker excludes bottled/unpurgeable, uses selected UID across reorder and real Parasite hook',function()
 local r,m=H.selecting({{uid=7,cardId='strike',inBottleFlame=true},{uid=8,cardId='defend',upgraded=true},
  {uid=9,cardId='parasite'},{uid=10,cardId='Necronomicurse'}})
 r.hp,r.maxHp=80,80
 local ui,get,shown,click=H.setup(r,m);eq(#ui.removeRows,2);eq(ui.removeRows[1].uid,8);eq(ui.removeRows[2].uid,9)
 assert(not shown('back'));H.unchanged(r,m,function()return ui:press('back')end)
 H.unchanged(r,m,function()return ui:press('confirm')end)
 assert(click('pickerView/card2'));eq(ui.selected,9);assert(get('pickerView/target/name').text~='')
 r.deck[1],r.deck[3]=r.deck[3],r.deck[1]
 H.parity(r,m,'purge',9,function()return click('confirm')end)
 eq(r.gold,25);eq(r.maxHp,77);eq(r.hp,77);eq(#r.deck,3);eq(r.nodeFlow.event.removedUid,9)
end)
test('empty/bottled-only paid groups expose a no-refund exit and reject stale leave after candidates return',function()
 for _,deck in ipairs({{},{{uid=7,cardId='strike',inBottleFlame=true}},{{uid=7,cardId='Necronomicurse'}}})do
  local r,m=H.fixture('beggar',deck,75);local ui,get,shown,click=H.setup(r,m)
  H.parity(r,m,'donate',nil,function()return click('eventView/option1')end)
  H.parity(r,m,'confirm',nil,function()return click('eventView/option1')end)
  eq(r.gold,0);assert(shown('eventView') and not shown('pickerView'),'empty paid group must expose event exit')
  eq(get('eventView/option1/title').text,'［离开］')
  assert(get('eventView/body').text:find('没有可移除的卡牌'))
  eq(get('notice').text,'已支付75金币。请查看下方选项。')
  assert(get('eventView/option1/description').text:find('没有可移除的卡牌'))
  assert(not shown('back'));H.unchanged(r,m,function()return ui:press('back')end)
  local stale=ui.actions['eventView/option1'].handler
  local paid=H.snapshot(r)
  table.insert(r.deck,{uid=100,cardId='strike'})
  H.unchanged(r,m,stale);ui:render();assert(shown('pickerView') and not shown('eventView'))
  table.remove(r.deck);ui:render();assert(shown('eventView') and not shown('pickerView'))
  H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
  eq(r.phase,'map');assert(r.nodeFlow.complete);eq(r.gold,0)
  same(r.deck,paid.deck);same(r.miscRng,paid.miscRng);same(r.relicPool,paid.relicPool)
  eq(r.nodeFlow.event.removedUid,nil);eq(get('confirm/label').text,'返回路线')
  assert(ui:press('confirm'));eq(r.phase,'map');H.unchanged(r,m,stale)
 end
end)
test('duplicate/deleted selected UID refuses without refund; bottled duplicate cannot retain a selected UID',function()
 for _,bottled in ipairs({false,true})do
  local r,m=H.selecting({{uid=7,cardId='strike'},{uid=8,cardId='strike'}})
  local ui,get,shown,click=H.setup(r,m);assert(click('pickerView/card1'))
  table.insert(r.deck,{uid=7,cardId='defend',inBottleLightning=bottled})
  H.parity(r,m,'purge',7,function()return click('confirm')end)
  eq(r.gold,25);eq(r.nodeFlow.event.stage,'choose_card');eq(ui.selected,nil);eq(ui.actions.confirm.enabled,false)
  H.unchanged(r,m,function()return click('pickerView/card1')end)
  r.deck={{uid=8,cardId='strike'}};ui:render();eq(ui.selected,nil);assert(click('pickerView/card1'))
  H.parity(r,m,'purge',8,function()return click('confirm')end);eq(#r.deck,0);eq(r.gold,25)
 end
end)
test('Addict buy84 refused and exact85 pays once with independent result leave; Mausoleum opens/result leave',function()
 for _,id in ipairs({'addict','mausoleum'})do
  local r,m=H.fixture(id);H.front(r,'Anchor');if id=='mausoleum' then H.boolean(r,false)else r.gold=84 end
  local ui,get,shown,click=H.setup(r,m)
  if id=='addict' then H.unchanged(r,m,function()return click('eventView/option1')end);r.gold=85;ui:render()end
  local old=ui.actions['eventView/option1'].handler
  H.parity(r,m,id=='addict' and 'buy' or 'open',nil,function()return click('eventView/option1')end)
  eq(r.nodeFlow.event.stage,'result');eq(r.nodeFlow.event.obtainedRelicId,'anchor');assert(shown('eventView'))
  assert(get('eventView/body').text:find('获得遗物：'));H.unchanged(r,m,old)
  H.parity(r,m,'leave',nil,function()return click('eventView/option1')end);eq(r.phase,'map')
 end
end)
test('mandatory Beggar target preserves complete detached repeatable/permanent-card metadata and card face',function()
 local r,m=H.selecting({{uid=7,cardId='searing_blow',upgraded=true,upgrades=2,damageBonus=4},
  {uid=8,cardId='strike',upgraded=true,damageBonus=7}})
 local before=H.snapshot(r);local ui,get,shown,click=H.setup(r,m);same(r,before)
 assert(click('pickerView/card1'));eq(ui.removeRows[1].upgrades,2);eq(ui.removeRows[1].damageBonus,4)
 eq(get('pickerView/card1/name').text,get('pickerView/target/name').text)
 eq(get('pickerView/card1/description').text,get('pickerView/target/description').text)
 ui.removeRows[1].damageBonus=99;eq(r.deck[1].damageBonus,4);ui:render()
 assert(click('pickerView/card2'));eq(get('pickerView/card2/description').text,get('pickerView/target/description').text)
 H.parity(r,m,'purge',8,function()return click('confirm')end);eq(r.deck[1].upgrades,2);eq(r.deck[1].damageBonus,4)
end)
H.finish()
