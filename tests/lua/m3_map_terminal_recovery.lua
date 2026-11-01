local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map,UI=require('abyss_map'),require('abyss_map_ui')
local cursor={CursorDown='down',CursorUp='up',CursorDrag='drag',CursorExit='exit',CursorEndDrag='endDrag'}
local passed=0
for _,device in ipairs({'touch','mouse'}) do
 for _,surface in ipairs({'background','node'}) do
  for _,boundary in ipairs({'endDrag','overlay'}) do
   local root=F.control({children=require('abyss_map_controls').controls})
   local panel=root:GetChild('stage'):GetChild('mapPanel')
   local map,calls=Map.generate(F.Data,42),0
   local ui=UI.new(root,map,function(node)calls=calls+1;return Map.choose(map,node.id)end,'click',{
     cursor=cursor,imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end})
   local id=device=='touch' and 7 or nil
   local function emit(slot,kind,touch)
    local box=F.mapControl(panel,slot=='background' and 'dragArea' or 'node'..slot)
    local hit=slot=='background' and box or box:GetChild('hit')
    return assert(hit.listeners[kind])({touchId=touch,GetUIPos=function()return 640,200 end})
   end
   local owner=surface=='background' and 'background' or 1
   emit(owner,'down',id) -- deliberately omit Up
   if boundary=='endDrag' then emit(owner,'endDrag',id)
   else ui:setVisible(false);ui:setVisible(true) end
   emit(owner,'up',id)
   if owner~='background' then assert(not emit(owner,'click',id)) end
   assert(map.floor==0 and calls==0,'terminal cancellation entered node')
   -- Explicit terminal event ends the old ownership. Same-ID reuse is valid.
   emit(2,'down',id)
   emit(owner,'up',id)
   if owner~='background' then assert(not emit(owner,'click',id)) end
   assert(not emit(2,'click',id) and map.floor==0 and calls==0,'old release armed a new node')
   emit(2,'up',id);assert(emit(2,'click',id))
   assert(not emit(2,'click',id) and calls==1 and map.floor==1)
   passed=passed+1;print('PASS '..device..' '..surface..' '..boundary..' missing-Up recovery')
  end
 end
end
print('M3_MAP_TERMINAL_RECOVERY '..passed..' passed')
