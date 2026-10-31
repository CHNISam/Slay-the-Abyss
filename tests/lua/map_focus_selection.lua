local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map,UI=require('abyss_map'),require('abyss_map_ui')
local Layout=require('abyss_map_layout')
local bounds=dofile('tests/lua/support/map_draw_bounds.lua')
local cases=0
for act=1,4 do for _,dt in ipairs({0,1/60,.1,.5,1,3})do
 local map=Map.generate(F.Data,'42',act)
 local root=F.control({children=require('abyss_map_controls').controls})
 local panel=root:GetChild('stage'):GetChild('mapPanel')
 local ui=UI.new(root,map,function(node)return Map.choose(map,node.id)end,'click',{
  imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
 assert(ui:update(dt))
 local chosen=Map.available(map)[1]
 assert(ui:choose(chosen.id));assert(ui:focusCurrent())
 local expected=math.max(0,math.min(Layout.maxScroll,Layout.firstY-Layout.focusY))
 assert(ui.scroll==expected,'selection must preserve first-floor focus offset')
 for i,node in ipairs(map.nodes)do if node.id==chosen.id then
  local box=F.mapControl(panel,'node'..i)
  assert(box.visible and box:GetChild('positionToken').visible,'selected room must be visible without another update')
  bounds(box,Layout.viewport)
  for _,step in ipairs({0,1/120,1/60,.25})do
   assert(ui:update(step));assert(box.visible,'selected room must stay visible after focus');bounds(box,Layout.viewport)
  end
 end end
 cases=cases+1
end end
print('MAP_FOCUS_SELECTION_PASS '..cases)
