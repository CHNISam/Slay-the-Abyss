-- Real Nodes and generated NodeUI. History values are explicit test inputs,
-- not evidence of naturally earned account history or native-client behavior.
local H=dofile('tests/helpers/act2_event_ui.lua')
local function fixture(seed,bossCount)
 local r=H.Run.new(H.Data,tostring(seed));local m=H.Map.generate(r.data,tostring(seed))
 assert(H.Nodes.beginNeow(r,m,{bossCount=bossCount}));return r,m
end
local function setup(seed,bossCount)
 local r,m=fixture(seed,bossCount);local ui,get,shown,click=H.setup(r,m)
 return r,m,ui,get,shown,click
end
-- Runtime SetSizeDelta must retain the native one-line text budget, not only
-- the generated initial layout. This does not prove native font rasterization.
local function readableOptions(get,shown,count)
 local line=require('abyss_theme').layout.nativeText.lineHeight
 for i=1,count do
  local path='eventView/option'..i;assert(shown(path))
  local box,title,description=get(path),get(path..'/title'),get(path..'/description')
  assert(title.size[2]>=line,'Neow runtime title is below native line height')
  assert(description.size[2]>=line,'Neow runtime description is below native line height')
  assert(title.y-title.size[2]/2>=description.y+description.size[2]/2)
  assert(title.y+title.size[2]/2<=box.size[2]/2)
  assert(description.y-description.size[2]/2>=-box.size[2]/2)
  assert(title.text~='' and description.visible)
 end
