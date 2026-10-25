-- TASK-15.18: source-ordered eight-item pool, not original PC seed parity.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Map,Nodes=require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local C,R,I,Data=require('abyss_combat'),require('abyss_sts_random'),require('abyss_inventory'),require('abyss_data')
local count,failed=0,0
local function eq(a,b,label) if a~=b then assert(false,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end end
local function same(a,b,path)
 path=path or 'state';eq(type(a),type(b),path)
 if type(a)~='table' then eq(a,b,path);return end
 for k,v in pairs(a) do same(v,b[k],path..'.'..tostring(k)) end
 for k in pairs(b) do assert(a[k]~=nil,path..' missing '..tostring(k)) end
end
-- Run owns the battle generation; standalone Core.new has no Run metadata.
-- Normalize this single proven host field on a copy, then compare everything.
local function sameRunCombat(run,expected)
 local generation=run.combatGeneration
 assert(type(generation)=='number'and generation%1==0 and generation>=1 and generation<=2147483647,'invalid Run combat generation')
 eq(run.combat.combatGeneration,generation,'Run/battle generation ownership')
 eq(expected.combatGeneration,nil,'standalone Core generation')
 local reference=C.copy(expected)
 reference.combatGeneration=generation
 same(run.combat,reference)
end
local function freeze(...)
 local refs={}
 local function visit(t)
  if type(t)~='table' or refs[t] then return end
  local fields={};refs[t]=fields;for k,v in pairs(t) do fields[k]=v;visit(v) end
 end
 for _,v in ipairs({...}) do visit(v) end
 return function()
  for t,fields in pairs(refs) do
   for k,v in pairs(fields) do eq(t[k],v,'preserved field '..tostring(k)) end
   for k in pairs(t) do assert(fields[k]~=nil,'unexpected field '..tostring(k)) end
  end
 end
end
local function test(name,fn)
 count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'ok ' or 'not ok ')..count..' - '..name..(ok and '' or ': '..tostring(err)))
end
local function ids(battle) local out={};for i,e in ipairs(battle.enemies) do out[i]=e.definitionId end;return out end
-- Independent oracle: rank remaining ORIGINAL slots via a used-index mask.
-- Never read production data; never remove/reorder items like the implementation.
local source={'mad_gremlin','mad_gremlin','sneaky_gremlin','sneaky_gremlin','fat_gremlin','fat_gremlin','shield_gremlin','wizard_gremlin'}
local function oracle(indices)
 local used,out={},{}
 for slot,n in ipairs(indices) do
  local rank=0
  for original,id in ipairs(source) do if not used[original] then
   if rank==n then used[original]=true;out[slot]=id;break end
   rank=rank+1
  end end
  assert(out[slot],'oracle out-of-range input')
 end
 return out
end
local vectors={
 {{0,0,0,0},{'mad_gremlin','mad_gremlin','sneaky_gremlin','sneaky_gremlin'}},
 {{7,6,5,4},{'wizard_gremlin','shield_gremlin','fat_gremlin','fat_gremlin'}},
 {{2,2,2,2},{'sneaky_gremlin','sneaky_gremlin','fat_gremlin','fat_gremlin'}},
 {{6,6,0,0},{'shield_gremlin','wizard_gremlin','mad_gremlin','mad_gremlin'}},
 {{1,2,3,4},{'mad_gremlin','sneaky_gremlin','fat_gremlin','wizard_gremlin'}},
}
-- Force only four misc integer RESULTS, retaining real stream advancement and
-- exact bound checks. HP/AI/Combat.random and production content stay untouched.
local function force(indices,fn)
 local original,calls=R.randomInt,0
 R.randomInt=function(state,upper)
  calls=calls+1;eq(upper,8-calls,'inclusive upper bound');assert(calls<=4,'extra misc draw')
  original(state,upper);return indices[calls]
 end
 local ok,why=pcall(fn,function() return calls end)
 R.randomInt=original;assert(ok,why)
end
local function direct(seed,advanced)
 local run=Run.new(Data,seed or 42);run.floor=5
 for _=1,advanced or 0 do R.randomInt(run.miscRng,999) end
 return run
