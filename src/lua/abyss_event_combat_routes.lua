-- Missing act1/act2 EventRoom combat routes. Map encounter queues are untouched.
local C=require('abyss_combat')
local R=require('abyss_sts_random')
local Gold=require('abyss_gold_rewards')
local Potion=require('abyss_potion_rewards')
local Cards=require('abyss_card_pool')
local Hooks=require('abyss_relic_hooks')
local M={}
local groups={
 ['3 Sentries']={act=1,id='event_dead_sentries',enemies={'sentry','sentry','sentry'},positions={{-330,25},{-85,10},{140,30}},eliteTrigger=true},
 ['Gremlin Nob']={act=1,id='event_dead_nob',enemies={'gremlin_nob'},positions={{0,0}},eliteTrigger=true},
 ['Lagavulin Event']={act=1,id='event_dead_lagavulin',enemies={'lagavulin_awake'},positions={{0,20}},eliteTrigger=true},
 ['Masked Bandits']={act=2,id='event_masked_bandits',enemies={'bandit_pointy','bandit_leader','bandit_bear'},positions={{-320,0},{-75,-6},{150,-6}}},
 ['Colosseum Slavers']={act=2,id='event_colosseum_slavers',enemies={'blue_slaver','red_slaver'},positions={{-270,15},{130,0}}},
 ['Colosseum Nobs']={act=2,id='event_colosseum_nobs',enemies={'taskmaster','gremlin_nob'},positions={{-270,15},{130,0}},eliteTrigger=true},
}
local events={dead_adventurer=true,masked_bandits=true,colosseum=true}
local streamKeys={'monsterHpRng','aiRng','shuffleRng','cardRandomRng'}
function M.supportsSource(source)return groups[source]~=nil end
function M.supportsEvent(id)return events[id]==true end
local function encounter(source)
 local group=groups[source]
 if not group then return nil end
 return {id=group.id,tier='normal',source=source,enemies=C.copy(group.enemies),eliteTrigger=group.eliteTrigger==true}
end
local function roomFor(run,floor,roomStreams,misc,continuation)
 local room=roomStreams(run,floor)
 room.miscRng=R.cloneState(misc or run.miscRng)
 if continuation then
  assert(continuation.floor==floor and continuation.runSeed==run.runSeed,'event room continuation mismatch')
  for _,key in ipairs(streamKeys)do room[key]=R.restore(continuation[key])end
 end
 return room
end
function M.prepare(run,source,floor,roomStreams,misc,continuation)
 local group=groups[source]
 if not group or run.campaign~=true or (run.act or 1)~=group.act or type(floor)~='number'or floor%1~=0
  or group.act==1 and floor<=6then return nil,'event_constructor_unavailable'end
 local room=roomFor(run,floor,roomStreams,misc,continuation)
 local prepared=C.prepareEncounter(run.data,{roomSeed=room.seed,roomStreams=room,enemies=group.enemies})
 for i,actor in ipairs(prepared.actors)do actor.sourcePosition={x=group.positions[i][1],y=group.positions[i][2]}end
 local result={version=1,source=source,floor=floor,runSeed=run.runSeed,roomSeed=room.seed,prepared=prepared}
 if continuation then result.continuation=C.copy(continuation)end
 return result
end
local function validRequest(event,request)
 if type(request)~='table'or getmetatable(request)~=nil or request.roomClass~='event'or request.route~=event.id then return false end
 if event.id=='dead_adventurer'then
  local sources={'3 Sentries','Gremlin Nob','Lagavulin Event'}
  return event.stage=='combat'and request.sourceEncounter==sources[event.enemy]
   and type(event.encounterGold)=='number'and event.encounterGold>=25 and event.encounterGold<=35
   and type(event.encounterGoldOffer)=='number'
 elseif event.id=='masked_bandits'then
  return event.stage=='combat'and request.sourceEncounter=='Masked Bandits'and type(request.gold)=='number'
   and request.gold%1==0 and request.gold>=25 and request.gold<=35
   and(request.fixedRelicId=='red_mask'or request.fixedRelicId=='circlet')
 end
 return event.id=='colosseum'and(request.round==1 and event.stage=='combat_first'and request.sourceEncounter=='Colosseum Slavers'
  or request.round==2 and event.stage=='combat_second'and request.sourceEncounter=='Colosseum Nobs')
end
local function addRelic(run,api,result,options)
 local offer,pool=api.prepareRelic(run,options)
 if not offer then return false,pool end
 run.relicPool=pool
 result[#result+1]={id=offer.id,sourceId=offer.sourceId,rarity=offer.tier,requestedId=offer.requestedId,
  requestedTier=offer.tier,trace=offer.trace,claimed=false}
 return true
