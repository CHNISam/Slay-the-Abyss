local Run,Map,Nodes,Q,R,C=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_encounter_queue'),require('abyss_sts_random'),require('abyss_combat')
local Data=require('abyss_data')
local count=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path)
 path=path or 'state';eq(type(a),type(b),path)
 if type(a)~='table'then eq(a,b,path);return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function test(name,fn)fn();count=count+1;print('ok encounter runtime '..count..' - '..name)end
test('normal entry uses the first source queue item regardless of node preview ID',function()
 local run,map=Run.new(Data,'42'),Map.generate(Data,'42')
 local expected=Q.peek(Q.new('42'),'normal')
 local first=Map.available(map)[1]
 for _,n in ipairs(map.nodes)do if n.id==first.id then n.encounterId='medium_slimes' end end
 assert(Nodes.enter(run,map,first.id))
 eq(run.encounterSource,expected);eq(run.combat.encounterSource,expected)
 eq(#run.encounters.normal,15);eq(#run.encounters.elite,10)
 eq(run.nodeFlow.encounterId,run.encounterId)
 eq(run.combat.monsterHpRng.counter,1);eq(run.combat.aiRng.counter,1)
end)
test('raw64 floor addition and rejected entry never mutate queue or RNG state',function()
 local run,map=Run.new(Data,'9223372036854775807'),Map.generate(Data,'9223372036854775807')
 local before,oldMap=C.copy(run),Map.snapshot(map)
 assert(not Nodes.enter(run,map,'invalid'));same(run,before);same(map,oldMap)
 local random=C.new;C.new=function()error('injected setup failure')end
 local ok,reason=Nodes.enter(run,map,Map.available(map)[1].id);C.new=random
 eq(ok,false);eq(reason,'combat_unavailable');same(run,before);same(map,oldMap)
 assert(Nodes.enter(run,map,Map.available(map)[1].id))
 eq(run.combat.roomSeed,'-9223372036854775808')
end)
test('view and restoration do not consume the run queue',function()
 local run,map=Run.new(Data,'42'),Map.generate(Data,'42')
 local before=Q.snapshot(run.encounters)
 for _=1,3 do Nodes.view(run,map);Map.view(map);map=assert(Map.restore(Data,Map.snapshot(map)))end
 same(Q.snapshot(run.encounters),before)
 local snapshot=Run.snapshotEncounters(run)
 local restored=Run.new(Data,'42');assert(Run.restoreEncounters(restored,snapshot));same(Q.snapshot(restored.encounters),before)
 snapshot.queue.rawSeed='43';local old=C.copy(restored)
 assert(not Run.restoreEncounters(restored,snapshot));same(restored,old)
end)
test('normal and elite share initialization but only their accepted queue entries advance',function()
 local run=Run.new(Data,'42');local expected=Q.new('42')
 same(Q.snapshot(run.encounters),Q.snapshot(expected))
 local firstElite=Q.peek(expected,'elite');local normal=Q.peek(expected,'normal')
 run.floor=7;assert(Run.startRoomCombat(run,'elite'));eq(run.encounterSource,firstElite)
 eq(Q.peek(run.encounters,'normal'),normal);eq(#run.encounters.elite,9)
 same(R.snapshot(run.encounters.monsterRng),R.snapshot(expected.monsterRng))
 run.phase='map';run.floor=11;assert(Run.startRoomCombat(run,'normal'))
 eq(run.encounterSource,normal);eq(#run.encounters.normal,15);eq(#run.encounters.elite,9)
 same(R.snapshot(run.encounters.monsterRng),R.snapshot(expected.monsterRng))
end)
test('three actual normal entries remain weak across floor gaps and fourth can be Gremlins at floor four',function()
 local run=Run.new(Data,'5')
 for i,source in ipairs({'Jaw Worm','Cultist','Small Slimes','Gremlin Gang'})do
  run.floor=i;assert(Run.startRoomCombat(run,'normal'));eq(run.encounterSource,source)
  run.phase='map' -- isolated accepted-entry fixture, no preceding victory claim
 end
 eq(#run.encounters.normal,12);eq(#run.combat.enemies,4)
 local other=Run.new(Data,'5')
 for i,source in ipairs({'Jaw Worm','Cultist','Small Slimes'})do
  other.floor=({1,8,14})[i];assert(Run.startRoomCombat(other,'normal'));eq(other.encounterSource,source);other.phase='map'
 end
end)
test('room HP and AI ignore legacy deck seed and old room misc progress',function()
 local a,b=Run.new(Data,'42'),Run.new(Data,'42')
 a.seed=0;b.seed=65535;a.deck={};b.deck={}
 for _=1,10 do R.randomInt(b.miscRng,999)end
 assert(Run.startRoomCombat(a,'normal'));assert(Run.startRoomCombat(b,'normal'))
 same(a.combat.enemies,b.combat.enemies);same(R.snapshot(a.combat.aiRng),R.snapshot(b.combat.aiRng))
 same(R.snapshot(a.combat.monsterHpRng),R.snapshot(b.combat.monsterHpRng));same(a.miscRng,b.miscRng)
 same(Q.snapshot(a.encounters),Q.snapshot(b.encounters))
end)
test('invalid tier, seed ownership and malformed queues reject without changing tables',function()
 for _,mode in ipairs({'tier','seed','malformed','floor','phase'})do
  local run=Run.new(Data,'42');local tier='normal'
  if mode=='tier'then tier='unknown'
  elseif mode=='seed'then run.encounters.rawSeed='43'
  elseif mode=='malformed'then run.encounters.monsterRng.counter=0.5
  elseif mode=='floor'then run.floor=17 else run.phase='reward'end
  local old=C.copy(run);local queue=run.encounters;local ok=Run.startRoomCombat(run,tier)
  eq(ok,false);same(run,old);eq(run.encounters,queue)
 end
 local run,map=Run.new(Data,'42'),Map.generate(Data,'43');local old=C.copy(run)
 eq(#Nodes.available(run,map),0);local ok,reason=Nodes.enter(run,map,Map.available(map)[1].id)
 eq(ok,false);eq(reason,'map_mismatch');same(run,old)
end)
test('normal exhaustion and unsupported Boss profiles are explicit atomic rejections',function()
 local run=Run.new(Data,'42')
 for _=1,16 do local _,nextQueue=Q.consume(run.encounters,'normal');run.encounters=nextQueue end
 local before=C.copy(run);local ok,reason=Run.startRoomCombat(run,'normal')
 eq(ok,false);eq(reason,'normal_queue_exhausted');same(run,before)
 local boss=Run.new(Data,'42');boss.floor=16
 local queue=Q.snapshot(boss.encounters);eq(boss.bossInitialization.profile,'guardian-unseen')
 assert(Run.startRoomCombat(boss,'boss'));eq(boss.encounterSource,'The Guardian')
 same(Q.snapshot(boss.encounters),queue);eq(boss.combat.monsterHpRng.counter,1)
 boss=Run.new(Data,'42');boss.floor=16;boss.bossInitialization.profile='all-unlocked';before=C.copy(boss)
 ok,reason=Run.startRoomCombat(boss,'boss');eq(ok,false);eq(reason,'unsupported_boss_initialization');same(boss,before)
end)
test('queue checkpoint rejects malformed, foreign and wrong-floor replacements atomically',function()
 local run=Run.new(Data,'42')
 for _,change in ipairs({
  function(s)s.queue.monsterRng.words[1]='invalid'end,
  function(s)s.runSeed='43'end,function(s)s.floor=2 end,
  function(s)s.unexpected=true end,function(s)s.queue.normal[1]='medium_slimes'end,
 })do
  local snapshot=Run.snapshotEncounters(run);change(snapshot);local before=C.copy(run);local queue=run.encounters
  eq(Run.restoreEncounters(run,snapshot),false);same(run,before);eq(run.encounters,queue)
 end
 local snapshot=Run.snapshotEncounters(run);assert(Run.startRoomCombat(run,'normal'))
 local before=C.copy(run);eq(Run.restoreEncounters(run,snapshot),false);same(run,before)
end)
test('later enemy rolls keep the room AI stream and never consume HP or misc',function()
 local run=Run.new(Data,'42');run.deck={};assert(Run.startRoomCombat(run,'normal'))
 local hp,misc=R.snapshot(run.combat.monsterHpRng),R.snapshot(run.miscRng)
 local ai=R.cloneState(run.combat.aiRng);R.randomInt(ai,99)
 assert(Run.endTurn(run)) -- source Cultist Ritual queues its next ignored roll
 same(R.snapshot(run.combat.aiRng),R.snapshot(ai))
 same(R.snapshot(run.combat.monsterHpRng),hp);same(R.snapshot(run.miscRng),misc)
end)
print('LUA_ENCOUNTER_RUNTIME_PASS '..count)
