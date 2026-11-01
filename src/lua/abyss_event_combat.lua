-- EventRoom owns its constructor and fixed rewards independently of map queues.
local C=require('abyss_combat')
local R=require('abyss_sts_random')
local Gold=require('abyss_gold_rewards')
local Potion=require('abyss_potion_rewards')
local Cards=require('abyss_card_pool')
local Hooks=require('abyss_relic_hooks')
local Routes=require('abyss_event_combat_routes')
local M={}
local bosses={['The Guardian']=true,Hexaghost=true,['Slime Boss']=true}
local function encounter(source)
 if source=='The Mushroom Lair'then
  return {id='event_mushrooms',tier='normal',source=source,sourceEncounter=source}
 end
 if source=='2 Orb Walkers'then
  return {id='event_orb_walkers',tier='normal',source=source,sourceEncounter=source}
 end
 if not bosses[source]then return nil end
 local result=require('abyss_act1_bosses').resolve(source,'boss')
 result.tier='normal' -- This is an EventRoom, including when the actors are Bosses.
 return result
end
local function roomOptions(room,definition)
 local options={roomSeed=room.seed,roomStreams=room,enemies=definition.enemies,sourceEncounter=definition.sourceEncounter,
  encounterSource=definition.source,encounterVisualFloat=function(lo,hi)return R.randomFloatBetween(room.visualRng,lo,hi)end}
 if definition.sourceEncounter then
  options.encounterBoundary={misc={boolean=function()return R.randomBoolean(room.miscRng)end,
   integer=function(lo,hi)return R.randomIntBetween(room.miscRng,lo,hi)end},
   visualFloat=function(lo,hi)return R.randomFloatBetween(room.visualRng,lo,hi)end}
 end
 return options
end
function M.prepare(run,source,floor,roomStreams,misc)
 if Routes.supportsSource(source)then return Routes.prepare(run,source,floor,roomStreams,misc)end
 if type(floor)~='number'or floor%1~=0 then return nil,'event_constructor_unavailable'end
 local act=run.act or 1
 local allowed=source=='The Mushroom Lair'and act==1 and floor>=7 and floor<=14
  or source~='The Mushroom Lair'and act==3 and floor>=35 and floor<=49
 if run.campaign~=true or not allowed then
  return nil,'event_constructor_unavailable'
 end
 local definition=encounter(source);if not definition then return nil,'event_encounter_unavailable'end
 local room=roomStreams(run,floor);room.miscRng=R.cloneState(misc or run.miscRng)
 local prepared=C.prepareEncounter(run.data,roomOptions(room,definition))
 return {version=1,source=source,floor=floor,runSeed=run.runSeed,roomSeed=room.seed,prepared=prepared}
end
local function validRequest(flow,request)
 if type(request)~='table'or getmetatable(request)~=nil or request.roomClass~='event'then return false end
 if type(request.gold)~='number'or request.gold%1~=0 then return false end
 if flow.event.id=='mushrooms'then
  return request.sourceEncounter=='The Mushroom Lair'and request.gold>=20 and request.gold<=30
   and(request.fixedRelicId=='odd_mushroom'or request.fixedRelicId=='circlet')and request.relicTier==nil
 end
 if request.relicTier~='rare'or request.fixedRelicId~=nil then return false end
 if flow.event.id=='mysterious_sphere'then
  return request.sourceEncounter=='2 Orb Walkers'and request.gold>=45 and request.gold<=55
 end
 return flow.event.id=='mind_bloom'and bosses[request.sourceEncounter]==true and request.gold==50
end
local function preparedFor(run,flow,request,roomStreams)
 local prepared=flow.event.preparedCombat
 if not prepared and(flow.event.id=='mysterious_sphere'or flow.event.id=='mushrooms')then return nil,'event_constructor_missing'end
 if not prepared then prepared=M.prepare(run,request.sourceEncounter,run.floor,roomStreams)end
 if type(prepared)~='table'or prepared.version~=1 or prepared.source~=request.sourceEncounter
  or prepared.floor~=run.floor or prepared.runSeed~=run.runSeed
  or prepared.roomSeed~=roomStreams(run,run.floor).seed then return nil,'event_constructor_mismatch'end
 return prepared
