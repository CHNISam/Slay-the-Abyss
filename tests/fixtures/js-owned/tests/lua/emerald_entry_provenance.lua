-- Controlled qualification/route/remaining relic queues, not natural-play evidence.
local F=dofile('tests/lua/support/emerald_run_fixture.lua')
local Run,Nodes,Map,C=F.Run,F.Nodes,F.Map,F.C
local R=require('abyss_sts_random')
local Hooks=require('abyss_relic_hooks')
local count=0
local function test(fn)fn();count=count+1;print('PASS emerald entry provenance '..count)end

-- Record raw values and every mutable physical owner, including metatables.
-- A copied snapshot alone would miss owner replacement and __pairs laundering.
local function owners(...)
 local seen,records={},{}
 local function visit(value,static)
  if type(value)~='table' or seen[value] or value==static then return end
  seen[value]=true
  local record={owner=value,meta=getmetatable(value),entries={}}
  records[#records+1]=record
  for key,item in next,value do record.entries[key]=item;visit(item,static)end
 end
 for _,root in ipairs({...})do visit(root,root.data)end
 return function()
  for _,record in ipairs(records)do
   assert(getmetatable(record.owner)==record.meta,'metatable changed')
   for key,item in next,record.entries do assert(rawget(record.owner,key)==item,'owner/value changed: '..tostring(key))end
   for key in next,record.owner do assert(record.entries[key]~=nil,'new field: '..tostring(key))end
  end
 end
end
local function rejected(change)
 local run,map,id=F.fixture();change(run,map,id)
 local unchanged=owners(run,map)
 local new,hook=C.new,Hooks.onEnterRoom
 local setups,hooks=0,0
 C.new=function(...)setups=setups+1;return new(...)end
 Hooks.onEnterRoom=function(...)hooks=hooks+1;return hook(...)end
 local called,ok,why=pcall(Nodes.enter,run,map,id)
 C.new,Hooks.onEnterRoom=new,hook
 assert(called,'public entry must return refusal, not throw')
 assert(not ok,'noncanonical map entered: '..tostring(why))
 assert(setups==0 and hooks==0,'invalid original map reached room hooks/setup')
 unchanged()
 assert(not run.rewards and not run.emeraldCombat and not run.keys.emerald)
 assert(not Run.claimEmeraldKey(run),'refused entry cannot publish a key')
 unchanged()
end

test(function()
 rejected(function(run,map,id)
  local canonical=assert(Map.prepareEmeraldBoost(map,id))
  map.mapRng=R.snapshot(R.fromSeed('2')) -- valid-shaped but not this map's source stream.
  assert(assert(Map.prepareEmeraldBoost(map,id)).effect.roll~=canonical.effect.roll)
  local restored,why=Nodes.restoreMap(run,map)
  assert(not restored and why=='invalid_snapshot','strict restore is the rejection control')
 end)
end)
test(function()
 for _,change in ipairs({
  function(_,m)m.emeraldSelection.x=(m.emeraldSelection.x+1)%7 end,
  function(_,m,id)for _,n in ipairs(m.nodes)do if n.id==id then n.hasEmeraldKey=nil end end end,
  function(_,m)
   m.emeraldSelection,m.mapRng,m.emeraldBoost=nil,nil,nil
   for _,n in ipairs(m.nodes)do n.hasEmeraldKey=nil end
  end,
  function(r)r.mapBirthAct,r.mapBirthContext=nil,nil end,
 })do rejected(change)end
 -- Even without birth facts, false is malformed modern state, not absence of
 -- a contract and therefore not permission to fall back to legacy components.
 for _,field in ipairs({'emeraldSelection','mapRng','emeraldBoost','hasEmeraldKey'})do
  rejected(function(r,m,id)
   r.mapBirthAct,r.mapBirthContext=nil,nil
   m.emeraldSelection,m.mapRng,m.emeraldBoost=nil,nil,nil
   for _,n in ipairs(m.nodes)do
    n.hasEmeraldKey=nil
    if field=='hasEmeraldKey' and n.id==id then n.hasEmeraldKey=false end
   end
   if field~='hasEmeraldKey' then m[field]=false end
  end)
 end
end)
test(function()
 for _,scope in ipairs({'root','nodes','node','path','selection','rng'})do
  rejected(function(_,m,id)
   local clean=C.copy(m)
   local target=scope=='root' and m or scope=='nodes' and m.nodes
    or scope=='path' and m.path or scope=='selection' and m.emeraldSelection or scope=='rng' and m.mapRng
   local original=scope=='root' and clean or scope=='nodes' and clean.nodes
    or scope=='path' and clean.path or scope=='selection' and clean.emeraldSelection or scope=='rng' and clean.mapRng
   if scope=='node' then
    for i,n in ipairs(m.nodes)do if n.id==id then target,original=n,clean.nodes[i]end end
   end
   setmetatable(target,{__pairs=function()return next,original,nil end})
  end)
 end
end)
test(function()
 for _,owned in ipairs({false,true})do
  local run=Run.new(F.Data,'42',{experimental=true,campaign=true})
  run.endingUnlocked,run.keys.emerald=owned,owned
  local map=Map.generate(run.data,run.runSeed,1,assert(Run.freezeMapContext(run)))
  assert(not map.emeraldSelection and not map.mapRng)
  local before=C.copy(map.randomState)
  assert(Nodes.enter(run,map,Map.available(map)[1].id),'valid unmarked birth map must enter')
  F.same(map.randomState,before)
 end
 local run,map,id=F.fixture()
 map=assert(Nodes.restoreMap(run,map)) -- restored maps retain the same canonical boost.
 local boost=assert(Map.prepareEmeraldBoost(map,id))
 local root,nodes,path=map,map.nodes,map.path
 assert(Nodes.enter(run,map,id))
 assert(map==root and map.nodes==nodes and map.path==path)
 F.same(map.emeraldBoost,boost)
 for _,enemy in ipairs(run.combat.enemies)do C.damage(run.combat,run.combat.player,enemy,999,false)end
 assert(Run.finishCombat(run));assert(Run.claimEmeraldKey(run))
 assert(Run.leaveCombatRewards(run));assert(Nodes.completeCombat(run,map))
 F.same(assert(Nodes.restoreMap(run,map)),map)
 local nextId=assert(Nodes.available(run,map)[1]).id
 local after=C.copy(map.mapRng)
 assert(Nodes.enter(run,map,nextId),'post-elite continuation must retain its birth context')
 F.same(map.mapRng,after)
end)
print('EMERALD_ENTRY_PROVENANCE 4 groups; 0 failed; natural/platform NOT_RUN')