end
local function fixedRelic(run,result,id)
 local expected=Hooks.owns(run,'red_mask')and'circlet'or'red_mask'
 if id~=expected then return false,'event_reward_mismatch'end
 for _,definition in ipairs(run.data.relics.relics)do
  if definition.id==id and definition.rarity=='special'then
   result[#result+1]={id=id,sourceId=definition.sourceId,rarity='special',claimed=false};return true
  end
 end
 return false,'event_relic_unavailable'
end
local function prepareRewards(run,event,api)
 local request=event.combatRequest;local result={gold=0,relics={},rewardAllowed=true}
 if event.id=='dead_adventurer'then
  result.gold=event.encounterGoldOffer
  for _,reward in ipairs(event.rewardOrder)do
   if reward=='GOLD'then
    -- AbstractRoom merges GOLD, then RewardItem.incrementGold recomputes the
    -- bonus from the combined base (rounding two separate offers is wrong).
    result.gold=Gold.offerAmount(event.encounterGold+30,run)
   elseif reward=='RELIC'then
    local ok,why=addRelic(run,api,result.relics,{channel='event',room='event'})
    if not ok then return nil,why end
   elseif reward~='NOTHING'then return nil,'event_reward_mismatch'end
  end
 elseif event.id=='masked_bandits'then
  result.gold=Gold.offerAmount(request.gold,run)
  local ok,why=fixedRelic(run,result.relics,request.fixedRelicId);if not ok then return nil,why end
 elseif request.round==1 then result.rewardAllowed=false
 else
  for _,tier in ipairs({'rare','uncommon'})do
   local ok,why=addRelic(run,api,result.relics,{tier=tier,room='event'});if not ok then return nil,why end
  end
  result.gold=Gold.offerAmount(100,run)
 end
 return result
end
local function preparedFor(run,event,api)
 local prepared=event.preparedCombat;local request=event.combatRequest
 if type(prepared)~='table'or prepared.version~=1 or prepared.source~=request.sourceEncounter
  or prepared.floor~=run.floor or prepared.runSeed~=run.runSeed or prepared.roomSeed~=api.roomStreams(run,run.floor).seed then
  return nil,'event_constructor_mismatch'
 end
 return prepared
end
function M.start(run,flow,api,startEncounter)
 if run.phase~='node'or flow~=run.nodeFlow or type(flow)~='table'or flow.type~='event'or flow.complete then return false,'event_combat_unavailable'end
 local event=flow.event
 if not event or not validRequest(event,event.combatRequest)then return false,'invalid_event_combat_request'end
 local group=groups[event.combatRequest.sourceEncounter]
 if run.campaign~=true or not group or (run.act or 1)~=group.act
  or event.id=='dead_adventurer'and run.floor<=6 then return false,'event_combat_unavailable'end
 local prepared,why=preparedFor(run,event,api);if not prepared then return false,why end
 local rewards;rewards,why=prepareRewards(run,event,api);if not rewards then return false,why end
 local room=roomFor(run,run.floor,api.roomStreams,run.miscRng,prepared.continuation)
 room.monsterHpRng=R.restore(prepared.prepared.monsterHpRng);room.preparedEncounter=prepared.prepared
 run.phase='map'
 local ok;ok,why=startEncounter(run,encounter(event.combatRequest.sourceEncounter),room)
 if not ok then return false,why end
 run.eventCombat={eventId=event.id,source=event.combatRequest.sourceEncounter,encounterId=run.encounterId,
  floor=run.floor,runSeed=run.runSeed,combatGeneration=run.combatGeneration,gold=rewards.gold,
  relics=rewards.relics,rewardAllowed=rewards.rewardAllowed,round=event.combatRequest.round}
 if event.id=='dead_adventurer'then event.numRewards=event.numRewards+1 end
 flow.eventCombat,flow.encounterId,flow.encounterSource=true,run.encounterId,event.combatRequest.sourceEncounter
 return true,'combat'
end
local function ownerMatches(run)
 local context,flow,battle=run.eventCombat,run.nodeFlow,run.combat
 return type(context)=='table'and M.supportsEvent(context.eventId)and flow and flow.type=='event'and flow.eventCombat
  and flow.event and flow.event.id==context.eventId and battle and context.encounterId==run.encounterId
  and flow.encounterId==run.encounterId and context.runSeed==run.runSeed and context.floor==run.floor
  and context.combatGeneration==run.combatGeneration and battle.combatGeneration==run.combatGeneration
end
local function reopen(run)
 local event,battle=run.nodeFlow.event,run.combat
 local continuation={floor=run.floor,runSeed=run.runSeed}
 for _,key in ipairs(streamKeys)do continuation[key]=R.snapshot(battle[key])end
 -- Colosseum.reopen explicitly calls preBattlePrep before entering its image.
 -- CardGroup.initializeDeck shuffles even an empty deck; this pile is discarded.
 local shuffle=R.restore(continuation.shuffleRng);R.randomLongHex(shuffle)
 continuation.shuffleRng=R.snapshot(shuffle)
 event.roomContinuation=continuation;event.preparedCombat,event.combatRequest=nil,nil
 event.stage,event.body='post_combat','第一场已经结束。你可以离开，或参加下一场战斗。'
 run.nodeFlow.eventCombat=false;run.eventCombat,run.rewards,run.pendingCombatRewards=nil,nil,nil
 run.phase='node'
 return {},'event_reopened'
end
function M.finish(run)
 if not ownerMatches(run)then return nil,'event_combat_owner_mismatch'end
 local context=run.eventCombat
 local count=(context.gold>0 and 1 or 0)+#context.relics
 local potion,potionRng,modifier=Potion.prepare(run,count,{allEscaped=false});Potion.commit(run,potionRng,modifier)
 if context.rewardAllowed==false then return reopen(run)end
 local choices,cardRng,offset,upgrades=Cards.prepareRewards(run)
 run.cardRng,run.cardRarityOffset=cardRng,offset
 local rewards={gold=context.gold,goldClaimed=context.gold==0,relics=C.copy(context.relics),cards=choices,
  cardUpgrades=upgrades,potion=potion,cardResolved=false,manualContinue=true}
 Hooks.previewCardReward(run,rewards,true)
 return rewards
end
function M.escape(run)
 if not ownerMatches(run)then return false,'event_combat_owner_mismatch'end
 local context=run.eventCombat
 -- Smoke discards room offers but retains the source EventRoom potion attempt.
 local count=(context.gold>0 and 1 or 0)+#context.relics
 local _,potionRng,modifier=Potion.prepare(run,count,{allEscaped=false});Potion.commit(run,potionRng,modifier)
 if context.rewardAllowed==false then reopen(run);return true,'event_reopened'end
 run.eventCombat=nil;return true
end
return M
