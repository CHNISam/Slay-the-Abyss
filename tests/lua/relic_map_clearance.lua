local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map,UI=require('abyss_map'),require('abyss_map_ui')
local L,T=require('abyss_map_layout'),require('abyss_theme')
local checks=0
for act=1,4 do
 local map=Map.generate(F.Data,'42',act)
 local root=F.control({children=require('abyss_map_controls').controls})
 local panel=root:GetChild('stage'):GetChild('mapPanel')
 local ui=UI.new(root,map,function(node)return Map.choose(map,node.id)end,'click',{
  imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
 local function verify()
  for i in ipairs(map.nodes)do
   local b=F.mapControl(panel,'node'..i)
   if b.visible then
    local hit=b:GetChild('hit')
    local w,h=hit.sizeDeltaX or hit.size[1],hit.sizeDeltaY or hit.size[2]
    for k=0,T.layout.relicView.bar.count-1 do
     local x=T.layout.relicView.bar.origin[1]+k*T.layout.relicView.bar.step
     local y=T.layout.relicView.bar.origin[2]
     assert(math.abs(b.x-x)>=(w+T.layout.relicView.bar.step)/2 or math.abs(b.y-y)>=(h+44)/2,
      'visible map node hit overlaps shared relic click area')
    end
    checks=checks+1
   end
  end
 end
 for scroll=0,L.maxScroll+12,12 do ui:setScroll(scroll);verify()end
 -- The previously obscured available eighth-floor node, not only decorative nodes.
 for _=1,math.min(7,#map.nodes)do
  local nextNode=Map.available(map)[1]
  if not nextNode then break end
  ui:setNavigationEnabled(true)
  assert(ui:choose(nextNode.id));assert(ui:focusCurrent());ui:setNavigationEnabled(true);verify()
 end
end
assert(checks>0)
print('RELIC_MAP_CLEARANCE_PASS '..checks)
