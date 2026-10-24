package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C=require('abyss_run'),require('abyss_combat')
local mode=os.getenv('MUTATION')
local realNew,realCopy=Run.new,C.copy
local templates,cloneChecks={},0
local function graph(a,b,ab,ba)
 assert(type(a)==type(b),'graph type mismatch')
 if type(a)~='table' then assert(a==b,'graph value mismatch');return end
 ab,ba=ab or {},ba or {}
 if ab[a] then assert(ab[a]==b,'alias split');return end
 assert(not ba[b],'alias merge');ab[a],ba[b]=b,a
 for k,v in pairs(a) do graph(v,b[k],ab,ba) end
 for k in pairs(b) do assert(a[k]~=nil,'graph extra key') end
end
local function tables(value,seen)
 seen=seen or {};if type(value)~='table' or seen[value] then return seen end
 seen[value]=true;for _,v in pairs(value) do tables(v,seen) end;return seen
end
Run.new=function(...)
 local v=realNew(...);templates[v]=realCopy(v);return v
end
C.copy=function(v)
 local result=realCopy(v)
 if mode=='shared-data' and templates[v] then result.data=v.data end
 if templates[v] then
  graph(v,result)
  local originals=tables(v)
  for t in pairs(tables(result)) do assert(not originals[t],'mutable table shared by copy') end
  cloneChecks=cloneChecks+1
 end
 return result
end
local starts=0
for _,name in ipairs({'startCombat','startRoomCombat'}) do
 local real=Run[name]
 Run[name]=function(run,...)
  local ok,reason=real(run,...)
  if ok then
   if mode=='split-alias' then run.combat.player.statusDefinitions=realCopy(run.combat.catalog.statuses) end
   assert(run.combat.player.statusDefinitions==run.combat.catalog.statuses,'opening player status alias split')
   for _,enemy in ipairs(run.combat.enemies) do assert(enemy.statusDefinitions==run.combat.catalog.statuses,'opening enemy status alias split') end
   starts=starts+1
  end
  return ok,reason
 end
end
dofile(assert(os.getenv('FIXTURE')))
local count=0;for v,snapshot in pairs(templates) do graph(v,snapshot);count=count+1 end
print('COLD_TEMPLATE_CONTRACT_PASS',count,cloneChecks,starts)
