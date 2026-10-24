local Run,Map,Nodes,C,Q=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_combat'),require('abyss_encounter_queue')
local Data=require('abyss_data')
local count=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'unexpected '..tostring(k))end
end
local function freeze(...)
 local refs={}
 local function visit(t)
  if type(t)~='table' or refs[t]then return end
  local fields={};refs[t]=fields;for k,v in pairs(t)do fields[k]=v;visit(v)end
 end
 for _,t in ipairs({...})do visit(t)end
 return function()for t,fields in pairs(refs)do
  for k,v in pairs(fields)do eq(t[k],v,'preserved '..tostring(k))end
  for k in pairs(t)do assert(fields[k]~=nil,'unexpected '..tostring(k))end
 end end
end
local function test(name,fn)fn();count=count+1;print('ok encounter checkpoint '..count..' - '..name)end
local function winFirstRoom()
 local run,map=Run.new(Data,'42'),Map.generate(Data,'42')
 local before=Run.snapshotEncounters(run)
 assert(Nodes.enter(run,map,Nodes.available(run,map)[1].id))
 for _=1,200 do
  if run.phase~='combat'then break end
  local target;for i,e in ipairs(run.combat.enemies)do if e.hp>0 then target=i;break end end
  local selected
  for _,card in ipairs(run.combat.hand)do if C.canPlay(run.combat,card.uid,target)then
   selected=card;if C.cardDefinition(run.combat,card).type=='attack'then break end
  end end
  if selected then assert(Run.play(run,selected.uid,target))else assert(Run.endTurn(run))end
 end
 eq(run.phase,'reward');eq(run.lastResult.outcome,'victory');assert(run.hp>0)
 assert(Run.leaveCombatRewards(run));assert(Nodes.completeCombat(run,map))
 eq(run.floor,1);eq(map.floor,1);eq(#run.encounters.normal,15)
 return run,map,before
end
test('real first-room victory rejects its same-floor pre-room checkpoint atomically',function()
 local run,map,old=winFirstRoom();local expected=Q.peek(run.encounters,'normal')
 eq(#old.queue.normal,16);local unchanged=freeze(run,map,old)
 local ok,reason=Run.restoreEncounters(run,old)
 eq(ok,false);eq(reason,'stale_encounter_checkpoint');unchanged()
 eq(#run.encounters.normal,15);eq(Q.peek(run.encounters,'normal'),expected)
end)
test('same-boundary initial and post-room checkpoints remain independently restorable',function()
 local initial=Run.new(Data,'42');local checkpoint=Run.snapshotEncounters(initial)
 assert(Run.restoreEncounters(initial,checkpoint));eq(initial.roomGeneration,0)
 same(Q.snapshot(initial.encounters),checkpoint.queue)
 local run,map=winFirstRoom();checkpoint=Run.snapshotEncounters(run)
 eq(checkpoint.roomGeneration,1);local wanted=C.copy(checkpoint.queue)
 assert(Run.restoreEncounters(run,checkpoint));eq(run.roomGeneration,1)
 same(Q.snapshot(run.encounters),wanted)
 checkpoint.queue.normal[1]='Cultist';same(Q.snapshot(run.encounters),wanted)
 local restored=assert(Map.restore(Data,Map.snapshot(map)))
 assert(#Nodes.available(run,restored)>0)
end)
test('failed entry and forged queue length cannot advance or rewind a boundary',function()
 local run,map=Run.new(Data,'42'),Map.generate(Data,'42');local stable=freeze(run,map)
 local construct=C.new;C.new=function()return nil,'injected_failure'end
 local ok=Nodes.enter(run,map,Nodes.available(run,map)[1].id);C.new=construct
 eq(ok,false);stable();eq(run.roomGeneration,0)
 local completed,completedMap,old=winFirstRoom()
 -- A changed scalar tag alone cannot authorize a different consumption count.
 old.roomGeneration=completed.roomGeneration;stable=freeze(completed,completedMap,old)
 local accepted,reason=Run.restoreEncounters(completed,old)
 eq(accepted,false);eq(reason,'encounter_progress_mismatch');stable()
end)
test('noncombat entry advances one generation without consuming the source queue',function()
 local run,map=Run.new(Data,'42'),Map.generate(Data,'42')
 local path=dofile('tests/lua/support/map_routes.lua').to(map,function(n)return n.type=='camp'end)
 -- Isolated reachable frontier, not a claim of earlier completed rooms.
 for i=1,#path-1 do assert(Map.choose(map,path[i]))end
 local queue=Q.snapshot(run.encounters)
 assert(Nodes.enter(run,map,path[#path]));eq(run.roomGeneration,1)
 same(Q.snapshot(run.encounters),queue);assert(Nodes.rest(run))
 local current=Run.snapshotEncounters(run);assert(Run.restoreEncounters(run,current))
 for _,change in ipairs({function(s)s.version=1 end,function(s)s.roomGeneration=0.5 end,
  function(s)s.roomGeneration=nil end})do
  local bad=Run.snapshotEncounters(run);change(bad);local stable=freeze(run,map,bad)
  eq(Run.restoreEncounters(run,bad),false);stable()
 end
end)
print('LUA_ENCOUNTER_CHECKPOINT_PASS '..count)
