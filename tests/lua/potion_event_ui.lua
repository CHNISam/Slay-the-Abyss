package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map,Run=require('abyss_map'),require('abyss_run')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fixture(id)
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=42,prologue=false,imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
 assert(ui:start());local r=ui.run
 -- Controlled content, real canonical room: navigation alone must not spend
 -- the persistent seed42 shop-potion stream used by Lab/Woman rewards.
 assert(r.data~=F.Data and r.data.rules.events~=F.Data.rules.events)
 local originalEvent=F.Data.rules.events.encounterId
 r.data.rules.events.encounterId=id
 assert(F.Data.rules.events.encounterId==originalEvent)
 local routes=dofile('tests/lua/support/map_routes.lua')
 local path=routes.to(ui.map,function(node)return node.type=='event'end)
 for i=1,#path-1 do assert(Map.choose(ui.map,path[i]))end
 r.floor=ui.map.floor;ui:refresh()
 local first=routes.at(ui.map,path[#path])
 assert(first.type=='event' and r.shopRng==nil)
 assert(F.Nodes.restoreMap(r,ui.map),'potion event fixture must retain the canonical source map')
 assert(ui.mapUI:choose(first.id))
 assert(r.nodeFlow.id==first.id and r.nodeFlow.type=='event' and r.nodeFlow.event.id==id)
 local function get(path)local n=root:GetChild('nodePanel');for key in path:gmatch('[^/]+')do n=assert(n:GetChild(key),path)end;return n end
 local function click(path)return get(path):GetChild('hit').click()end
 return ui,get,click
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS potion event UI '..count..' '..name)end
test('Lab displays three named bottle rewards and returns from real bag management to claim',function()
 local ui,get,click=fixture('lab');local r=ui.run;r.potions={'block_potion','blood_potion','fruit_juice'};ui:refresh()
 eq(get('eventView/name').text,'实验室');click('eventView/option1');eq(r.nodeFlow.event.stage,'potion_rewards')
 eq(get('eventView/option4').visible,true);eq(ui.nodeUI.actions['eventView/option2'].enabled,false)
 eq(get('confirm').visible,false)
 assert(get('eventView/option2/title').text:find('火',1,true))
 assert(ui:openPotions());local bag=ui.potionUI.root
 assert(bag:GetChild('slot2'):GetChild('hit').click());assert(bag:GetChild('discard'):GetChild('hit').click());assert(ui:closePotions())
 eq(ui.nodeUI.actions['eventView/option2'].enabled,true);local stale=ui.nodeUI.actions['eventView/option2'].handler
 click('eventView/option2');eq(r.potions[2],'fire_potion');eq(stale(),false)
 eq(ui.nodeUI.actions['eventView/option2'].enabled,false);click('eventView/option4');eq(r.nodeFlow.event.stage,'result');click('eventView/option1');eq(r.phase,'map')
 eq(get('eventView/option4').visible,false);eq(get('confirm').visible,true)
end)
test('Woman shows all prices and Sozu rewards remain claimable as blocked items',function()
 local ui,get,click=fixture('woman_in_blue');local r=ui.run;eq(get('eventView/name').text,'蓝衣女子')
 eq(get('eventView/option4').visible,true);eq(get('confirm').visible,false)
 for i,price in ipairs({'20','30','40'})do assert(get('eventView/option'..i..'/description').text:find(price,1,true))end
 assert(Run.obtainRelic(r,'Sozu'));click('eventView/option3');eq(r.gold,59);eq(#r.nodeFlow.event.potionOffers,3)
 eq(ui.nodeUI.actions['eventView/option1'].enabled,true);click('eventView/option1');eq(r.nodeFlow.event.potionOffers[1].blocked,true)
 eq(ui.nodeUI.actions['eventView/option1'].enabled,false);eq(r.phase,'node')
end)
print('POTION_EVENT_UI '..count..' passed')
