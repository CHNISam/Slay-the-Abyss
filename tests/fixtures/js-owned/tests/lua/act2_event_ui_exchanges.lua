local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq,same=H.test,H.eq,H.same
local maps={}
local SourceFixture=dofile('tests/lua/support/sapphire_source_fixture.lua')
local function keyRoom(kind)
 if not maps[kind] then
  local m=H.Map.generate(H.Data,'42',1)
  while true do
   local available=H.Map.available(m);assert(#available>0);local target
   for _,n in ipairs(available)do if n.type==kind then target=n;break end end
   if target then maps[kind]={m,target.id};break end
   assert(H.Map.choose(m,available[1].id)) -- staged navigation; no played history claim
  end
 end
 local r=H.Run.new(H.Data,'42',{experimental=true,campaign=true});r.endingUnlocked=true
 if kind=='treasure' then SourceFixture.stage(r)end
 local m=H.Copy(maps[kind][1]);assert(H.Nodes.enter(r,m,maps[kind][2]));return r,m
end
local function selecting()
 local r,m=H.selecting({{uid=7,cardId='strike'},{uid=8,cardId='defend'}})
 local ui,get,shown,click=H.setup(r,m);assert(click('pickerView/card1'));return r,m,ui,get,shown,click
end
local function expectedKey(r,m,kind)
 local expected,expectedMap=H.snapshot(r),H.Copy(m)
 if kind=='camp' then assert(H.Nodes.recall(expected,expectedMap,assert(H.Nodes.recallSource(expected,expectedMap))))
 else assert(H.Nodes.chooseTreasure(expected,expectedMap,assert(H.Nodes.treasureSource(expected,expectedMap)),'sapphire'))end
 return expected,expectedMap
end

test('Beggar held purge/footer and row never turn into Ruby Recall; fresh Recall stays canonical',function()
 local r,m,ui,get,shown,click=selecting();local kr,km=keyRoom('camp');local hit=get('confirm/hit')
 local old=ui.actions.confirm.handler;hit:emit('down',20);get('pickerView/card2/hit'):emit('down',21)
 ui.run,ui.map=kr,km;ui:render();eq(get('confirm/label').text,'Recall')
 H.unchanged(kr,km,function()hit:emit('up',20);return hit:emit('click',20)end)
 H.unchanged(kr,km,function()get('pickerView/card2/hit'):emit('up',21);return get('pickerView/card2/hit'):emit('click',21)end)
 H.unchanged(kr,km,old);eq(r.gold,25);eq(#r.deck,2)
 local expected,expectedMap=expectedKey(kr,km,'camp');assert(click('confirm'));same(kr,expected);same(km,expectedMap)
end)
test('Ruby held token/footer cannot become Beggar purge, old token remains refused, fresh mandatory choice succeeds',function()
 local kr,km=keyRoom('camp');local ui,get,shown,click=H.setup(kr,km);local hit=get('confirm/hit')
 local old=ui.actions.confirm.handler;hit:emit('down',22)
 local r,m=H.selecting({{uid=7,cardId='strike'}});ui.run,ui.map=r,m;ui:render();assert(click('pickerView/card1'))
 H.unchanged(r,m,function()hit:emit('up',22);return hit:emit('click',22)end);H.unchanged(r,m,old)
 eq(kr.keys.ruby,false);H.parity(r,m,'purge',7,function()return click('confirm')end)
end)
test('Beggar purge footer cannot become Sapphire or take-relic; distinct fresh Sapphire still canonical',function()
 local r,m,ui,get,shown,click=selecting();local kr,km=keyRoom('treasure');local hit=get('confirm/hit')
 local old=ui.actions.confirm.handler;hit:emit('down',23);ui.run,ui.map=kr,km;ui:render();assert(click('treasureView/chest'))
 eq(get('confirm/label').text,'蓝钥匙')
 H.unchanged(kr,km,function()hit:emit('up',23);return hit:emit('click',23)end);H.unchanged(kr,km,old)
 local expected,expectedMap=expectedKey(kr,km,'treasure');assert(click('confirm'));same(kr,expected);same(km,expectedMap)
 eq(r.gold,25);eq(#r.deck,2)
end)
test('Sapphire held linked token and reward choice cannot become Beggar mandatory purge',function()
 local kr,km=keyRoom('treasure');local ui,get,shown,click=H.setup(kr,km);assert(click('treasureView/chest'))
 local hit=get('confirm/hit');local old=ui.actions.confirm.handler;local take=ui.actions['treasureView/take'].handler
 hit:emit('down',24);local r,m=H.selecting({{uid=7,cardId='strike'}});ui.run,ui.map=r,m;ui:render();assert(click('pickerView/card1'))
 H.unchanged(r,m,function()hit:emit('up',24);return hit:emit('click',24)end);H.unchanged(r,m,old);H.unchanged(r,m,take)
 eq(kr.keys.sapphire,false);H.parity(r,m,'purge',7,function()return click('confirm')end)
end)
test('Act2 option gestures cannot become other event choices or be revived after returning to same event owner',function()
 local r,m=H.fixture('beggar');local ui,get,shown,click=H.setup(r,m)
 local old=ui.actions['eventView/option1'].handler;local hit=get('eventView/option1/hit');hit:emit('down',25)
 local ar,am=H.fixture('addict');H.front(ar,'Anchor');ui.run,ui.map=ar,am;ui:render()
 H.unchanged(ar,am,function()hit:emit('up',25);return hit:emit('click',25)end);H.unchanged(ar,am,old)
 ui.run,ui.map=r,m;ui:render();H.unchanged(r,m,old);eq(r.gold,100)
 H.parity(r,m,'donate',nil,function()return click('eventView/option1')end)
end)
test('key and event completion footer keeps host next-act wording and event leave has no extra invented hold',function()
 local r,m=H.fixture('addict');local ui,get,shown,click=H.setup(r,m)
 assert(click('eventView/option3'));eq(r.phase,'map');eq(ui:holding(),false);eq(get('confirm/label').text,'返回路线')
 -- Existing Host transition phase is a controlled input here, not a played act.
 r.phase='act_transition';ui:render();eq(get('confirm/label').text,'前往下一幕')
 assert(click('confirm'));eq(r.phase,'act_transition');eq(ui:holding(),false)
end)
H.finish()
