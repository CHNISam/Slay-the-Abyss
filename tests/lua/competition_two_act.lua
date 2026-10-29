-- Production boundaries with controlled chapter completion; not natural/platform playthroughs.
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local Acts,C,R,Q=require('abyss_acts'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_encounter_queue')
local Data=require('abyss_data')
local Snapshot=require('abyss_snapshot')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS competition '..count..' '..name)end
local function same(a,b,path)
 path=path or 'state';assert(type(a)==type(b),path)
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
-- Seed3 supplies a legal implemented source Boss relic for the single-chest
-- endpoint test; it does not certify the full random relic pool (TASK-14.1).
local function new(profile,character)
 return Run.new(Data,'3',{experimental=true,campaign=true,campaignProfile=profile or 'competition-two-act',character=character})
end
local function terminal(act,profile,character)
 local run=new(profile,character)
 run.act=act
 if act~=1 then run.encounters=Q.new(run.runSeed,act)end
 local context=assert(Run.freezeMapContext(run))
 local map=Map.generate(run.data,run.runSeed,act,context)
 local boss=Acts.get(act).boss
 while Map.available(map)[1].floor<=boss do assert(Map.choose(map,Map.available(map)[1].id))end
 run.floor,run.phase=boss,'map'
 run.nodeFlow={id=map.currentNodeId,floor=boss,type='boss',complete=true,result='boss_victory',
  mapSeed=map.seed,mapSignature=map.sourceSignature}
 assert(Nodes.enter(run,map,Map.available(map)[1].id))
 return run,map
end
local function resource(run)
 return C.copy({deck=run.deck,hp=run.hp,maxHp=run.maxHp,gold=run.gold,relics=run.relics,potions=run.potions,
  uid=run.nextDeckUid,eventRng=R.snapshot(run.eventRng),cardRng=R.snapshot(run.cardRng),miscRng=R.snapshot(run.miscRng),
  treasureRng=R.snapshot(run.treasureRng),encounters=Q.snapshot(run.encounters),unknown=run.unknown,seed=run.runSeed})
end

test('explicit profile is validated and future/test campaign stays available',function()
 assert(Acts.isCompetition(new()))
 assert(not Acts.isCompetition(new('full-source')))
 for _,profile in ipairs({'two-act','',2,false,{}})do
  assert(not pcall(Run.new,Data,'42',{experimental=true,campaign=true,campaignProfile=profile}))
 end
 assert(not pcall(Run.new,Data,'42',{experimental=true,campaignProfile='competition-two-act'}))
end)

test('competition roster and all four full-source classes keep same-run resources and snapshots through Act1 to Act2',function()
 local scenarios={{profile='competition-two-act',characters={'ironclad'}},
  {profile='full-source',characters={'ironclad','silent','defect','watcher','raiden'}}}
 for _,scenario in ipairs(scenarios)do for _,character in ipairs(scenario.characters)do
  local run,map=terminal(1,scenario.profile,character)
  run.hp=3;run.gold=345;run.deck[1].upgraded=true;run.potions={'block_potion'}
  run.relicCounters={sameRun=4}
  local before=resource(run);local counters=C.copy(run.relicCounters)
  assert(Nodes.leaveTreasure(run));assert(run.phase=='act_transition'and run.pendingAct==2)
  local restore=Snapshot.capture(run)
  assert(Nodes.advanceAct(run,map));assert(run.act==2 and map.act==2 and map.floor==17 and run.phase=='map')
  assert(run.hp==run.maxHp and run.gold==before.gold and run.runSeed==before.seed)
  same(run.deck,before.deck);same(run.relics,before.relics);same(run.potions,before.potions)
  same(run.relicCounters,counters);same(R.snapshot(run.eventRng),before.eventRng)
  assert(run.nextDeckUid==before.uid and run.campaignProfile==scenario.profile)
  assert(not Nodes.advanceAct(run,map))
  restore();assert(run.act==1 and run.phase=='act_transition'and run.campaignProfile==scenario.profile)
  same(resource(run),before)
 end end
end)

test('skip and zero-choice routes end at identical legal floor34 without consuming resource streams',function()
 local endings={}
 for index,command in ipairs({Nodes.leaveTreasure,function(run)return Nodes.claimBossTreasure(run,0)end})do
  local run,map=terminal(2);local before=resource(run)
  assert(command(run));assert(run.act==2 and run.floor==34 and map.floor==34)
  assert(run.phase=='victory'and run.ending=='two_act_complete'and not run.pendingAct)
  assert(run.nodeFlow.complete and run.nodeFlow.result=='boss_treasure_complete')
  same(resource(run),before)
  local finished=C.copy(run);local saved=Map.snapshot(map)
  assert(not command(run)and not Nodes.claimBossTreasure(run,0)and not Nodes.leaveTreasure(run))
  assert(not Nodes.advanceAct(run,map)and not Run.advanceAct(run))
  same(run,finished);same(Map.snapshot(map),saved)
  endings[index]={phase=run.phase,ending=run.ending,floor=run.floor,pendingAct=run.pendingAct}
 end
 same(endings[1],endings[2])
end)

test('claimed source boss relic commits once and failed reward hook rolls back the endpoint',function()
 local run=terminal(2);assert(Nodes.openTreasure(run))
 local choice
 for index,item in ipairs(run.nodeFlow.reward.items)do if item.available then choice=index;break end end
 assert(choice,'controlled source chest must offer an implemented relic')
 local id=run.nodeFlow.reward.items[choice].id
 local before=C.copy(run);local obtain=Run.obtainRelic
 Run.obtainRelic=function(staged,selected)
  assert(obtain(staged,selected));staged.gold=staged.gold+99;return false,'controlled_reward_failure'
 end
 local ok,why=Nodes.claimBossTreasure(run,choice);Run.obtainRelic=obtain
 assert(not ok and why=='controlled_reward_failure');same(run,before)
 assert(Nodes.claimBossTreasure(run,choice));assert(run.phase=='victory'and run.ending=='two_act_complete')
 local found=0;for _,owned in ipairs(run.relics)do if owned==id then found=found+1 end end
 assert(found==1 and not Nodes.claimBossTreasure(run,choice))
end)

test('illegal final floors and transitions reject atomically before RNG or map replacement',function()
 for _,bad in ipairs({1,17,33,35,51,55})do
  local run,map=terminal(2);run.floor=bad
  local before=C.copy(run);local saved=Map.snapshot(map)
  assert(not Nodes.leaveTreasure(run)and not Nodes.claimBossTreasure(run,0))
  same(run,before);same(Map.snapshot(map),saved)
 end
 local run,map=terminal(2)
 run.phase,run.pendingAct='act_transition',3;run.nodeFlow.complete=true;run.nodeFlow.result='boss_treasure_complete'
 local before=C.copy(run);local saved=Map.snapshot(map)
 local ok,why=Run.advanceAct(run);assert(not ok and why=='competition_act_limit')
 assert(not Nodes.advanceAct(run,map));same(run,before);same(Map.snapshot(map),saved)
 for _,act in ipairs({3,4})do
  run.act,run.floor,run.phase=act,Acts.get(act).first,'map';run.nodeFlow=nil
  local future=Map.generate(run.data,run.runSeed,act)
  before=C.copy(run);saved=Map.snapshot(future)
  assert(not Nodes.enter(run,future,Map.available(future)[1].id))
  assert(not Run.startRoomCombat(run,act==3 and 'normal'or 'elite'))
  same(run,before);same(Map.snapshot(future),saved)
 end
end)

test('competition has original non-final-act key policy even with supplied historical flags',function()
 local run=new();run.endingUnlocked=true
 local context=assert(Run.freezeMapContext(run))
 assert(context.endingUnlocked==false)
 local map=Map.generate(run.data,run.runSeed,1,context)
 assert(not map.emeraldSelection and not map.emeraldBoost)
 local function enterFloor(owner,current,floor)
  while Map.available(current)[1].floor<floor do assert(Map.choose(current,Map.available(current)[1].id))end
  owner.floor,owner.phase=current.floor,'map'
  owner.nodeFlow={id=current.currentNodeId,floor=current.floor,type='combat',complete=true,result='victory',
   mapSeed=current.seed,mapSignature=current.sourceSignature}
  assert(Nodes.enter(owner,current,Map.available(current)[1].id))
 end
 enterFloor(run,map,9)
 assert(Nodes.openTreasure(run)) -- key offers are created at OPEN, not room construction
 assert(not run.nodeFlow.reward.sapphireKey)
 for _,item in ipairs(run.nodeFlow.reward.items)do
  assert(item.kind~='sapphire','competition advertised a key after OPEN')
  assert(not item.linkedSlot,'competition relic advertises a linked key')
 end
 local before=C.copy(run);local saved=Map.snapshot(map)
 local ok,reason=Nodes.chooseTreasure(run,map,{},'sapphire')
 assert(not ok and reason=='ending_unavailable');same(run,before);same(Map.snapshot(map),saved)
 -- The same source opening with an explicit future profile must still offer
 -- its real linked key, not silently remove the original full-source policy.
 local full=new('full-source');full.endingUnlocked=true
 local fullMap=Map.generate(full.data,full.runSeed,1,assert(Run.freezeMapContext(full)))
 enterFloor(full,fullMap,9);assert(Nodes.openTreasure(full))
 assert(full.nodeFlow.reward.sapphireKey)
 same(R.snapshot(run.treasureRng),R.snapshot(full.treasureRng))
 same(R.snapshot(run.cardRng),R.snapshot(full.cardRng))
 local relicPool=require('abyss_relic_pool')
 same(relicPool.snapshot(run.relicPool),relicPool.snapshot(full.relicPool))
 local keyToken
 for _,item in ipairs(full.nodeFlow.reward.items)do
  if item.kind=='sapphire'then keyToken=assert(Nodes.treasureRewardSource(full,item.slot))end
 end
 assert(keyToken and Nodes.treasureSource(full,fullMap))
 assert(not Nodes.claimTreasureReward(run,keyToken));same(run,before);same(Map.snapshot(map),saved)
 assert(Nodes.leaveTreasure(run))
 enterFloor(run,map,15)
 local source,why=Nodes.recallSource(run,map)
 assert(not source and why=='ending_unavailable')
end)

test('competition disables platform WIN/SPIRITS persistence while retaining session-only Neow history',function()
 local Ending,Neow=require('abyss_ending_history'),require('abyss_neow_history')
 local calls=0;local owner=Ending.new({read=function()calls=calls+1;error('must not read')end,
  write=function()calls=calls+1;error('must not write')end})
 local neow=Neow.new(function()calls=calls+1;error('must not read')end)
 local run,map=terminal(2)
 local history=assert(Ending.begin(owner,run,{seedSet=false,isDailyRun=false,isTrial=false}))
 assert(history.unlocked==false and history.readStatus=='disabled'and history.persistence=='disabled')
 assert(Nodes.leaveTreasure(run))
 assert(not Ending.finish(owner,run,map))
 assert(calls==0 and not owner.loaded and not owner.sessionWon)
 assert(Neow.finish(neow,run,'victory'))
 local entry=assert(Neow.read(neow,'ironclad',true))
 assert(entry.bossCount==1 and entry.source=='session-completed-run')
 assert(neow.finished[run] and not Neow.finish(neow,run,'victory'))
 assert(calls==0 and not owner.loaded and not owner.sessionWon)
 assert(history.unlocked==false and history.readStatus=='disabled' and history.persistence=='disabled')
end)

print('COMPETITION_TWO_ACT_PASS '..count..'; controlled boundaries; native/natural NOT_RUN')
