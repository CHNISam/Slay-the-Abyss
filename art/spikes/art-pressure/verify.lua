-- Offline lifecycle checks only; these do not measure platform performance.
local live, maximum, destroyed = 0, 0, 0
local callbacks, logs = {}, {}
local function object(parent)
  local c = {alive=true, children={}, parent=parent, text=''}
  if parent then parent.children[#parent.children+1]=c end
  function c:GetChild(name) return assert(self.children[name], name) end
  function c:AddCursorEventListener(_, fn) callbacks[self.name]=fn end
  return setmetatable(c,{__index=function() return function() end end})
end
local function destroy(c)
  if not c.alive then return end
  for _, child in ipairs(c.children) do destroy(child) end
  c.alive=false; live=live-1; destroyed=destroyed+1
end
game={InstantiateClientUIControl=function(_,p) live=live+1;maximum=math.max(maximum,live);return object(p) end,
 DestroyClientUIControl=destroy,GetUICanvasSize=function() return 1600,900 end}
Enum={CursorEventType={CursorClick=1}}
local costs={AP_A=257,AP_B2=939,AP_Card=15,AP_HighCard=343,AP_Icon=64}
require=function(name) return function(host)
 return {start=function() for i=1,assert(costs[name]) do game.InstantiateClientUIControl(1,host) end end,
 destroy=function() end}
end end
print=function(s) logs[#logs+1]=s end
printerr=error
local root=object()
root.children.Toolbar=root
for _, name in ipairs({'Status','Metrics','Prev','Next','Clear','Rebuild','Motion','Auto','Mid','Masked','High','Extreme','Icons','Reuse'}) do
 root.children[name]=object();root.children[name].name=name
end
script={object=root,EnableUpdate=function() end}
assert(loadfile(arg[1] or 'art/spikes/art-pressure/controller.lua'))()
OnStart();assert(live==0)
callbacks.Mid();assert(live==1435+30)
callbacks.Masked();assert(live==2817+6,'previous stage must be destroyed')
callbacks.Extreme();assert(live==8125+30)
callbacks.Icons();assert(live==640+20)
for i=1,3 do callbacks.Mid();callbacks.Clear();assert(live==0,'clear must release nested geometry and hosts') end
callbacks.Mid();callbacks.Rebuild();assert(live==1465)
callbacks.Motion();OnUpdate(1/30)
callbacks.Reuse();callbacks.Masked();assert(live==1465+2823,'reuse retains but hides old stage')
callbacks.Clear();assert(live==0,'clear must release retained cache too')
callbacks.Auto();for i=1,50 do OnUpdate(1) end
for _,child in ipairs(root.children) do destroy(child) end -- engine tears down the subtree
OnDestroy();assert(live==0)
io.write('PASS pressure lifecycle: stage switching, nested cleanup, repeated rebuild, reuse cache, motion, auto sweep\n')
