local F=dofile('tests/lua/support/game_ui_fixture.lua')
local cursor={CursorDown='down',CursorUp='up',CursorDrag='drag',CursorExit='exit',CursorEndDrag='endDrag'}
local host,root=F.fixture(nil,function()return true end,nil,cursor)
assert(F.start(host))
local panel=root:GetChild('mapPanel')
local dragArea=F.mapControl(panel,'dragArea')
local available=F.Nodes.available(host.run,host.map)[1].id
local slot
for i,id in pairs(host.mapUI.slots)do if id==available then slot=i end end
assert(slot,'available node not drawn')
local hit=F.mapControl(panel,'node'..slot):GetChild('hit')
local function ev(id,y)return {touchId=id,GetUIPos=function()return 640,y or 200 end}end
local function tap(id)
  hit.listeners.down(ev(id));hit.listeners.up(ev(id));return hit.listeners.click(ev(id))
end
dragArea.listeners.down(ev(7))
-- Model a physical release the native dispatch surface failed to deliver.
-- Every later click is complete, using the same pointer ID on a real node.
for i=1,3 do
  local ok,reason=tap(7)
  print('MAP_RETRY',i,tostring(ok),tostring(reason),host.mode,host.map.floor)
  assert(ok==false and reason=='stale_gesture' and host.mode=='map' and host.map.floor==0)
end
assert(host:openExit() and host:closeExit())
local ok,reason=tap(7)
print('MAP_AFTER_EXIT_CONTINUE',tostring(ok),tostring(reason),host.mode,host.map.floor)
assert(ok==true and host.mode=='battle' and host.map.floor==1)
print('MAP_LOST_RELEASE_CURRENT_SOURCE_CONFIRMED')
