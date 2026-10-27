local F=dofile('tests/lua/support/sensory_stone_fixture.lua')
local U=dofile('tests/lua/support/game_ui_fixture.lua');local UI=require('abyss_node_ui')
local function spec(list,name)for _,v in ipairs(list)do if v.name==name then return v end;local found=v.children and spec(v.children,name);if found then return found end end end
local r,m,n=F.fixture();assert(F.Nodes.enter(r,m,n))
local root=U.control(spec(U.Layout,'nodePanel'));local p=require('abyss_character_presentation').prepare(U.Presentation,r.data)
local ui=UI.new(root,r,m,p,'click',nil,{cursorEvents={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'},color=function(...)return{...}end,imageSource='static'})
local function get(path)local v=root;for part in path:gmatch('[^/]+')do v=assert(v:GetChild(part),path)end;return v end
local touch=100
local function click(i)touch=touch+1;local hit=get('eventView/option'..i..'/hit');hit.listeners.down({touchId=touch});hit.listeners.up({touchId=touch});assert(hit.listeners.click({touchId=touch}))end
ui:setVisible(true);F.eq(get('eventView/name').text,'Sensory Stone');F.eq(get('eventView/option2').visible,false)
click(1);for i,text in ipairs({'1组','5点','10点'})do assert(get('eventView/option'..i..'/description').text:find(text,1,true))end
local old=ui.actions['eventView/option3'].handler;click(3);F.eq(r.hp,70);F.eq(r.nodeFlow.event.stage,'rewards');F.eq(get('eventView/option4').visible,true);F.eq(old(),false)
click(2);F.eq(r.nodeFlow.event.selectedReward,2)
for i,c in ipairs(r.nodeFlow.event.rewards[2].cards)do
 assert(get('eventView/option'..i..'/title').text:find(p[c.cardId].name,1,true))
 assert(get('eventView/option'..i..'/description').text:find('费用 '..p[c.cardId].cost,1,true))
 assert(get('eventView/option'..i..'/description').text:find(p[c.cardId].text,1,true))
end
local hit=get('eventView/option1/hit');hit.listeners.down({touchId=7});old=ui.actions['eventView/option1'].handler
local rng=F.R.snapshot(r.cardRng);click(4);F.eq(r.nodeFlow.event.stage,'rewards');F.eq(old(),false)
hit.listeners.up({touchId=7});F.eq(hit.listeners.click({touchId=7}),false);F.same(F.R.snapshot(r.cardRng),rng)
click(2);local uid=r.nextDeckUid;click(1);F.eq(r.nextDeckUid,uid+1);F.eq(r.nodeFlow.event.rewards[2].claimed,true)
-- Remaining groups keep their original IDs; final Proceed returns the event LEAVE page.
F.eq(ui.view.node.event.options[2].choice,'open_3');click(3);F.eq(r.nodeFlow.event.stage,'result');F.eq(r.phase,'node');F.eq(get('eventView/option2').visible,false);click(1);F.eq(r.phase,'map')
-- Every ordinary colorless candidate fits the existing two-line event slot,
-- including cost/type/rarity and complete canonical rules; no clipped values.
local Display=require('abyss_card_display')
for _,id in ipairs(r.data.cards.sourcePools.srcColorless)do
 local d;for _,v in ipairs(r.data.cards.cards)do if v.id==id then d=v;break end end
 local text='费用 '..p[id].cost..' · '..({attack='攻击',skill='技能',power='能力'})[d.type]..' · '..({rare='稀有',uncommon='罕见'})[d.rarity]..'｜'..Display.permanentText(p[id],d,{upgraded=false})
 local _,fits=Display.fit(text,14,680,40);assert(fits,'reward description exceeds native event slot: '..id)
end
print('SENSORY_STONE_UI_PASS three costs, four reward/skip actions, full card name/cost/rules, stale callbacks/touches and separate exits; all35 fit existing layout')
