-- TASK-15.18: source-ordered eight-item pool, not original PC seed parity.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Map,Nodes=require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local C,R,I,Data=require('abyss_combat'),require('abyss_sts_random'),require('abyss_inventory'),require('abyss_data')
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function same(a,b,path)
 path=path or 'state';eq(type(a),type(b),path)
 if type(a)~='table' then eq(a,b,path);return end
 for k,v in pairs(a) do same(v,b[k],path..'.'..tostring(k)) end
 for k in pairs(b) do assert(a[k]~=nil,path..' missing '..tostring(k)) end
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

test('all 1680 selection paths match independent remaining-index oracle without constructing worlds',function()
 local run=direct();local stable=freeze(run);local oldDraw,oldNew=R.randomInt,C.new
 local input,calls,captured,first,unique,total=nil,0,nil,{},{},0
 R.randomInt=function(state,upper)
  calls=calls+1;eq(upper,8-calls);assert(state~=run.miscRng,'must stage the stream');return input[calls]
 end
 C.new=function(_,options) captured=C.copy(options.enemies);return nil,'selection_probe' end
 local ok,why=pcall(function()
  for a=0,7 do for b=0,6 do for c=0,5 do for d=0,4 do
   input={a,b,c,d};calls=0;captured=nil
   local success,reason=Run.startCombat(run,'gremlin_gang');eq(success,false);eq(reason,'selection_probe')
   eq(calls,4);same(captured,oracle(input));eq(#captured,4)
   local caps={mad_gremlin=2,sneaky_gremlin=2,fat_gremlin=2,shield_gremlin=1,wizard_gremlin=1}
   for _,id in ipairs(captured) do caps[id]=caps[id]-1;assert(caps[id]>=0) end
   total=total+1;first[captured[1]]=(first[captured[1]] or 0)+1;unique[table.concat(captured,',')]=true
  end end end end
 end)
 R.randomInt,C.new=oldDraw,oldNew;assert(ok,why);stable();eq(total,1680)
 same(first,{mad_gremlin=420,sneaky_gremlin=420,fat_gremlin=420,shield_gremlin=210,wizard_gremlin=210})
 local n=0;for _ in pairs(unique) do n=n+1 end;eq(n,354)
end)
for i,v in ipairs(vectors) do test('literal source vector '..i..' constructs four ordered independent instances',function()
 local run=direct(42,11);local wanted=streamAfter(run)
 local oldMisc,oldEvent,oldData,oldDeck=run.miscRng,run.eventRng,run.data,run.deck
 local stable=freeze(oldMisc,oldEvent,oldData,oldDeck)
 force(v[1],function(calls)
  assert(Run.startCombat(run,'gremlin_gang'));eq(calls(),4);same(ids(run.combat),v[2]);same(oracle(v[1]),v[2])
  same(run.miscRng,wanted);eq(run.miscRng.counter,15);eq(run.eventRng,oldEvent);eq(run.data,oldData);eq(run.deck,oldDeck);stable()
  local seen={}
  for slot,e in ipairs(run.combat.enemies) do
   assert(not seen[e.id],'duplicate instance ID');seen[e.id]=true
   for previous=1,slot-1 do local other=run.combat.enemies[previous]
    assert(e~=other and e.statuses~=other.statuses and e.intents~=other.intents,'shared instance state')
   end
  end
  local pristine=freeze(run);eq(Run.startCombat(run,'gremlin_gang'),false);eq(calls(),4);pristine()
 end)
 -- Independent Combat constructor proves slot-to-HP/AI correspondence under
 -- CURRENT separate misc vs shared Combat stream. Not Java cross-stream order.
 local reference=C.new(Data,{seed=run.seed,hp=run.hp,gold=run.gold,deck=run.deck,enemies=v[2]})
 same(run.combat,reference)
end) end

local seeded={
 {0,0,{'fat_gremlin','wizard_gremlin','mad_gremlin','sneaky_gremlin'}},
 {1,0,{'wizard_gremlin','fat_gremlin','fat_gremlin','sneaky_gremlin'}},
 {42,0,{'mad_gremlin','shield_gremlin','fat_gremlin','fat_gremlin'}},
 {65535,0,{'wizard_gremlin','mad_gremlin','mad_gremlin','sneaky_gremlin'}},
 {42,11,{'fat_gremlin','wizard_gremlin','shield_gremlin','sneaky_gremlin'}},
}
for _,v in ipairs(seeded) do test('current stream seed '..v[1]..' at counter '..v[2]..' is deterministic without reseeding',function()
 local run,again=direct(v[1],v[2]),direct(v[1],v[2]);local wanted=streamAfter(run)
 assert(Run.startCombat(run,'gremlin_gang'));assert(Run.startCombat(again,'gremlin_gang'))
 same(ids(run.combat),v[3]);same(run.miscRng,wanted);same(run,again)
end) end

test('each battle owns a fresh candidate pool and repeated species remain separate actors',function()
 local run=direct();local pool
 for _,e in ipairs(run.data.enemies.encounters) do if e.id=='gremlin_gang' then pool=e.gremlinPool end end
 assert(pool,'source candidate pool missing');local stable=freeze(pool)
 for _=1,2 do
  force(vectors[1][1],function(calls) assert(Run.startCombat(run,'gremlin_gang'));eq(calls(),4);same(ids(run.combat),vectors[1][2]) end)
  local a,b=run.combat.enemies[1],run.combat.enemies[2];local hp=b.hp
  C.addStatus(a,'weak',1);a.hp=a.hp-1;eq(b.hp,hp);eq(b.statuses.weak,nil);eq(b.statuses.angry,1)
  stable();run.phase='map' -- explicit repeated-host fixture, not a played victory
 end
 eq(run.miscRng.counter,8)
end)
for _,entry in ipairs({'normal','unknown'}) do test(entry..' source queue frontier commits four room misc draws and never redraws on view/reentry',function()
 local setup=entry=='normal' and normal or unknown;local run,map,id=setup();local again,againMap=setup()
 local target;for _,n in ipairs(Map.available(map))do if n.id==id then target=n end end
 local wanted=streamAfter(run,target.floor);local indices={};local before=Run.roomStreams(run,target.floor).miscRng
 for _,upper in ipairs({7,6,5,4})do indices[#indices+1]=R.randomInt(before,upper)end
 local oldMisc=run.miscRng;local oldStable=freeze(oldMisc)
 local oldEvent=run.eventRng;local eventAfter=R.cloneState(oldEvent)
 if entry=='unknown' then R.randomFloat(eventAfter) end
 assert(Nodes.enter(run,map,id));eq(run.encounterId,'gremlin_gang');eq(#run.combat.enemies,4)
 same(ids(run.combat),oracle(indices))
 same(run.miscRng,wanted);eq(run.miscRng.counter,4);oldStable();same(run.eventRng,eventAfter)
 eq(run.nodeFlow.sourceType,entry=='normal' and 'combat' or 'event');eq(run.nodeFlow.type,'combat')
 if entry=='unknown' then
  for _,n in ipairs(map.nodes) do if n.id==id then eq(n.type,'event');eq(n.encounterId,nil) end end
  eq(run.unknown.chances.monster,R.float32(.1));eq(run.unknown.chances.shop,R.float32(.06));eq(run.unknown.chances.treasure,R.float32(.04))
  same(run.unknown.pools,again.unknown.pools)
 else eq(run.eventRng,oldEvent) end
 local stable=freeze(run,map);Nodes.view(run,map);Nodes.view(run,map);eq(Nodes.enter(run,map,id),false);eq(Run.startCombat(run,'gremlin_gang'),false);stable()
 assert(Nodes.enter(again,againMap,id));same(run,again);same(map,againMap)
end) end

for _,entry in ipairs({'direct','normal','unknown'}) do
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

test('invalid direct requests and illegal node destinations do not draw or mutate',function()
 for _,mode in ipairs({'id','floor','relic','phase'}) do
  local run=direct();local id='gremlin_gang'
  if mode=='id' then id='missing' elseif mode=='floor' then run.floor=4 elseif mode=='relic' then run.relics={'missing'} else run.phase='reward' end
  local stable=freeze(run);force({},function(calls) eq(Run.startCombat(run,id),false);eq(calls(),0);stable() end)
 end
 local run,map,id=normal();local stable=freeze(run,map)
 eq(Nodes.enter(run,map,'missing'),false);eq(Nodes.enter(run,map,'f1_l1'),false);stable()
 assert(Nodes.enter(run,map,id));run.phase='map';run.nodeFlow.complete=true;run.nodeFlow.mapSeed=-1
 stable=freeze(run,map);local ok,reason=Nodes.enter(run,map,'f11_l2');eq(ok,false);eq(reason,'map_mismatch');stable()
end)

test('low-level explicit five-actor arrays retain capacity and never trigger group selection',function()
 local roster={'mad_gremlin','sneaky_gremlin','fat_gremlin','wizard_gremlin','shield_gremlin'}
 force({},function(calls) local battle=C.new(Data,{seed=42,enemies=roster});same(ids(battle),roster);eq(calls(),0) end)
end)

local unchanged={
 cultist_solo={'cultist'},jaw_solo={'jaw_worm'},louse_pair={'red_louse','green_louse'},
 louse_trio={'red_louse','green_louse','red_louse'},medium_slimes={'acid_slime_m','spike_slime_m'},
 large_acid={'acid_slime_l'},large_spike={'spike_slime_l'},looter_solo={'looter'},
 blue_slaver_solo={'blue_slaver'},red_slaver_solo={'red_slaver'},fungi_pair={'fungi_beast','fungi_beast'},
 wildlife={'jaw_worm','green_louse'},elite_nob={'gremlin_nob'},elite_lagavulin={'lagavulin'},
 elite_sentries={'sentry','sentry','sentry'},boss_guardian={'guardian'},small_slimes={'spike_slime_s','acid_slime_m'}
}
test('all other 17 encounters keep original slot order, construction and misc consumption',function()
 local n=0
 for _,e in ipairs(Data.enemies.encounters) do if e.id~='gremlin_gang' then
  n=n+1;local run=Run.new(Data,42);run.floor=e.minFloor
  local oldMisc=run.miscRng;local stable=freeze(oldMisc)
  assert(Run.startCombat(run,e.id));same(ids(run.combat),assert(unchanged[e.id]));stable()
  if e.id=='small_slimes' then local wanted=R.cloneState(oldMisc);R.randomBoolean(wanted);same(run.miscRng,wanted)
  else eq(run.miscRng,oldMisc) end
  same(run.combat,C.new(Data,{seed=42,enemies=unchanged[e.id],deck=run.deck}))
 end end
 eq(n,17)
end)
assert(failed==0,tostring(failed)..' failed of '..count)
print('GREMLIN_GANG_PASS '..count..'; exhaustive selection paths=1680; full constructions only for targeted integration')
