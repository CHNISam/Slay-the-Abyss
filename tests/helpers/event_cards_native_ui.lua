-- Generated controls + actual Nodes/Run; no desktop or natural-play evidence.
local H={}
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local UI=require('abyss_node_ui')
local function find(list,name)
 for _,entry in ipairs(list)do
  if entry.name==name then return entry end
  local child=entry.children and find(entry.children,name);if child then return child end
 end
end
function H.setup(r,m)
 local spec=assert(find(F.Layout,'nodePanel'))
 local host=F.control({name='host',children={spec}});local root=host:GetChild('nodePanel')
 local presentation=require('abyss_character_presentation').prepare(F.Presentation,r.data)
 local ui=UI.new(root,r,m,presentation,'click',nil,{imageSource='static',
  color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,
  cursorEvents={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='enddrag'}})
 local function get(path)
  local box=root;for key in path:gmatch('[^/]+')do box=assert(box:GetChild(key),path)end;return box
 end
 local function shown(path)
  local box=get(path);while box do if not box.visible then return false end;box=box.parent end;return true
 end
 local function tap(path,touch)
  assert(shown(path),'hidden '..path);local hit=get(path):GetChild('hit')
  if hit.listeners.down then hit.listeners.down({touchId=touch});hit.listeners.up({touchId=touch})end
  return hit.listeners.click({touchId=touch})
 end
 ui:setVisible(true)
 return ui,get,shown,tap,root
end
function H.startUI(r,tap)
 assert(tap('eventView/option1',1));assert(r.nodeFlow.event.stage=='rules')
 assert(tap('eventView/option1',2));assert(r.nodeFlow.event.stage=='play')
end
function H.key(slot)return 'pickerView/forgeGrid/card'..slot end
return H
