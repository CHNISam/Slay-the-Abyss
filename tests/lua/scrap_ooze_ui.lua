package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local UI,Nodes,Run,Map,R=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map'),require('abyss_sts_random')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function spec(list,name)for _,item in ipairs(list)do if item.name==name then return item end;local found=item.children and spec(item.children,name);if found then return found end end end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local run,map=Run.new(F.Data,42),Map.generate(F.Data,42)
local first=Map.available(map)[1];for _,n in ipairs(map.nodes)do if n.id==first.id then n.type='event';n.eventId='scrap_ooze' end end
assert(Nodes.enter(run,map,first.id))
run.miscRng=R.restore({words={'0000000000000000','0000000000000000'},counter=0})
local root=F.control(spec(F.Layout,'nodePanel'))
local ui=UI.new(root,run,map,F.Presentation,'click',nil,{color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,imageSource='static'})
local function get(path)local n=root;for key in path:gmatch('[^/]+')do n=assert(n:GetChild(key),path)end;return n end
local function click(path)get(path):GetChild('hit').click()end
eq(get('eventView/name').text,'废料黏液');assert(get('eventView/option1/description').text:find('3',1,true))
local before=run.hp;local stale=ui.actions['eventView/option1'].handler
click('eventView/option1');eq(run.hp,before-3);eq(run.nodeFlow.event.chance,35)
assert(get('eventView/option1/description').text:find('35',1,true));eq(stale(),false);eq(run.hp,before-3)
click('eventView/option2');eq(run.phase,'node');eq(get('eventView/option2').visible,false)
click('eventView/option1');eq(run.phase,'map');eq(get('eventView').visible,false)
print('SCRAP_OOZE_UI 1 passed')
