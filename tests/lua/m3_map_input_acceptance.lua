local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map,UI=require('abyss_map'),require('abyss_map_ui')
local Layout=require('abyss_map_layout')
local cursor={CursorDown='down',CursorUp='up',CursorDrag='drag',CursorExit='exit',CursorEndDrag='endDrag'}
local passed,failed=0,0
local function test(name,fn)
  local ok,why=pcall(fn)
  if ok then passed=passed+1 else failed=failed+1 end
  print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))
end
local function setup()
  local root=F.control({children=require('abyss_map_controls').controls})
  local panel=root:GetChild('stage'):GetChild('mapPanel')
  local map,calls=Map.generate(F.Data,42),0
  local ui=UI.new(root,map,function(node)calls=calls+1;return Map.choose(map,node.id)end,'click',{
    cursor=cursor,imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end})
  local function emit(slot,kind,id,x,y)
    local box=F.mapControl(panel,slot=='background' and 'dragArea' or 'node'..slot)
    local hit=slot=='background' and box or box:GetChild('hit')
    return assert(hit.listeners[kind])({touchId=id,GetUIPos=function()return x or 640,y or 200 end})
  end
  local function unchanged(before)
    assert(map.floor==0 and map.currentNodeId==nil and calls==0,'cancel entered a node')
    local function equal(a,b)
      if type(a)~=type(b) then return false end
      if type(a)~='table' then return a==b end
      for k,v in pairs(a)do if not equal(v,b[k])then return false end end
      for k in pairs(b)do if a[k]==nil then return false end end
      return true
    end
    assert(equal(Map.snapshot(map),before),'cancel changed route/map/RNG')
  end
  return ui,map,emit,unchanged,function()return calls end
end
for _,device in ipairs({'touch','mouse'}) do
  for _,releaseOnly in ipairs({false,true}) do
    test(device..' horizontal movement cancels '..(releaseOnly and 'without Drag callback' or 'with Drag callback'),function()
      local ui,map,e,unchanged,calls=setup()
      local id=device=='touch' and 7 or nil
      local before=Map.snapshot(map)
      e(1,'down',id,640,200)
      if not releaseOnly then e(1,'drag',id,640+Layout.dragThreshold,200) end
      e(1,'up',id,640+Layout.dragThreshold,200)
      assert(not e(1,'click',id),'horizontal drag was treated as a node tap')
      assert(not e(1,'click',id),'duplicate release Click entered a node')
      unchanged(before);assert(ui.scroll==0,'horizontal drag scrolled vertically')
      e(1,'down',id);e(1,'up',id);assert(e(1,'click',id))
      assert(map.floor==1 and calls()==1,'fresh tap must enter exactly once')
    end)
  end
end
print('LUA_M3_MAP_INPUT_ACCEPTANCE '..passed..' passed; '..failed..' failed')
assert(failed==0,'M3 map input acceptance failed')
