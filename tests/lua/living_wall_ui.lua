package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local UI,Nodes,Run,Map,C=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map'),require('abyss_combat')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function spec(list,name)
 for _,item in ipairs(list) do if item.name==name then return item end
  local found=item.children and spec(item.children,name);if found then return found end end
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function fixture(deck)
 local run,map=Run.new(F.Data,42),Map.generate(F.Data,42)
 run.deck=C.copy(deck or {{uid=1,cardId='strike',upgraded=false},{uid=2,cardId='bash',upgraded=false}})
 local first=Map.available(map)[1]
 for _,node in ipairs(map.nodes) do if node.id==first.id then node.type='event';node.eventId='living_wall' end end
 assert(Nodes.enter(run,map,first.id))
 local root=F.control(spec(F.Layout,'nodePanel'))
 local ui=UI.new(root,run,map,F.Presentation,'click',nil,{color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,imageSource='static'})
 local function get(path) local node=root;for key in path:gmatch('[^/]+') do node=assert(node:GetChild(key),path)end;return node end
 local function click(path) get(path):GetChild('hit').click() end
 return run,map,ui,get,click
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS living-wall UI '..count..' '..name)end
test('native Forget opens filtered picker, locks choice and removes one real permanent UID',function()
 local run,map,ui,get,click=fixture({{uid=1,cardId='strike',upgraded=false},{uid=2,cardId='bash',upgraded=false,inBottleFlame=true}})
 eq(get('eventView/name').text,'活墙');eq(get('eventView/option4').visible,false)
 click('eventView/option1');eq(run.nodeFlow.event.stage,'choose_card');eq(get('pickerView').visible,true)
 eq(get('back').visible,false);eq(get('pickerView/card2').visible,false)
 click('pickerView/card1');click('confirm');eq(#run.deck,1);eq(run.deck[1].uid,2);eq(run.phase,'map')
 eq(get('eventView').visible,true);assert(get('eventView/body').text:find('移除',1,true))
 local before=#run.deck;assert(not ui:press('confirm') or #run.deck==before)
end)
test('native Grow uses upgrade preview, preserves UID, and returns a visible result',function()
 local run,map,ui,get,click=fixture();click('eventView/option3')
 eq(run.nodeFlow.event.choice,'grow');click('pickerView/card1')
 eq(get('pickerView/before').visible,true);eq(get('pickerView/after').visible,true)
 click('confirm');eq(run.deck[1].uid,1);eq(run.deck[1].upgraded,true);eq(run.phase,'map')
 assert(get('eventView/body').text:find('升级',1,true))
end)
test('native Change uses complete source pool and shows the actual replacement',function()
 local run,map,ui,get,click=fixture()
 run.transformContext={pools=dofile('tests/lua/support/living_wall_source_pools.lua'),
  cards={strike={sourceId='Strike_R',category='colored'}},sourceToLocal={Anger='anger'}}
 run.miscRng=require('abyss_sts_random').restore({words={'0000000000000000','0000000000000000'},counter=0})
 click('eventView/option2');click('pickerView/card1');eq(get('confirm/label').text,'确认变换')
 click('confirm');eq(run.phase,'map');eq(run.deck[#run.deck].cardId,'anger');eq(run.deck[#run.deck].upgraded,false)
 assert(get('eventView/body').text:find(F.Presentation.anger.name,1,true));eq(#run.deck,2)
end)
test('empty native Forget and Change finish directly while Grow is unavailable',function()
 for _,option in ipairs({1,2}) do
  local run,map,ui,get,click=fixture({});eq(ui.actions['eventView/option3'].enabled,false)
  eq(get('eventView/option3/disabled').visible,true);assert(not ui:press('eventView/option3'));eq(run.phase,'node')
  click('eventView/option'..option);eq(run.phase,'map');eq(get('pickerView').visible,false);eq(get('eventView').visible,true)
 end
end)
print('LIVING_WALL_UI '..count..' passed')
