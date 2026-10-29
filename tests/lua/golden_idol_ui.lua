local F=dofile('tests/lua/support/golden_idol_fixture.lua')
local U=dofile('tests/lua/support/game_ui_fixture.lua')
local UI,Nodes,Run,C=require('abyss_node_ui'),F.Nodes,F.Run,F.C
local function spec(list,name)for _,v in ipairs(list)do if v.name==name then return v end;local found=v.children and spec(v.children,name);if found then return found end end end
local function fixture(hp)
 local r,m,n=F.fixture(hp);assert(Nodes.enter(r,m,n))
 local root=U.control(spec(U.Layout,'nodePanel'));local p=require('abyss_character_presentation').prepare(U.Presentation,r.data)
 local ui=UI.new(root,r,m,p,'click',nil,{cursorEvents={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'},color=function(...)return{...}end,imageSource='static'})
 local function get(path)local v=root;for part in path:gmatch('[^/]+')do v=assert(v:GetChild(part),path)end;return v end
 local touch=100
 local function click(i)touch=touch+1;local hit=get('eventView/option'..i..'/hit');hit.listeners.down({touchId=touch});hit.listeners.up({touchId=touch});assert(hit.listeners.click({touchId=touch}))end
 ui:setVisible(true);return r,m,ui,get,click
end
local r,m,ui,get,click=fixture()
F.eq(get('eventView/name').text,'鎏金神像');F.eq(get('eventView/option3').visible,false)
F.eq(get('eventView/option1/title').text,'［拿取鎏金神像］')
assert(not get('eventView/option1/description').text:find('[A-Za-z]'))
local old=ui.actions['eventView/option1'].handler;local hit=get('eventView/option1/hit');hit.listeners.down({touchId=7});click(1)
F.eq(r.nodeFlow.event.stage,'trap');assert(r.relics[#r.relics]=='golden_idol');F.eq(get('back').visible,false)
F.eq(get('eventView/option1/title').text,'［承受旧伤］')
assert(not get('eventView/option1/description').text:find('[A-Za-z]'))
for i,id in ipairs({'injury','damage','max_hp'})do F.eq(ui.view.node.event.options[i].choice,id);assert(ui.actions['eventView/option'..i].enabled)end
assert(get('eventView/option1/description').text:find(ui.presentation.injury.name,1,true));assert(get('eventView/option2/description').text:find('20',1,true));F.eq(get('eventView/option4').visible,false)
local before=C.copy(r);F.eq(old(),false);hit.listeners.up({touchId=7});F.eq(hit.listeners.click({touchId=7}),false);F.same(r,before)
-- Legitimate real potion changes current owner, not the cached trap amount.
assert(Run.obtainPotion(r,'fruit_juice'));old=ui.actions['eventView/option3'].handler;get('eventView/option3/hit').listeners.down({touchId=8})
assert(Run.usePotion(r,1));ui:render();assert(get('eventView/option3/description').text:find('85 → 79',1,true));F.eq(old(),false)
before=C.copy(r);get('eventView/option3/hit').listeners.up({touchId=8});F.eq(get('eventView/option3/hit').listeners.click({touchId=8}),false);F.same(r,before)
click(3);F.eq(r.maxHp,79);F.eq(r.nodeFlow.event.stage,'result');F.eq(r.phase,'node');F.eq(get('eventView/option2').visible,false);click(1);F.eq(r.phase,'map')
local no,_,_,_,decline=fixture();decline(2);F.eq(no.nodeFlow.event.stage,'result');F.eq(#no.relics,1);decline(1);F.eq(no.phase,'map')
local fatal,_,fui,_,pay=fixture(1);pay(1);pay(2);F.eq(fatal.phase,'defeat');assert(fatal.relics[#fatal.relics]=='golden_idol');F.eq(fui:press('eventView/option1'),false)
print('GOLDEN_IDOL_UI_PASS intro/trap/result, actual immediate owner, three costs/card name, Fruit cached value, stale callback/touch and fatal defeat')