end
local function paths(map)
 local seen={};for _,n in ipairs(Map.available(map)) do seen[n.id]={n.id} end
 for _,n in ipairs(map.nodes) do if seen[n.id] then for _,nextId in ipairs(n.nextIds) do if not seen[nextId] then
  local path=C.copy(seen[n.id]);path[#path+1]=nextId;seen[nextId]=path
 end end end end
 return seen
end
local function nodeSetup(seed,id)
 local run,map=Run.new(Data,seed),Map.generate(Data,seed)
 local path=assert(paths(map)[id]);for i=1,#path-1 do assert(Map.choose(map,path[i])) end
 return run,map,id
end
-- Position a real map frontier plus three consumed weak queue entries. These
-- are isolated entry fixtures, not claimed completed preceding victories.
local function frontier(seed,kind)
 local run,map=Run.new(Data,seed),Map.generate(Data,seed)
 local path=dofile('tests/lua/support/map_routes.lua').to(map,function(n)return n.floor>=4 and n.type==kind end)
 for i=1,#path-1 do assert(Map.choose(map,path[i]))end
 local Q=require('abyss_encounter_queue')
 for _=1,3 do local _,nextQueue=Q.consume(run.encounters,'normal');run.encounters=nextQueue end
 eq(Q.peek(run.encounters,'normal'),'Gremlin Gang')
 return run,map,path[#path]
end
local function normal()return frontier(5,'combat')end
local function unknown()return frontier(91,'event')end
local function enter(entry,run,map,id)
 if entry=='direct' then return Run.startCombat(run,'gremlin_gang') end
 return Nodes.enter(run,map,id)
end
local function streamAfter(run,floor)
 local s=floor and Run.roomStreams(run,floor).miscRng or R.cloneState(run.miscRng)
 for _,upper in ipairs({7,6,5,4}) do R.randomInt(s,upper) end;return s
end

local function frontierCases(entry)
test(entry..' source queue frontier commits four room misc draws and never redraws on view/reentry',function()
 local setup=entry=='normal' and normal or unknown;local run,map,id=setup();local again,againMap=setup()
 local target;for _,n in ipairs(Map.available(map))do if n.id==id then target=n end end
 local wanted=streamAfter(run,target.floor);local indices={};local before=Run.roomStreams(run,target.floor).miscRng
 for _,upper in ipairs({7,6,5,4})do indices[#indices+1]=R.randomInt(before,upper)end
 local oldMisc=run.miscRng;local oldStable=freeze(oldMisc)
 local oldEvent=run.eventRng;local eventAfter=R.cloneState(oldEvent);local oldEventStable=freeze(oldEvent)
 if entry=='unknown' then R.randomFloat(eventAfter) end
 assert(Nodes.enter(run,map,id));eq(run.encounterId,'gremlin_gang');eq(#run.combat.enemies,4)
 same(ids(run.combat),oracle(indices))
 same(run.miscRng,wanted);eq(run.miscRng.counter,4);oldStable();same(run.eventRng,eventAfter)
 eq(run.nodeFlow.sourceType,entry=='normal' and 'combat' or 'event');eq(run.nodeFlow.type,'combat')
 if entry=='unknown' then
  for _,n in ipairs(map.nodes) do if n.id==id then eq(n.type,'event');eq(n.encounterId,nil) end end
  eq(run.unknown.chances.monster,R.float32(.1));eq(run.unknown.chances.shop,R.float32(.06));eq(run.unknown.chances.treasure,R.float32(.04))
  same(run.unknown.pools,again.unknown.pools)
 else same(run.eventRng,oldEvent) end
 oldEventStable()
 local stable=freeze(run,map);Nodes.view(run,map);Nodes.view(run,map);eq(Nodes.enter(run,map,id),false);eq(Run.startCombat(run,'gremlin_gang'),false);stable()
 assert(Nodes.enter(again,againMap,id));same(run,again);same(map,againMap)
end)
end
local function failureCases(entry)
 for _,failure in ipairs({'return','throw','tail_return','tail_throw'}) do test(entry..' '..failure..' preserves every old reference and retry equals fresh success',function()
  local setup=entry=='direct' and direct or entry=='normal' and normal or unknown
  local run,map,id=setup();local pristine,pristineMap,pristineId=setup()
  local stable=freeze(run,map);local oldNew,oldOpening=C.new,I.applyOpening;local constructed,tail=0,0
  C.new=function(...)
   local battle,reason=oldNew(...);assert(battle,reason);constructed=constructed+1
   if failure=='throw' then error('injected failure after real construction') end
   if failure=='return' then return nil,'injected_construction_failure' end
   return battle
  end
  I.applyOpening=function(...)
   local ok,reason=oldOpening(...);assert(ok,reason);tail=tail+1
   if tail==2 and failure=='tail_throw' then error('injected tail failure') end
   if tail==2 and failure=='tail_return' then return false,'injected_tail_failure' end
   return ok,reason
  end
  local called,ok,reason=pcall(enter,entry,run,map,id);C.new,I.applyOpening=oldNew,oldOpening
  eq(constructed,1)
  if entry=='direct' and failure:find('throw',1,true) then eq(called,false)
  else eq(called,true);eq(ok,false);assert(type(reason)=='string') end
  stable()
  assert(enter(entry,run,map,id));assert(enter(entry,pristine,pristineMap,pristineId));same(run,pristine);same(map,pristineMap);eq(run.miscRng.counter,4)
 end) end
end
local function finish(expected,marker)
eq(count,expected,'registered original groups')
assert(failed==0,tostring(failed)..' failed of '..count)
print(marker..' '..count)
end
return {Run=Run,Map=Map,Nodes=Nodes,C=C,R=R,I=I,Data=Data,eq=eq,same=same,sameRunCombat=sameRunCombat,freeze=freeze,test=test,ids=ids,oracle=oracle,vectors=vectors,force=force,direct=direct,nodeSetup=nodeSetup,normal=normal,unknown=unknown,enter=enter,streamAfter=streamAfter,frontierCases=frontierCases,failureCases=failureCases,finish=finish}