end
H.test('opening outside map has no room entry effects, source consumption or fabricated map visit',function()
 local r=H.Run.new(H.Data,'42');local m=H.Map.generate(r.data,'42');local before=H.snapshot(r);local beforeMap=H.Copy(m)
 assert(H.Nodes.beginNeow(r,m,{bossCount=0}));H.eq(r.floor,0);H.eq(r.phase,'node');H.eq(r.nodeFlow.roomKind,'neow')
 H.same(m,beforeMap);H.eq(#H.Nodes.available(r,m),0)
 for _,key in ipairs({'miscRng','cardRng','eventRng','treasureRng','encounters','relicPool','gold','deck','roomGeneration'})do H.same(r[key],before[key])end
 local live=H.snapshot(r);local ok=H.Nodes.beginNeow(r,m,{bossCount=1});H.eq(ok,false);H.same(r,live)
end)
H.test('missing history refuses atomically while mini real rows lead back to legal first map room',function()
 local r=H.Run.new(H.Data,'42');local m=H.Map.generate(r.data,'42');local before=H.snapshot(r)
 local ok,why=H.Nodes.beginNeow(r,m,nil);H.eq(ok,false);H.eq(why,'neow_history_unavailable');H.same(r,before)
 local ui,get,shown,click
 r,m,ui,get,shown,click=setup(42,0)
 H.eq(get('title').text,'第 0 层 · 七天神像')
 readableOptions(get,shown,1)
 H.eq(get('eventView/name').text,'高塔恩赐');H.eq(get('eventView/option1/title').text,'［继续］')
 H.parity(r,m,'continue',nil,function()return click('eventView/option1')end)
 assert(shown('eventView/option2'));assert(not shown('eventView/option3'));readableOptions(get,shown,2)
 H.parity(r,m,'reward_2',nil,function()return click('eventView/option2')end);H.eq(r.maxHp,88);H.eq(r.hp,88);readableOptions(get,shown,1)
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
 H.eq(r.phase,'map');H.eq(r.neowStatus,'complete');H.eq(m.floor,0);H.eq(#m.path,0)
 -- Reuse the same renderer for a legally entered ordinary event: Neow sizes must not leak.
 local otherRun,otherMap=H.fixture('big_fish');ui.run,ui.map=otherRun,otherMap;ui:render()
 assert(get('title').text:find('未知事件',1,true),'ordinary event heading must retain its own identity')
 local layout=require('abyss_theme').layout.nativeNode.event.options
 local title,description=get('eventView/option1/title'),get('eventView/option1/description')
 assert(description.visible and description.text~='')
 H.eq(title.x,layout.title[1]);H.eq(title.y,layout.title[2]);H.same(title.size,{layout.title[3],layout.title[4]})
 H.eq(description.x,layout.description[1]);H.eq(description.y,layout.description[2]);H.same(description.size,{layout.description[3],layout.description[4]})
 ui.run,ui.map=r,m;ui:render()

 local first=H.Nodes.available(r,m)[1];assert(first);assert(H.Nodes.enter(r,m,first.id));H.eq(m.floor,1);H.eq(r.phase,'combat')
end)
H.test('full source four offers and three-card reward route preserve every choice and separate skip',function()
 local r,m,ui,get,shown,click=setup(3,1)
 assert(click('eventView/option1'));assert(shown('eventView/option4'));H.eq(#r.nodeFlow.event.rewards,4);readableOptions(get,shown,4)
 assert(click('eventView/option1'));H.eq(r.nodeFlow.event.stage,'neow_card_reward');assert(shown('eventView/option4'))
 assert(get('eventView/option1/description').text:find('费用',1,true)==nil or get('eventView/option1/description').text~='')
 local cardId=r.nodeFlow.event.cardOffers[2].cardId;local uid=r.nextDeckUid
 H.parity(r,m,'claim_2',nil,function()return click('eventView/option2')end)
 H.eq(r.deck[#r.deck].cardId,cardId);H.eq(r.deck[#r.deck].uid,uid);assert(not ui:holding())
 assert(click('eventView/option1'));H.eq(r.phase,'map');assert(H.Nodes.available(r,m)[1])
end)
H.test('generated upgrade picker uses actual preview and ownership; old callback cannot select twice',function()
 local r,m,ui,get,shown,click=setup(4,1);assert(click('eventView/option1'));assert(click('eventView/option1'))
 H.eq(r.nodeFlow.event.stage,'neow_choose_card');assert(shown('pickerView'));assert(not shown('back'))
 local uid=ui.removeRows[1].uid;assert(click('pickerView/card1'));assert(shown('pickerView/before')and shown('pickerView/after'))
 local stale=ui.actions.confirm.handler
 H.parity(r,m,'select',uid,function()return click('confirm')end);assert(shown('eventView'));H.eq(r.deck[1].upgraded,true)
 H.unchanged(r,m,stale);assert(click('eventView/option1'));H.eq(r.phase,'map')
end)
H.test('two-card deletion retains first until second source UID and never exposes cancel',function()
 local r,m,ui,get,shown,click=setup(4,1);assert(click('eventView/option1'));assert(click('eventView/option3'))
 local size=#r.deck;local first=ui.removeRows[1].uid;assert(click('pickerView/card1'))
 H.parity(r,m,'select',first,function()return click('confirm')end);H.eq(#r.deck,size);H.eq(#r.nodeFlow.event.selectedUids,1)
 assert(shown('pickerView'));assert(not shown('back'));H.eq(ui.selected,nil);assert(not get('pickerView/hint').text:find('返回',1,true))
 local second=ui.removeRows[1].uid;assert(second~=first);assert(click('pickerView/card1'))
 H.parity(r,m,'select',second,function()return click('confirm')end);H.eq(#r.deck,size-2);assert(shown('eventView'))
 assert(click('eventView/option1'));H.eq(r.phase,'map')
end)
H.test('single and double transforms use same generated picker and commit fresh identities',function()
 for _,case in ipairs({{0,1,1},{15,3,2}})do
  local r,m,ui,get,shown,click=setup(case[1],1);assert(click('eventView/option1'));assert(click('eventView/option'..case[2]))
  local size,nextUid=#r.deck,r.nextDeckUid
  for _=1,case[3]do local uid=ui.removeRows[1].uid;assert(click('pickerView/card1'));assert(shown('pickerView/target'));H.parity(r,m,'select',uid,function()return click('confirm')end)end
  H.eq(#r.deck,size);H.eq(r.nextDeckUid,nextUid+case[3]);assert(shown('eventView'));assert(click('eventView/option1'));H.eq(r.phase,'map')
 end
end)
H.test('three potion rows independently claim once with visible descriptions and leave',function()
 local r,m,ui,get,shown,click=setup(0,1);assert(click('eventView/option1'));assert(click('eventView/option2'))
 H.eq(r.nodeFlow.event.stage,'neow_potions');assert(shown('eventView/option4'))
 local stale=ui.actions['eventView/option1'].handler;local id=r.nodeFlow.event.potionOffers[1].id
 H.parity(r,m,'potion_1',nil,function()return click('eventView/option1')end);H.eq(r.potions[1],id)
 H.unchanged(r,m,stale);H.parity(r,m,'skip',nil,function()return click('eventView/option4')end)
 assert(click('eventView/option1'));H.eq(r.phase,'map')
end)
H.test('resize, visibility loss and changed run retire held Neow buttons before repair',function()
 local r,m,ui,get,shown,click=setup(42,0);local old=ui.actions['eventView/option1'].handler
 ui:resize(1280,720);readableOptions(get,shown,1);H.unchanged(r,m,old);old=ui.actions['eventView/option1'].handler
 ui:setVisible(false);ui:setVisible(true);H.unchanged(r,m,old)
 old=ui.actions['eventView/option1'].handler;local nextRun,nextMap=fixture(42,1);ui.run,ui.map=nextRun,nextMap;ui:render()
 H.unchanged(nextRun,nextMap,old);ui.run,ui.map=r,m;ui:render();H.unchanged(r,m,old)
 assert(click('eventView/option1'));H.eq(r.nodeFlow.event.stage,'neow_blessing')
end)
print('NEOW_ENTRY_UI '..H.count..' passed')
