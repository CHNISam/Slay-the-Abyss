package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local UI,Nodes,Run,Map,C=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map'),require('abyss_combat')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local cursor={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'}
local function spec(list,name)for _,item in ipairs(list)do if item.name==name then return item end;local found=item.children and spec(item.children,name);if found then return found end end end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function fixture(id,deck)
 local r,m=Run.new(F.Data,42),Map.generate(F.Data,42);if deck then r.deck=C.copy(deck)end
 local first=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId=id end end;assert(Nodes.enter(r,m,first.id))
 local root=F.control(spec(F.Layout,'nodePanel'));local ui=UI.new(root,r,m,F.Presentation,'click',nil,{cursorEvents=cursor,color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,imageSource='static'})
 local function get(path)local n=root;for k in path:gmatch('[^/]+')do n=assert(n:GetChild(k),path)end;return n end
 local function click(path)get(path):GetChild('hit').click()end
 return r,m,ui,get,click
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS act1 content UI '..count..' '..name)end
test('blacksmith native forge locks picker and shows result before leaving',function()
 local r,m,ui,get,click=fixture('accursed_blacksmith',{{uid=7,cardId='strike',upgraded=false}})
 eq(get('eventView/name').text,'诅咒铁匠');click('eventView/option1');eq(r.nodeFlow.event.stage,'choose_card');eq(get('pickerView').visible,true);eq(get('back').visible,false)
 click('pickerView/card1');eq(get('pickerView/after').visible,true);click('confirm');eq(r.deck[1].uid,7);eq(r.deck[1].upgraded,true);eq(r.phase,'node');eq(get('eventView').visible,true)
 click('eventView/option1');eq(r.phase,'map')
end)
test('bonfire native source purge picker excludes bottled card',function()
 local r,m,ui,get,click=fixture('bonfire',{{uid=1,cardId='strike',upgraded=false,inBottleFlame=true},{uid=7,cardId='bash',upgraded=false}})
 eq(get('eventView/name').text,'篝火精灵');click('eventView/option1');eq(r.nodeFlow.event.stage,'choose');click('eventView/option1');eq(r.nodeFlow.event.stage,'choose_card');eq(get('pickerView').visible,true)
 eq(get('back').visible,false);eq(get('pickerView/card2').visible,false);eq(ui.removeRows[1].uid,7)
 click('pickerView/card1');eq(get('confirm/label').text,'确认献祭')
end)
test('serpent native decline keeps farewell and rejects old option closure',function()
 local r,m,ui,get,click=fixture('sssserpent');local old=ui.actions['eventView/option1'].handler
 click('eventView/option2');eq(r.nodeFlow.event.stage,'disagree');eq(get('eventView/option2').visible,false)
 local gold=r.gold;eq(old(),false);eq(r.gold,gold);click('eventView/option1');eq(r.phase,'map')
end)
test('serpent reused native hit rejects old touch rather than confirming payment',function()
 local r,m,ui,get=fixture('sssserpent')
 ui:setVisible(true)
 local hit=get('eventView/option1/hit')
 hit.listeners.down({touchId=7});hit.listeners.up({touchId=7});assert(hit.listeners.click({touchId=7}))
 eq(r.nodeFlow.event.stage,'agree');local before=r.gold
 eq(hit.listeners.click({touchId=7}),false);eq(hit.listeners.click({touchId=7}),false)
 eq(r.nodeFlow.event.stage,'agree');eq(r.gold,before)
end)
local function tap(get,path,touch)
 local hit=get(path..'/hit')
 hit.listeners.down({touchId=touch});hit.listeners.up({touchId=touch})
 assert(hit.listeners.click({touchId=touch}))
 return hit
end
local exits={
 {name='serpent accepted result',id='sssserpent',choices={1,1}},
 {name='serpent rejected farewell',id='sssserpent',choices={2},stage='disagree'},
 {name='fish result',id='big_fish',choices={1}},
 {name='blacksmith declined result',id='accursed_blacksmith',choices={3}},
 {name='blacksmith forged result',id='accursed_blacksmith',choices={1},pick=true},
 {name='bonfire offering result',id='bonfire',choices={1,1},pick=true},
 {name='bonfire empty result',id='bonfire',choices={1,1},deck={}},
}
for _,scenario in ipairs(exits)do
 test(scenario.name..' leaves directly without a second held screen or stale touch',function()
  local r,m,ui,get=fixture(scenario.id,scenario.deck or {{uid=7,cardId='strike',upgraded=false}})
  ui:setVisible(true)
  for step,choice in ipairs(scenario.choices)do tap(get,'eventView/option'..choice,step)end
  if scenario.pick then tap(get,'pickerView/card1',20);tap(get,'confirm',21)end
  eq(r.phase,'node');eq(r.nodeFlow.event.stage,scenario.stage or 'result')
  eq(ui:holding(),false);eq(get('eventView').visible,true)
  local hit=tap(get,'eventView/option1',30)
  eq(r.phase,'map');eq(r.nodeFlow.complete,true);eq(ui:holding(),false)
  eq(get('eventView').visible,false);eq(get('pickerView').visible,false)
  eq(get('confirm/label').text,'返回路线')
  local runBefore,mapBefore=C.copy(r),C.copy(m)
  for attempt=1,2 do eq(hit.listeners.click({touchId=30}),false)end
  hit.listeners.up({touchId=30});eq(hit.listeners.click({touchId=30}),false)
  eq(ui:press('eventView/option1'),false);same(r,runBefore);same(m,mapBefore)
  eq(ui:holding(),false);eq(get('eventView').visible,false)
 end)
end
print('ACT1_EVENT_UI '..count..' passed')
