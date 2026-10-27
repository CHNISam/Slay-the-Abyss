package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local UI,Nodes,Run,Map,C,P,Q=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map'),require('abyss_combat'),require('abyss_event_pool'),require('abyss_encounter_queue')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local cursor={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'}
local function spec(list,name)for _,item in ipairs(list)do if item.name==name then return item end;local found=item.children and spec(item.children,name);if found then return found end end end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local template=Map.generate(F.Data,'42',3)
local function fixture(eventId)
 local r=Run.new(F.Data,'42',{experimental=true,campaign=true});local m=C.copy(template)
 r.act,r.floor=3,34;r.encounters=Q.new(r.runSeed,3);r.unknown.pools=P.new('full',false,3);assert(Run.obtainPotion(r,'fruit_juice'))
 local first=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId=eventId end end;assert(Nodes.enter(r,m,first.id))
 local root=F.control(spec(F.Layout,'nodePanel'));local ui=UI.new(root,r,m,F.Presentation,'click',nil,{cursorEvents=cursor,color=function(a,b,c,d)return{a,b,c,d}end,imageSource='static'})
 local function get(path)local n=root;for k in path:gmatch('[^/]+')do n=assert(n:GetChild(k),path)end;return n end
 local touch=100
 local function click(path)touch=touch+1;local hit=get(path..'/hit');hit.listeners.down({touchId=touch});hit.listeners.up({touchId=touch});assert(hit.listeners.click({touchId=touch}))end
 ui:setVisible(true);return r,m,ui,get,click
end
for _,id in ipairs({'moai_head','winding_halls'})do
 local r,m,ui,get,click=fixture(id)
 if id=='winding_halls'then click('eventView/option1')end
 local slot=id=='moai_head'and 1 or 3
 local old=ui.actions['eventView/option'..slot].handler;local hit=get('eventView/option'..slot..'/hit')
 hit.listeners.down({touchId=50})
 assert(Run.usePotion(r,1));eq(r.maxHp,85);ui:render()
 local text=get('eventView/option'..slot..'/description').text
 assert(text:find('85',1,true)and text:find(id=='moai_head'and'75'or'81',1,true))
 local before=C.copy(r);eq(old(),false)
 hit.listeners.up({touchId=50});eq(hit.listeners.click({touchId=50}),false);same(r,before)
 click('eventView/option'..slot);eq(r.maxHp,id=='moai_head'and 75 or 81);eq(r.hp,r.maxHp)
 eq(r.nodeFlow.event.stage,'result');click('eventView/option1');eq(r.phase,'map')
end
print('ACT3_EVENT_FRUIT_UI_PASS actual Fruit/refreshed current HP display; old callbacks/touches rejected; fresh native choices succeed with cached costs')
