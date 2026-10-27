package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local UI,Nodes,Run,Map,C,P,Q=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map'),require('abyss_combat'),require('abyss_event_pool'),require('abyss_encounter_queue')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local cursor={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'}
local function spec(list,name)for _,item in ipairs(list)do if item.name==name then return item end;local found=item.children and spec(item.children,name);if found then return found end end end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local template=Map.generate(F.Data,'42',3)
local function fixture(relics,hp)
 local r=Run.new(F.Data,'42',{experimental=true,campaign=true});local m=C.copy(template)
 r.act,r.floor=3,34;r.encounters=Q.new(r.runSeed,3);r.unknown.pools=P.new('full',false,3);r.relics=C.copy(relics or {'burning_blood'});r.hp=hp or 80
 local first=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId='moai_head'end end;assert(Nodes.enter(r,m,first.id))
 local root=F.control(spec(F.Layout,'nodePanel'));local ui=UI.new(root,r,m,F.Presentation,'click',nil,{cursorEvents=cursor,color=function(a,b,c,d)return{a,b,c,d}end,imageSource='static'})
 local function get(path)local n=root;for k in path:gmatch('[^/]+')do n=assert(n:GetChild(k),path)end;return n end
 local touch=100
 local function click(path)touch=touch+1;local hit=get(path..'/hit');hit.listeners.down({touchId=touch});hit.listeners.up({touchId=touch});assert(hit.listeners.click({touchId=touch}))end
 ui:setVisible(true);return r,m,ui,get,click
end
local r,m,ui,get,click=fixture()
eq(get('eventView/name').text,'巨像之首');eq(get('eventView/option4').visible,false);eq(get('back').visible,false)
eq(ui.view.node.event.options[1].choice,'heal');eq(ui.view.node.event.options[2].choice,'give_idol');eq(ui.view.node.event.options[3].choice,'leave')
assert(get('eventView/option1/description').text:find('10',1,true));assert(not ui.actions['eventView/option2'].enabled)
local b=C.copy(r);eq(ui:press('eventView/option2'),false);same(r,b)
local old=ui.actions['eventView/option1'].handler;local hit=get('eventView/option1/hit')
hit.listeners.down({touchId=7});hit.listeners.up({touchId=7});assert(hit.listeners.click({touchId=7}))
eq(r.maxHp,70);eq(r.hp,70);eq(r.phase,'node');eq(r.nodeFlow.event.stage,'result');eq(ui:holding(),false)
eq(get('eventView/option2').visible,false);eq(get('eventView/option3').visible,false)
b=C.copy(r);eq(old(),false);eq(hit.listeners.click({touchId=7}),false);same(r,b)
click('eventView/option1');eq(r.phase,'map');eq(get('eventView').visible,false);eq(ui:press('eventView/option1'),false)
local idol,_,iui,iget,iclick=fixture({'anchor','golden_idol','vajra'})
assert(iui.actions['eventView/option2'].enabled);assert(iget('eventView/option2/description').text:find('333',1,true));local gold=idol.gold
local stale=iui.actions['eventView/option2'].handler;iclick('eventView/option2');eq(idol.gold,gold+333);eq(idol.hp,80);eq(idol.maxHp,80)
same(idol.relics,{'anchor','vajra'});eq(idol.nodeFlow.event.stage,'result');eq(stale(),false);eq(idol.phase,'node');iclick('eventView/option1');eq(idol.phase,'map')
local blocked,_,_,bget,bclick=fixture({'mark_of_bloom','magic_flower'},5)
assert(bget('eventView/option1/description').text:find('禁止治疗',1,true));bclick('eventView/option1');eq(blocked.hp,5);eq(blocked.maxHp,70)
assert(bget('eventView/body').text:find('阻止',1,true));bclick('eventView/option1');eq(blocked.phase,'map')
local plasma,_,_,pget,pclick=fixture({'golden_idol','ectoplasm'})
assert(pget('eventView/option2/description').text:find('禁止获得金币',1,true));gold=plasma.gold;pclick('eventView/option2');eq(plasma.gold,gold);eq(plasma.relics[1],'ectoplasm')
local decline,_,dui,dget,dclick=fixture();local before=C.copy(decline);dclick('eventView/option3');eq(decline.nodeFlow.event.stage,'result');eq(decline.phase,'node');eq(decline.hp,before.hp);eq(decline.maxHp,before.maxHp);eq(decline.gold,before.gold)
eq(dget('eventView/option2').visible,false);eq(dui:holding(),false);dclick('eventView/option1');eq(decline.phase,'map')
print('ACT3_MOAI_UI_PASS exact three options, disabled Idol, 333/blocked-gold/heal notes, native actions/result leave and stale callbacks/touches')
