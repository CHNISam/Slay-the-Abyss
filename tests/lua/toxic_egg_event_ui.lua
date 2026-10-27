local F=dofile('tests/lua/support/sensory_stone_fixture.lua')
local U=dofile('tests/lua/support/game_ui_fixture.lua');local UI=require('abyss_node_ui')
local function spec(list,name)for _,v in ipairs(list)do if v.name==name then return v end;local found=v.children and spec(v.children,name);if found then return found end end end
-- Seed3 is selected by the existing independent fixed-source Sensory oracle:
-- its first group is Forethought, HandOfGreed, Madness. No pool changes.
local r,m,n=F.fixture(80,'3');assert(F.Run.obtainRelic(r,'Toxic Egg 2'));assert(F.Nodes.enter(r,m,n))
assert(F.Nodes.chooseEvent(r,'continue'));assert(F.Nodes.chooseEvent(r,'three'));assert(F.Nodes.chooseEvent(r,'open_1'))
local card=r.nodeFlow.event.rewards[1].cards[3];F.eq(card.cardId,'madness');F.eq(card.upgraded,true)
local root=U.control(spec(U.Layout,'nodePanel'));local p=require('abyss_character_presentation').prepare(U.Presentation,r.data)
local ui=UI.new(root,r,m,p,'click',nil,{cursorEvents={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'},color=function(...)return{...}end,imageSource='static'})
local function get(path)local v=root;for k in path:gmatch('[^/]+')do v=assert(v:GetChild(k),path)end;return v end
ui:setVisible(true);assert(get('eventView/option3/title').text:find(p.madness.name..'+',1,true))
assert(get('eventView/option3/description').text:find('费用 0',1,true),'upgraded Madness must visibly cost0')
assert(ui:press('eventView/option3'));F.eq(r.deck[#r.deck].cardId,'madness');F.eq(r.deck[#r.deck].upgrades,1)
print('TOXIC_EGG_EVENT_UI_PASS oracle seed3 actual Madness+ name/cost0/rules and true permanent acquire')
