local __abyss_entropy_audit=false
local __abyss_entropy_print=print
do
 local function unseeded()
  __abyss_entropy_audit=true
 end
 local original=package.searchers[2]
 package.searchers[2]=function(name)
  local loader,path=original(name)
  if (name~='abyss_external_random'and name~='abyss_new_run_seed')or type(loader)~='function' then return loader,path end
  return function(...)
   local module=loader(...)
   if name=='abyss_new_run_seed'then
    local nextSeed=module.next
    module.next=function(...)unseeded();return nextSeed(...)end
    return module
   end
   local seeded=false
   local replay=module.setReplayState
   module.setReplayState=function(...)
    local values=table.pack(replay(...));seeded=true
    return table.unpack(values,1,values.n)
   end
   for _,key in ipairs({'begin','snapshot'})do
    local operation=module[key]
    module[key]=function(...)
     if not seeded then unseeded()end
     return operation(...)
    end
   end
   return module
  end,path
 end
end