end
function M.start(run,flow,api,startEncounter)
 if flow and flow.event and Routes.supportsEvent(flow.event.id)then return Routes.start(run,flow,api,startEncounter)end
 if run.phase~='node'or type(flow)~='table'or flow~=run.nodeFlow or flow.type~='event'or flow.complete then return false,'event_combat_unavailable'end
 local request=flow.event and flow.event.combatRequest
 if not validRequest(flow,request)then return false,'invalid_event_combat_request'end
 if flow.event.id=='mushrooms'and(run.act~=1 or run.floor<7 or run.floor>14)then return false,'event_combat_unavailable'end
 local prepared,why=preparedFor(run,flow,request,api.roomStreams);if not prepared then return false,why end
 -- Source creates actors, then GOLD, then a fixed SPECIAL or drawn RARE.
 local gold=Gold.offerAmount(request.gold,run)
 local offer,pool
 if flow.event.id=='mushrooms'then
  local expected=Hooks.owns(run,'odd_mushroom')and'circlet'or'odd_mushroom'
  if request.fixedRelicId~=expected then return false,'event_reward_mismatch'end
  for _,def in ipairs(run.data.relics.relics)do
   if def.id==expected and def.rarity=='special'then offer={id=def.id,sourceId=def.sourceId,tier='special'}end
  end
  if not offer then return false,'event_relic_unavailable'end
  pool=run.relicPool -- Fixed SPECIAL never consumes a source rarity/queue draw.
 else offer,pool=api.prepareRelic(run,{tier='rare',room='event',screenless=flow.event.id=='mysterious_sphere'})end
 if not offer then return false,pool end
 local room=api.roomStreams(run,run.floor)
 room.miscRng=R.cloneState(run.miscRng)
 room.monsterHpRng=R.restore(prepared.prepared.monsterHpRng)
 room.preparedEncounter=prepared.prepared
 run.phase,run.relicPool='map',pool
 local called,ok,reason=pcall(startEncounter,run,encounter(request.sourceEncounter),room)
 if not called or not ok then return false,called and reason or 'event_combat_unavailable'end
 run.eventCombat={eventId=flow.event.id,source=request.sourceEncounter,encounterId=run.encounterId,
  floor=run.floor,runSeed=run.runSeed,combatGeneration=run.combatGeneration,
  gold=gold,relics={{id=offer.id,sourceId=offer.sourceId,rarity=offer.tier,
   requestedId=offer.requestedId,requestedTier=offer.tier,trace=offer.trace,claimed=false}}}
 flow.event.preparedCombat=prepared
 flow.eventCombat,flow.encounterId,flow.encounterSource=true,run.encounterId,request.sourceEncounter
 return true,'combat'
end
local function ownerMatches(run)
 local context,flow,battle=run.eventCombat,run.nodeFlow,run.combat
 if type(context)~='table'or not flow or flow.type~='event'or not flow.eventCombat or not flow.event
  or flow.event.id~=context.eventId or context.encounterId~=run.encounterId or flow.encounterId~=run.encounterId
  or context.runSeed~=run.runSeed or context.floor~=run.floor
  or context.combatGeneration~=run.combatGeneration or battle.combatGeneration~=run.combatGeneration then
  return false
 end
 return true
end
function M.finish(run)
 if run.eventCombat and Routes.supportsEvent(run.eventCombat.eventId)then return Routes.finish(run)end
 if not ownerMatches(run)then return nil,'event_combat_owner_mismatch'end
 local context=run.eventCombat
 -- Preserve pre-created GOLD/RARE, then source EventRoom potion and card order.
 local potion,potionRng,modifier=Potion.prepare(run,2,{allEscaped=false})
 Potion.commit(run,potionRng,modifier)
 local choices,cardRng,offset,upgrades=Cards.prepareRewards(run)
 run.cardRng,run.cardRarityOffset=cardRng,offset
 local rewards={gold=context.gold,goldClaimed=context.gold==0,relics=C.copy(context.relics),
  cards=choices,cardUpgrades=upgrades,potion=potion,cardResolved=false,manualContinue=true}
 Hooks.previewCardReward(run,rewards,true)
 return rewards
end
function M.escape(run)
 if run.eventCombat and Routes.supportsEvent(run.eventCombat.eventId)then return Routes.escape(run)end
 if not ownerMatches(run)then return false,'event_combat_owner_mismatch'end
 -- A smoke screen discards all offers. EventRoom still attempts a potion,
 -- without a card reward or an all-monsters-escaped zero-chance override.
 local _,potionRng,modifier=Potion.prepare(run,2,{allEscaped=false})
 Potion.commit(run,potionRng,modifier)
 run.eventCombat=nil
 return true
end
return M
