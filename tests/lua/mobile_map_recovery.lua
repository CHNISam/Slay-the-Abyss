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
local function ev(id)return {touchId=id,GetUIPos=function()return 640,200 end}end
dragArea.listeners.down(ev(7))
-- Native release was lost. The fresh Down on a node retires the old surface.
hit.listeners.down(ev(7))
dragArea.listeners.up(ev(7)) -- delayed old surface release cannot submit
assert(host.mode=='map' and host.map.floor==0)
assert(not hit.listeners.click(ev(7)))
hit.listeners.up(ev(7))
assert(hit.listeners.click(ev(7)))
assert(host.mode=='battle' and host.map.floor==1)
print('LUA_MOBILE_MAP_RECOVERY 1 passed')
