-- Explicit component owners, not claimed natural-play or device evidence.
local P=require('abyss_potion_rewards')
local R=require('abyss_sts_random')
local D=require('abyss_data')
local function graph(label,...) SESSION_GRAPH_WRITE(table.pack(...),label,true) end
if SESSION_GROUP=='potion' then
 for _,character in ipairs({'ironclad','watcher','shared'})do
  for _,relic in ipairs({'none','white_beast_statue','White Beast Statue'})do
   for _,count in ipairs({0,3,4})do
    for _,escaped in ipairs({false,true})do
     local run={seed=42,eventSeed='42',character=character,data=D,relics={relic},encounterTier='normal',potionChanceModifier=10}
     local before=R.snapshot(R.fromSeed('42'))
     local offer,rng,modifier=P.prepare(run,count,{allEscaped=escaped})
     assert(run.shopRng==nil and run.potionChanceModifier==10,'prepare cannot publish RNG')
     P.commit(run,rng,modifier)
     graph('potion',run,offer,before,R.snapshot(rng))
    end
   end
  end
 end
 if not SESSION_OLD then assert(not package.loaded.abyss_relic_hooks and not package.loaded.abyss_run,'reward query must not load Session commands')end
 return
end
local Run=require('abyss_run')
local Hooks=require('abyss_relic_hooks')
local Queries=require('abyss_relic_queries').hooks
local Rewards=require('abyss_relic_family_combat').common
local Event=require('abyss_event_combat')
local Routes=require('abyss_event_combat_routes')
local function owner(id,egg)
 local run=Run.new(D,'42',{experimental=true,campaign=true})
 run.act,run.floor,run.phase=2,18,'combat'
 run.encounterId,run.combatGeneration='reward-fixture',1
 run.combat={combatGeneration=1}
 run.eventCombat={eventId=id,source=id,floor=18,runSeed=run.runSeed,encounterId=run.encounterId,combatGeneration=1,gold=35,relics={{id='red_mask'}},rewardAllowed=true}
 run.nodeFlow={type='event',eventCombat=true,encounterId=run.encounterId,event={id=id}}
 if egg then run.relics[#run.relics+1]=egg end
 return run
end
if SESSION_GROUP=='events' then
 for _,id in ipairs({'mushrooms','masked_bandits','colosseum'})do
  for _,egg in ipairs({'none','toxic_egg','molten_egg','frozen_egg'})do
   local run=owner(id,egg)
   local rewards=assert(Event.finish(run));graph('finish',run,rewards)
   assert(run.eventCombat and rewards.manualContinue and not rewards.cardResolved)
   local escaping=owner(id,egg);assert(Event.escape(escaping));graph('escape',escaping)
  end
 end
 local run=owner('masked_bandits');run.combat.combatGeneration=2
 local value,why=Routes.finish(run);assert(value==nil and why=='event_combat_owner_mismatch');graph('stale',run,value,why)
 return
end
assert(SESSION_GROUP=='dynamic')
local originalOwns=Hooks.owns
local seen={}
Hooks.owns=function(run,id)seen[#seen+1]=id;return id=='white_beast_statue' end
assert(Queries.owns==Hooks.owns)
local run=owner('masked_bandits')
local offer,rng,modifier=P.prepare(run,0,{allEscaped=false});assert(offer and modifier==-10);graph('owns-replaced',run,offer,R.snapshot(rng),seen)
Hooks.owns=nil;assert(Queries.owns==nil)
local accepted=pcall(P.prepare,run,0);assert(not accepted,'nil slot must not silently fall back')
Hooks.owns=originalOwns;assert(Queries.owns==originalOwns)
local originalPreview=Hooks.previewCardReward
local thrown={kind='preview-failure'}
Hooks.previewCardReward=function(current,reward,skip)
 assert(skip==true);reward.partial={owner=current};current.previewPartial=reward.partial;error(thrown)
end
assert(Rewards.previewCardReward==Hooks.previewCardReward)
for _,id in ipairs({'mushrooms','masked_bandits'})do
 local current=owner(id)
 local ok,why=pcall(Event.finish,current);assert(not ok and why==thrown);assert(current.previewPartial.owner==current)
 graph('preview-error',current,why)
end
Hooks.previewCardReward=nil;assert(Rewards.previewCardReward==nil)
assert(not pcall(Event.finish,owner('mushrooms')),'nil preview slot must fail')
Hooks.previewCardReward=originalPreview;assert(Rewards.previewCardReward==originalPreview)
for _,id in ipairs({'mushrooms','masked_bandits'})do local current=owner(id,'toxic_egg');graph('preview-restored',current,Event.finish(current))end
