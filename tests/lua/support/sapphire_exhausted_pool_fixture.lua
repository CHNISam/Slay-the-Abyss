-- Current exhausted-pool checkpoint only. Keep both frozen fixture bodies
-- intact and exhaust finite chest-hook charges as well as their source queues.
return function(runCases)
 local original=dofile
 local loaded,adapted=false,0
 dofile=function(path)
  if path~='tests/lua/support/sapphire_source_fixture.lua'then return original(path)end
  assert(not loaded);loaded=true
  local fixture=original(path);local stage=fixture.stage
  fixture.stage=function(run,options)
   local result=table.pack(stage(run,options))
   if options and options.exhausted then
    adapted=adapted+1
    for _,tier in ipairs({'common','uncommon','rare'})do assert(#run.relicPool.queues[tier]==0)end
    for _,id in ipairs(run.relics)do
     if id=='matryoshka'or id=='Matryoshka'then run.relicCounters[id]=-2 end
    end
   end
   return table.unpack(result,1,result.n)
  end
  dofile=original
  return fixture
 end
 local ok,reason=pcall(runCases)
 dofile=original
 if not ok then error(reason,0)end
 assert(loaded and adapted==1,'only the one exhausted-pool group may adapt its finite charges')
 print('SAPPHIRE_EXHAUSTED_POOL_FIXTURE '..adapted)
end
