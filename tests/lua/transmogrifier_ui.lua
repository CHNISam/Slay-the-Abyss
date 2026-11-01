package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local UI,Nodes,Run,Map=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function spec(list,name)for _,item in ipairs(list)do if item.name==name then return item end;local found=item.children and spec(item.children,name);if found then return found end end end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local run,map=Run.new(F.Data,42),Map.generate(F.Data,42)
run.deck={{uid=7,cardId='strike',upgraded=true},{uid=8,cardId='bash',upgraded=false,inBottleFlame=true}}
local first=Map.available(map)[1];for _,n in ipairs(map.nodes)do if n.id==first.id then n.type='event';n.eventId='transmogrifier' end end
assert(Nodes.enter(run,map,first.id))
run.miscRng=require('abyss_sts_random').restore({words={'0000000000000000','0000000000000000'},counter=0})
local root=F.control(spec(F.Layout,'nodePanel'))
local ui=UI.new(root,run,map,F.Presentation,'click',nil,{color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,imageSource='static'})
local function get(path)local n=root;for key in path:gmatch('[^/]+')do n=assert(n:GetChild(key),path)end;return n end
local function click(path)get(path):GetChild('hit').click()end
eq(get('eventView/name').text,'变换神龛');click('eventView/option1')
eq(run.nodeFlow.event.stage,'choose_card');eq(get('pickerView').visible,true);eq(get('back').visible,false)
eq(get('pickerView/card2').visible,false);click('pickerView/card1');eq(get('confirm/label').text,'确认变换')
click('confirm');eq(run.phase,'node');eq(run.nodeFlow.event.stage,'result');eq(get('eventView').visible,true)
eq(run.deck[2].cardId,'anger');assert(get('eventView/body').text:find(F.Presentation.anger.name,1,true))
click('eventView/option1');eq(run.phase,'map');assert(ui)
print('TRANSMOGRIFIER_UI 1 passed')
