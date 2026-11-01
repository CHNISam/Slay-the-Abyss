local F=dofile('tests/lua/support/tomb_red_mask_fixture.lua')
local U=dofile('tests/lua/support/game_ui_fixture.lua');local UI=require('abyss_node_ui')
local function spec(list,name)for _,v in ipairs(list)do if v.name==name then return v end;local found=v.children and spec(v.children,name);if found then return found end end end
local r,m,n=F.fixture(0);assert(F.Nodes.enter(r,m,n))
local root=U.control(spec(U.Layout,'nodePanel'));local p=require('abyss_character_presentation').prepare(U.Presentation,r.data)
local ui=UI.new(root,r,m,p,'click',nil,{cursorEvents={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'},color=function(...)return{...}end,imageSource='static'})
local function get(path)local v=root;for part in path:gmatch('[^/]+')do v=assert(v:GetChild(part),path)end;return v end
local touch=100
local function click(i)touch=touch+1;local hit=get('eventView/option'..i..'/hit');hit.listeners.down({touchId=touch});hit.listeners.up({touchId=touch});return hit.listeners.click({touchId=touch})end
ui:setVisible(true);F.eq(get('eventView/name').text,'红面具领主之墓')
assert(get('eventView/option1/description').text:find('未持有',1,true));assert(get('eventView/option2/description').text:find('0金币也可以',1,true))
F.eq(click(1),false);F.eq(r.gold,0);F.eq(r.nodeFlow.event.stage,'intro')
local old=ui.actions['eventView/option2'].handler
assert(click(2));F.eq(r.relics[#r.relics],'red_mask');F.eq(r.nodeFlow.event.stage,'result');F.eq(get('eventView/option2').visible,false);F.eq(old(),false)
assert(get('eventView/body').text:find('红面具',1,true));assert(click(1));F.eq(r.phase,'map')
local other,om,on=F.fixture(17);assert(F.Run.obtainRelic(other,'red_mask'));assert(F.Nodes.enter(other,om,on))
ui.run,ui.map=other,om;ui:render();F.eq(get('eventView/option3').visible,false)
assert(get('eventView/option1/description').text:find('222',1,true));old=ui.actions['eventView/option1'].handler
assert(click(1));F.eq(other.gold,239);F.eq(other.nodeFlow.event.stage,'result');F.eq(old(),false)
-- A callback from this result cannot mutate a replaced Run or an exited UI.
old=ui.actions['eventView/option1'].handler;ui.run=r;ui.map=m;F.eq(old(),false)
ui:setVisible(false);F.eq(old(),false)
print('TOMB_RED_MASK_UI_PASS native disabled ownership/zero payment/mask222/full result, single-action replay and replaced-Run/hidden-panel callbacks; headless only')
