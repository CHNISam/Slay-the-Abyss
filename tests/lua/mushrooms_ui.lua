local F=dofile('tests/lua/support/mushrooms_fixture.lua');local U=dofile('tests/lua/support/game_ui_fixture.lua')
local function spec(list,name)for _,v in ipairs(list)do if v.name==name then return v end;local found=v.children and spec(v.children,name);if found then return found end end end
local function fixture()
local r,m=F.enter();r.hp=10
local root=U.control(spec(U.Layout,'nodePanel'));local presentation=require('abyss_character_presentation').prepare(U.Presentation,r.data)
local ui=require('abyss_node_ui').new(root,r,m,presentation,'click',nil,{cursorEvents={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'},color=function(...)return{...}end,imageSource='static'})
local function get(path)local v=root;for part in path:gmatch('[^/]+')do v=assert(v:GetChild(part),path)end;return v end
local touch=100
local function click(i)touch=touch+1;local hit=get('eventView/option'..i..'/hit');hit.listeners.down({touchId=touch});hit.listeners.up({touchId=touch});assert(hit.listeners.click({touchId=touch}))end
ui:setVisible(true);return r,m,ui,get,click end
local r,m,ui,get,click=fixture();F.eq(get('eventView/name').text,'蘑菇');assert(get('eventView/option2/description').text:find('寄生',1,true));F.eq(get('eventView/option3').visible,false)
local old=ui.actions['eventView/option1'].handler;local hit=get('eventView/option1/hit');hit.listeners.down({touchId=7});click(2)
F.eq(r.nodeFlow.event.stage,'result');F.eq(get('eventView/option2').visible,false);assert(get('eventView/body').text:find('寄生',1,true));local copy=F.C.copy(r)
F.eq(old(),false);hit.listeners.up({touchId=7});F.eq(hit.listeners.click({touchId=7}),false);F.same(r,copy)
click(1);F.eq(r.phase,'map')
local f,_,fui,fg,fc=fixture();local oldFight=fui.actions['eventView/option1'].handler
fg('eventView/option1/hit').listeners.down({touchId=44});fc(1);F.eq(f.nodeFlow.event.stage,'pre_combat');F.eq(fg('eventView/option2').visible,false)
F.eq(oldFight(),false);fg('eventView/option1/hit').listeners.up({touchId=44});F.eq(fg('eventView/option1/hit').listeners.click({touchId=44}),false)
F.eq(f.phase,'node');fc(1);F.eq(f.phase,'combat');F.eq(#f.combat.enemies,3)
print('MUSHROOMS_UI_PASS real generated controls/heal/result/leave/stale callback and touch')
