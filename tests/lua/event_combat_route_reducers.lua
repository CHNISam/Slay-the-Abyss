-- Isolated source reducers. These are not natural-map/device acceptance.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R,D=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local Dead,Bandits,Colosseum=require('abyss_dead_adventurer_event'),require('abyss_masked_bandits_event'),require('abyss_colosseum_event')
local V=require('event_combat_routes_vectors')
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for key,value in pairs(a)do same(value,b[key])end;for key in pairs(b)do assert(a[key]~=nil)end
end
local function start(seed,id,act,floor)
 local run=Run.new(D,seed,{experimental=true,campaign=true})
 run.act,run.phase,run.floor=act,'node',floor
 run.nodeFlow={type='event',event={id=id}}
 return run
end
local function choose(run,module,choice,uid)
 return Run.transaction(run,function(staged)return module.choose(staged,staged.nodeFlow,choice,uid)end)
end
local completed,refused=0,0
for _,vector in ipairs(V.dead)do
 local run=start(vector.seed,'dead_adventurer',1,7)
 Dead.prepare(run,run.nodeFlow.event,run.miscRng,7)
 same(run.nodeFlow.event.rewardOrder,vector.rewards);assert(run.nodeFlow.event.enemy==vector.enemy)
 same(R.snapshot(run.miscRng),vector.afterConstructor)
 local copy=C.copy(run);assert(not choose(run,Dead,'search',1));same(run,copy)
 local safe=0
 for _,step in ipairs(vector.searches)do
  local before=C.copy(run)
  local ok,why=choose(run,Dead,'search')
  assert(ok,why) -- real eligible source rewards must not be refused
  same(R.snapshot(run.miscRng),step.after)
  local event=run.nodeFlow.event
  if step.encounter then
   assert(event.stage=='fail'and event.encounterGold==step.gold)
   assert(event.preparedCombat.source==({'3 Sentries','Gremlin Nob','Lagavulin Event'})[vector.enemy])
   assert(event.preparedCombat.floor==7 and event.preparedCombat.roomSeed==require('abyss_run_seed').forFloor(run.runSeed,7))
   assert(#Dead.options(run,event)==1 and Dead.options(run,event)[1].choice=='fight')
   local immutable=C.copy(run);assert(not choose(run,Dead,'leave'));same(run,immutable)
   assert(choose(run,Dead,'fight'));assert(event~=run.nodeFlow.event)
   assert(run.nodeFlow.event.stage=='combat'and run.nodeFlow.event.combatRequest.sourceEncounter==event.preparedCombat.source)
   local repeated=C.copy(run);assert(not choose(run,Dead,'fight'));same(run,repeated)
   completed=completed+1;break
  else
   safe=safe+1;assert(event.numRewards==safe and event.encounterChance==25+25*safe)
   if safe==3 then assert(event.stage=='success');assert(choose(run,Dead,'leave'));completed=completed+1 end
  end
 end
end
assert(completed>0 and completed+refused==#V.dead,'account for every unmodified source branch')
do
 local run=start('42','dead_adventurer',1,7);Dead.prepare(run,run.nodeFlow.event,run.miscRng,7)
 local before=R.snapshot(run.miscRng);assert(choose(run,Dead,'leave'));assert(run.nodeFlow.event.stage=='escape')
 assert(choose(run,Dead,'leave'));same(R.snapshot(run.miscRng),before)
end
do
 local run=start('42','masked_bandits',2,18);Bandits.prepare(run,run.nodeFlow.event)
 assert(run.nodeFlow.event.constructorEncounter=='Masked Bandits')
 local before=R.snapshot(run.miscRng);local gold=run.gold
 assert(choose(run,Bandits,'pay'));assert(run.gold==0 and run.nodeFlow.event.goldPaid==gold)
 assert(not choose(run,Bandits,'fight'));same(R.snapshot(run.miscRng),before)
 assert(choose(run,Bandits,'continue'));assert(run.nodeFlow.event.stage=='paid_2')
 assert(choose(run,Bandits,'continue'));assert(run.nodeFlow.event.stage=='paid_3')
 assert(choose(run,Bandits,'leave'));assert(run.nodeFlow.event.stage=='end')
end
do
 local run=start('42','colosseum',2,18);Colosseum.prepare(run,run.nodeFlow.event)
 assert(#Colosseum.options(run,run.nodeFlow.event)==1)
 local before=C.copy(run);assert(not choose(run,Colosseum,'leave'));same(run,before)
 assert(choose(run,Colosseum,'continue'));assert(run.nodeFlow.event.stage=='fight')
 assert(choose(run,Colosseum,'fight'));assert(run.nodeFlow.event.stage=='combat_first')
 assert(run.nodeFlow.event.preparedCombat.source=='Colosseum Slavers')
 assert(run.nodeFlow.event.combatRequest.round==1)
end
print('EVENT_COMBAT_ROUTE_REDUCERS_PASS '..completed..' completed source branches; '..refused..' unchanged-content refusals')
