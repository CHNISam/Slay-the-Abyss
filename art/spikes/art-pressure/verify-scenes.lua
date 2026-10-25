-- Current controller + real art exporters. Offline contract, never platform FPS.
local folder='art/spikes/art-pressure/'
local live,moves=0,0
local callbacks,logs,request,ack={}, {}, nil,nil
local createFailure=false
local function control(parent)
 local c={alive=true,children={},active=true,parent=parent}
 if parent then parent.children[#parent.children+1]=c end
 function c:GetChild(name) return assert(self.children[name],name) end
 function c:AddCursorEventListener(_,fn) callbacks[self.name]=fn end
 function c:SetActive(v) self.active=v end
 function c:SetImage(source,id) self.imageSource=source;self.imageId=id end
 function c:SetAnchoredPosition() moves=moves+1 end
 return setmetatable(c,{__index=function() return function() end end})
end
local function destroy(c)
 if not c.alive then return end
 for i=#c.children,1,-1 do destroy(c.children[i]) end
 if c.parent then for i=#c.parent.children,1,-1 do if c.parent.children[i]==c then table.remove(c.parent.children,i);break end end end
 c.alive=false;live=live-1
end
game={InstantiateClientUIControl=function(_,parent)
 if createFailure then createFailure=false;error('injected allocation failure') end
 live=live+1;return control(parent)
end,DestroyClientUIControl=destroy,GetUICanvasSize=function() return 1600,900 end,
ServerSignal=function() local values={};return {AddInt=function(_,n) values[#values+1]=n end,SendSignal=function() request=values end} end}
Enum=setmetatable({},{__index=function(t,k) local v=setmetatable({},{__index=function() return 1 end});rawset(t,k,v);return v end})
Color={FromRGBA=function(...) return {...} end}
print=function(s) logs[#logs+1]=s end
local sources=assert(ARTPRESS_TEST_SOURCES,'Use run-verify.mjs to load actual exporter sources')
local factories={}
require=function(name)
 if name=='AP_Scenes' then return dofile(folder..'scenes.lua') end
 if name=='AP_Production25D' then return dofile(folder..'production-25d.lua') end
 if name=='AP_Icon' then return function(host,count) return {start=function() for i=1,count do game.InstantiateClientUIControl(0,host) end end,destroy=function() end} end end
 if factories[name] then return factories[name] end
 local raw=assert(sources[name],name):gsub('%-%- MILIASTRA_EDITOR_SCENE_V1[^\n]*\n','')
 raw=raw:gsub('local IMAGE_PREFAB_ID%s*=%s*0','local IMAGE_PREFAB_ID = 1'):gsub('local TEXTBOX_PREFAB_ID%s*=%s*0','local TEXTBOX_PREFAB_ID = 2')
 factories[name]=assert(load('return function(host) local script={object=host};local OnStart,OnDestroy;local printerr=error;\n'..raw..'\nreturn {start=OnStart,destroy=OnDestroy} end'))()
 return factories[name]
end
local root=control();root.children.Toolbar=root
for _,name in ipairs({'Backdrop','Status','Metrics','Prev','Next','Clear','Rebuild','Motion','Auto','Mid','Masked','High','Extreme','Icons','Reuse'}) do root.children[name]=control();root.children[name].name=name end
script={object=root,EnableUpdate=function() end,RegisterServerSignalHandler=function(_,_,fn) ack=fn end}
local source=sources.AP_Control:gsub('local EXTENDED = false','local EXTENDED = true')
assert(load(source))()
local function contains(needle) for _,s in ipairs(logs) do if s:find(needle,1,true) then return true end end return false end
local function ready(count,group,id) ack(nil,{group or request[1],count or (request[1]==100 and 32 or request[1]*7),id or request[2]}) end
OnStart();assert(live==0 and request[1]==100 and request[2]==1)
for i=1,8 do OnUpdate(1) end
assert(not contains('ARTPRESS_DT'),'sampling must wait for ACK')
ready(32);OnUpdate(1);assert(not contains('ARTPRESS_DT'),'ACK wait is excluded from warmup')
local stage=33
local function go(target)
 while stage~=target do
  if (target-stage)%41<=(stage-target)%41 then callbacks.Next();stage=stage%41+1
  else callbacks.Prev();stage=(stage-2)%41+1 end
 end
end
local base={0,160,320,640,257,771,1285,939,2817,4695,15,75,150,343,1715,3430,1435,4715,8125,8765}
local hosts={0,20,20,20,2,6,10,2,6,10,2,10,20,2,10,20,30,30,30,50}
local extra={0,0,0,0,195,774,1542,1465,8155,2239,9697,8815,0,221,1465,1686,8155,8376,221,1686,8376}
go(1)
for i=1,41 do
 if stage~=i then go(i) end
 local expected=i<=20 and base[i]+hosts[i] or extra[i-20]
 assert(live==expected,'stage '..i..' expected '..expected..' got '..live..' '..tostring(root.children.Status.text))
 ready();OnUpdate(1/30)
end
local before=moves;OnUpdate(1/30);assert(moves-before==15,'static background moves zero;15 foreground groups move')
go(39);ready(0);before=moves;OnUpdate(1/30);assert(moves==before,'pure2D is completely static')
callbacks.Rebuild();assert(live==221)
go(33);ready(32);local oldId=request[2]
go(34);go(33);logs={};ready(32,100,oldId)
for i=1,11 do OnUpdate(1) end
assert(contains('ARTSCENE_ACK_STALE') and not contains('ARTPRESS_DT'))
ready(32);for i=1,10 do OnUpdate(1) end;assert(contains('ARTPRESS_DT'))
go(33);ready(32);logs={};callbacks.Clear();assert(live==0 and request[1]==0)
assert(contains('ARTPRESS_CLEAR_PENDING') and not contains('ARTPRESS_CLEARED'))
ready(0);assert(contains('ARTPRESS_CLEARED'))
go(33);logs={};ready(31);assert(contains('ARTSCENE_FAIL_COUNT') and root.children.Status.active)
go(34);go(33);logs={};for i=1,17 do OnUpdate(1) end
assert(contains('ARTSCENE_ACK_TIMEOUT') and root.children.Status.active and not contains('ARTPRESS_DT'))
go(33);ready(32);createFailure=true;logs={};go(34)
assert(live==0 and contains('ARTPRESS_FAIL') and root.children.Status.active)
callbacks.Clear();ready(0);assert(live==0)
OnDestroy();assert(live==0,'engine owns teardown')
io.write('PASS all41 stages: real character/card modules, static2D, parallax, cleanup, request IDs, stale/wrong/missing ACK and allocation failure\n')
