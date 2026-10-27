package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local UI,Nodes,Run,Map,C,P,Q=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map'),require('abyss_combat'),require('abyss_event_pool'),require('abyss_encounter_queue')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local cursor={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'}
local function spec(list,name)for _,item in ipairs(list)do if item.name==name then return item end;local found=item.children and spec(item.children,name);if found then return found end end end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local template=Map.generate(F.Data,'42',3)
local function fixture(deck)
 local r=Run.new(F.Data,'42',{experimental=true,campaign=true});local m=C.copy(template)
 r.act,r.floor=3,34;r.encounters=Q.new(r.runSeed,3);r.unknown.pools=P.new('full',false,3);r.deck=C.copy(deck)
 local first=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId='falling'end end;assert(Nodes.enter(r,m,first.id))
 local root=F.control(spec(F.Layout,'nodePanel'));local ui=UI.new(root,r,m,F.Presentation,'click',nil,{cursorEvents=cursor,color=function(a,b,c,d)return{a,b,c,d}end,imageSource='static'})
 local function get(path)local n=root;for k in path:gmatch('[^/]+')do n=assert(n:GetChild(k),path)end;return n end
 local function click(path)get(path..'/hit').click()end
 ui:setVisible(true);return r,m,ui,get,click
end
local r,m,ui,get,click=fixture({{uid=1,cardId='strike'},{uid=2,cardId='defend'},{uid=3,cardId='inflame',upgraded=true},{uid=4,cardId='strike',inBottleFlame=true}})
eq(get('eventView/name').text,'坠落');eq(get('eventView/option2').visible,false)
local old=ui.actions['eventView/option1'].handler
click('eventView/option1');eq(r.nodeFlow.event.stage,'choice');eq(old(),false)
for i,kind in ipairs({'skill','power','attack'})do
 eq(ui.view.node.event.options[i].choice,kind);local c=r.nodeFlow.event.candidates[kind]
 assert(get('eventView/option'..i..'/description').text:find(F.Presentation[c.cardId].name,1,true))
end
eq(get('eventView/option4').visible,false);eq(get('back').visible,false)
local hit=get('eventView/option2/hit');hit.listeners.down({touchId=7});hit.listeners.up({touchId=7});assert(hit.listeners.click({touchId=7}))
eq(r.nodeFlow.event.stage,'result');eq(r.nodeFlow.event.removedUid,3);eq(r.phase,'node');eq(ui:holding(),false)
local before=C.copy(r);eq(hit.listeners.click({touchId=7}),false);same(r,before)
click('eventView/option1');eq(r.phase,'map');eq(get('eventView').visible,false)
for _,c in ipairs(r.deck)do assert(c.uid~=3);if c.uid==4 then assert(c.inBottleFlame)end end
before=C.copy(r);eq(ui:press('eventView/option2'),false);same(r,before)
local single,_,sui,sget,sclick=fixture({{uid=9,cardId='defend'}})
sclick('eventView/option1');eq(single.nodeFlow.event.stage,'choice');eq(#single.deck,1)
eq(sui.actions['eventView/option2'].enabled,false);eq(sui.actions['eventView/option3'].enabled,false)
sclick('eventView/option1');eq(#single.deck,0);eq(single.nodeFlow.event.stage,'result');eq(sget('eventView/option2').visible,false)
local empty,_,eui,eget,eclick=fixture({{uid=8,cardId='regret'}})
eclick('eventView/option1');eq(eui.view.node.event.options[1].choice,'escape');eq(eget('eventView/option2').visible,false)
eclick('eventView/option1');eq(empty.nodeFlow.event.stage,'result');eq(#empty.deck,1);eclick('eventView/option1');eq(empty.phase,'map')
print('ACT3_FALLING_UI_PASS source order/actual card names, native choices, singleton/escape, result leave and stale callback/touch')
