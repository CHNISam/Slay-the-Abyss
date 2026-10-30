package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R,C,Map=require('abyss_run'),require('abyss_combat'),require('abyss_map')
local UI,Pending=require('abyss_node_ui'),require('abyss_relic_pending')
local D,L,P=require('abyss_data'),require('abyss_ui_layout'),require('abyss_presentation')
local _,control=dofile('tests/lua/support/node_ui_cases.lua')(0,0)
local function find(rows,name)
 for _,row in ipairs(rows)do if row.name==name then return row end
  local value=row.children and find(row.children,name);if value then return value end
 end
end
local count=0
local function test(name,f)f();count=count+1;print('PASS '..name)end
local function setup(relic)
 local r=R.new(D,42);local m=Map.generate(D,42)
 assert(R.obtainRelic(r,relic))
 local root=control(find(L,'nodePanel'))
 local p=require('abyss_character_presentation').prepare(P,r.data)
 local ui=UI.new(root,r,m,p,'click',nil,{imageSource='static',cursorEvents={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'}})
 ui:setVisible(true);return r,m,root,ui
end
test('map pending relic renders named card descriptions and pages instead of leaving',function()
 local r,m,root,ui=setup('DollysMirror')
 assert(r.phase=='map'and root:GetChild('eventView').visible)
 assert(not root:GetChild('shopView').visible)
 local option=root:GetChild('eventView'):GetChild('option1')
 assert(option:GetChild('title').text~=''and option:GetChild('description').text~='')
 local old=ui.actions['eventView/option1'].handler
 local before=#r.deck;assert(ui:press('confirm'));assert(ui.pendingPage==2)
 assert(not old());assert(#r.deck==before and Pending.owner(r))
 assert(ui:press('back'));assert(ui.pendingPage==1)
 assert(ui:press('eventView/option1'));assert(#r.deck==before+1 and not Pending.owner(r))
 assert(r.phase=='map')
end)
test('render hide busy and replacement run retire pending gestures',function()
 local r,m,root,ui=setup('DollysMirror');local before=#r.deck
 local old=ui.actions['eventView/option1'].handler;ui:render();assert(not old())
 old=ui.actions['eventView/option1'].handler;ui:setVisible(false);assert(not old())
 assert(not ui:press('eventView/option1'));ui:setVisible(true);assert(not old())
 ui.busy=true;assert(not ui:press('eventView/option1'));ui.busy=false
 local hit=root:GetChild('eventView'):GetChild('option1'):GetChild('hit')
 hit:emit('down',41);ui:render();hit:emit('up',41);hit:emit('click',41)
 assert(#r.deck==before)
 old=ui.actions['eventView/option1'].handler;ui.run=R.new(D,99);assert(not old())
 assert(not ui:press('eventView/option1'));assert(#r.deck==before)
end)
test('Orrery modal claims five real cards and finishes with explicit continue',function()
 local r,m,root,ui=setup('Orrery');local before=#r.deck
 for _=1,5 do assert(ui:press('eventView/option1'))end
 assert(#r.deck==before+5 and Pending.owner(r))
 assert(root:GetChild('eventView'):GetChild('option1'):GetChild('title').text=='继续')
 assert(ui:press('eventView/option1'));assert(not Pending.owner(r))
end)
test('Cauldron modal shows real potion text and full-slot recovery without mutation',function()
 local r,m,root,ui=setup('Cauldron')
 local row=root:GetChild('eventView'):GetChild('option1')
 assert(row:GetChild('title').text~=''and row:GetChild('description').text~='')
 for _=1,3 do assert(ui:press('eventView/option1'))end
 assert(not ui:press('eventView/option1'))
 assert(root:GetChild('notice').text:find('药水槽已满',1,true))
 assert(Pending.owner(r)and not r.shopRelicRewards.items[4].claimed)
 assert(ui:press('eventView/option2'));assert(ui:press('eventView/option2'))
 assert(ui:press('eventView/option1'));assert(not Pending.owner(r))
end)
test('mandatory bottled relic has no leave action and selects a real deck UID',function()
 local r,m,root,ui=setup('Bottled Flame')
 assert(not root:GetChild('back').visible or root:GetChild('back'):GetChild('label').text=='上一页')
 assert(not ui:press('back'))
 local uid=r.pendingBottledRelic.uids[1]
 assert(ui:press('eventView/option1'));assert(not Pending.owner(r))
 local found=false;for _,c in ipairs(r.deck)do if c.uid==uid then assert(c.inBottleFlame);found=true end end
 assert(found)
end)
test('real GameUI gives relic modal priority over map reward and victory',function()
 local F=dofile('tests/lua/support/game_ui_fixture.lua')
 local ui,root=F.fixture();assert(F.start(ui))
 local originalPhase=ui.run.phase
 assert(R.obtainRelic(ui.run,'DollysMirror'))
 ui.run.rewards={cards={},cardResolved=true,gold=0,goldClaimed=true,manualContinue=true}
 for _,phase in ipairs({'map','reward','victory'})do
  ui.run.phase=phase;ui:refresh()
  assert(ui.mode=='node'and root:GetChild('nodePanel').visible)
  assert(not root:GetChild('battlePanel').visible and not root:GetChild('mapPanel').visible)
 end
 ui.run.phase=originalPhase;local before=#ui.run.deck
 assert(ui.nodeUI:press('eventView/option1'));assert(#ui.run.deck==before+1 and not Pending.owner(ui.run))
 assert(ui.mode=='map'and ui.run.phase==originalPhase)
end)
local function chooseKind(ui,kind,choice)
 local rows=Pending.view(ui.run).rows
 for i,row in ipairs(rows)do if row.token.kind==kind and (choice==nil or row.token.choice==choice)then
  assert(ui:setPage(math.floor((i-1)/3)+1))
  return ui:press('eventView/option'..((i-1)%3+1))
 end end
 error('missing modal row '..kind)
end
test('Orrery Singing Bowl is visible per group and applies through native rows',function()
 local r,m,root,ui=setup('singing_bowl');assert(R.obtainRelic(r,'Orrery'));ui:render()
 local before=r.maxHp
 for _=1,5 do assert(chooseKind(ui,'card','bowl'))end
 assert(r.maxHp==before+10);assert(chooseKind(ui,'done'));assert(not Pending.owner(r))
end)
test('boss mandatory selection removes chosen cards and restores origin',function()
 local r,m,root,ui=setup('Empty Cage');local before=#r.deck
 assert(Pending.owner(r));assert(chooseKind(ui,'select'));assert(Pending.owner(r))
 assert(chooseKind(ui,'select'));assert(#r.deck==before-2 and not Pending.owner(r))
end)
test('Tiny House modal exposes actual gold potion and card rewards with descriptions',function()
 local r,m,root,ui=setup('Tiny House');local before=r.gold
 assert(chooseKind(ui,'gold'));assert(r.gold==before+50)
 assert(chooseKind(ui,'potion'));assert(R.potionCount(r)==1)
 local size=#r.deck;assert(chooseKind(ui,'card',1));assert(#r.deck==size+1)
 assert(chooseKind(ui,'done'));assert(not Pending.owner(r))
end)
print('LUA_SHOP_RELIC_PENDING_UI_PASS '..count)
