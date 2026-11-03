local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map,UI=require('abyss_map'),require('abyss_map_ui')
local root=F.control({children=require('abyss_map_controls').controls})
local map=Map.generate(F.Data,1)
local ui;ui=UI.new(root,map,function(node)return Map.choose(ui.map,node.id)end,'click',{
 imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end})
local frame=0
local function snapshot()
 frame=frame+1
 local rows={}
 for i,fx in ipairs(ui.activeFx)do
  local box=fx.box;local icon,ring,hit=box:GetChild('icon'),box:GetChild('ring'),box:GetChild('hit')
  local c=icon.imageColor or {}
  local values={i,fx.state,tostring(fx.visible),tostring(box.visible),box.x or 0,box.y or 0,
   c.r or 0,c.g or 0,c.b or 0,c.a or 0,(icon.size or {})[1] or 0,(icon.size or {})[2] or 0,(ring.size or {})[1] or 0,(ring.size or {})[2] or 0,
   tostring(ring.visible),tostring(hit.visible),tostring(hit.canControllerFocus),icon.image or '',fx.alpha,fx.scale}
  for n,v in ipairs(values)do values[n]=tostring(v)end
  rows[#rows+1]=table.concat(values,',')
 end
 print('FRAME '..frame..' '..table.concat(rows,';'))
end
ui:resize(1280,720)
for _=1,300 do ui:update(1/60);snapshot()end
for _=1,4 do
 local next=Map.available(ui.map)[1];assert(Map.choose(ui.map,next.id));ui:render();snapshot()
 for _=1,12 do ui:update(1/30);snapshot()end
end
for _,offset in ipairs({200,600,0,150})do ui:setScroll(offset);snapshot();ui:update(.1);snapshot()end
ui:setVisible(false);ui:update(.5);snapshot();ui:setVisible(true);snapshot()
ui:setReducedMotion(true);ui:update(.3);snapshot();ui:setReducedMotion(false);ui:update(.3);snapshot()
for _,seed in ipairs({42,1,5,1})do ui.map=Map.generate(F.Data,seed);ui:render();snapshot();ui:update(.1);snapshot()end
ui:resize(720,1280);ui:render();snapshot()
print('MAP_SIZE_TRACE_PASS '..frame)
