local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map,UI=require('abyss_map'),require('abyss_map_ui')
local Layout=require('abyss_map_layout')
local function newUI(seed)
 local root=F.control({children=require('abyss_map_controls').controls})
 local map=Map.generate(F.Data,seed)
 return UI.new(root,map,function()end,'click',{imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}),map
end
local function checkRoom(fx,label)
 local icon=fx.size*Layout.sts.iconPerScale*UI.drawScale(fx)
 local ring=fx.size*Layout.sts.circlePerScale*(fx.scale*.95+.2)
 for name,size in pairs({icon=icon,ring=ring})do
  local actual=fx.box:GetChild(name).size
  assert(math.abs(actual[1]-size)<1e-8 and math.abs(actual[2]-size)<1e-8,label..' stale '..name..' size')
 end
end
local function check(ui,label)
 for _,fx in ipairs(ui.activeFx)do if fx.visible then checkRoom(fx,label)end end
end
local ui,first=newUI(42)
local mapOk,mapError=pcall(function()
ui:update(.1);check(ui,'first')
for seed=1,10 do
 ui.map=Map.generate(F.Data,seed);ui:render();check(ui,'new '..seed)
 ui.map=first;ui:render();check(ui,'return '..seed)
 ui:update(.1);check(ui,'update '..seed)
end
end)
print(mapOk and 'ok map A/B/A restores pooled icon and ring dimensions' or 'FAIL map A/B/A: '..tostring(mapError))
-- A retained native handle can be handed to another controller's room view.
local other=newUI(1)
local a,b
for _,fx in ipairs(ui.activeFx)do if fx.visible then a=fx;break end end
for _,fx in ipairs(other.activeFx)do if fx.visible then b=fx;break end end
assert(a and b)
b.box=a.box;b.state='locked';b.scale=.83
local controllerOk,controllerError=pcall(function()
UI.paintRoom(a)
for _=1,3 do
 UI.paintRoom(b);checkRoom(b,'other controller')
 UI.paintRoom(a);checkRoom(a,'original controller resumes')
end
end)
print(controllerOk and 'ok distinct controllers sharing a native handle honor the last actual writer' or 'FAIL controller reuse: '..tostring(controllerError))
local retryOk,retryError=pcall(function()
 local icon=a.box:GetChild('icon');local setter=icon.SetSizeDelta;local attempts=0
 icon.SetSizeDelta=function(self,w,h)
  attempts=attempts+1;setter(self,w,h)
  if attempts==1 then return false end
 end
 UI.paintRoom(b) -- A failed setter cannot preserve the old controller's promise.
 UI.paintRoom(a);checkRoom(a,'resume after rejected pooled write')
 assert(attempts==2,'failed pooled write left a stale successful cache entry')
 UI.paintRoom(a);assert(attempts==2,'stable resumed size was not cached')
end)
print(retryOk and 'ok failed pooled write invalidates the old ownership promise' or 'FAIL pooled retry: '..tostring(retryError))
assert(mapOk and controllerOk and retryOk,'native size ownership regressions failed')
