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
 local first=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId='winding_halls'end end;assert(Nodes.enter(r,m,first.id))
 local root=F.control(spec(F.Layout,'nodePanel'));local presentation=require('abyss_character_presentation').prepare(F.Presentation,r.data);local ui=UI.new(root,r,m,presentation,'click',nil,{cursorEvents=cursor,color=function(a,b,c,d)return{a,b,c,d}end,imageSource='static'})
 local function get(path)local n=root;for k in path:gmatch('[^/]+')do n=assert(n:GetChild(k),path)end;return n end
 local touch=100
 local function click(path)touch=touch+1;local hit=get(path..'/hit');hit.listeners.down({touchId=touch});hit.listeners.up({touchId=touch});assert(hit.listeners.click({touchId=touch}))end
 ui:setVisible(true);return r,m,ui,get,click
end
local r,m,ui,get,click=fixture()
eq(get('eventView/name').text,'迷途回廊');eq(get('eventView/option2').visible,false);eq(get('back').visible,false)
local before=C.copy(r);eq(ui:press('eventView/option2'),false);same(r,before)
local old=ui.actions['eventView/option1'].handler;click('eventView/option1');eq(r.nodeFlow.event.stage,'choice');eq(old(),false)
for i,choice in ipairs({'madness','writhe','max_hp'})do eq(ui.view.node.event.options[i].choice,choice);assert(ui.actions['eventView/option'..i].enabled)end
assert(get('eventView/option1/description').text:find(ui.presentation.madness.name,1,true));assert(get('eventView/option2/description').text:find(ui.presentation.writhe.name,1,true))
eq(get('eventView/option4').visible,false);assert(get('eventView/option1/description').text:find('10',1,true));assert(get('eventView/option1/description').text:find('2',1,true))
assert(get('eventView/option2/description').text:find('20',1,true));assert(get('eventView/option3/description').text:find('4',1,true))
local uid=r.nextDeckUid;local hit=get('eventView/option1/hit');old=ui.actions['eventView/option1'].handler
hit.listeners.down({touchId=7});hit.listeners.up({touchId=7});assert(hit.listeners.click({touchId=7}))
eq(r.hp,70);eq(r.nextDeckUid,uid+2);eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node');eq(ui:holding(),false);eq(get('eventView/option2').visible,false)
before=C.copy(r);eq(old(),false);eq(hit.listeners.click({touchId=7}),false);same(r,before);click('eventView/option1');eq(r.phase,'map')
local heal,_,_,hget,hclick=fixture({'mark_of_bloom','omamori'},1)
heal.relicCounters={omamori=1};hclick('eventView/option1');hclick('eventView/option2');eq(heal.hp,1);eq(heal.relicCounters.omamori,0);eq(heal.nodeFlow.event.curseBlocked,true)
assert(hget('eventView/body').text:find('0',1,true));assert(hget('eventView/body').text:find('Omamori',1,true));hclick('eventView/option1');eq(heal.phase,'map')
local loss,_,_,_,lclick=fixture(nil,1);lclick('eventView/option1');lclick('eventView/option3');eq(loss.hp,1);eq(loss.maxHp,76);lclick('eventView/option1');eq(loss.phase,'map')
local fatal,_,fui,_,fclick=fixture(nil,1);fclick('eventView/option1');local count=#fatal.deck;fclick('eventView/option1');eq(fatal.phase,'defeat');eq(#fatal.deck,count+2);eq(fui:press('eventView/option1'),false)
print('ACT3_WINDING_UI_PASS source title/three values and card names, no escape, two UIDs, blocked heal/curse, maximum loss, fatal obtains and stale native callbacks/touches')
