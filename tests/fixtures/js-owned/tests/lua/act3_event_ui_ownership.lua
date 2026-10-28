-- Real current EventCombat/NodeUI and strict native controls. Chapter, event ID
-- and late rare queue are controlled component inputs, not a natural run.
local F=dofile('tests/lua/support/sensory_stone_fixture.lua')
local U=dofile('tests/lua/support/game_ui_fixture.lua')
local UI=require('abyss_node_ui')
local function spec(list,name)
 for _,v in ipairs(list)do
  if v.name==name then return v end
  local found=v.children and spec(v.children,name);if found then return found end
 end
end
local function panel(id)
 local run,map,nodeId=F.fixture()
 for _,node in ipairs(map.nodes)do if node.id==nodeId then node.eventId=id end end
 run.relicPool.queues.rare={'TungstenRod'}
 assert(F.Nodes.enter(run,map,nodeId))
 if id=='mysterious_sphere'then assert(F.Nodes.chooseEvent(run,'open'))end
 local root=U.control(spec(U.Layout,'nodePanel'))
 local presentation=require('abyss_character_presentation').prepare(U.Presentation,run.data)
 local ui=UI.new(root,run,map,presentation,'click',nil,{cursorEvents={
  CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'},
  color=function(...)return{...}end,imageSource='static'})
 ui:setVisible(true)
 local touch=700
 local function tap()
  touch=touch+1;local hit=root:GetChild('eventView'):GetChild('option1'):GetChild('hit')
  assert(hit.kind=='cursorArea'and hit.raycastTarget)
  hit.listeners.down({touchId=touch});hit.listeners.up({touchId=touch})
  return hit.listeners.click({touchId=touch})
 end
 return run,map,ui,root,tap
end
local count,failed=0,0
local function case(id,name,fn)
 local ok,why=pcall(fn);count=count+1
 print('ACT3_EVENT_UI_OWNERSHIP_CASE '..id..' '..name..' '..(ok and 'PASS'or'FAIL '..tostring(why)))
 if not ok then failed=failed+1 end
end
for _,id in ipairs({'mysterious_sphere','mind_bloom'})do
 case(id,'physical_event_owner_replacement',function()
  local run,_,_,_,tap=panel(id)
  run.nodeFlow.event=F.C.copy(run.nodeFlow.event)
  local before=F.C.copy(run);local ok=tap()
  assert(ok==false,'native callback committed against replacement event owner: '..run.phase);F.same(run,before)
 end)
 case(id,'room_generation_changed',function()
  local run,_,ui=panel(id);local old=ui.actions['eventView/option1'].handler
  run.roomGeneration=run.roomGeneration+1
  local before=F.C.copy(run);local ok=old()
  assert(ok==false,'captured fight committed after room generation changed: '..run.phase);F.same(run,before)
 end)
 case(id,'hide_show_does_not_revive_old_fight',function()
  local run,_,ui=panel(id);local old=ui.actions['eventView/option1'].handler
  ui:setVisible(false);ui:setVisible(true)
  local before=F.C.copy(run);local ok=old()
  assert(ok==false,'hide/show revived the old fight callback: '..run.phase);F.same(run,before)
 end)
 case(id,'detached_control_old_handler',function()
  local run,_,ui,root=panel(id);local old=ui.actions['eventView/option1'].handler
  root:GetChild('eventView'):GetChild('option1').parent=nil
  local before=F.C.copy(run);local ok=old()
  assert(ok==false,'detached option fight callback committed: '..run.phase);F.same(run,before)
 end)
 case(id,'fresh_native_fight_still_works',function()
  local run,_,_,_,tap=panel(id);assert(tap())
  assert(run.phase=='combat'and run.eventCombat.eventId==id and run.nodeFlow.eventCombat)
 end)
end
assert(failed==0,tostring(failed)..' Act3 native ownership cases failed')
print('ACT3_EVENT_UI_OWNERSHIP_PASS '..count)
