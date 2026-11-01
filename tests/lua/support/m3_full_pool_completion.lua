-- Controlled destination/stream fixtures, not natural campaign/device evidence.
-- Unlike explicit eventId routes, every identity must pass the unchanged full
-- source pool and production unknown-room reducer before its public commands.
local Run,N,Map,C,D=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_data')
local Pool,R,U=require('abyss_event_pool'),require('abyss_sts_random'),require('abyss_unknown')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function copy(r)return C.copy(r,{[r.data]=r.data})end
local function route(map,target)
 for _,node in ipairs(Map.available(map))do
  local m=C.copy(map);assert(Map.choose(m,node.id))
  if node.floor==target and #node.nextIds==1 then return m end
  if node.floor<target then local result=route(m,target);if result then return result end end
 end
end
local overrides={mushrooms='heal',big_fish='banana',bonfire='approach',the_library='sleep',back_to_basics='elegance',
 living_wall='forget',knowing_skull='leave',masked_bandits='pay'}
local function finish(r,m,original)
 for _=1,40 do
  if r.phase=='map'then return end
  if r.phase=='combat'then
   for _=1,12 do
    if r.phase~='combat'then break end
    local ok,slot=Run.obtainPotion(r,'explosive_potion');assert(ok,slot);assert(Run.usePotion(r,slot))
   end
   eq(r.lastResult.outcome,'victory')
  end
  local node=N.view(r,m).node;local e=node.event;local match=e.match
  local choice,uid
  if match and match.phase=='play'then
   choice='flip';for _,slot in ipairs(match.slots)do if slot.enabled then uid=slot.token;break end end
  elseif match and match.phase=='resolving'then choice,uid='resolve',match.resolveToken
  elseif match and match.phase=='cleanup'then choice,uid='finish',match.completionToken
  else
   for _,option in ipairs(e.options)do if option.enabled and option.choice=='leave'then choice='leave';break end end
   if not choice then
    for _,option in ipairs(e.options)do
     if option.enabled and (not overrides[e.id]or option.choice==overrides[e.id]or e.stage=='result')then choice=option.choice;break end
    end
   end
   if not choice then for _,option in ipairs(e.options)do if option.enabled then choice=option.choice;break end end end
   local cards=e.selectionCards or e.purgeCards or node.upgradeCards
   if e.stage=='choose_card'and cards and cards[1]then uid=cards[1].uid end
  end
  assert(choice,original..' no public completion at '..tostring(e.stage))
  local ok,why=N.chooseEvent(r,choice,uid)
  assert(ok,original..' '..tostring(e.stage)..' '..choice..': '..tostring(why))
 end
 error(original..' did not finish')
end
return function(act,first,last)
local count,identities=0,{}
do
 local base=Run.new(D,'42',{experimental=true,campaign=true,campaignProfile='competition-two-act'})
 base.act=act;base.encounters=require('abyss_encounter_queue').new('42',act)
 base.unknown.pools=Pool.new('full',false,act);base.gold=200;base.elapsedSeconds=900
 assert(Run.obtainRelic(base,'anchor'));assert(Run.obtainRelic(base,'vajra'));assert(Run.obtainCard(base,'regret'))
 local map=assert(route(Map.generate(D,'42',act),act==1 and 9 or 24));base.floor=map.floor
 local destination=assert(Map.available(map)[1]);eq(#Map.available(map),1)
 -- Only the destination type is controlled; source event identity is never assigned.
 for _,node in ipairs(map.nodes)do if node.id==destination.id then node.type,node.eventId='event',nil end end
 local context={act=act,floor=destination.floor,gold=base.gold,hp=base.hp,relicCount=#base.relics,cursed=true,elapsedSeconds=900}
 local eligible=Pool.eligible(base.unknown.pools,context);local wanted,streams={},{ }
 for _,group in ipairs({eligible.act,eligible.rare})do for _,id in ipairs(group)do wanted[#wanted+1]=id end end
 local rng=R.cloneState(base.eventRng)
 for _=0,2047 do
  local start=R.cloneState(rng);local nextRng=R.cloneState(rng)
  if U.advancePc(C.copy(base.unknown.chances),R.randomFloat(nextRng),{})=='event'then
   local selection=R.cloneState(nextRng)
   local id=Pool.draw(C.copy(base.unknown.pools),context,selection)
   if not streams[id]then streams[id]=start end
  end
  R.randomFloat(rng)
  local ready=true;for _,id in ipairs(wanted)do if not streams[id]then ready=false;break end end
  if ready then break end
 end
 eq(#wanted,act==1 and 24 or 31)
 for index,original in ipairs(wanted)do if index>=first and index<=last then
  local r,m=copy(base),C.copy(map);r.eventRng=assert(streams[original],original..' no source vector')
  local before=copy(r);local ok,why=N.enter(r,m,destination.id)
  assert(ok,'act'..act..' '..original..' admission: '..tostring(why))
  eq(r.nodeFlow.event.originalId,original);eq(r.nodeFlow.event.id,Pool.contentId[original])
  eq(r.eventRng.counter,before.eventRng.counter+1)
  local expected=C.copy(before.unknown.pools)
  for _,kind in ipairs({'act','shrine','once'})do for i,id in ipairs(expected[kind])do if id==original then table.remove(expected[kind],i);break end end end
  same(r.unknown.pools,expected)
  finish(r,m,original);eq(r.nodeFlow.complete,true);assert(#N.available(r,m)>0)
  local done=copy(r);assert(not N.chooseEvent(r,'leave'));same(r,done)
  identities[original]=true;count=count+1
  print('PASS full pool act'..act..' '..original..' eventCounter='..before.eventRng.counter)
 end end
end
local unique=0;for _ in pairs(identities)do unique=unique+1 end
eq(count,last-first+1);eq(unique,count)
print('M3_FULL_POOL_COMPLETION act'..act..' '..first..'-'..last..' '..count..' routes passed')
end
